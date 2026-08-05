// TicBuddy — DomainGuardrail.swift
// Layered domain guardrail: decides whether a user message is in-scope for
// Ziggy's CBIT / tic-management domain before any Claude API call. (tb-rag-ondevice-004)
//
// WHY LAYERED (and not a single cosine threshold)
// -----------------------------------------------
// We measured Apple's on-device sentence embeddings against this exact corpus with
// 6 in-domain and 6 out-of-domain probe queries. The scores OVERLAP:
//
//     in-domain  max-chunk-similarity: 0.329 – 0.452   (min 0.329)
//     out-domain max-chunk-similarity: 0.240 – 0.338   (max 0.338)
//
// e.g. "What is the feeling before a tic called?" (in-domain) scored 0.329, while
// "best cryptocurrency to invest in?" (out-of-domain) scored 0.338. And
// "what medication dosage for my child?" scored HIGH on the centroid because it
// shares vocabulary with the domain. So no lone similarity cutoff is defensible.
//
// The guardrail therefore uses three complementary layers, each covering the
// others' blind spots:
//
//   Layer 1 — Deterministic keyword/phrase classifier (HIGH precision).
//     Catches the categories embeddings get wrong precisely because they share
//     domain vocabulary: medication names/dosages, diagnosis requests, side
//     effects, diet/weight, and obvious unrelated asks (crypto, essays, weather).
//     Fast, no model, no cost. Only fires on high-confidence patterns.
//
//   Layer 2 — Embedding-distance floor (RECALL for the long tail).
//     For anything the keywords miss, if the query's best similarity to ANY corpus
//     chunk is below FLOOR (0.30 — a safe margin under the 0.329 in-domain min),
//     it is semantically distant from everything we know about and is refused.
//     Catches novel out-of-domain phrasings the keyword list never enumerated.
//
//   Layer 3 — System-prompt refusal instruction (BACKSTOP, in ClaudeService).
//     For near-threshold queries that slip both deterministic layers, the model is
//     instructed to redirect out-of-scope questions. This is the last line only.
//
// This file has NO app-type dependencies, so the CLI self-test exercises the exact
// shipping decision logic.

import Foundation

// MARK: - Categories & Decision

enum OutOfScopeCategory: String {
    case medication   = "medication"
    case diagnosis    = "diagnosis"
    case sideEffects  = "side_effects"
    case dietWeight   = "diet_weight"
    case unrelated    = "unrelated"
    /// Refused by the embedding floor rather than a specific keyword category.
    case offDomain    = "off_domain"
}

enum GuardrailDecision {
    /// In-scope. `signals` are carried through for observability/logging.
    case allow(signals: DomainSignals)
    /// Out-of-scope. Show `redirect` to the user and skip the API call.
    case refuse(category: OutOfScopeCategory, redirect: String, signals: DomainSignals)

    var isAllowed: Bool { if case .allow = self { return true }; return false }
}

// MARK: - Guardrail

/// Immutable after init (an index reference plus `let` keyword lists), safe to share.
final class DomainGuardrail: @unchecked Sendable {

    static let shared = DomainGuardrail()

    private let index: OnDeviceRAGIndex

    init(index: OnDeviceRAGIndex = .shared) {
        self.index = index
    }

    // MARK: Calibrated thresholds (see header for the measurement they came from)

    /// Below this best-chunk similarity, AND with no explicit domain vocabulary,
    /// a query is treated as semantically off-domain. Set at 0.28 — under the
    /// weakest genuine in-domain query we measured, so real CBIT questions are not
    /// falsely refused. Note this is a SEMANTIC net only: it is deliberately not
    /// the sole gate, because embedding scores for in- and out-of-domain overlap
    /// (see header). The keyword layer and the domain-lexicon allow-path do the
    /// precise work; this floor just catches the semantically-distant long tail.
    static let domainFloor: Double = 0.28

    // MARK: - Public API

    /// Evaluate a (PII-scrubbed) user message through the layered guardrail.
    ///
    /// Order matters:
    ///   1. Out-of-scope keyword/phrase classifier → REFUSE. Runs first so that
    ///      "medication for tics" is blocked even though it contains "tics".
    ///   2. Domain-lexicon allow-path → ALLOW. Any query explicitly naming core
    ///      tic/CBIT vocabulary is in-scope regardless of embedding weakness. Bias
    ///      is intentionally toward answering a child's on-topic question.
    ///   3. Semantic floor → REFUSE if the best chunk similarity is below the floor
    ///      (the long-tail catch for novel off-domain phrasings).
    ///   4. Otherwise ALLOW (system-prompt refusal is the final backstop).
    func evaluate(_ message: String) -> GuardrailDecision {
        let normalized = message.lowercased()

        // Layer 1 — deterministic out-of-scope classifier (highest precedence).
        if let (category, redirect) = keywordClassify(normalized) {
            let signals = index.domainSignals(for: message)   // on-device/free; for the log
            return .refuse(category: category, redirect: redirect, signals: signals)
        }

        let signals = index.domainSignals(for: message)

        // Layer 2 — explicit domain vocabulary always passes.
        if TextMatch.mentionsDomain(message) {
            return .allow(signals: signals)
        }

        // Layer 3 — semantic distance floor. Only enforced when the on-device index
        // actually built; if the model is unavailable we fail OPEN (never hard-block
        // a real user on a missing embedding — the system-prompt backstop remains).
        if index.isReady, signals.maxChunkSimilarity < Self.domainFloor {
            return .refuse(category: .offDomain, redirect: offDomainRedirect, signals: signals)
        }

        return .allow(signals: signals)
    }

    // MARK: - Layer 1: keyword/phrase classifier

    /// Returns a category + redirect if the message matches a high-confidence
    /// out-of-scope pattern, else nil. Conservative by design: ambiguous messages
    /// pass through to the embedding layer and ultimately to Claude.
    private func keywordClassify(_ normalized: String) -> (OutOfScopeCategory, String)? {
        if contains(normalized, medicationKeywords) || contains(normalized, medicationPhrases) {
            return (.medication, medicationRedirect)
        }
        if contains(normalized, diagnosisPhrases) {
            return (.diagnosis, diagnosisRedirect)
        }
        if contains(normalized, sideEffectPhrases) {
            return (.sideEffects, sideEffectsRedirect)
        }
        if contains(normalized, dietWeightPhrases) {
            return (.dietWeight, dietWeightRedirect)
        }
        if contains(normalized, unrelatedPhrases) {
            return (.unrelated, unrelatedRedirect)
        }
        return nil
    }

    private func contains(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    // MARK: Keyword & phrase lists
    // (Consolidated single source of truth — previously duplicated in the
    //  now-removed ZiggyOutOfScopeClassifier. Mirrors ZiggyOutputFilter's med list.)

    private let medicationKeywords: [String] = [
        "haloperidol", "haldol", "fluphenazine", "pimozide", "orap",
        "risperidone", "risperdal", "aripiprazole", "abilify",
        "ziprasidone", "quetiapine", "seroquel", "olanzapine",
        "clonidine", "catapres", "guanfacine", "tenex", "intuniv",
        "adderall", "amphetamine", "ritalin", "methylphenidate",
        "concerta", "vyvanse", "strattera", "atomoxetine", "wellbutrin",
        "sertraline", "zoloft", "fluoxetine", "prozac", "fluvoxamine",
        "escitalopram", "lexapro", "citalopram", "paroxetine", "paxil",
        "venlafaxine", "duloxetine", "clomipramine", "anafranil",
        "clonazepam", "klonopin", "lorazepam", "ativan",
        "diazepam", "valium", "alprazolam", "xanax",
        "topiramate", "topamax", "naltrexone", "baclofen",
        "tetrabenazine", "valbenazine", "ingrezza", "deutetrabenazine",
    ]

    private let medicationPhrases: [String] = [
        "what medication", "which medication", "what medicine", "which medicine",
        "what drug", "what pill", "what dose", "what dosage", "how many mg",
        "should i take", "should they take", "should my child take", "what to prescribe",
        "can i take", "can they take", "is it safe to take", "what about medication",
        "medication for tics", "medicine for tics", "drugs for tics", "pills for tics",
        "medicate my child",
    ]

    private let diagnosisPhrases: [String] = [
        "do i have tourette", "does my child have tourette", "does he have tourette",
        "does she have tourette", "is it tourette", "do i have ocd", "do i have adhd",
        "do i have a tic disorder", "is this a tic disorder", "can you diagnose",
        "diagnose me", "diagnose my child", "what disorder do i have",
        "what condition do i have", "am i autistic", "do i have autism",
        "is this autism", "is this a diagnosis", "is this normal for tourette",
        // Person-diagnosis phrasings that name domain vocabulary ("tic disorder",
        // "tourette") and previously slipped past to the domain-lexicon ALLOW-path.
        // The keyword classifier runs before that allow-path, so enriching it here
        // closes the leak. Kept to the "does <person> have <condition>" shape so
        // general education ("do kids with tics often have adhd?") is NOT caught.
        "does my son have tourette", "does my daughter have tourette",
        "have a tic disorder", "has a tic disorder", "diagnosed with", "get a diagnosis",
    ]

    private let sideEffectPhrases: [String] = [
        "side effect", "side effects", "adverse effect", "adverse reaction",
        "bad reaction", "reaction to medication", "reaction to medicine",
        "is it safe", "drug interaction", "medication interaction",
    ]

    private let dietWeightPhrases: [String] = [
        "lose weight", "gain weight", "weight loss", "calorie", "calories",
        "diet plan", "gluten free for tics", "gluten and tics", "sugar and tics",
        "sugar free", "food and tics", "what foods cause tics", "does diet affect tics",
        "nutrition for tics", "supplement for tics", "omega 3 for tics",
        "magnesium for tics", "vitamin for tics",
        // General diet-cure claims about tics (any named diet, not just gluten-for-tics).
        // Fixes the prior leak of "does a gluten free diet reduce tics?" and generalizes
        // to other fad diets. These belong with a clinician/dietitian, not this app.
        "gluten free", "gluten-free", "keto diet", "special diet",
        "diet reduce tics", "diet for tics", "diet cure",
    ]

    private let unrelatedPhrases: [String] = [
        "do my homework", "write my essay", "write an essay", "write me an essay",
        "solve this math", "what's the weather", "what is the weather", "who won the game",
        "tell me a joke", "play a game with me", "what's 2 plus 2", "what is 2 plus 2",
        "search the internet", "browse the web", "send an email", "call my mom",
        "book a flight", "order food", "stock price", "cryptocurrency", "crypto",
        "bitcoin", "invest in", "investment", "politics", "who should i vote",
        "write code for me", "program a", "french revolution", "fix a flat", "flat tire",
        // Coding requests (previously "write me some python code" sat just above the
        // embedding floor with no keyword match and leaked through). Covers common
        // coding phrasings/languages, not just the one query that failed.
        "python", "javascript", "write code", "some code", "write a program",
        "coding", "write me code",
    ]

    // MARK: - Redirect messages (warm, age-neutral)

    private let medicationRedirect = """
    Medication is definitely one to talk through with your doctor or psychiatrist — \
    they know your full situation and can give you the real answers on that. \
    I'm just here for CBIT practice! 💙

    Is there something about your tic exercises or strategies I can help with?
    """

    private let diagnosisRedirect = """
    Working out whether something is a tic disorder or another condition is something \
    only a qualified doctor or psychologist can do — not something I'm able to help \
    with, even if I wanted to! If you're unsure about a diagnosis, your doctor is \
    the right person to ask. 💙

    I'm here to help with CBIT skills and tic practice — want to work on those together?
    """

    private let sideEffectsRedirect = """
    Questions about medication side effects are really important to discuss with your \
    doctor or pharmacist — they have the full picture on what's safe for you. \
    That's beyond what I'm designed to help with. 💙

    Is there something about your CBIT practice I can support you with today?
    """

    private let dietWeightRedirect = """
    Diet and nutrition questions are best answered by a doctor or registered dietitian — \
    I'm not the right resource for that. \
    My focus is supporting your CBIT tic-management practice. 💙

    Want to work on a technique or talk through how things are going with your exercises?
    """

    private let unrelatedRedirect = """
    Ha — I'm just a tic-training buddy, so that one is a bit outside my world! 😄 \
    I'm best at helping with CBIT exercises, tic strategies, and cheering you on.

    Is there something about your tic practice I can help with today?
    """

    private let offDomainRedirect = """
    That one's a little outside what I know about! 💙 I'm your CBIT buddy — I'm best \
    with tics, the feeling before a tic, Power Moves, and how your brain is learning.

    Want to work on something tic-related together?
    """
}
