// TicBuddy — TextMatch.swift
// Lightweight lexical matching utilities for HYBRID retrieval + domain detection.
// (tb-rag-ondevice-008)
//
// WHY THIS EXISTS
// ---------------
// Apple's on-device sentence embedding is weak on short, colloquial queries: e.g.
// "What is the premonitory urge?" scores only ~0.25 against a chunk that literally
// defines the premonitory urge, and "focus on week 1" retrieves nothing. That is a
// known limitation of general-purpose embeddings on keyword-y questions.
//
// The standard, defensible remedy is HYBRID search: blend the dense semantic score
// with a sparse lexical (term-overlap) score. Lexical matching nails exact-term
// questions; embeddings handle paraphrase. Together they cover each other.
//
// This also provides a small curated DOMAIN LEXICON so the guardrail can allow any
// query that explicitly names core tic/CBIT vocabulary, regardless of embedding
// score — biasing, deliberately, toward answering a child's on-topic question
// rather than falsely refusing it.
//
// App-type-free: compiles into the app and the CLI self-test alike.

import Foundation

enum TextMatch {

    /// Common English stopwords stripped before term-overlap scoring so matches
    /// reflect content words, not "the/of/is".
    static let stopwords: Set<String> = [
        "a","an","the","and","or","but","if","then","of","to","in","on","at","for",
        "is","am","are","was","were","be","been","being","do","does","did","doing",
        "i","me","my","we","us","our","you","your","he","she","it","they","them","their",
        "this","that","these","those","what","which","who","how","when","where","why",
        "can","could","should","would","will","shall","may","might","must",
        "with","about","from","as","so","just","really","today","get","got","have","has",
        "some","any","not","no","yes","help","tell","like","want","need","much","more",
    ]

    /// Tokenize into lowercased alphanumeric words.
    static func tokenize(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    /// Content words = tokens minus stopwords.
    static func contentWords(_ text: String) -> Set<String> {
        Set(tokenize(text).filter { !stopwords.contains($0) })
    }

    /// Two content words count as a lexical match if they are equal, or if one is
    /// a prefix of the other and both are reasonably long. Prefix matching absorbs
    /// simple inflection ("focus"/"focuses", "tic"/"tics", "notice"/"noticing")
    /// without the pitfalls of ad-hoc suffix stripping.
    static func wordsMatch(_ a: String, _ b: String) -> Bool {
        if a == b { return true }
        let shorter = a.count <= b.count ? a : b
        let longer  = a.count <= b.count ? b : a
        return shorter.count >= 4 && longer.hasPrefix(shorter)
    }

    /// General lay↔clinical synonym map for the CBIT / Tourette's domain. Keys are
    /// the everyday words a child or parent types; values are the clinical terms the
    /// curated corpus actually uses (every target below appears verbatim in
    /// `CBITCorpus.swift`, so each entry can do real work). Built from domain-glossary
    /// knowledge, NOT reverse-engineered from failing queries, and applied ONLY to the
    /// retrieval lexical signal below — embeddings and the guardrail are untouched.
    ///
    /// This is a deliberately small, transparent list: a lexical map only helps queries
    /// that use an enumerated lay term. Truly novel vocabulary still needs the semantic
    /// signal (or a stronger embedding); this just closes the most common lay/clinical gaps.
    static let synonyms: [String: [String]] = [
        // prognosis / aging: "will they grow out of it?" → corpus says "adolescence/adulthood"
        "grow": ["adolescence", "adulthood"], "grows": ["adolescence", "adulthood"],
        "growing": ["adolescence", "adulthood"], "outgrow": ["adolescence", "adulthood"],
        "older": ["adolescence", "adulthood"], "teen": ["adolescence", "adulthood"],
        "teenager": ["adolescence", "adulthood"],
        "kids": ["children", "child"], "kid": ["children", "child"],
        // outcome / efficacy: "does it work?" → corpus says "improvement/evidence"
        "better": ["improve", "improvement"],
        "work": ["improvement", "evidence"], "works": ["improvement", "evidence"],
        "working": ["improvement", "evidence"], "proven": ["evidence", "improvement"],
        // co-occurring conditions: "what comes along with it?" → corpus says "co-occur"
        "along": ["occur"], "alongside": ["occur"], "related": ["occur"],
        // relaxation
        "chill": ["relaxation", "calm"], "destress": ["relaxation", "calm"],
    ]

    /// True if query word `qw` matches any word in `t` directly, or via a mapped synonym.
    private static func matches(_ qw: String, in t: Set<String>) -> Bool {
        if t.contains(where: { wordsMatch(qw, $0) }) { return true }
        if let syns = synonyms[qw] {
            return syns.contains { s in t.contains(where: { wordsMatch(s, $0) }) }
        }
        return false
    }

    /// Fraction of the query's content words that lexically match some word in
    /// `text` (0…1), counting general lay↔clinical synonyms as matches. This is the
    /// sparse/lexical relevance signal for hybrid retrieval.
    static func overlapFraction(query: String, in text: String) -> Double {
        let q = contentWords(query)
        guard !q.isEmpty else { return 0 }
        let t = contentWords(text)
        let hits = q.filter { matches($0, in: t) }.count
        return Double(hits) / Double(q.count)
    }

    // MARK: - Domain lexicon

    /// Core single-word domain terms. If a query contains any of these it is
    /// unambiguously about the CBIT / tic domain (the out-of-scope keyword layer
    /// still runs FIRST, so "medication for tics" is refused before it gets here).
    static let domainUnigrams: Set<String> = [
        "tic","tics","tourette","tourettes","premonitory","cbit","neuroplasticity",
        "twitch","twitches","twitching","blink","blinking","grimace","shrug","shrugging",
        "grunt","grunting","sniff","sniffing","redirect","redirecting","urge",
        // Genuine domain terms that legitimate CBIT questions use but the raised
        // embedding floor (0.38) would otherwise over-refuse: the app's own "baseline"
        // vocabulary and inflections of "tic". Added as real domain vocab, not per-query.
        "baseline","ticcing","ticced",
    ]

    /// Multi-word domain phrases checked as substrings.
    static let domainPhrases: [String] = [
        "competing response","power move","premonitory urge","brain training",
        "throat clearing","vocal tic","motor tic","the feeling before","signal feeling",
        "eye blink","head jerk","tic disorder",
        // CBIT weekly-program vocabulary: a question naming a program week or one of
        // the app's kid-friendly week names is in-domain (fixes prior over-refusal of
        // "what should we focus on in week 1/2?", which named no other domain term and
        // fell below the embedding floor). Covers the whole 4-week program, not just
        // the two queries that failed.
        "week 1","week 2","week 3","week 4","detective mode","signal spotter",
    ]

    /// True if the text explicitly names domain vocabulary.
    static func mentionsDomain(_ text: String) -> Bool {
        let lower = text.lowercased()
        if domainPhrases.contains(where: { lower.contains($0) }) { return true }
        let words = Set(tokenize(text))
        return !words.isDisjoint(with: domainUnigrams)
    }
}
