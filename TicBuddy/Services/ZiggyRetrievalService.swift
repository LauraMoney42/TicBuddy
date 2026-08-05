// TicBuddy — ZiggyRetrievalService.swift
// App-facing orchestrator for the on-device RAG + guardrail pipeline. (tb-rag-ondevice-006)
//
// This is the ONLY RAG entry point ChatViewModel needs. It bridges app models
// (ZiggyVoiceProfile, CBITPhase, TicCategory) to the app-type-free RAG core
// (DomainGuardrail, OnDeviceRAGIndex) and handles observability.
//
// Pipeline per user turn:
//   1. guardrail.evaluate(scrubbedMessage)  → allow | refuse(redirect)
//   2. if allowed: index.retrieve(...)      → top-k CBIT chunks (on-device)
//   3. format chunks as a KNOWLEDGE CONTEXT block for the system prompt
//
// Retrieval is on-device and synchronous-fast, but exposed async so the call site
// stays uniform and future model work can move off the main actor.
//
// This SUPERSEDES the legacy remote ZiggyRAGService (Voyage AI + Supabase proxy),
// which required external infrastructure not shipped with the app and silently
// returned nothing when unconfigured. On-device retrieval always works offline
// and keeps every message on the phone.

import Foundation

/// Immutable after init (references to shared, thread-safe collaborators), safe to share.
final class ZiggyRetrievalService: @unchecked Sendable {

    static let shared = ZiggyRetrievalService()

    private let guardrail: DomainGuardrail
    private let index: OnDeviceRAGIndex
    private let observability: RAGObservability

    init(
        guardrail: DomainGuardrail = .shared,
        index: OnDeviceRAGIndex = .shared,
        observability: RAGObservability = .shared
    ) {
        self.guardrail = guardrail
        self.index = index
        self.observability = observability
    }

    /// Warm the index (embed the corpus + centroid) off the main thread. Safe to
    /// call at launch; idempotent. Avoids a first-message hitch.
    func warmUp() {
        Task.detached(priority: .utility) { [index] in
            index.build()
        }
    }

    // MARK: - Guardrail

    /// Result of the domain check for a user turn.
    enum ScopeCheck {
        case inScope
        case outOfScope(category: OutOfScopeCategory, redirect: String)
    }

    /// Run the layered domain guardrail on a PII-scrubbed message.
    /// Logs the decision (metadata only) and returns whether to proceed.
    func checkScope(_ scrubbedMessage: String) -> ScopeCheck {
        let decision = guardrail.evaluate(scrubbedMessage)
        observability.logGuardrail(decision)
        switch decision {
        case .allow:
            return .inScope
        case let .refuse(category, redirect, _):
            return .outOfScope(category: category, redirect: redirect)
        }
    }

    // MARK: - Retrieval

    /// Retrieve grounding context for an in-scope message and format it for the
    /// system prompt. Returns nil if nothing relevant was found or the on-device
    /// model is unavailable (chat then proceeds from base knowledge).
    func groundingBlock(
        for scrubbedMessage: String,
        phase: CBITPhase,
        ticCategories: [TicCategory],
        topK: Int = 4
    ) async -> String? {
        let ticType: String? = {
            // Only pass a filter when the child has a single dominant modality; a
            // mixed profile leaves it nil so both motor and vocal chunks stay eligible.
            let set = Set(ticCategories)
            if set == [.motor] { return "motor" }
            if set == [.vocal] { return "vocal" }
            return nil
        }()

        let results = index.retrieve(
            query: scrubbedMessage,
            topK: topK,
            sessionStage: phase.ragKey,
            ticType: ticType
        )
        observability.logRetrieval(count: results.count, topScore: results.first?.score, latencyMs: nil)
        return Self.format(results)
    }

    // MARK: - Formatting

    /// Formats retrieved chunks as an injected KNOWLEDGE CONTEXT block, or nil if empty.
    static func format(_ results: [ScoredChunk]) -> String? {
        guard !results.isEmpty else { return nil }
        let numbered = results.enumerated().map { (i, r) in
            "[\(i + 1)] \(r.chunk.text)"
        }.joined(separator: "\n\n")
        return """
        KNOWLEDGE CONTEXT (retrieved on-device from TicBuddy's curated CBIT reference — \
        use it to give accurate, specific guidance; paraphrase, do not quote verbatim):
        \(numbered)
        (End of knowledge context.)
        """
    }
}

// MARK: - CBITPhase → RAG session_stage key
// (Moved here from the now-removed remote ZiggyRAGService; used as the on-device
//  retrieval's soft `sessionStage` filter.)

extension CBITPhase {
    /// Maps a CBITPhase to the `sessionStage` tag used by CBITChunk metadata.
    var ragKey: String {
        switch self {
        case .week1Awareness:  return "week1_awareness"
        case .week2Competing:  return "week2_competing"
        case .week3Building:   return "week3_building"
        case .week4Advanced:   return "week4_advanced"
        case .ongoing:         return "maintenance"
        }
    }
}
