// TicBuddy — COPPAConsentService.swift
// COPPA (Children's Online Privacy Protection Act) consent management (tb-mvp2-014).
//
// COPPA applies to all children under 13:
//   AgeGroup.veryYoung (4–6), .young (7–9), .olderChild (10–12)
//
// Consent flow:
//   1. During onboarding for an under-13 child, caregiver sees COPPAConsentSheet.
//   2. Caregiver reads disclosures, enters email, checks two acknowledgments.
//   3. COPPAConsentRecord is saved locally (UserDefaults, keyed by childID).
//   4. Consent is "pending" for 30 days — production would send email verification.
//      MVP2 stores locally; the email verification endpoint is a future backend task.
//   5. After 30 days without confirmation: data becomes eligible for deletion.
//   6. Caregiver can revoke at any time via Settings → Family → Delete Child's Data.
//
// What we collect (disclosed to caregiver):
//   - Tic types and counts (local only, never sent to any server)
//   - Nickname (local only)
//   - CBIT coaching session summaries (sent to Claude API as tic types only — no names)
//   - Private journal entries for teens (local only, never leaves device)
//
// What we do NOT collect:
//   - Full name, date of birth, location
//   - Behavioral analytics, advertising identifiers
//   - Persistent server-side identifiers for children
//
// Security bot recommendation (hub):
//   - Email consent gate → block cloud sync until confirmed
//   - 30-day delete if no confirmation
//   - Minimal PII to API (already enforced; add coppa_mode flag)
//   - No email notifications (avoids additional COPPA server-side obligations)

import Foundation

// MARK: - Consent Record

struct COPPAConsentRecord: Codable {
    let childID: UUID
    /// Caregiver-provided email for verification (stored locally only — not transmitted).
    let caregiverEmail: String
    /// When the caregiver first acknowledged the disclosures.
    let consentDate: Date
    /// True once caregiver has confirmed (MVP2: confirmed by checking both boxes and tapping Accept).
    /// Production: would require email link click to set this to true.
    var isConfirmed: Bool
    /// If revoked (right-to-be-forgotten requested), data deletion is pending.
    var isRevoked: Bool = false
    /// Checkboxes the caregiver confirmed.
    var acknowledgedDataCollection: Bool = false
    var acknowledgedNoThirdPartySharing: Bool = false
}

// MARK: - COPPA Consent Service

final class COPPAConsentService: @unchecked Sendable {
    static let shared = COPPAConsentService()
    private init() {}

    // MARK: - Constants

    /// COPPA applies to children strictly under 13.
    /// Maps to AgeGroups: veryYoung (4–6), young (7–9), olderChild (10–12).
    static func requiresCOPPA(_ ageGroup: AgeGroup) -> Bool {
        ageGroup.minimumAge < 13
    }

    /// Grace period: 30 days from consent date to email confirmation (COPPA §312.5).
    static let gracePeriodDays = 30

    // MARK: - Persistence Keys

    private func key(for childID: UUID) -> String {
        "coppa_consent_\(childID.uuidString)"
    }

    // MARK: - Read

    /// Returns the consent record for `childID`, or nil if no consent has been recorded.
    func record(for childID: UUID) -> COPPAConsentRecord? {
        guard let data = UserDefaults.standard.data(forKey: key(for: childID)),
              let record = try? JSONDecoder().decode(COPPAConsentRecord.self, from: data)
        else { return nil }
        return record
    }

    /// True if a valid, non-expired, non-revoked consent record exists.
    func hasValidConsent(for childID: UUID) -> Bool {
        guard let record = record(for: childID) else { return false }
        guard !record.isRevoked else { return false }
        if record.isConfirmed { return true }
        // Still within grace period
        let expiryDate = Calendar.current.date(byAdding: .day, value: Self.gracePeriodDays, to: record.consentDate) ?? record.consentDate
        return Date() < expiryDate
    }

    /// True if consent was recorded but the 30-day grace period has elapsed without confirmation.
    func isExpired(for childID: UUID) -> Bool {
        guard let record = record(for: childID), !record.isConfirmed, !record.isRevoked else { return false }
        let expiryDate = Calendar.current.date(byAdding: .day, value: Self.gracePeriodDays, to: record.consentDate) ?? record.consentDate
        return Date() >= expiryDate
    }

    /// Days remaining in the grace period. Returns 0 if expired or confirmed.
    func daysRemaining(for childID: UUID) -> Int {
        guard let record = record(for: childID), !record.isConfirmed else { return 0 }
        let expiryDate = Calendar.current.date(byAdding: .day, value: Self.gracePeriodDays, to: record.consentDate) ?? record.consentDate
        let remaining = Calendar.current.dateComponents([.day], from: Date(), to: expiryDate).day ?? 0
        return max(0, remaining)
    }

    // MARK: - Write

    /// Records initial consent when caregiver completes the COPPAConsentSheet.
    /// In MVP2, `isConfirmed = true` immediately (both checkboxes + tap = consent).
    /// Production: `isConfirmed = false` until email link clicked.
    func recordConsent(
        childID: UUID,
        caregiverEmail: String,
        acknowledgedDataCollection: Bool,
        acknowledgedNoThirdPartySharing: Bool
    ) {
        var record = COPPAConsentRecord(
            childID: childID,
            caregiverEmail: caregiverEmail,
            consentDate: Date(),
            // MVP2: both acknowledgments checked → confirmed immediately.
            // Production: set false and require email verification.
            isConfirmed: acknowledgedDataCollection && acknowledgedNoThirdPartySharing
        )
        record.acknowledgedDataCollection = acknowledgedDataCollection
        record.acknowledgedNoThirdPartySharing = acknowledgedNoThirdPartySharing
        save(record)
    }

    /// Marks consent as confirmed (called after email verification in production).
    func confirmConsent(for childID: UUID) {
        guard var record = record(for: childID) else { return }
        record.isConfirmed = true
        save(record)
    }

    /// Revokes consent and marks data for deletion (COPPA §312.6 right to be forgotten).
    /// Actual data deletion is performed by TicDataService.deleteChildData(_:).
    func revokeConsent(for childID: UUID) {
        guard var record = record(for: childID) else { return }
        record.isRevoked = true
        record.isConfirmed = false
        save(record)
    }

    /// Deletes the consent record entirely (called after child profile is deleted).
    func deleteRecord(for childID: UUID) {
        UserDefaults.standard.removeObject(forKey: key(for: childID))
    }

    // MARK: - Private

    private func save(_ record: COPPAConsentRecord) {
        if let data = try? JSONEncoder().encode(record) {
            UserDefaults.standard.set(data, forKey: key(for: record.childID))
        }
    }
}

// MARK: - AgeGroup COPPA Helpers

extension AgeGroup {
    /// True for children under 13 (veryYoung, young, olderChild).
    var isCOPPAApplicable: Bool {
        COPPAConsentService.requiresCOPPA(self)
    }
}
