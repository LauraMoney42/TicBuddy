// TicBuddy — UserProfile.swift
// Stores user setup info and CBIT program state.

import Foundation

// MARK: - CBIT Week Phase

enum CBITPhase: Int, Codable, CaseIterable {
    case week1Awareness = 1    // Just notice tics and urges
    case week2Competing = 2    // Introduce competing responses
    case week3Building = 3     // Build competing response fluency
    case week4Advanced = 4     // Function-based interventions
    case ongoing = 5           // Maintenance

    var title: String {
        switch self {
        case .week1Awareness: return "Week 1: Become a Tic Detective 🔍"
        case .week2Competing: return "Week 2: Learn Your Superpower 💪"
        case .week3Building: return "Week 3: Practice Makes Perfect ⭐️"
        case .week4Advanced: return "Week 4: Level Up! 🚀"
        case .ongoing: return "Ongoing: You're a Pro! 🏆"
        }
    }

    var description: String {
        switch self {
        case .week1Awareness:
            return "This week, your only job is to notice when a tic happens. Don't worry about stopping it — just be aware. You're training your brain to pay attention!"
        case .week2Competing:
            return "Now we're going to learn a special move — a competing response. When you feel the urge to tic, you'll do this move instead. Your brain will start to learn a new path!"
        case .week3Building:
            return "Keep using your competing response every time you feel the urge. The more you practice, the stronger the new brain pathway gets. You're literally rewiring your brain!"
        case .week4Advanced:
            return "Time to look at what makes tics worse — like stress or excitement — and make a plan for those times."
        case .ongoing:
            return "You've built amazing skills. Keep practicing and logging. Remember: every day you practice, your brain gets stronger!"
        }
    }

    var goalText: String {
        switch self {
        case .week1Awareness: return "Just notice your tics. Log every one you catch! 🕵️"
        case .week2Competing: return "Try your competing response at least once today!"
        case .week3Building: return "Use your competing response every time you notice the urge!"
        case .week4Advanced: return "Notice what triggers your tics and use your tools!"
        case .ongoing: return "Keep logging and practicing your competing responses!"
        }
    }
}

// MARK: - UserProfile

struct UserProfile: Codable {
    var id: UUID = UUID()
    var name: String = ""
    var age: Int = 10
    var programStartDate: Date = Date()
    var currentPhase: CBITPhase = .week1Awareness

    // Their main tics (set during onboarding)
    var primaryTics: [String] = []          // e.g. ["Eye Blink", "Throat Clearing"]
    var primaryTicCategories: [TicCategory] = []

    // Tic awareness level set during onboarding (1 = rarely notice, 5 = always notice)
    var ticAwarenessLevel: Int = 3

    // Their chosen competing responses (set when phase advances)
    var competingResponses: [String: String] = [:]  // ticName → competing response description

    // Onboarding complete flag
    var hasCompletedOnboarding: Bool = false

    // Computed: days since program started
    var daysSinceStart: Int {
        Calendar.current.dateComponents([.day], from: programStartDate, to: Date()).day ?? 0
    }

    // Auto-advance phase based on days
    var recommendedPhase: CBITPhase {
        switch daysSinceStart {
        case 0..<7: return .week1Awareness
        case 7..<14: return .week2Competing
        case 14..<21: return .week3Building
        case 21..<28: return .week4Advanced
        default: return .ongoing
        }
    }

    // Kid-friendly greeting
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning, \(name)! ☀️"
        case 12..<17: return "Hey \(name)! 👋"
        case 17..<21: return "Good evening, \(name)! 🌙"
        default: return "Hi \(name)! ⭐️"
        }
    }
}
