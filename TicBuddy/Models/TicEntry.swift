// TicBuddy — TicEntry.swift
// Represents a single logged tic event.

import Foundation

// MARK: - Tic Type

enum TicMotorType: String, Codable, CaseIterable, Identifiable {
    case eyeBlink = "Eye Blink"
    case headJerk = "Head Jerk"
    case shoulderShrug = "Shoulder Shrug"
    case facialGrimace = "Facial Grimace"
    case armJerk = "Arm Jerk"
    case legJerk = "Leg Jerk"
    case touching = "Touching"
    case jumping = "Jumping"
    case other = "Other"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .eyeBlink: return "👁"
        case .headJerk: return "🔄"
        case .shoulderShrug: return "🤷"
        case .facialGrimace: return "😬"
        case .armJerk: return "💪"
        case .legJerk: return "🦵"
        case .touching: return "✋"
        case .jumping: return "⬆️"
        case .other: return "⚡️"
        }
    }
}

enum TicVocalType: String, Codable, CaseIterable, Identifiable {
    case throatClearing = "Throat Clearing"
    case sniffing = "Sniffing"
    case grunting = "Grunting"
    case coughing = "Coughing"
    case wordOrPhrase = "Word or Phrase"
    case humming = "Humming"
    case other = "Other"

    var id: String { rawValue }
    var emoji: String {
        switch self {
        case .throatClearing: return "🗣"
        case .sniffing: return "👃"
        case .grunting: return "😤"
        case .coughing: return "🤧"
        case .wordOrPhrase: return "💬"
        case .humming: return "🎵"
        case .other: return "⚡️"
        }
    }
}

enum TicCategory: String, Codable, CaseIterable {
    case motor   = "Motor"
    case vocal   = "Vocal"
    // tb-mvp2-108: Complex tics combine motor + vocal in one coordinated sequence
    // (e.g. hands to face + scream). Stored as a single hierarchy entry so CBIT
    // treats the full sequence as one addressable behaviour.
    case complex = "Complex"
}

// MARK: - Tic Outcome

enum TicOutcome: String, Codable, CaseIterable {
    case noticed = "Noticed It"         // Week 1: awareness only
    case caught = "Caught It"           // Felt the urge before the tic
    case redirected = "Redirected It"   // Successfully used competing response
    case ticHappened = "Tic Happened"   // Could not redirect

    var emoji: String {
        switch self {
        case .noticed: return "👀"
        case .caught: return "⚡️"
        case .redirected: return "🌟"
        case .ticHappened: return "💙"
        }
    }

    var encouragement: String {
        switch self {
        case .noticed: return "Great job noticing! That's exactly what we practice in week 1."
        case .caught: return "Amazing! Feeling the urge before the tic is a big deal!"
        case .redirected: return "WOW! You redirected it! Your brain is changing! 🧠✨"
        case .ticHappened: return "That's okay! Noticing it still counts. Keep going! 💙"
        }
    }
}

// MARK: - TicEntry

struct TicEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var category: TicCategory
    var motorType: TicMotorType?
    var vocalType: TicVocalType?
    var customLabel: String?     // if "Other" is selected
    var outcome: TicOutcome
    var urgeStrength: Int        // 1-5 scale (premonitory urge)
    var note: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        category: TicCategory,
        motorType: TicMotorType? = nil,
        vocalType: TicVocalType? = nil,
        customLabel: String? = nil,
        outcome: TicOutcome = .noticed,
        urgeStrength: Int = 1,
        note: String? = nil
    ) {
        self.id = id
        self.date = date
        self.category = category
        self.motorType = motorType
        self.vocalType = vocalType
        self.customLabel = customLabel
        self.outcome = outcome
        self.urgeStrength = urgeStrength
        self.note = note
    }

    var displayName: String {
        if let custom = customLabel { return custom }
        if let motor = motorType { return motor.rawValue }
        if let vocal = vocalType { return vocal.rawValue }
        return "Unknown Tic"
    }

    var emoji: String {
        if let motor = motorType { return motor.emoji }
        if let vocal = vocalType { return vocal.emoji }
        return "⚡️"
    }
}

// MARK: - DayLog (aggregate for calendar)

struct DayLog: Identifiable {
    let id: Date   // start of day
    let entries: [TicEntry]

    var totalTics: Int { entries.count }
    var redirected: Int { entries.filter { $0.outcome == .redirected }.count }
    var caught: Int { entries.filter { $0.outcome == .caught }.count }
    var noticed: Int { entries.filter { $0.outcome == .noticed }.count }

    var successRate: Double {
        guard totalTics > 0 else { return 0 }
        return Double(redirected + caught) / Double(totalTics)
    }
}
