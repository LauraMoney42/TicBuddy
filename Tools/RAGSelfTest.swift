// TicBuddy — Tools/RAGSelfTest.swift
// Standalone, runnable proof that the on-device RAG + domain guardrail work.
// (tb-rag-ondevice-007)
//
// This compiles the EXACT shipping RAG core (no copies, no mocks). Run it with:
//
//   swiftc \
//     TicBuddy/Services/RAG/CBITCorpus.swift \
//     TicBuddy/Services/RAG/OnDeviceEmbedder.swift \
//     TicBuddy/Services/RAG/OnDeviceRAGIndex.swift \
//     TicBuddy/Services/RAG/DomainGuardrail.swift \
//     Tools/RAGSelfTest.swift \
//     -o /tmp/ragselftest && /tmp/ragselftest
//
// It uses Apple's on-device NLEmbedding (macOS ships the same English sentence
// model as iOS), so the numbers here are representative of on-device behavior.
// Exits non-zero if any assertion fails, so it can gate CI.

import Foundation

@main
enum RAGSelfTest {

    static var failures = 0

    static func check(_ condition: Bool, _ message: String) {
        let mark = condition ? "✅ PASS" : "❌ FAIL"
        if !condition { failures += 1 }
        print("  \(mark)  \(message)")
    }

    static func main() {
        let index = OnDeviceRAGIndex.shared
        let guardrail = DomainGuardrail.shared

        print("=== TicBuddy on-device RAG self-test ===\n")
        print("Embedder available: \(OnDeviceEmbedder.shared.isAvailable) (dim=\(OnDeviceEmbedder.shared.dimension))")
        print("Corpus chunks: \(CBITCorpus.count)   Indexed chunks: \(index.indexedChunkCount)")
        print("Domain floor: \(DomainGuardrail.domainFloor)\n")

        guard OnDeviceEmbedder.shared.isAvailable else {
            print("❌ On-device embedding model unavailable — cannot run RAG. Aborting.")
            exit(2)
        }

        // MARK: 1. Retrieval quality (in-domain)
        print("--- 1. Retrieval (in-domain queries return relevant chunks) ---")
        let retrievalProbes: [(query: String, expectSectionContains: String)] = [
            ("How do I do a power move for my eye blinking tic?", "Competing Response"),
            ("What is that feeling I get right before a tic?",     "Premonitory Urge"),
            ("Why do my tics get worse when I'm stressed?",         "What Makes Tics Worse"),
            ("What should we focus on in week 1?",                  "Week"),
        ]
        for probe in retrievalProbes {
            let hits = index.retrieve(query: probe.query, topK: 3)
            let top = hits.first
            let sectionOK = hits.contains { $0.chunk.section.contains(probe.expectSectionContains) }
            let desc = top.map { String(format: "top=%.3f “%@…”", $0.score, String($0.chunk.text.prefix(48))) } ?? "no hits"
            check(!hits.isEmpty && sectionOK,
                  "“\(probe.query)” → \(hits.count) hits, expected section ‘\(probe.expectSectionContains)’ present [\(desc)]")
        }

        // MARK: 2. Guardrail — in-domain is allowed
        print("\n--- 2. Guardrail ALLOWS in-domain queries ---")
        let inDomain = [
            "How do I do a competing response for my eye blinking tic?",
            "My throat clearing tic is really bad today, what can I do?",
            "What is the premonitory urge?",
            "Why do my tics get worse when I am stressed?",
            "I caught my head jerk today but couldn't redirect it",
        ]
        for q in inDomain {
            let d = guardrail.evaluate(q)
            let sig: String = {
                switch d {
                case let .allow(s): return String(format: "maxSim=%.3f", s.maxChunkSimilarity)
                case let .refuse(_, _, s): return String(format: "REFUSED maxSim=%.3f", s.maxChunkSimilarity)
                }
            }()
            check(d.isAllowed, "allow: “\(q)”  [\(sig)]")
        }

        // MARK: 3. Guardrail — out-of-domain is refused
        print("\n--- 3. Guardrail REFUSES out-of-domain queries ---")
        let outOfDomain: [(String, OutOfScopeCategory?)] = [
            ("What is the best cryptocurrency to invest in this year?", .unrelated),
            ("Can you help me write an essay about the French Revolution?", nil),
            ("How do I fix a flat tire on my bicycle?", nil),
            ("What medication dosage should my child take for tics?", .medication),
            ("Do I have Tourette syndrome?", .diagnosis),
            ("Tell me a joke about cats", .unrelated),
        ]
        for (q, expectedCat) in outOfDomain {
            let d = guardrail.evaluate(q)
            switch d {
            case let .refuse(category, _, s):
                let catOK = expectedCat == nil || category == expectedCat!
                check(catOK, String(format: "refuse[%@]: “%@”  [maxSim=%.3f]", category.rawValue, q, s.maxChunkSimilarity))
            case let .allow(s):
                check(false, String(format: "refuse: “%@”  [WRONGLY ALLOWED maxSim=%.3f]", q, s.maxChunkSimilarity))
            }
        }

        // MARK: 4. Calibration table (transparency — shows WHY the guardrail is layered)
        print("\n--- 4. Calibration (raw embedding signals; note the overlap) ---")
        func signalsRow(_ q: String) -> String {
            let s = index.domainSignals(for: q)
            return String(format: "  max=%.3f centroid=%.3f  %@", s.maxChunkSimilarity, s.centroidSimilarity, q)
        }
        print(" IN-DOMAIN:")
        inDomain.forEach { print(signalsRow($0)) }
        print(" OUT-OF-DOMAIN:")
        outOfDomain.forEach { print(signalsRow($0.0)) }

        print("\n=== \(failures == 0 ? "ALL TESTS PASSED ✅" : "\(failures) TEST(S) FAILED ❌") ===")
        exit(failures == 0 ? 0 : 1)
    }
}
