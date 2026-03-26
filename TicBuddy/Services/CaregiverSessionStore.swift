// TicBuddy — CaregiverSessionStore.swift
// Tracks first-time caregiver onboarding state (tb-mvp2-028).
//
// Once the caregiver completes the Ziggy onboarding session,
// hasCompletedOnboarding is set to true and never triggered again.
// Stored in UserDefaults — survives app restart; cleared on dataService.reset().

import Foundation

@MainActor
final class CaregiverSessionStore: ObservableObject {
    static let shared = CaregiverSessionStore()
    private init() {}

    private let key = "ticbuddy_caregiver_onboarding_complete"

    /// False on first family setup completion. Set to true when the caregiver
    /// finishes (or explicitly skips) the Ziggy onboarding session.
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    /// Resets onboarding state — call from Settings "Reset family data" or test helpers.
    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        objectWillChange.send()
    }
}
