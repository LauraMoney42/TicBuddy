// TicBuddy — FamilyPINService.swift
// Manages PIN storage and biometric authentication for all Family Unit profiles.
//
// Security model:
//   - PINs are stored in Keychain, keyed by profile UUID
//   - PIN values never appear in model structs or UserDefaults
//   - Adolescent PINs flagged private — caregiver cannot read via this service
//   - Biometric auth (Face ID / Touch ID) used for caregiver unlock on single-device model

import Foundation
import LocalAuthentication

final class FamilyPINService: @unchecked Sendable {
    static let shared = FamilyPINService()
    private init() {}

    // MARK: - Keychain Key Helpers

    private func caregiverPINKey(_ profileID: UUID) -> String {
        "ticbuddy_caregiver_pin_\(profileID.uuidString)"
    }

    private func childPINKey(_ profileID: UUID) -> String {
        "ticbuddy_child_pin_\(profileID.uuidString)"
    }

    // MARK: - Caregiver PIN

    @discardableResult
    func saveCaregiverPIN(_ pin: String, profileID: UUID) -> Bool {
        KeychainHelper.save(key: caregiverPINKey(profileID), value: pin)
    }

    func verifyCaregiverPIN(_ pin: String, profileID: UUID) -> Bool {
        guard let stored = KeychainHelper.read(key: caregiverPINKey(profileID)) else { return false }
        return stored == pin
    }

    func caregiverHasPIN(profileID: UUID) -> Bool {
        guard let stored = KeychainHelper.read(key: caregiverPINKey(profileID)) else { return false }
        return !stored.isEmpty
    }

    @discardableResult
    func deleteCaregiverPIN(profileID: UUID) -> Bool {
        KeychainHelper.delete(key: caregiverPINKey(profileID))
    }

    // MARK: - Child PIN

    @discardableResult
    func saveChildPIN(_ pin: String, profileID: UUID) -> Bool {
        KeychainHelper.save(key: childPINKey(profileID), value: pin)
    }

    func verifyChildPIN(_ pin: String, profileID: UUID) -> Bool {
        guard let stored = KeychainHelper.read(key: childPINKey(profileID)) else { return false }
        return stored == pin
    }

    func childHasPIN(profileID: UUID) -> Bool {
        guard let stored = KeychainHelper.read(key: childPINKey(profileID)) else { return false }
        return !stored.isEmpty
    }

    @discardableResult
    func deleteChildPIN(profileID: UUID) -> Bool {
        KeychainHelper.delete(key: childPINKey(profileID))
    }

    // MARK: - PIN Reset Flow
    //
    // Adolescent PIN reset: routes through family unit email with notification to parent
    // (content not shown — only that a reset occurred). This is handled at the service layer
    // by clearing the old PIN and flagging that a reset notification should be sent.

    func resetChildPIN(profileID: UUID, ageGroup: AgeGroup) {
        deleteChildPIN(profileID: profileID)
        if ageGroup.childPINIsPrivate {
            // TODO (V2): trigger family unit email notification that reset occurred
            // Parent sees: "PIN was reset on [date]" — not the new PIN
        }
    }

    // MARK: - Biometric Authentication (Caregiver)
    //
    // Used when switching back to caregiver mode on a single-device configuration.
    // Face ID / Touch ID is preferred; PIN fallback if biometrics unavailable.

    /// Async biometric auth for caregiver mode unlock.
    /// Returns true on success. Caller should fall back to PIN entry if false.
    @MainActor
    func authenticateCaregiverBiometric(reason: String = "Unlock caregiver view") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Biometrics not available (no Face ID / Touch ID enrolled, or simulator)
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            // User cancelled, or biometric match failed
            return false
        }
    }

    /// Callback-based biometric auth for use in non-async contexts
    func authenticateCaregiverBiometric(
        reason: String = "Unlock caregiver view",
        completion: @escaping @Sendable (_ success: Bool) -> Void
    ) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Task { @MainActor in completion(false) }
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, _ in
            Task { @MainActor in completion(success) }
        }
    }

    /// Returns true if this device supports Face ID or Touch ID
    var biometricAuthAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Returns the biometric type available on this device (.faceID, .touchID, or .none)
    var biometricType: LABiometryType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType
    }
}
