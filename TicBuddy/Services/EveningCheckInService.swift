// TicBuddy — EveningCheckInService.swift
// Evening check-in sync service (tb-mvp2-018).
//
// Schedules a local notification reminding the caregiver to log today's
// CBIT practice session. All scheduling is on-device — no server involved.
//
// Behaviour:
//   • Default reminder time: 8:00 PM daily (caregiver-configurable)
//   • Fires only if practice hasn't been logged today (checked via shared UserDefaults)
//   • In-app: CaregiverHomeView reads `shouldShowEveningPrompt` to show a soft banner
//   • Notification: deep-links to the app (no custom URL needed — just opens app)
//   • Permission requested lazily on first enable, never re-requested if denied
//
// COPPA note: zero data leaves the device. Notifications are scheduled locally.

import Foundation
import UserNotifications

// MARK: - Evening Check-In Service

@MainActor
final class EveningCheckInService: ObservableObject {
    static let shared = EveningCheckInService()

    // MARK: State

    /// Whether the daily evening reminder is enabled.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Keys.isEnabled)
            if isEnabled {
                Task { await scheduleIfPermitted() }
            } else {
                cancelScheduled()
            }
        }
    }

    /// Hour of day for the reminder (24h). Default 20 = 8 PM.
    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: Keys.reminderHour)
            if isEnabled { Task { await reschedule() } }
        }
    }

    /// Minute of the reminder. Default 0 = :00.
    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: Keys.reminderMinute)
            if isEnabled { Task { await reschedule() } }
        }
    }

    /// Whether permission was denied — used to show a settings-redirect in UI.
    @Published var permissionDenied: Bool = false

    // MARK: Constants

    private enum Keys {
        static let isEnabled     = "ticbuddy_evening_enabled"
        static let reminderHour  = "ticbuddy_evening_hour"
        static let reminderMinute = "ticbuddy_evening_minute"
    }

    private let notificationID = "ticbuddy.evening.checkin"
    private let center = UNUserNotificationCenter.current()

    // MARK: Init

    private init() {
        self.isEnabled      = UserDefaults.standard.bool(forKey: Keys.isEnabled)
        self.reminderHour   = UserDefaults.standard.object(forKey: Keys.reminderHour) as? Int ?? 20
        self.reminderMinute = UserDefaults.standard.object(forKey: Keys.reminderMinute) as? Int ?? 0
    }

    // MARK: - In-App Prompt

    /// Returns true when it's past the reminder hour AND today's practice hasn't been logged.
    /// CaregiverHomeView reads this to decide whether to show an in-app soft banner.
    func shouldShowEveningPrompt(practiceCalendar: [String: PracticeStatus]) -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= reminderHour else { return false }
        let todayKey = todayCalendarKey()
        return practiceCalendar[todayKey] == nil
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

    /// Current authorization status (non-async).
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Scheduling

    /// Requests permission if needed, then schedules the daily reminder.
    func scheduleIfPermitted() async {
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

    /// Cancels existing notification and reschedules (used when time changes).
    func reschedule() async {
        cancelScheduled()
        await scheduleIfPermitted()
    }

    /// Schedules (or replaces) the daily evening check-in notification.
    private func scheduleNotification() {
        // Cancel any existing before re-adding
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let content = UNMutableNotificationContent()
        content.title = "Practice check-in 💙"
        content.body = "Did you complete today's CBIT practice? Tap to log it before the day ends."
        content.sound = .default
        content.categoryIdentifier = "EVENING_CHECKIN"

        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[EveningCheckIn] Failed to schedule: \(error.localizedDescription)")
            }
        }
    }

    /// Removes the scheduled notification without disabling the service.
    func cancelScheduled() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    // MARK: - Helpers

    private func todayCalendarKey() -> String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }

    /// Human-readable time string for display in settings (e.g. "7:00 PM").
    var formattedTime: String {
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        guard let date = Calendar.current.date(from: components) else { return "\(reminderHour):00" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
