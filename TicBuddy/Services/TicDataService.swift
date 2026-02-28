// TicBuddy — TicDataService.swift
// Persistence layer for tic logs and user profile via UserDefaults.

import Foundation
import Combine

@MainActor
class TicDataService: ObservableObject {
    static let shared = TicDataService()

    @Published var ticEntries: [TicEntry] = []
    @Published var userProfile: UserProfile = UserProfile()

    private let entriesKey = "ticbuddy_entries"
    private let profileKey = "ticbuddy_profile"

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

    // MARK: - Tic Entry CRUD

    func addTicEntry(_ entry: TicEntry) {
        ticEntries.insert(entry, at: 0)
        saveEntries()
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

    // MARK: - Quick Log (from chat intent)

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
