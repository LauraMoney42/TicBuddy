// TicBuddy — SessionMemory.swift
// Data model for the Claude Dream-style cross-session memory system.
//
// Pattern: at session end, Ziggy's transcript is parsed for key clinical moments
// (pain, breakthroughs, goals, flags). Those moments are stored locally and
// injected into the system prompt at the next session so Ziggy "remembers" naturally.
// All data is local-only — COPPA safe, no cloud, no PII transmitted.

import Foundation

// MARK: - Memory Type

enum SessionMemoryType: String, Codable, CaseIterable {
    case painReport      // Tic-related pain or physical discomfort reported
    case emotionalFlag   // Frustration, sadness, embarrassment, or distress
    case breakthrough    // First successful redirect, streak, or awareness win
    case goalSet         // Child stated an intention ("I want to try the shoulder move")
    case ticObservation  // Notable observation about a specific tic pattern
    case caregiverNote   // Something a caregiver mentioned or asked about
    case progressNote    // Observable improvement or regression vs. prior session
    case contextNote     // Life context relevant to tic patterns (stress, school, etc.)

    var displayName: String {
        switch self {
        case .painReport:    return "Pain Report"
        case .emotionalFlag: return "Emotional Flag"
        case .breakthrough:  return "Breakthrough"
        case .goalSet:       return "Goal"
        case .ticObservation:return "Tic Observation"
        case .caregiverNote: return "Caregiver Note"
        case .progressNote:  return "Progress Note"
        case .contextNote:   return "Context"
        }
    }

    /// Higher priority types surface first in the memory injection
    var defaultImportance: Int {
        switch self {
        case .painReport:    return 3
        case .emotionalFlag: return 3
        case .breakthrough:  return 3
        case .goalSet:       return 2
        case .ticObservation:return 2
        case .caregiverNote: return 2
        case .progressNote:  return 2
        case .contextNote:   return 1
        }
    }
}

// MARK: - Session Memory Item

struct SessionMemoryItem: Codable, Identifiable {
    var id: UUID = UUID()
    var type: SessionMemoryType
    /// The remembered fact — kept to 1–2 sentences max.
    /// Written in third person for clean system prompt injection.
    /// e.g. "Reported that shoulder shrug tic causes neck soreness."
    var content: String
    var sessionDate: Date = Date()
    var childProfileID: UUID
    /// 1 = low, 2 = medium, 3 = high — surfaces high-importance memories first
    var importance: Int
    /// Whether this memory is still considered "active" (not resolved/outdated)
    var isActive: Bool = true

    init(
        type: SessionMemoryType,
        content: String,
        childProfileID: UUID,
        importance: Int? = nil,
        sessionDate: Date = Date()
    ) {
        self.type = type
        self.content = content
        self.childProfileID = childProfileID
        self.importance = importance ?? type.defaultImportance
        self.sessionDate = sessionDate
    }
}

// MARK: - Session Memory Store

/// Per-child memory store — all memories for one child profile.
struct SessionMemoryStore: Codable {
    var childProfileID: UUID
    var memories: [SessionMemoryItem] = []
    var lastExtracted: Date?

    /// Max memories retained — keeps system prompt injection concise
    static let maxRetained = 25
    /// Max memories injected per session — avoids prompt bloat
    static let maxInjected = 10

    init(childProfileID: UUID) {
        self.childProfileID = childProfileID
    }

    /// The memories to inject at session start:
    /// recent, active, sorted by importance then recency
    var injectionMemories: [SessionMemoryItem] {
        memories
            .filter { $0.isActive }
            .sorted {
                if $0.importance != $1.importance { return $0.importance > $1.importance }
                return $0.sessionDate > $1.sessionDate
            }
            .prefix(Self.maxInjected)
            .map { $0 }
    }

    /// Whether there are enough memories to inject something meaningful
    var hasMemories: Bool { !memories.filter { $0.isActive }.isEmpty }
}
