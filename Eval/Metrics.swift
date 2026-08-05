// TicBuddy — Eval/Metrics.swift
// Pure, testable metric functions shared by the eval harness and its unit tests.
// No I/O, no globals — every function is a deterministic transform of its inputs,
// so `Eval/ScorerTests.swift` can assert the math on known toy inputs. Keeping the
// scoring here (rather than inline in the harness) is what lets the numbers be trusted.

import Foundation

enum Metrics {

    // MARK: - Retrieval (per query)

    /// True if any gold id appears in the top-k of the ranked list.
    static func hit(rankedIds: [Int], gold: Set<Int>, k: Int) -> Bool {
        rankedIds.prefix(k).contains { gold.contains($0) }
    }

    /// Fraction of the gold set present in the top-k (0…1).
    static func recall(rankedIds: [Int], gold: Set<Int>, k: Int) -> Double {
        guard !gold.isEmpty else { return 0 }
        let top = Set(rankedIds.prefix(k))
        return Double(top.intersection(gold).count) / Double(gold.count)
    }

    /// Reciprocal rank of the first gold id in the full ranking (0 if none).
    static func reciprocalRank(rankedIds: [Int], gold: Set<Int>) -> Double {
        guard let idx = rankedIds.firstIndex(where: { gold.contains($0) }) else { return 0 }
        return 1.0 / Double(idx + 1)
    }

    // MARK: - Classification (from confusion counts)

    static func precision(tp: Int, fp: Int) -> Double { tp + fp > 0 ? Double(tp) / Double(tp + fp) : 0 }
    static func recall(tp: Int, fn: Int) -> Double { tp + fn > 0 ? Double(tp) / Double(tp + fn) : 0 }
    static func accuracy(tp: Int, fp: Int, fn: Int, tn: Int) -> Double {
        let n = tp + fp + fn + tn
        return n > 0 ? Double(tp + tn) / Double(n) : 0
    }
    static func f1(precision p: Double, recall r: Double) -> Double { p + r > 0 ? 2 * p * r / (p + r) : 0 }

    /// Confusion counts for a binary decision set (positive class = "refuse").
    /// Each item is (expectedRefuse, predictedRefuse).
    static func confusion(_ items: [(exp: Bool, pred: Bool)]) -> (tp: Int, fp: Int, fn: Int, tn: Int) {
        var tp = 0, fp = 0, fn = 0, tn = 0
        for it in items {
            switch (it.exp, it.pred) {
            case (true, true): tp += 1
            case (false, true): fp += 1
            case (true, false): fn += 1
            case (false, false): tn += 1
            }
        }
        return (tp, fp, fn, tn)
    }

    // MARK: - Deterministic bootstrap confidence intervals

    /// SplitMix64 — a tiny deterministic PRNG so bootstrap CIs are reproducible
    /// (the harness must never use unseeded randomness).
    struct SeededRNG: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    /// Percentile bootstrap 95% CI of `stat` over `items`, resampling with
    /// replacement. Deterministic given `seed`. Returns the point-estimate-agnostic
    /// (lo, hi) at the 2.5th / 97.5th percentiles.
    static func bootstrapCI<T>(_ items: [T],
                               iterations: Int = 10_000,
                               seed: UInt64 = 0xC0FFEE,
                               _ stat: ([T]) -> Double) -> (lo: Double, hi: Double) {
        guard items.count > 1 else { return (0, 0) }
        var rng = SeededRNG(seed: seed)
        let n = items.count
        var samples = [Double]()
        samples.reserveCapacity(iterations)
        var resample = [T]()
        resample.reserveCapacity(n)
        for _ in 0..<iterations {
            resample.removeAll(keepingCapacity: true)
            for _ in 0..<n { resample.append(items[Int.random(in: 0..<n, using: &rng)]) }
            samples.append(stat(resample))
        }
        samples.sort()
        func pct(_ p: Double) -> Double {
            let idx = min(samples.count - 1, max(0, Int((p / 100.0) * Double(samples.count))))
            return samples[idx]
        }
        return (pct(2.5), pct(97.5))
    }

    /// Mean of a [0,1]-valued array (used for hit-rate / recall / MRR bootstrap).
    static func mean(_ xs: [Double]) -> Double {
        xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }
}
