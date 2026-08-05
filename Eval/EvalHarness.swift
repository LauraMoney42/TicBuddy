// TicBuddy — Eval/EvalHarness.swift
// Reproducible evaluation harness for the on-device RAG + layered domain guardrail.
//
// WHAT THIS IS
// ------------
// A standalone macOS command-line tool that compiles the EXACT shipping RAG core
// (CBITCorpus, OnDeviceEmbedder, OnDeviceRAGIndex, TextMatch, DomainGuardrail) —
// no copies, no re-implementation, no substitute embedding model — and measures it
// against a hand-labeled golden set (Eval/goldenset.json). It emits:
//   1. Eval/results/eval_results.json   — machine-readable metrics
//   2. Eval/results/EVAL_REPORT.md      — human-readable report (tables + confusion matrix)
//
// It changes NOTHING about retrieval or guardrail behavior; it only measures.
//
// METRICS
// -------
// Retrieval (in-domain queries only): hit-rate@k and recall@k for k in {1,3,5}, and MRR.
//   Ranking is the shipping hybrid score (dense NLEmbedding cosine + 0.30*lexical
//   term-overlap) over all 35 corpus chunks, with NO metadata boost and NO minScore
//   floor, so the metric isolates ranking quality. (The app additionally applies a
//   0.22 minScore floor and +/-0.02 phase/tic-type metadata boosts in context; those
//   are documented, not applied here.)
// Guardrail (all queries): precision / recall / accuracy / F1 with the positive class
//   = "refuse" (catching out-of-scope), plus a 2x2 confusion matrix, a 3-class
//   answered-vs-refused breakdown, and secondary category accuracy.
//
// Run it with Eval/run_eval.sh (single command, documented in Eval/README.md).

import Foundation

// MARK: - Golden-set model

struct GoldenQuery: Decodable {
    let id: String
    let `class`: String            // "in_domain" | "off_domain" | "medical_unsafe"
    let expected_action: String    // "answer" | "refuse"
    let query: String
    let gold_chunks: [Int]?
    let expected_category: String?
    let rationale: String?
}

struct GoldenSet: Decodable {
    let queries: [GoldenQuery]
}

// MARK: - Small helpers

func f3(_ x: Double) -> String { String(format: "%.3f", x) }
func pct(_ x: Double) -> String { String(format: "%.1f%%", x * 100) }

@main
enum EvalHarness {

    static func main() {
        let args = CommandLine.arguments
        let goldenPath = args.count > 1 ? args[1] : "Eval/goldenset.json"
        let outDir = args.count > 2 ? args[2] : "Eval/results"

        // Load golden set
        guard let data = FileManager.default.contents(atPath: goldenPath),
              let golden = try? JSONDecoder().decode(GoldenSet.self, from: data) else {
            FileHandle.standardError.write("ERROR: could not read/parse golden set at \(goldenPath)\n".data(using: .utf8)!)
            exit(2)
        }

        let index = OnDeviceRAGIndex.shared
        let guardrail = DomainGuardrail.shared
        let embedder = OnDeviceEmbedder.shared

        guard embedder.isAvailable else {
            FileHandle.standardError.write("ERROR: on-device NLEmbedding unavailable — cannot evaluate the real stack.\n".data(using: .utf8)!)
            exit(2)
        }

        print("=== TicBuddy RAG + Guardrail Eval ===")
        print("Corpus chunks: \(CBITCorpus.count)   Indexed: \(index.indexedChunkCount)   Embedding dim: \(embedder.dimension)")
        print("Queries: \(golden.queries.count)\n")

        // ------------------------------------------------------------------
        // RETRIEVAL (in-domain only)
        // ------------------------------------------------------------------
        let ks = [1, 3, 5]
        var retrievalRows: [[String: Any]] = []
        // accumulators
        var hitAtK: [Int: Int] = [1: 0, 3: 0, 5: 0]
        var recallSumAtK: [Int: Double] = [1: 0, 3: 0, 5: 0]
        var rrSum = 0.0
        var inDomainCount = 0

        for q in golden.queries where q.class == "in_domain" {
            guard let gold = q.gold_chunks, !gold.isEmpty else { continue }
            inDomainCount += 1
            let goldSet = Set(gold)

            // Real shipping retrieval path; rank ALL chunks (minScore 0, no metadata filters).
            let ranked = index.retrieve(query: q.query, topK: CBITCorpus.count, minScore: 0.0,
                                        sessionStage: nil, ticType: nil)
            let rankedIds = ranked.map { $0.chunk.id }

            // MRR: reciprocal rank of the FIRST gold chunk in the full ranking.
            var rr = 0.0
            if let firstGoldRank = rankedIds.firstIndex(where: { goldSet.contains($0) }) {
                rr = 1.0 / Double(firstGoldRank + 1)
            }
            rrSum += rr

            var perKHit: [String: Bool] = [:]
            var perKRecall: [String: Double] = [:]
            for k in ks {
                let topK = Set(rankedIds.prefix(k))
                let inter = topK.intersection(goldSet)
                let hit = !inter.isEmpty
                if hit { hitAtK[k]! += 1 }
                let recall = Double(inter.count) / Double(goldSet.count)
                recallSumAtK[k]! += recall
                perKHit["hit@\(k)"] = hit
                perKRecall["recall@\(k)"] = recall
            }

            let top5 = ranked.prefix(5).map { sc -> [String: Any] in
                ["id": sc.chunk.id, "score": Double(f3(sc.score)) ?? sc.score, "section": sc.chunk.section]
            }
            retrievalRows.append([
                "id": q.id,
                "query": q.query,
                "gold_chunks": gold,
                "first_gold_rank": (rankedIds.firstIndex(where: { goldSet.contains($0) }).map { $0 + 1 }) ?? -1,
                "reciprocal_rank": Double(f3(rr)) ?? rr,
                "hits": perKHit,
                "recalls": perKRecall,
                "top5": top5
            ])
        }

        let nID = Double(max(inDomainCount, 1))
        var retrievalSummary: [String: Any] = ["n_in_domain": inDomainCount, "mrr": Double(f3(rrSum / nID)) ?? 0]
        for k in ks {
            retrievalSummary["hit_rate@\(k)"] = Double(f3(Double(hitAtK[k]!) / nID)) ?? 0
            retrievalSummary["recall@\(k)"] = Double(f3(recallSumAtK[k]! / nID)) ?? 0
        }

        // ------------------------------------------------------------------
        // GUARDRAIL (all queries)
        // ------------------------------------------------------------------
        // Positive class = "refuse" (correctly catching out-of-scope / unsafe).
        var tp = 0, fp = 0, fn = 0, tn = 0
        // 3-class answered/refused: [class][answered/refused]
        var byClass: [String: [String: Int]] = [
            "in_domain": ["answered": 0, "refused": 0],
            "off_domain": ["answered": 0, "refused": 0],
            "medical_unsafe": ["answered": 0, "refused": 0]
        ]
        var categoryExpectedTotal = 0, categoryCorrect = 0
        var guardrailRows: [[String: Any]] = []

        for q in golden.queries {
            let decision = guardrail.evaluate(q.query)
            let refused: Bool
            let predictedCategory: String
            let maxSim: Double
            switch decision {
            case let .allow(s):
                refused = false; predictedCategory = "allowed"; maxSim = s.maxChunkSimilarity
            case let .refuse(cat, _, s):
                refused = true; predictedCategory = cat.rawValue; maxSim = s.maxChunkSimilarity
            }
            let predictedAction = refused ? "refuse" : "answer"
            let expectRefuse = (q.expected_action == "refuse")

            if expectRefuse && refused { tp += 1 }
            else if !expectRefuse && refused { fp += 1 }
            else if expectRefuse && !refused { fn += 1 }
            else { tn += 1 }

            byClass[q.class]?[refused ? "refused" : "answered"]? += 1

            // Secondary: category correctness among items we expected to refuse AND did refuse.
            if expectRefuse, let expCat = q.expected_category, refused {
                categoryExpectedTotal += 1
                if predictedCategory == expCat { categoryCorrect += 1 }
            }

            guardrailRows.append([
                "id": q.id,
                "class": q.class,
                "query": q.query,
                "expected_action": q.expected_action,
                "predicted_action": predictedAction,
                "correct": predictedAction == q.expected_action,
                "expected_category": q.expected_category ?? NSNull(),
                "predicted_category": predictedCategory,
                "max_chunk_similarity": Double(f3(maxSim)) ?? maxSim
            ])
        }

        let total = tp + fp + fn + tn
        let precision = (tp + fp) > 0 ? Double(tp) / Double(tp + fp) : 0
        let recall = (tp + fn) > 0 ? Double(tp) / Double(tp + fn) : 0
        let accuracy = total > 0 ? Double(tp + tn) / Double(total) : 0
        let f1 = (precision + recall) > 0 ? 2 * precision * recall / (precision + recall) : 0

        let categoryAccuracy: Double = categoryExpectedTotal > 0
            ? Double(categoryCorrect) / Double(categoryExpectedTotal) : 0
        let guardrailSummary: [String: Any] = [
            "n": total,
            "precision": Double(f3(precision)) ?? 0,
            "recall": Double(f3(recall)) ?? 0,
            "accuracy": Double(f3(accuracy)) ?? 0,
            "f1": Double(f3(f1)) ?? 0,
            "confusion_matrix": [
                "true_positive_refused_correctly": tp,
                "false_positive_over_refused_in_domain": fp,
                "false_negative_leaked_out_of_scope": fn,
                "true_negative_answered_correctly": tn
            ],
            "positive_class": "refuse",
            "category_accuracy_secondary": [
                "correct": categoryCorrect,
                "of_refused_with_expected_category": categoryExpectedTotal,
                "value": Double(f3(categoryAccuracy)) ?? 0
            ]
        ]

        // ------------------------------------------------------------------
        // Emit JSON + Markdown
        // ------------------------------------------------------------------
        let results: [String: Any] = [
            "meta": [
                "corpus_chunks": CBITCorpus.count,
                "indexed_chunks": index.indexedChunkCount,
                "embedding_dim": embedder.dimension,
                "domain_floor": DomainGuardrail.domainFloor,
                "lexical_weight": OnDeviceRAGIndex.lexicalWeight,
                "golden_set": goldenPath,
                "n_queries": golden.queries.count,
                "note": "Numbers are measured on this macOS host's NLEmbedding sentence model (same model family as iOS). Deterministic per OS version."
            ],
            "retrieval": ["summary": retrievalSummary, "per_query": retrievalRows],
            "guardrail": ["summary": guardrailSummary, "per_query": guardrailRows]
        ]

        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let jsonPath = "\(outDir)/eval_results.json"
        if let jsonData = try? JSONSerialization.data(withJSONObject: results,
                                                      options: [.prettyPrinted, .sortedKeys]) {
            try? jsonData.write(to: URL(fileURLWithPath: jsonPath))
            print("Wrote \(jsonPath)")
        }

        let md = renderMarkdown(
            golden: golden, index: index, embedder: embedder,
            retrievalSummary: retrievalSummary, retrievalRows: retrievalRows,
            guardrailSummary: guardrailSummary, guardrailRows: guardrailRows,
            tp: tp, fp: fp, fn: fn, tn: tn, byClass: byClass,
            categoryCorrect: categoryCorrect, categoryTotal: categoryExpectedTotal
        )
        let mdPath = "\(outDir)/EVAL_REPORT.md"
        try? md.write(to: URL(fileURLWithPath: mdPath), atomically: true, encoding: .utf8)
        print("Wrote \(mdPath)")

        // Console summary
        print("\n--- Retrieval (n=\(inDomainCount) in-domain) ---")
        for k in ks {
            print("  hit@\(k)=\(f3(Double(hitAtK[k]!) / nID))  recall@\(k)=\(f3(recallSumAtK[k]! / nID))")
        }
        print("  MRR=\(f3(rrSum / nID))")
        print("\n--- Guardrail (n=\(total)) ---")
        print("  precision=\(f3(precision)) recall=\(f3(recall)) accuracy=\(f3(accuracy)) f1=\(f3(f1))")
        print("  confusion: TP=\(tp) FP=\(fp) FN=\(fn) TN=\(tn)")
        print("\nDone.")
    }

    // MARK: - Markdown report

    static func renderMarkdown(
        golden: GoldenSet, index: OnDeviceRAGIndex, embedder: OnDeviceEmbedder,
        retrievalSummary: [String: Any], retrievalRows: [[String: Any]],
        guardrailSummary: [String: Any], guardrailRows: [[String: Any]],
        tp: Int, fp: Int, fn: Int, tn: Int, byClass: [String: [String: Int]],
        categoryCorrect: Int, categoryTotal: Int
    ) -> String {

        func g(_ d: [String: Any], _ k: String) -> String {
            if let v = d[k] as? Double { return f3(v) }
            if let v = d[k] as? Int { return "\(v)" }
            return "\(d[k] ?? "")"
        }

        let nIn = (retrievalSummary["n_in_domain"] as? Int) ?? 0
        let counts = [
            "in_domain": golden.queries.filter { $0.class == "in_domain" }.count,
            "off_domain": golden.queries.filter { $0.class == "off_domain" }.count,
            "medical_unsafe": golden.queries.filter { $0.class == "medical_unsafe" }.count
        ]
        let total = tp + fp + fn + tn
        let precision = g(guardrailSummary, "precision")
        let recall = g(guardrailSummary, "recall")
        let accuracy = g(guardrailSummary, "accuracy")
        let f1 = g(guardrailSummary, "f1")

        var s = ""
        s += "# TicBuddy — On-Device RAG + Guardrail Evaluation\n\n"
        s += "_Disclaimer: TicBuddy is a personal / portfolio project, not clinical software, "
        s += "and nothing here is medical advice._\n\n"
        s += "_Auto-generated by `Eval/EvalHarness.swift`. Do not edit by hand — re-run `Eval/run_eval.sh`._\n\n"

        s += "## Methodology\n\n"
        s += "This harness compiles the **exact shipping RAG core** (`TicBuddy/Services/RAG/*`) — "
        s += "Apple `NLEmbedding` sentence vectors (\(embedder.dimension)-dim), an in-memory brute-force "
        s += "cosine index with hybrid semantic + \(f3(OnDeviceRAGIndex.lexicalWeight))·lexical scoring, and the "
        s += "layered `DomainGuardrail` — and measures it against a hand-labeled golden set. "
        s += "No behavior is changed; the harness only measures. Retrieval numbers are computed on this "
        s += "macOS host's on-device sentence model (same model family that ships on iOS) and are "
        s += "deterministic for a given OS version.\n\n"
        s += "- **Corpus:** \(CBITCorpus.count) clinician-vetted CBIT chunks (`CBITCorpus.swift`), indexed: \(index.indexedChunkCount).\n"
        s += "- **Retrieval metric:** all \(CBITCorpus.count) chunks are ranked by the shipping hybrid score "
        s += "(no metadata boost, no minScore floor) so the metric isolates ranking quality. Gold chunks were "
        s += "hand-assigned by reading every chunk; `hit@k` = any gold chunk in the top-k, "
        s += "`recall@k` = fraction of gold chunks in the top-k, `MRR` = reciprocal rank of the first gold chunk.\n"
        s += "- **Guardrail metric:** positive class = **refuse** (correctly catching out-of-scope / unsafe). "
        s += "In-domain queries should be answered; off-domain and medical/unsafe queries should be refused.\n\n"

        s += "## Dataset\n\n"
        s += "| Class | Count | Expected action |\n|---|---:|---|\n"
        s += "| In-domain CBIT/Tourette's | \(counts["in_domain"] ?? 0) | answer (retrieve grounding) |\n"
        s += "| Off-domain | \(counts["off_domain"] ?? 0) | refuse |\n"
        s += "| Medical-advice / unsafe | \(counts["medical_unsafe"] ?? 0) | refuse / defer to clinician |\n"
        s += "| **Total** | **\(golden.queries.count)** | |\n\n"
        s += "Small by design (a curated smoke-test set, not a large benchmark). See _Limitations_.\n\n"

        s += "## Retrieval results (in-domain, n=\(nIn))\n\n"
        s += "| Metric | @1 | @3 | @5 |\n|---|---:|---:|---:|\n"
        s += "| Hit-rate | \(g(retrievalSummary, "hit_rate@1")) | \(g(retrievalSummary, "hit_rate@3")) | \(g(retrievalSummary, "hit_rate@5")) |\n"
        s += "| Recall | \(g(retrievalSummary, "recall@1")) | \(g(retrievalSummary, "recall@3")) | \(g(retrievalSummary, "recall@5")) |\n\n"
        s += "**MRR = \(g(retrievalSummary, "mrr"))**\n\n"

        s += "## Guardrail results (n=\(total))\n\n"
        s += "| Metric | Value |\n|---|---:|\n"
        s += "| Precision (refuse) | \(precision) |\n"
        s += "| Recall (refuse) | \(recall) |\n"
        s += "| Accuracy | \(accuracy) |\n"
        s += "| F1 | \(f1) |\n\n"

        s += "### Confusion matrix (positive class = refuse)\n\n"
        s += "```\n"
        s += "                    PREDICTED\n"
        s += "                 answer     refuse\n"
        s += String(format: "EXPECTED answer  %5d TN   %5d FP\n", tn, fp)
        s += String(format: "         refuse  %5d FN   %5d TP\n", fn, tp)
        s += "```\n\n"
        s += "- **TP** (\(tp)): out-of-scope / unsafe correctly refused.\n"
        s += "- **FN** (\(fn)): out-of-scope / unsafe that **leaked** through (answered). The costly errors.\n"
        s += "- **FP** (\(fp)): in-domain CBIT questions **over-refused**.\n"
        s += "- **TN** (\(tn)): in-domain questions correctly answered.\n\n"

        s += "### Answered vs refused by class\n\n"
        s += "| Class | Answered | Refused |\n|---|---:|---:|\n"
        for cls in ["in_domain", "off_domain", "medical_unsafe"] {
            let a = byClass[cls]?["answered"] ?? 0
            let r = byClass[cls]?["refused"] ?? 0
            s += "| \(cls) | \(a) | \(r) |\n"
        }
        s += "\n"
        if categoryTotal > 0 {
            let catVal = Double(categoryCorrect) / Double(categoryTotal)
            s += "_Secondary — refusal-category accuracy (of refused items that had an expected category): "
            s += "\(categoryCorrect)/\(categoryTotal) = \(pct(catVal))._\n\n"
        }

        // Appendix: per-query retrieval
        s += "## Appendix A — Per-query retrieval (in-domain)\n\n"
        s += "| id | query | gold | 1st gold rank | RR | top-1 (id, score, section) |\n|---|---|---|---:|---:|---|\n"
        for r in retrievalRows {
            let id = r["id"] as? String ?? ""
            let query = (r["query"] as? String ?? "").replacingOccurrences(of: "|", with: "\\|")
            let gold = (r["gold_chunks"] as? [Int] ?? []).map(String.init).joined(separator: ",")
            let rank = r["first_gold_rank"] as? Int ?? -1
            let rr = (r["reciprocal_rank"] as? Double).map(f3) ?? "0"
            var top1 = "-"
            if let t5 = r["top5"] as? [[String: Any]], let first = t5.first {
                let tid = first["id"] as? Int ?? -1
                let sc = (first["score"] as? Double).map(f3) ?? "?"
                let sec = first["section"] as? String ?? ""
                top1 = "\(tid), \(sc), \(sec)"
            }
            s += "| \(id) | \(query) | \(gold) | \(rank) | \(rr) | \(top1) |\n"
        }
        s += "\n"

        // Appendix: per-query guardrail
        s += "## Appendix B — Per-query guardrail decisions\n\n"
        s += "| id | class | query | expected | predicted | ok | maxSim | category |\n|---|---|---|---|---|:--:|---:|---|\n"
        for r in guardrailRows {
            let id = r["id"] as? String ?? ""
            let cls = r["class"] as? String ?? ""
            let query = (r["query"] as? String ?? "").replacingOccurrences(of: "|", with: "\\|")
            let exp = r["expected_action"] as? String ?? ""
            let pred = r["predicted_action"] as? String ?? ""
            let ok = (r["correct"] as? Bool ?? false) ? "✅" : "❌"
            let sim = (r["max_chunk_similarity"] as? Double).map(f3) ?? "?"
            let cat = r["predicted_category"] as? String ?? ""
            s += "| \(id) | \(cls) | \(query) | \(exp) | \(pred) | \(ok) | \(sim) | \(cat) |\n"
        }
        s += "\n"

        s += "## Limitations\n\n"
        s += "- **Small golden set (\(golden.queries.count) queries).** These are smoke-test / regression numbers, "
        s += "not a large-scale benchmark; treat them as directional and as a guard against regressions.\n"
        s += "- **Labels are author-assigned** from a single annotator reading the corpus; no inter-annotator agreement.\n"
        s += "- **Absolute embedding scores are compressed** (Apple's general-purpose sentence model), which is exactly "
        s += "why the guardrail is layered rather than a single cosine threshold — see `Docs/RAG_AND_GUARDRAIL.md`.\n"
        s += "- **No LLM-judge groundedness** score is included here: it requires network + an API key and would break "
        s += "offline reproducibility. It is noted as future work.\n\n"
        return s
    }
}
