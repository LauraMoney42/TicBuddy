// TicBuddy — ZiggyRAGService.swift
// RAG (Retrieval-Augmented Generation) pipeline client. (tb-rag-001)
//
// Architecture:
//   1. Client POSTs { userMessage, ageGroup, sessionStage, ticTypes } to /api/rag
//   2. Proxy embeds userMessage via Voyage AI voyage-3 (1024-dim)
//   3. Proxy queries Supabase pgvector RPC match_cbit_knowledge with embedding + metadata filters
//   4. Proxy returns top-K CBIT knowledge chunks
//   5. Client formats chunks as KNOWLEDGE CONTEXT block → injected into system prompt
//
// Best-effort: any failure (network, Supabase timeout, Voyage error) returns nil.
// Chat continues uninterrupted from Ziggy's base knowledge. No UI error shown.
//
// Filters applied server-side to narrow results:
//   - age_group:     matches content tagged for this child's voice profile (or NULL = all ages)
//   - session_stage: matches content tagged for the current CBIT phase (or NULL = all phases)
//   - tic_types:     ANY match on motor/vocal/both (or NULL = both)
//
// REQUIRED SUPABASE SETUP (run migrations/cbit_knowledge.sql in your Supabase project):
//
//   CREATE EXTENSION IF NOT EXISTS vector;
//
//   CREATE TABLE cbit_knowledge (
//     id            BIGSERIAL PRIMARY KEY,
//     content       TEXT NOT NULL,
//     embedding     VECTOR(1024),
//     age_group     TEXT,    -- 'young_child'|'older_child'|'adolescent'|'caregiver'|NULL
//     session_stage TEXT,    -- 'week1_awareness'|'week2_competing'|'week3_building'|'week4_advanced'|NULL
//     tic_type      TEXT     -- 'motor'|'vocal'|'both'|NULL
//   );
//
//   CREATE INDEX ON cbit_knowledge USING ivfflat (embedding vector_cosine_ops);
//
//   CREATE OR REPLACE FUNCTION match_cbit_knowledge(
//     query_embedding VECTOR(1024),
//     match_count     INT            DEFAULT 4,
//     filter_age      TEXT           DEFAULT NULL,
//     filter_stage    TEXT           DEFAULT NULL,
//     filter_tic      TEXT           DEFAULT NULL
//   )
//   RETURNS TABLE (content TEXT, similarity FLOAT)
//   LANGUAGE sql STABLE AS $$
//     SELECT content,
//            1 - (embedding <=> query_embedding) AS similarity
//     FROM   cbit_knowledge
//     WHERE  (filter_age   IS NULL OR age_group     = filter_age   OR age_group     IS NULL)
//       AND  (filter_stage IS NULL OR session_stage = filter_stage OR session_stage IS NULL)
//       AND  (filter_tic   IS NULL OR tic_type      = filter_tic   OR tic_type      IS NULL
//                                  OR tic_type      = 'both')
//     ORDER  BY embedding <=> query_embedding
//     LIMIT  match_count;
//   $$;

import Foundation

// MARK: - Models

struct RAGChunk: Decodable {
    /// The raw CBIT knowledge text to inject into the system prompt.
    let content: String
    /// Cosine similarity score (0–1). Higher = more relevant.
    let similarity: Double
}

private struct RAGResponse: Decodable {
    let chunks: [RAGChunk]
}

private struct RAGRequest: Encodable {
    let userMessage: String
    let ageGroup: String
    let sessionStage: String
    let ticTypes: [String]
    let topK: Int
}

// MARK: - ZiggyRAGService

/// Client for the /api/rag proxy endpoint.
/// Call `fetchContext(for:voiceProfile:phase:ticCategories:)` once per user turn.
/// Returns a formatted KNOWLEDGE CONTEXT block for injection into the system prompt,
/// or nil if the pipeline is unavailable or returns no results.
final class ZiggyRAGService: @unchecked Sendable {
    static let shared = ZiggyRAGService()
    private init() {}

    // tb-mvp2-050: URL + token now read from APIConfig (single source of truth).
    private let ragURL    = APIConfig.ragURL
    private let authToken = APIConfig.authToken

    // MARK: - Public API

    /// Fetch relevant CBIT knowledge chunks for the current user turn.
    ///
    /// - Parameters:
    ///   - userMessage: PII-scrubbed user message (same text sent to ClaudeService)
    ///   - voiceProfile: Ziggy's active voice profile — used as `age_group` filter
    ///   - phase: The child's current CBIT phase — used as `session_stage` filter
    ///   - ticCategories: The child's tic categories — used as `tic_type` filter
    ///   - topK: Max chunks to retrieve (default 4; proxy caps at 8)
    /// - Returns: Formatted KNOWLEDGE CONTEXT injection string, or nil on any failure.
    func fetchContext(
        for userMessage: String,
        voiceProfile: ZiggyVoiceProfile,
        phase: CBITPhase,
        ticCategories: [TicCategory],
        topK: Int = 4
    ) async -> String? {
        // Map TicCategory to rag filter strings
        let ticTypes: [String] = ticCategories.isEmpty
            ? ["motor", "vocal"]
            : ticCategories.map { $0 == .motor ? "motor" : "vocal" }

        let body = RAGRequest(
            userMessage: userMessage,
            ageGroup: voiceProfile.rawValue,    // e.g. "older_child"
            sessionStage: phase.ragKey,         // e.g. "week1_awareness"
            ticTypes: Array(Set(ticTypes)),     // deduplicate
            topK: min(topK, 8)                  // client-enforced cap
        )

        guard
            let url = URL(string: ragURL),
            let bodyData = try? JSONEncoder().encode(body)
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        // Tight timeout: RAG should be fast; fail gracefully rather than blocking the chat
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            let ragResponse = try JSONDecoder().decode(RAGResponse.self, from: data)
            return formatChunks(ragResponse.chunks)
        } catch {
            // Best-effort — network error, Supabase down, Voyage quota, etc.
            // Never surface to user; Ziggy responds from base knowledge.
            return nil
        }
    }

    // MARK: - Formatting

    /// Formats retrieved chunks as an injected KNOWLEDGE CONTEXT block.
    /// Returns nil if the array is empty.
    private func formatChunks(_ chunks: [RAGChunk]) -> String? {
        guard !chunks.isEmpty else { return nil }

        let numbered = chunks.enumerated().map { (i, chunk) in
            "[\(i + 1)] \(chunk.content.trimmingCharacters(in: .whitespacesAndNewlines))"
        }.joined(separator: "\n\n")

        return """
        KNOWLEDGE CONTEXT (retrieved CBIT reference material — use to give accurate, \
        specific guidance; do not quote directly):
        \(numbered)
        (End of knowledge context.)
        """
    }
}

// MARK: - CBITPhase → RAG session_stage key

extension CBITPhase {
    /// Maps CBITPhase to the `session_stage` column value in cbit_knowledge.
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
