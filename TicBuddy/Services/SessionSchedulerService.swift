// TicBuddy — SessionSchedulerService.swift
// tb-mvp2-096 + tb-mvp2-097 + tb-optC-addendum: Weekly session scheduling + 5 notification types.
//
// For a user who picks e.g. Wednesday at 3:00 PM:
//   • Tuesday  @ 3:00 PM  — day-before reminder  ("Your session is tomorrow...")
//   • Wednesday @ 2:55 PM  — 5-min warning         ("starts in 5 minutes ⏱️")
//   • Wednesday @ 3:00 PM  — session start          ("Time for your session! 🎯")
//
// Lesson-unlock notifications are one-shot (timeInterval trigger) via scheduleLessonUnlock(lessonNumber:).
// Permission is requested lazily when the user first saves a schedule.
// Re-schedules automatically when weekday or time changes.

import Foundation
import UserNotifications

// MARK: - Session Scheduler Service

@MainActor
final class SessionSchedulerService: ObservableObject {
    static let shared = SessionSchedulerService()

    // MARK: - Published State

    /// Calendar weekday integer (1=Sunday … 7=Saturday). 0 means no schedule set.
    @Published var scheduledWeekday: Int {
        didSet { UserDefaults.standard.set(scheduledWeekday, forKey: Keys.weekday) }
    }

    /// Hour of day (24h) for the weekly session. Default 10 = 10 AM.
    @Published var scheduledHour: Int {
        didSet { UserDefaults.standard.set(scheduledHour, forKey: Keys.hour) }
    }

    /// Minute of the session. Default 0 = :00.
    @Published var scheduledMinute: Int {
        didSet { UserDefaults.standard.set(scheduledMinute, forKey: Keys.minute) }
    }

    /// Whether notification permission was denied — used to show a settings-redirect in UI.
    @Published var permissionDenied: Bool = false

    // MARK: - Computed

    /// True when the user has configured a weekly session schedule.
    var hasSchedule: Bool { scheduledWeekday > 0 }

    /// Human-readable schedule label shown in SettingsView.
    var formattedSchedule: String {
        guard hasSchedule else { return "" }
        let dayName = Calendar.current.weekdaySymbols[scheduledWeekday - 1]
        var comps = DateComponents()
        comps.hour   = scheduledHour
        comps.minute = scheduledMinute
        guard let date = Calendar.current.date(from: comps) else { return dayName }
        let tf = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        return "\(dayName) at \(tf.string(from: date)) · reminder the day before"
    }

    // MARK: - Constants

    private enum Keys {
        static let weekday = "ticbuddy_session_weekday"
        static let hour    = "ticbuddy_session_hour"
        static let minute  = "ticbuddy_session_minute"
    }

    /// All notification IDs managed by this service (for bulk cancel).
    private enum NotifID {
        static let dayBefore = "ticbuddy.session.daybefore"
        static let dayOf     = "ticbuddy.session.dayof"
        static let warning   = "ticbuddy.session.warning"
        static func lessonUnlock(_ n: Int) -> String { "ticbuddy.lesson.unlock.\(n)" }
    }

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    private init() {
        self.scheduledWeekday = UserDefaults.standard.object(forKey: Keys.weekday) as? Int ?? 0
        self.scheduledHour    = UserDefaults.standard.object(forKey: Keys.hour)    as? Int ?? 10
        self.scheduledMinute  = UserDefaults.standard.object(forKey: Keys.minute)  as? Int ?? 0
    }

    // MARK: - Permission

    /// Requests notification permission. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionDenied = !granted
            return granted
        } catch {
            permissionDenied = true
            return false
        }
    }

    private func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Public API

    /// Saves the user's chosen day/time and schedules all weekly notifications.
    func saveSchedule(weekday: Int, hour: Int, minute: Int) async {
        scheduledWeekday = weekday
        scheduledHour    = hour
        scheduledMinute  = minute
        await scheduleIfPermitted()
    }

    /// Cancels all session notifications and reschedules with current stored values.
    func reschedule() async {
        cancelAllSessionNotifications()
        await scheduleIfPermitted()
    }

    /// Removes all pending session notifications (day-before, day-of, 5-min warning).
    func cancelAllSessionNotifications() {
        center.removePendingNotificationRequests(withIdentifiers: [
            NotifID.dayBefore, NotifID.dayOf, NotifID.warning
        ])
    }

    // MARK: - Lesson Unlock (One-Shot)

    /// Schedules a one-shot notification for when a new CBIT lesson unlocks.
    /// Call this from wherever session completion is recorded.
    /// - Parameters:
    ///   - lessonNumber: The lesson number that just unlocked (shown in message body).
    ///   - delay: Seconds from now before the notification fires. Default 2 s (fires nearly immediately).
    nonisolated static func scheduleLessonUnlock(lessonNumber: Int, delay: TimeInterval = 2) {
        let content = UNMutableNotificationContent()
        content.title = "Lesson \(lessonNumber) is ready for you! 📖"
        content.body  = "Your next TicBuddy session is unlocked — tap to continue."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(
            identifier: NotifID.lessonUnlock(lessonNumber),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("[SessionScheduler] Lesson unlock notif failed: \(error.localizedDescription)") }
        }
    }

    // MARK: - Private Scheduling

    private func scheduleIfPermitted() async {
        guard hasSchedule else { return }
        let status = await checkAuthorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await requestPermission()
            if granted { scheduleAllSessionNotifications() }
        case .authorized, .provisional, .ephemeral:
            scheduleAllSessionNotifications()
        case .denied:
            permissionDenied = true
        @unknown default:
            break
        }
    }

    /// Schedules all three weekly session notifications for the current stored schedule.
    private func scheduleAllSessionNotifications() {
        scheduleDayBeforeNotification()
        scheduleDayOfNotification()
        scheduleWarningNotification()
    }

    // MARK: Day-Before Reminder

    private func scheduleDayBeforeNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotifID.dayBefore])
        let content = UNMutableNotificationContent()
        content.title = "Your TicBuddy session is tomorrow — find a quiet 15 min 🧠"
        content.body  = "Tap to open TicBuddy."
        content.sound = .default
        // Fire the evening before (same clock time, one weekday earlier; Sunday=1 wraps to Saturday=7)
        let reminderWeekday = scheduledWeekday == 1 ? 7 : scheduledWeekday - 1
        var comps = DateComponents()
        comps.weekday = reminderWeekday
        comps.hour    = scheduledHour
        comps.minute  = scheduledMinute
        add(content: content, components: comps, id: NotifID.dayBefore)
    }

    // MARK: Day-Of Session Start

    private func scheduleDayOfNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotifID.dayOf])
        let content = UNMutableNotificationContent()
        content.title = "Time for your TicBuddy session! Find a quiet spot 🎯"
        content.body  = "Tap to start your session."
        content.sound = .default
        var comps = DateComponents()
        comps.weekday = scheduledWeekday
        comps.hour    = scheduledHour
        comps.minute  = scheduledMinute
        add(content: content, components: comps, id: NotifID.dayOf)
    }

    // MARK: 5-Minute Warning

    private func scheduleWarningNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [NotifID.warning])
        let content = UNMutableNotificationContent()
        content.title = "Your TicBuddy session starts in 5 minutes ⏱️"
        content.body  = "Find a quiet spot and get ready."
        content.sound = .default
        // Subtract 5 minutes, with proper hour rollback
        let totalMinutes = scheduledHour * 60 + scheduledMinute - 5
        let warnHour   = (totalMinutes / 60 + 24) % 24   // guard against negative wrap
        let warnMinute = ((totalMinutes % 60) + 60) % 60
        // If subtracting 5 min crosses midnight backward, the weekday also rolls back
        let warnWeekday: Int
        if totalMinutes < 0 {
            // Rolled back past midnight — previous calendar day
            warnWeekday = scheduledWeekday == 1 ? 7 : scheduledWeekday - 1
        } else {
            warnWeekday = scheduledWeekday
        }
        var comps = DateComponents()
        comps.weekday = warnWeekday
        comps.hour    = warnHour
        comps.minute  = warnMinute
        add(content: content, components: comps, id: NotifID.warning)
    }

    // MARK: Helper

    private func add(content: UNMutableNotificationContent, components: DateComponents, id: String) {
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request) { error in
            if let error { print("[SessionScheduler] Failed to schedule '\(id)': \(error.localizedDescription)") }
        }
    }
}
