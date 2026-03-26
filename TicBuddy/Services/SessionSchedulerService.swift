// TicBuddy — SessionSchedulerService.swift
// tb-mvp2-096 + tb-mvp2-097: Weekly session scheduling + UNUserNotificationCenter reminders.
//
// User picks a day of week + time → stored in UserDefaults → weekly repeating
// UNCalendarNotificationTrigger fires every 7 days at the chosen time.
// Notification copy: "Time for your TicBuddy session! 🧠 Tap to start."
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

    /// Hour of day (24h) for the weekly reminder. Default 10 = 10 AM.
    @Published var scheduledHour: Int {
        didSet { UserDefaults.standard.set(scheduledHour, forKey: Keys.hour) }
    }

    /// Minute of the reminder. Default 0 = :00.
    @Published var scheduledMinute: Int {
        didSet { UserDefaults.standard.set(scheduledMinute, forKey: Keys.minute) }
    }

    /// Whether notification permission was denied — used to show a settings-redirect in UI.
    @Published var permissionDenied: Bool = false

    // MARK: - Computed

    /// True when the user has configured a weekly session schedule.
    var hasSchedule: Bool { scheduledWeekday > 0 }

    /// Human-readable schedule label, e.g. "Sunday at 2:00 PM".
    var formattedSchedule: String {
        guard hasSchedule else { return "" }
        // Calendar.weekdaySymbols is 0-indexed; Calendar weekday is 1-indexed
        let dayName = Calendar.current.weekdaySymbols[scheduledWeekday - 1]
        var comps = DateComponents()
        comps.hour = scheduledHour
        comps.minute = scheduledMinute
        guard let date = Calendar.current.date(from: comps) else { return dayName }
        let tf = DateFormatter()
        tf.timeStyle = .short
        tf.dateStyle = .none
        return "\(dayName) at \(tf.string(from: date))"
    }

    // MARK: - Constants

    private enum Keys {
        static let weekday = "ticbuddy_session_weekday"
        static let hour    = "ticbuddy_session_hour"
        static let minute  = "ticbuddy_session_minute"
    }

    private let notificationID = "ticbuddy.weekly.session"
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

    /// Saves the user's chosen day/time and schedules the weekly notification.
    /// Call this from SessionSchedulerView when the user taps "Set Weekly Reminder".
    func saveSchedule(weekday: Int, hour: Int, minute: Int) async {
        scheduledWeekday = weekday
        scheduledHour    = hour
        scheduledMinute  = minute
        await scheduleIfPermitted()
    }

    /// Cancels existing notification and reschedules with current stored values.
    /// Call this when the user updates their schedule from Settings.
    func reschedule() async {
        cancelNotification()
        await scheduleIfPermitted()
    }

    /// Removes the pending weekly session notification.
    func cancelNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: - Private Scheduling

    private func scheduleIfPermitted() async {
        guard hasSchedule else { return }
        let status = await checkAuthorizationStatus()
        switch status {
        case .notDetermined:
            let granted = await requestPermission()
            if granted { scheduleNotification() }
        case .authorized, .provisional, .ephemeral:
            scheduleNotification()
        case .denied:
            permissionDenied = true
        @unknown default:
            break
        }
    }

    private func scheduleNotification() {
        // Remove any existing before re-adding (prevents duplicates on reschedule)
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let content = UNMutableNotificationContent()
        content.title = "Time for your TicBuddy session! 🧠"
        content.body  = "Tap to start."
        content.sound = .default

        // weekday + hour + minute with repeats: true → fires every 7 days at this time
        var components = DateComponents()
        components.weekday = scheduledWeekday
        components.hour    = scheduledHour
        components.minute  = scheduledMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[SessionScheduler] Failed to schedule: \(error.localizedDescription)")
            }
        }
    }
}
