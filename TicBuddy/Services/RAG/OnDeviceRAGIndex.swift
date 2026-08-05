// TicBuddy — OnDeviceRAGIndex.swift
// In-memory vector index over the curated CBIT corpus. (tb-rag-ondevice-003)
//
// DESIGN
// ------
// The corpus is small and clinician-curated (a few dozen chunks), so the right
// index is brute-force cosine similarity held in memory. No sqlite-vec, no ANN
// structure, no external dependency: a query embeds once and is compared against
// every chunk vector. At this size that is well under a millisecond and the
// results are exact (no approximation error).
//
// The index is built lazily on first use and cached for the process lifetime.
// Building = embedding all ~three dozen chunks once (tens of ms) plus computing
// the corpus centroid, which the guardrail uses as a domain reference point.
//
// Everything here is on-device and app-type-free, so the CLI self-test exercises
// the identical retrieval path that ships in the app.

import Foundation

/// A retrieved chunk with its similarity to the query (1.0 = identical direction).
struct ScoredChunk {
    let chunk: CBITChunk
    let score: Double
}

/// Domain signals for a query, used by the guardrail and for observability.
struct DomainSignals {
    /// Highest cosine similarity between the query and any single corpus chunk.
    /// This is the primary "is this about our domain" signal.
    let maxChunkSimilarity: Double
    /// Cosine similarity between the query and the corpus centroid (mean vector).
    /// A softer, more holistic signal; logged for observability.
    let centroidSimilarity: Double
    /// The single closest chunk (nil only if the corpus/index is empty).
    let nearestChunk: CBITChunk?
}

/// Mutable index state (vectors/centroid/built) is guarded by `buildLock`, so the
/// shared instance is safe to use across tasks — hence `@unchecked Sendable`.
final class OnDeviceRAGIndex: @unchecked Sendable {

    static let shared = OnDeviceRAGIndex()

    /// Weight of the lexical term-overlap signal added to semantic cosine in
    /// hybrid retrieval. Tuned so a FULL lexical match adds ~0.30 — decisive for
    /// exact-term queries the embedding badly under-scores (e.g. "focus on week 1"
    /// embeds at ~0 semantic against the Week-1 chunk despite matching every word),
    /// while a partial coincidence adds proportionally less and cannot bury a
    /// strong semantic match.
    static let lexicalWeight: Double = 0.30

    private let embedder: OnDeviceEmbedder
    private let corpus: [CBITChunk]

    /// Parallel to `alignedCorpus`: the BODY-ONLY embedded vector for each chunk.
    /// The domain guardrail's signals (max/centroid similarity) are computed from
    /// these, so they are intentionally left unchanged by the retrieval-only title
    /// augmentation below — the guardrail's calibrated behavior is preserved exactly.
    private var vectors: [[Double]] = []
    /// Parallel to `alignedCorpus`: retrieval embeddings that ALSO include each
    /// chunk's section title (e.g. "Co-occurring Conditions. Conditions that…").
    /// Used ONLY for retrieval ranking, so a query that names a topic matches the
    /// right chunk semantically even when the body wording differs. Falls back to
    /// the body vector if the augmented text fails to embed.
    private var retrievalVectors: [[Double]] = []
    /// Mean of all BODY-ONLY chunk vectors — the corpus centroid (guardrail input).
    private var centroid: [Double] = []
    private var built = false
    private let buildLock = NSLock()

    init(embedder: OnDeviceEmbedder = .shared, corpus: [CBITChunk] = CBITCorpus.chunks) {
        self.embedder = embedder
        self.corpus = corpus
    }

    /// True once the corpus has been embedded and at least one vector exists.
    var isReady: Bool {
        build()
        return !vectors.isEmpty
    }

    /// Number of successfully embedded chunks (equals corpus size when the model
    /// is available). Cited in docs/observability.
    var indexedChunkCount: Int {
        build()
        return vectors.count
    }

    // MARK: - Build

    /// Embed the corpus and compute the centroid. Idempotent and thread-safe.
    func build() {
        buildLock.lock()
        defer { buildLock.unlock() }
        guard !built else { return }
        built = true

        guard embedder.isAvailable else {
            // No on-device model — leave vectors empty; callers degrade gracefully.
            return
        }

        var bodyVecs: [[Double]] = []
        var retVecs: [[Double]] = []
        var alignedChunks: [CBITChunk] = []
        bodyVecs.reserveCapacity(corpus.count)
        for chunk in corpus {
            // Body-only vector (guardrail input). Skip any chunk the model can't
            // embed so the index stays aligned; in practice every chunk embeds.
            guard let bv = embedder.vector(for: chunk.text), !bv.isEmpty else { continue }
            // Retrieval vector = section title + body, so topic-label queries match.
            // Fall back to the body vector if the augmented text fails to embed.
            let augmented = chunk.section + ". " + chunk.text
            let rv = embedder.vector(for: augmented) ?? bv
            bodyVecs.append(bv)
            retVecs.append(rv.isEmpty ? bv : rv)
            alignedChunks.append(chunk)
        }
        self.vectors = bodyVecs
        self.retrievalVectors = retVecs
        self.alignedCorpus = alignedChunks
        // Centroid stays body-only so the guardrail's centroid signal is unchanged.
        self.centroid = Self.mean(of: bodyVecs)
    }

    /// Corpus filtered to only chunks that embedded successfully; parallel to `vectors`.
    private var alignedCorpus: [CBITChunk] = []

    // MARK: - Retrieval

    /// Retrieve the top-k most similar chunks to `query`.
    ///
    /// - Parameters:
    ///   - query: the (PII-scrubbed) user message.
    ///   - topK: max chunks to return.
    ///   - minScore: floor; chunks below this similarity are dropped even if they
    ///     are in the top-k. Prevents padding grounding context with weak matches.
    ///   - sessionStage / ticType: optional soft filters. Chunks tagged for a
    ///     specific stage/type that does NOT match are lightly de-prioritized, but
    ///     untagged (nil) chunks always remain eligible so general knowledge is
    ///     never filtered away.
    /// - Returns: scored chunks, highest similarity first (possibly empty).
    func retrieve(
        query: String,
        topK: Int = 4,
        minScore: Double = 0.22,
        sessionStage: String? = nil,
        ticType: String? = nil
    ) -> [ScoredChunk] {
        build()
        guard !retrievalVectors.isEmpty, let qv = embedder.vector(for: query) else { return [] }

        var scored: [ScoredChunk] = []
        scored.reserveCapacity(retrievalVectors.count)
        for (i, v) in retrievalVectors.enumerated() {
            let semantic = OnDeviceEmbedder.cosine(qv, v)
            // HYBRID: blend a sparse lexical (term-overlap) signal with the dense
            // semantic score. Weighted so semantic leads but exact-term questions
            // (which the embedding under-scores) still surface the right chunk.
            // Lexical overlap also considers the section title, so a query that names
            // the topic ("what conditions co-occur…") matches the right chunk even
            // when the body wording differs.
            let lexical = TextMatch.overlapFraction(query: query,
                                                    in: alignedCorpus[i].section + " " + alignedCorpus[i].text)
            let hybrid = semantic + Self.lexicalWeight * lexical
            let boosted = hybrid + metadataBoost(alignedCorpus[i], sessionStage: sessionStage, ticType: ticType)
            scored.append(ScoredChunk(chunk: alignedCorpus[i], score: boosted))
        }
        return scored
            .filter { $0.score >= minScore }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    /// Domain signals for the guardrail (max chunk similarity + centroid similarity).
    /// Uses RAW cosine (no metadata boosting) so the domain decision is not skewed
    /// by filter preferences.
    func domainSignals(for query: String) -> DomainSignals {
        build()
        guard !vectors.isEmpty, let qv = embedder.vector(for: query) else {
            return DomainSignals(maxChunkSimilarity: 0, centroidSimilarity: 0, nearestChunk: nil)
        }
        var best = -1.0
        var bestIdx = 0
        for (i, v) in vectors.enumerated() {
            let s = OnDeviceEmbedder.cosine(qv, v)
            if s > best { best = s; bestIdx = i }
        }
        let cen = centroid.isEmpty ? 0 : OnDeviceEmbedder.cosine(qv, centroid)
        return DomainSignals(
            maxChunkSimilarity: max(best, 0),
            centroidSimilarity: cen,
            nearestChunk: alignedCorpus.isEmpty ? nil : alignedCorpus[bestIdx]
        )
    }

    // MARK: - Helpers

    /// Small additive nudge for chunks whose metadata matches the current context.
    /// Kept intentionally tiny (±0.02) so semantic similarity dominates and a
    /// perfectly relevant untagged chunk is never buried by a weakly-related
    /// stage-matched one.
    private func metadataBoost(_ chunk: CBITChunk, sessionStage: String?, ticType: String?) -> Double {
        var boost = 0.0
        if let stage = sessionStage, let cStage = chunk.sessionStage {
            boost += (cStage == stage) ? 0.02 : -0.01
        }
        if let tt = ticType, let cTic = chunk.ticType {
            boost += (cTic == tt) ? 0.02 : -0.01
        }
        return boost
    }

    private static func mean(of vectors: [[Double]]) -> [Double] {
        guard let dim = vectors.first?.count, dim > 0 else { return [] }
        var acc = [Double](repeating: 0, count: dim)
        for v in vectors where v.count == dim {
            for i in 0..<dim { acc[i] += v[i] }
        }
        let n = Double(vectors.count)
        return acc.map { $0 / n }
    }
}
