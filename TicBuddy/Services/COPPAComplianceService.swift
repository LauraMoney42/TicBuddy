// TicBuddy — COPPAComplianceService.swift
// Extends COPPAConsentService with runtime compliance enforcement (tb-mvp2-014).
//
// Design decisions (approved 2026-03-24):
//   1. Parental consent  — checkbox acknowledgment (handled by COPPAConsentService)
//   2. Data retention    — auto-delete under-13 after 30 days inactivity (this file)
//   3. API logging       — UUID-only already sufficient; no changes needed
//   4. Notifications     — immediate notification when child logs tic + weekly digest (this file)
//
// COPPAConsentService.swift handles the consent record / storage.
// This file adds: activity tracking, auto-delete enforcement, and caregiver notifications.

import Foundation
import UserNotifications

// MARK: - Activity Tracking Extension

extension COPPAConsentService {

    private func lastActiveKey(_ childID: UUID) -> String {
        "coppa_last_active_\(childID.uuidString)"
    }

    /// Records that the child is actively using the app right now.
    /// Call on every profile switch into child mode.
    func recordActivity(for childID: UUID) {
        UserDefaults.standard.set(Date(), forKey: lastActiveKey(childID))
    }

    /// Returns the last recorded activity date for this child profile.
    func lastActive(for childID: UUID) -> Date? {
        UserDefaults.standard.object(forKey: lastActiveKey(childID)) as? Date
    }

    /// Days since the child last used the app. nil if no activity ever recorded.
    func daysSinceLastActive(for childID: UUID) -> Int? {
        guard let last = lastActive(for: childID) else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
}

// MARK: - Auto-Delete Enforcement (30-day inactivity rule)

extension COPPAConsentService {

    /// Scans all under-13 child profiles and purges any inactive ≥30 days.
    /// Also purges profiles where consent has expired (consent grace period elapsed).
    /// Called from TicDataService.loadAll() on every app launch.
    @MainActor func checkAndPurgeInactiveUnder13(dataService: TicDataService) {
        let under13 = dataService.familyUnit.children.filter { $0.ageGroup.isCOPPAApplicable }
        var didPurge = false

        for child in under13 {
            let shouldPurge: Bool
            if let days = daysSinceLastActive(for: child.id), days >= 30 {
                // Inactive for 30+ days
                shouldPurge = true
            } else if isExpired(for: child.id) {
                // Consent grace period elapsed without confirmation
                shouldPurge = true
            } else {
                shouldPurge = false
            }

            if shouldPurge {
                purgeChildData(child.id, dataService: dataService)
                didPurge = true
            }
        }

        if didPurge { dataService.saveFamilyUnit() }
    }

    /// Permanently removes all on-device data for one child profile.
    @MainActor func purgeChildData(_ childID: UUID, dataService: TicDataService) {
        // Tic entries
        UserDefaults.standard.removeObject(forKey: "ticbuddy_entries_\(childID.uuidString)")
        // Adolescent journal
        UserDefaults.standard.removeObject(forKey: "teen_journal_\(childID.uuidString)")
        // Activity tracking key
        UserDefaults.standard.removeObject(forKey: "coppa_last_active_\(childID.uuidString)")
        // Session memories (Claude Dream extracts — tb-mvp2-019)
        UserDefaults.standard.removeObject(forKey: "ticbuddy_session_memory_\(childID.uuidString)")
        // Consent record
        deleteRecord(for: childID)
        // Keychain PIN
        _ = FamilyPINService.shared.deleteChildPIN(profileID: childID)
        // Remove from family unit
        dataService.familyUnit.children.removeAll { $0.id == childID }
        if dataService.familyUnit.activeChildID == childID {
            dataService.familyUnit.activeChildID = dataService.familyUnit.children.first?.id
        }
    }
}

// MARK: - Caregiver Notification Extension

extension COPPAConsentService {

    private var center: UNUserNotificationCenter { .current() }
    private var weeklyDigestID: String { "ticbuddy.coppa.weekly_digest" }

    /// Fires an immediate local notification to the caregiver when an under-13 child logs a tic.
    /// Fires 2 seconds after the log to allow child mode UI to settle first.
    func notifyCaregiver(childName: String, outcome: TicOutcome) {
        let content = UNMutableNotificationContent()
        content.title = "\(childName) just logged a tic 💙"
        content.body = caregiverNotificationBody(childName: childName, outcome: outcome)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(
            identifier: "ticbuddy.coppa.activity.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        center.add(request) { _ in }
    }

    private func caregiverNotificationBody(childName: String, outcome: TicOutcome) -> String {
        switch outcome {
        case .redirected:   return "\(childName) redirected a tic using their competing response! 🌟"
        case .caught:       return "\(childName) caught an urge before the tic. Great awareness! ⚡️"
        case .noticed:      return "\(childName) noticed and logged a tic. Building awareness. 👀"
        case .ticHappened:  return "\(childName) logged a tic. Staying consistent with tracking! 📋"
        }
    }

    /// Schedules a repeating weekly Sunday 9 AM digest notification for the caregiver.
    func scheduleWeeklyDigest() {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyDigestID])

        let content = UNMutableNotificationContent()
        content.title = "Weekly CBIT summary 📊"
        content.body = "Check this week's tic log and practice calendar in TicBuddy."
        content.sound = .default

        var components = DateComponents()
        components.weekday = 1   // Sunday
        components.hour = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyDigestID, content: content, trigger: trigger)
        center.add(request) { _ in }
    }

    /// Requests notification permission (if not yet determined) then schedules weekly digest.
    func setupCaregiverNotifications() async {
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .notDetermined:
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            scheduleWeeklyDigest()
        case .authorized, .provisional, .ephemeral:
            scheduleWeeklyDigest()
        default:
            break
        }
    }
}

/// Backward-compat alias — any code that already references COPPAComplianceService still compiles.
typealias COPPAComplianceService = COPPAConsentService
