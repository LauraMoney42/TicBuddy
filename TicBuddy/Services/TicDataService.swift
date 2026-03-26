// TicBuddy — TicDataService.swift
// Persistence layer for tic logs, user profile, and family unit via UserDefaults.
//
// Architecture note:
//   - familyUnit is the new top-level entity (V2 multi-profile model)
//   - userProfile / ticEntries are preserved for backward compatibility
//     and are used as the active child's data when in family unit mode
//   - When a child profile is active, activeChildUserProfile bridges
//     the family unit to the existing single-profile view layer

import Foundation
import Combine

@MainActor
class TicDataService: ObservableObject {
    static let shared = TicDataService()

    @Published var ticEntries: [TicEntry] = []
    @Published var userProfile: UserProfile = UserProfile()
    /// The family unit — populated during new onboarding flow (V2)
    @Published var familyUnit: FamilyUnit = FamilyUnit()

    private let entriesKey      = "ticbuddy_entries"
    private let profileKey      = "ticbuddy_profile"
    private let familyUnitKey   = "ticbuddy_family_unit"

    // Per-child tic entries are keyed by child profile UUID
    private func childEntriesKey(_ childID: UUID) -> String {
        "ticbuddy_entries_\(childID.uuidString)"
    }

    init() {
        loadAll()
    }

    // MARK: - Load

    func loadAll() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let entries = try? JSONDecoder().decode([TicEntry].self, from: data) {
            ticEntries = entries
        }
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            userProfile = profile
        }
        if let data = UserDefaults.standard.data(forKey: familyUnitKey),
           let unit = try? JSONDecoder().decode(FamilyUnit.self, from: data) {
            familyUnit = unit
        }
        // tb-mvp2-014: Purge under-13 profiles inactive ≥30 days (COPPA auto-delete)
        COPPAComplianceService.shared.checkAndPurgeInactiveUnder13(dataService: self)
    }

    // MARK: - Save

    func saveEntries() {
        if let data = try? JSONEncoder().encode(ticEntries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    func saveProfile() {
        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }

    func saveFamilyUnit() {
        if let data = try? JSONEncoder().encode(familyUnit) {
            UserDefaults.standard.set(data, forKey: familyUnitKey)
        }
    }

    // MARK: - Tic Entry CRUD

    func addTicEntry(_ entry: TicEntry) {
        ticEntries.insert(entry, at: 0)
        saveEntries()
        // tb-mvp2-014: Notify caregiver when under-13 child logs a tic
        if let child = familyUnit.activeChild,
           [AgeGroup.veryYoung, .young, .olderChild].contains(child.ageGroup) {
            COPPAComplianceService.shared.notifyCaregiver(
                childName: child.displayName,
                outcome: entry.outcome
            )
        }
    }

    func deleteTicEntry(_ entry: TicEntry) {
        ticEntries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func updateTicEntry(_ entry: TicEntry) {
        if let idx = ticEntries.firstIndex(where: { $0.id == entry.id }) {
            ticEntries[idx] = entry
            saveEntries()
        }
    }

    // MARK: - Queries

    func entries(for date: Date) -> [TicEntry] {
        let calendar = Calendar.current
        return ticEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func entries(for dateRange: ClosedRange<Date>) -> [TicEntry] {
        ticEntries.filter { dateRange.contains($0.date) }
    }

    func totalTicsToday() -> Int {
        entries(for: Date()).count
    }

    func redirectionsToday() -> Int {
        entries(for: Date()).filter { $0.outcome == .redirected }.count
    }

    // Returns the day's "win" — best outcome of the day
    func bestOutcomeToday() -> TicOutcome? {
        let todayEntries = entries(for: Date())
        if todayEntries.contains(where: { $0.outcome == .redirected }) { return .redirected }
        if todayEntries.contains(where: { $0.outcome == .caught }) { return .caught }
        if todayEntries.contains(where: { $0.outcome == .noticed }) { return .noticed }
        return nil
    }

    // Streak: consecutive days with at least 1 log
    var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = Date()
        while true {
            let dayEntries = entries(for: checkDate)
            if dayEntries.isEmpty { break }
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        return streak
    }

    // MARK: - Profile Updates

    func updateProfile(_ profile: UserProfile) {
        userProfile = profile
        saveProfile()
    }

    /// Check if phase should advance and update if so
    func checkAndAdvancePhase() {
        let recommended = userProfile.recommendedPhase
        if recommended.rawValue > userProfile.currentPhase.rawValue {
            userProfile.currentPhase = recommended
            saveProfile()
        }
    }

    // MARK: - Reward Points (tb-mvp2-016)

    /// Awards `delta` points to the shared family reward total and persists.
    /// Returns `true` if a reward tier boundary was crossed (every 10 points),
    /// so child mode views can show a milestone celebration.
    /// Caregiver dashboard auto-updates because `familyUnit` is @Published.
    @discardableResult
    func awardPoints(_ delta: Int) -> Bool {
        guard delta > 0 else { return false }
        let before = familyUnit.sharedData.rewardPoints
        familyUnit.sharedData.rewardPoints += delta
        familyUnit.sharedData.lastModified = Date()
        saveFamilyUnit()
        // Tier = every 10 points. Did we cross a boundary?
        let tierBefore = before / 10
        let tierAfter  = familyUnit.sharedData.rewardPoints / 10
        return tierAfter > tierBefore
    }

    // MARK: - Evening Check-In (tb-mvp2-018)

    /// Stores the child's evening check-in summary in SharedFamilyData.
    /// PRIVACY: Only moodEmoji, energyLevel, and practiceDoneToday cross to the parent.
    /// Free-text journal entries and trigger notes are NEVER included here.
    func submitEveningCheckIn(_ summary: EveningCheckInSummary) {
        let key = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        familyUnit.sharedData.eveningCheckIns[key] = summary
        familyUnit.sharedData.lastModified = Date()
        saveFamilyUnit()
    }

    /// Returns today's evening check-in summary, or nil if not yet submitted.
    func todayEveningCheckIn() -> EveningCheckInSummary? {
        let key = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return familyUnit.sharedData.eveningCheckIns[key]
    }

    // MARK: - Quick Log (from chat intent)

    // MARK: - Family Unit Management

    /// Adds a caregiver profile to the family unit and persists.
    func addCaregiver(_ caregiver: CaregiverProfile) {
        familyUnit.caregivers.append(caregiver)
        saveFamilyUnit()
    }

    /// Updates an existing caregiver profile (e.g., after PIN is set).
    func updateCaregiver(_ caregiver: CaregiverProfile) {
        if let idx = familyUnit.caregivers.firstIndex(where: { $0.id == caregiver.id }) {
            familyUnit.caregivers[idx] = caregiver
            saveFamilyUnit()
        }
    }

    /// Adds a child profile to the family unit and persists.
    func addChild(_ child: ChildProfile) {
        familyUnit.children.append(child)
        saveFamilyUnit()
    }

    /// Updates an existing child profile (e.g., after onboarding completes or PIN changes).
    func updateChild(_ child: ChildProfile) {
        if let idx = familyUnit.childIndex(id: child.id) {
            familyUnit.children[idx] = child
            saveFamilyUnit()
        }
    }

    /// Switches the app into child mode for the given profile.
    /// Also loads that child's tic entries into the active ticEntries array.
    func switchToChild(_ childID: UUID) {
        guard familyUnit.childIndex(id: childID) != nil else { return }
        familyUnit.activeChildID = childID
        saveFamilyUnit()
        loadChildEntries(childID)
        // tb-mvp2-014: Record activity for COPPA 30-day inactivity tracking
        COPPAComplianceService.shared.recordActivity(for: childID)
    }

    /// Switches back to caregiver mode. Persists any pending child data first.
    func switchToCaregiverMode() {
        if let childID = familyUnit.activeChildID {
            saveChildEntries(childID)
        }
        familyUnit.activeChildID = nil
        saveFamilyUnit()
        // Reload legacy entries for single-user compatibility
        loadAll()
    }

    /// Returns the UserProfile for the currently active child, or the legacy userProfile.
    var activeUserProfile: UserProfile {
        familyUnit.activeChild?.userProfile ?? userProfile
    }

    /// Updates the active child's UserProfile within the family unit.
    func updateActiveChildProfile(_ profile: UserProfile) {
        guard let childID = familyUnit.activeChildID,
              let idx = familyUnit.childIndex(id: childID) else {
            // No active child — update legacy single-user profile
            updateProfile(profile)
            return
        }
        familyUnit.children[idx].userProfile = profile
        saveFamilyUnit()
    }

    // MARK: - Per-Child Tic Entry Persistence

    private func saveChildEntries(_ childID: UUID) {
        let key = childEntriesKey(childID)
        if let data = try? JSONEncoder().encode(ticEntries) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadChildEntries(_ childID: UUID) {
        let key = childEntriesKey(childID)
        if let data = UserDefaults.standard.data(forKey: key),
           let entries = try? JSONDecoder().decode([TicEntry].self, from: data) {
            ticEntries = entries
        } else {
            ticEntries = []
        }
    }

    // MARK: - Reset

    /// Clears all tic entries and resets program start date. API key in Keychain is preserved.
    func resetProgram() {
        ticEntries = []
        userProfile.programStartDate = Date()
        userProfile.currentPhase = .week1Awareness
        userProfile.hasCompletedOnboarding = false
        saveEntries()
        saveProfile()
    }

    // MARK: - Quick Log (from chat intent)

    func quickLog(intent: TicLogIntent) -> TicEntry {
        // Try to match known motor type
        let motorType = TicMotorType.allCases.first { $0.rawValue.lowercased().contains(intent.typeName.lowercased()) }
        let vocalType = TicVocalType.allCases.first { $0.rawValue.lowercased().contains(intent.typeName.lowercased()) }

        let entry = TicEntry(
            category: intent.category,
            motorType: motorType,
            vocalType: vocalType,
            customLabel: (motorType == nil && vocalType == nil) ? intent.typeName : nil,
            outcome: intent.outcome
        )
        addTicEntry(entry)
        return entry
    }
}
