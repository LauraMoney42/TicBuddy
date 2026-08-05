// TicBuddy — OnDeviceEmbedder.swift
// Fully on-device text embeddings via Apple's NaturalLanguage framework. (tb-rag-ondevice-002)
//
// WHY NLEmbedding
// ---------------
// NLEmbedding.sentenceEmbedding(for: .english) runs entirely on the device with
// no network call, no API key, and no data leaving the phone — which is exactly
// the privacy posture TicBuddy needs (a child's messages are never sent anywhere
// just to be embedded). It returns a fixed 512-dimension dense vector.
//
// HONEST LIMITATION (measured, documented)
// -----------------------------------------
// Apple's sentence embedding is a general-purpose model, not a domain-tuned one.
// Its absolute cosine scores are compressed (in-domain queries land ~0.33–0.45
// against our corpus, out-of-domain ~0.24–0.34), so a single similarity threshold
// does NOT cleanly separate "about tics" from "not about tics." That measurement
// is the reason the domain guardrail (see DomainGuardrail.swift) is layered rather
// than a lone cosine cutoff. This wrapper's job is only to produce vectors and
// compare them; interpretation of the scores lives in the guardrail.
//
// No app-specific imports — this compiles into the app and the CLI self-test alike.

import Foundation
import NaturalLanguage

/// Thin, testable wrapper around NLEmbedding providing vectors + cosine similarity.
/// Immutable after init (the model + dimension are `let`), so it is safe to share.
final class OnDeviceEmbedder: @unchecked Sendable {

    /// Shared instance — loading the embedding model is comparatively expensive,
    /// so we do it once.
    static let shared = OnDeviceEmbedder()

    private let embedding: NLEmbedding?

    /// The vector dimension (512 for Apple's English sentence embedding), or 0 if
    /// the model could not be loaded on this device/OS.
    let dimension: Int

    init(language: NLLanguage = .english) {
        let model = NLEmbedding.sentenceEmbedding(for: language)
        self.embedding = model
        self.dimension = model?.dimension ?? 0
    }

    /// True when the on-device model loaded successfully. If false, callers should
    /// degrade gracefully (skip retrieval, fall back to keyword-only guardrail).
    var isAvailable: Bool { embedding != nil }

    /// Embed a string into a dense vector, or nil if unavailable / not embeddable.
    /// The text is lightly normalized (trimmed, collapsed whitespace) for stability.
    func vector(for text: String) -> [Double]? {
        guard let embedding else { return nil }
        let normalized = Self.normalize(text)
        guard !normalized.isEmpty else { return nil }
        // NLEmbedding.vector(for:) returns nil only in edge cases; the sentence
        // model produces a vector for essentially any non-empty English input.
        return embedding.vector(for: normalized)
    }

    /// Cosine similarity in [-1, 1]. Returns 0 for empty/degenerate inputs so
    /// callers never divide by zero.
    static func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            na += a[i] * a[i]
            nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (sqrt(na) * sqrt(nb))
    }

    // MARK: - Normalization

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
