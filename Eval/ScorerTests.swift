// TicBuddy — Eval/ScorerTests.swift
// Unit tests for the eval scorer (Metrics.swift) on known toy inputs, so the
// metric math itself is trusted — an off-by-one in rank handling would fail here,
// not silently ship a wrong number. Run:  bash Eval/run_scorer_tests.sh

import Foundation

@main
enum ScorerTests {
    static var failures = 0

    static func expect(_ cond: Bool, _ name: String) {
        print("  \(cond ? "✅" : "❌")  \(name)")
        if !cond { failures += 1 }
    }
    static func eq(_ a: Double, _ b: Double, _ name: String, tol: Double = 1e-9) {
        expect(abs(a - b) <= tol, "\(name)  (\(a) ≈ \(b))")
    }

    static func main() {
        print("=== scorer unit tests ===")

        // hit@k
        expect(Metrics.hit(rankedIds: [3, 1, 2], gold: [1], k: 1) == false, "hit@1 miss when gold not first")
        expect(Metrics.hit(rankedIds: [3, 1, 2], gold: [1], k: 2) == true, "hit@2 catches gold at rank 2")
        expect(Metrics.hit(rankedIds: [3, 1, 2], gold: [9], k: 3) == false, "hit@3 miss when gold absent")

        // recall@k
        eq(Metrics.recall(rankedIds: [3, 1, 4, 2], gold: [1, 2], k: 2), 0.5, "recall@2 = 1 of 2 gold")
        eq(Metrics.recall(rankedIds: [3, 1, 4, 2], gold: [1, 2], k: 4), 1.0, "recall@4 = 2 of 2 gold")
        eq(Metrics.recall(rankedIds: [1, 2], gold: [], k: 2), 0.0, "recall with empty gold = 0")

        // reciprocal rank
        eq(Metrics.reciprocalRank(rankedIds: [3, 1, 2], gold: [1]), 0.5, "RR: gold at rank 2 -> 1/2")
        eq(Metrics.reciprocalRank(rankedIds: [3, 1, 2], gold: [2]), 1.0 / 3.0, "RR: gold at rank 3 -> 1/3")
        eq(Metrics.reciprocalRank(rankedIds: [3, 1, 2], gold: [9]), 0.0, "RR: gold absent -> 0")

        // classification from counts (tp=3, fp=1, fn=1, tn=5)
        eq(Metrics.precision(tp: 3, fp: 1), 0.75, "precision 3/(3+1)")
        eq(Metrics.recall(tp: 3, fn: 1), 0.75, "recall 3/(3+1)")
        eq(Metrics.f1(precision: 0.75, recall: 0.75), 0.75, "f1 of equal p,r")
        eq(Metrics.accuracy(tp: 3, fp: 1, fn: 1, tn: 5), 0.8, "accuracy (3+5)/10")
        eq(Metrics.precision(tp: 0, fp: 0), 0.0, "precision undefined -> 0")

        // confusion counting
        let conf = Metrics.confusion([(true, true), (true, true), (false, true), (true, false), (false, false)])
        expect(conf == (tp: 2, fp: 1, fn: 1, tn: 1), "confusion counts (2,1,1,1)")

        // bootstrap: determinism + sane bounds
        let ones = [Double](repeating: 1.0, count: 20)
        let ci1 = Metrics.bootstrapCI(ones, seed: 42, Metrics.mean)
        eq(ci1.lo, 1.0, "bootstrap of all-1s: lo = 1")
        eq(ci1.hi, 1.0, "bootstrap of all-1s: hi = 1")
        let mixed = (0..<40).map { Double($0 % 2) }  // twenty 0s, twenty 1s -> mean 0.5
        let a = Metrics.bootstrapCI(mixed, seed: 7, Metrics.mean)
        let b = Metrics.bootstrapCI(mixed, seed: 7, Metrics.mean)
        expect(a.lo == b.lo && a.hi == b.hi, "bootstrap deterministic for a fixed seed")
        expect(a.lo <= 0.5 && 0.5 <= a.hi, "bootstrap CI brackets the mean (0.5)")
        expect(a.lo < a.hi, "bootstrap CI has positive width on mixed data")

        print(failures == 0 ? "\n=== ALL SCORER TESTS PASSED ✅ ===" : "\n=== \(failures) FAILED ❌ ===")
        exit(failures == 0 ? 0 : 1)
    }
}
