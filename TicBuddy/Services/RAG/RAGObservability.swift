// TicBuddy — RAGObservability.swift
// Lightweight, PII-safe request logging for the RAG + Claude pipeline. (tb-rag-ondevice-005)
//
// PRIVACY CONTRACT
// ----------------
// TicBuddy is privacy-first and (for under-13 users) COPPA-scoped. This logger
// therefore records ONLY non-identifying metadata about each turn — never the
// user's message text, never Ziggy's reply text. What it stores:
//   • timestamp, event kind, latency
//   • guardrail decision + the numeric domain signals (similarities)
//   • how many chunks were retrieved and the top score
//   • success / failure + a coarse error label (no payload)
//
// Everything stays on-device: an in-memory ring buffer (for a future in-app
// "diagnostics" screen) plus os.Logger, which routes to the unified log locally.
// Nothing here performs any network I/O.

import Foundation
import os

/// A single observed pipeline event. Contains no free-text user content.
struct RAGLogEvent {
    enum Kind: String {
        case guardrailAllowed   = "guardrail_allowed"
        case guardrailRefused   = "guardrail_refused"
        case retrieval          = "retrieval"
        case claudeRequest      = "claude_request"
        case claudeRetry        = "claude_retry"
        case claudeError        = "claude_error"
    }

    let timestamp: Date
    let kind: Kind
    /// Wall-clock duration in milliseconds, when meaningful (else nil).
    let latencyMs: Int?
    /// Guardrail category when kind == guardrailRefused (e.g. "medication").
    let guardrailCategory: String?
    /// Best chunk similarity for this query (domain signal), when computed.
    let maxSimilarity: Double?
    /// Centroid similarity for this query, when computed.
    let centroidSimilarity: Double?
    /// Number of chunks injected as grounding context.
    let retrievedCount: Int?
    /// Coarse, non-identifying error label (e.g. "timeout", "http_503"), no payload.
    let errorLabel: String?
    /// Attempt number for retry accounting (1-based).
    let attempt: Int?
}

/// Process-wide, thread-safe, bounded observer. Not a network client.
final class RAGObservability: @unchecked Sendable {

    static let shared = RAGObservability()

    private let logger = Logger(subsystem: "com.ticbuddy.app", category: "rag")
    private let lock = NSLock()
    private var buffer: [RAGLogEvent] = []
    private let maxEvents = 200

    private init() {}

    // MARK: - Recording

    func record(_ event: RAGLogEvent) {
        lock.lock()
        buffer.append(event)
        if buffer.count > maxEvents { buffer.removeFirst(buffer.count - maxEvents) }
        lock.unlock()
        emit(event)
    }

    /// Convenience for the guardrail decision.
    func logGuardrail(_ decision: GuardrailDecision) {
        switch decision {
        case let .allow(signals):
            record(RAGLogEvent(timestamp: Date(), kind: .guardrailAllowed, latencyMs: nil,
                               guardrailCategory: nil, maxSimilarity: signals.maxChunkSimilarity,
                               centroidSimilarity: signals.centroidSimilarity,
                               retrievedCount: nil, errorLabel: nil, attempt: nil))
        case let .refuse(category, _, signals):
            record(RAGLogEvent(timestamp: Date(), kind: .guardrailRefused, latencyMs: nil,
                               guardrailCategory: category.rawValue, maxSimilarity: signals.maxChunkSimilarity,
                               centroidSimilarity: signals.centroidSimilarity,
                               retrievedCount: nil, errorLabel: nil, attempt: nil))
        }
    }

    /// Convenience for a completed retrieval.
    func logRetrieval(count: Int, topScore: Double?, latencyMs: Int?) {
        record(RAGLogEvent(timestamp: Date(), kind: .retrieval, latencyMs: latencyMs,
                           guardrailCategory: nil, maxSimilarity: topScore, centroidSimilarity: nil,
                           retrievedCount: count, errorLabel: nil, attempt: nil))
    }

    /// Convenience for a Claude API attempt outcome.
    func logClaude(kind: RAGLogEvent.Kind, latencyMs: Int?, attempt: Int?, errorLabel: String? = nil) {
        record(RAGLogEvent(timestamp: Date(), kind: kind, latencyMs: latencyMs,
                           guardrailCategory: nil, maxSimilarity: nil, centroidSimilarity: nil,
                           retrievedCount: nil, errorLabel: errorLabel, attempt: attempt))
    }

    // MARK: - Read-out (for a future in-app diagnostics view)

    func recentEvents() -> [RAGLogEvent] {
        lock.lock(); defer { lock.unlock() }
        return buffer
    }

    // MARK: - Emit to unified log (local only)

    private func emit(_ event: RAGLogEvent) {
        switch event.kind {
        case .guardrailRefused:
            logger.notice("guardrail refused [\(event.guardrailCategory ?? "?", privacy: .public)] maxSim=\(event.maxSimilarity ?? -1, privacy: .public)")
        case .guardrailAllowed:
            logger.debug("guardrail allowed maxSim=\(event.maxSimilarity ?? -1, privacy: .public) centroid=\(event.centroidSimilarity ?? -1, privacy: .public)")
        case .retrieval:
            logger.debug("retrieval count=\(event.retrievedCount ?? -1, privacy: .public) top=\(event.maxSimilarity ?? -1, privacy: .public) \(event.latencyMs ?? -1, privacy: .public)ms")
        case .claudeRequest:
            logger.info("claude ok attempt=\(event.attempt ?? -1, privacy: .public) \(event.latencyMs ?? -1, privacy: .public)ms")
        case .claudeRetry:
            logger.notice("claude retry attempt=\(event.attempt ?? -1, privacy: .public) reason=\(event.errorLabel ?? "?", privacy: .public)")
        case .claudeError:
            logger.error("claude error attempt=\(event.attempt ?? -1, privacy: .public) reason=\(event.errorLabel ?? "?", privacy: .public)")
        }
    }
}
