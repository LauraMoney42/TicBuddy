// TicBuddy — CBITSessionStore.swift
// Manages cross-session memory: extraction, persistence, and system-prompt injection.
//
// "Dream" pattern:
//   1. Session ends  →  extractAndSaveMemories() is called with the transcript
//   2. Claude (via extraction prompt, not Ziggy persona) returns structured JSON
//   3. Memories are saved to UserDefaults, keyed by child profile UUID
//   4. Next session start  →  buildMemoryInjection() appends memories to system prompt
//   5. Ziggy "naturally remembers" without ever announcing it
//
// Privacy:
//   - All storage is local-only (UserDefaults) — never uploaded
//   - Extraction API call sends session transcript to proxy, same as normal chat
//   - childProfileID is a UUID — no name or DOB in the key
//   - Memory content is written in abstract clinical terms (no last names, schools, etc.)

import Foundation

@MainActor
final class CBITSessionStore: ObservableObject {
    static let shared = CBITSessionStore()
    private init() {}

    // MARK: - Storage Keys

    private func storeKey(for childID: UUID) -> String {
        "ticbuddy_session_memory_\(childID.uuidString)"
    }

    // MARK: - Load / Save

    func loadStore(for childID: UUID) -> SessionMemoryStore {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey(for: childID)),
            let store = try? JSONDecoder().decode(SessionMemoryStore.self, from: data)
        else {
            return SessionMemoryStore(childProfileID: childID)
        }
        return store
    }

    private func save(_ store: SessionMemoryStore) {
        guard let data = try? JSONEncoder().encode(store) else { return }
        UserDefaults.standard.set(data, forKey: storeKey(for: store.childProfileID))
    }

    // MARK: - Add / Update Memories

    func addMemory(_ memory: SessionMemoryItem) {
        var store = loadStore(for: memory.childProfileID)

        // Deduplicate: skip if same type + similar content already exists from the same calendar day
        let today = Calendar.current.startOfDay(for: memory.sessionDate)
        let duplicate = store.memories.first {
            Calendar.current.startOfDay(for: $0.sessionDate) == today &&
            $0.type == memory.type &&
            $0.content.lowercased().trimmingCharacters(in: .whitespaces) ==
                memory.content.lowercased().trimmingCharacters(in: .whitespaces)
        }
        guard duplicate == nil else { return }

        store.memories.append(memory)

        // Trim to max retained — keep highest importance + most recent
        if store.memories.count > SessionMemoryStore.maxRetained {
            store.memories = store.memories
                .sorted {
                    if $0.importance != $1.importance { return $0.importance > $1.importance }
                    return $0.sessionDate > $1.sessionDate
                }
                .prefix(SessionMemoryStore.maxRetained)
                .map { $0 }
        }

        save(store)
    }

    /// Marks a memory inactive when it's been resolved or is no longer relevant.
    /// e.g. "pain in shoulder" resolved after parent reported it to doctor.
    func resolveMemory(id: UUID, childID: UUID) {
        var store = loadStore(for: childID)
        if let idx = store.memories.firstIndex(where: { $0.id == id }) {
            store.memories[idx].isActive = false
            save(store)
        }
    }

    func clearAllMemories(for childID: UUID) {
        var store = loadStore(for: childID)
        store.memories = []
        save(store)
    }

    // MARK: - Memory Injection (System Prompt)

    /// Returns a formatted memory block ready to append to the system prompt.
    /// Returns nil if no memories exist yet (first session).
    func buildMemoryInjection(for childID: UUID) -> String? {
        let store = loadStore(for: childID)
        let memories = store.injectionMemories
        guard !memories.isEmpty else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full

        let lines = memories.map { memory -> String in
            let when = formatter.localizedString(for: memory.sessionDate, relativeTo: Date())
            return "• [\(memory.type.displayName)] \(when): \(memory.content)"
        }.joined(separator: "\n")

        return """
        MEMORY FROM PREVIOUS SESSIONS (use naturally — do not read out loud or announce):
        \(lines)

        If the child references something from this list, respond as if you genuinely remember it. \
        Don't say "according to my notes" — just say "I remember you mentioned..."
        """
    }

    // MARK: - Session Extraction

    /// Called when a session ends (user closes chat or after extended idle).
    /// Sends transcript to Claude with an extraction prompt; saves returned memories locally.
    ///
    /// - Parameters:
    ///   - messages: The full session chat history
    ///   - childID: The active child's profile UUID
    ///   - childAge: Used to calibrate clinical vs. simple language in the extraction prompt
    ///   - claudeService: Shared ClaudeService instance
    func extractAndSaveMemories(
        from messages: [ChatMessage],
        childID: UUID,
        childAge: Int,
        using claudeService: ClaudeService
    ) async {
        // Need at least a few exchanges to be worth extracting from
        guard messages.count >= 4 else { return }

        // Build transcript — last 40 messages max, to stay within proxy limits
        let transcript = messages.suffix(40).map { msg -> String in
            let speaker = msg.role == .user ? "Child" : "TicBuddy"
            return "\(speaker): \(msg.content)"
        }.joined(separator: "\n")

        do {
            let extracted = try await claudeService.extractSessionMemories(
                transcript: transcript,
                childID: childID,
                childAge: childAge
            )
            for item in extracted {
                addMemory(item)
            }

            // Mark extraction timestamp
            var store = loadStore(for: childID)
            store.lastExtracted = Date()
            save(store)
        } catch {
            // Extraction failure is non-critical — silently swallow
            // Memories from this session just won't be available next time
            #if DEBUG
            print("CBITSessionStore: extraction failed — \(error.localizedDescription)")
            #endif
        }
    }
}
