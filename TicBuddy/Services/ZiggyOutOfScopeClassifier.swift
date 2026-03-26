// TicBuddy — ZiggyOutOfScopeClassifier.swift
// Out-of-scope classifier — intercepts user messages BEFORE they hit the RAG
// pipeline or Claude API. If a message is clearly outside Ziggy's educational
// CBIT scope, it returns a warm redirect immediately — no API call, no cost.
// (tb-rag-003)
//
// WHY THIS LAYER EXISTS:
//   The system prompt instructs Claude to redirect out-of-scope questions, but
//   calling the API for every medication / diagnosis / diet query wastes latency
//   and tokens. This classifier handles obvious cases client-side so Claude is
//   only called for questions that genuinely belong in the CBIT domain.
//
// Design:
//   - Fast keyword + phrase matching (no ML on-device, no latency).
//   - Conservative: only blocks patterns with high confidence — ambiguous messages
//     are passed through and left to Claude + the system prompt.
//   - Returns a `.redirect` with a warm, age-neutral fallback message.
//   - Categories: medication, diagnosis, sideEffects, dietWeight, unrelated.
//
// Integration point: call `classify(_:)` in ClaudeService.sendMessage*,
// AFTER PII scrubbing and BEFORE building the API request.

import Foundation

// MARK: - Classification Result

enum OutOfScopeCategory: String {
    case medication    = "medication"
    case diagnosis     = "diagnosis"
    case sideEffects   = "side_effects"
    case dietWeight    = "diet_weight"
    case unrelated     = "unrelated"
}

enum ClassificationResult {
    /// Message is within CBIT / tic-management scope — continue to RAG / Claude.
    case inScope
    /// Message is clearly out of scope — show `redirect` to user, skip API call.
    case outOfScope(category: OutOfScopeCategory, redirect: String)
}

// MARK: - Classifier

final class ZiggyOutOfScopeClassifier: @unchecked Sendable {
    static let shared = ZiggyOutOfScopeClassifier()
    private init() {}

    // MARK: - Public API

    /// Classify an inbound user message (should be called AFTER PII scrubbing).
    /// Returns `.inScope` or `.outOfScope(category:redirect:)`.
    func classify(_ input: String) -> ClassificationResult {
        let normalized = input.lowercased()

        if let result = checkMedication(normalized)  { return result }
        if let result = checkDiagnosis(normalized)   { return result }
        if let result = checkSideEffects(normalized) { return result }
        if let result = checkDietWeight(normalized)  { return result }
        if let result = checkUnrelated(normalized)   { return result }

        return .inScope
    }

    // MARK: - Medication

    // Named medications, dosage language, prescription requests.
    // Mirrors ZiggyOutputFilter's list so both layers stay consistent.
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
        "tetrabenazine", "valbenazine", "ingrezza", "deutetrabenazine"
    ]

    private let medicationPhrases: [String] = [
        "what medication",
        "which medication",
        "what medicine",
        "which medicine",
        "what drug",
        "what pill",
        "what dose",
        "what dosage",
        "how many mg",
        "should i take",
        "should they take",
        "what to prescribe",
        "can i take",
        "can they take",
        "is it safe to take",
        "what about medication",
        "medication for tics",
        "medicine for tics",
        "drugs for tics",
        "pills for tics",
        "medicate my child",
    ]

    private func checkMedication(_ normalized: String) -> ClassificationResult? {
        let hit = medicationKeywords.contains(where: { normalized.contains($0) })
            || medicationPhrases.contains(where: { normalized.contains($0) })
        guard hit else { return nil }
        return .outOfScope(category: .medication, redirect: medicationRedirect)
    }

    // MARK: - Diagnosis

    // Requests to diagnose or confirm a condition — Ziggy cannot diagnose.
    private let diagnosisPhrases: [String] = [
        "do i have tourette",
        "does my child have tourette",
        "does he have tourette",
        "does she have tourette",
        "is it tourette",
        "do i have ocd",
        "do i have adhd",
        "do i have a tic disorder",
        "is this a tic disorder",
        "can you diagnose",
        "diagnose me",
        "diagnose my child",
        "what disorder do i have",
        "what condition do i have",
        "am i autistic",
        "do i have autism",
        "is this autism",
        "is this a diagnosis",
        "is this normal for tourette",
    ]

    private func checkDiagnosis(_ normalized: String) -> ClassificationResult? {
        guard diagnosisPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return .outOfScope(category: .diagnosis, redirect: diagnosisRedirect)
    }

    // MARK: - Side Effects

    // Questions about medication side effects — out of scope, redirect to doctor.
    private let sideEffectPhrases: [String] = [
        "side effect",
        "side effects",
        "adverse effect",
        "adverse reaction",
        "bad reaction",
        "reaction to medication",
        "reaction to medicine",
        "is it safe",
        "drug interaction",
        "medication interaction",
    ]

    private func checkSideEffects(_ normalized: String) -> ClassificationResult? {
        guard sideEffectPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return .outOfScope(category: .sideEffects, redirect: sideEffectsRedirect)
    }

    // MARK: - Diet / Weight

    // Weight loss, dietary interventions — not part of CBIT protocol.
    private let dietWeightPhrases: [String] = [
        "lose weight",
        "gain weight",
        "weight loss",
        "calorie",
        "calories",
        "diet plan",
        "gluten free for tics",
        "gluten and tics",
        "sugar and tics",
        "sugar free",
        "food and tics",
        "what foods cause tics",
        "does diet affect tics",
        "nutrition for tics",
        "supplement for tics",
        "omega 3 for tics",
        "magnesium for tics",
        "vitamin for tics",
    ]

    private func checkDietWeight(_ normalized: String) -> ClassificationResult? {
        guard dietWeightPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return .outOfScope(category: .dietWeight, redirect: dietWeightRedirect)
    }

    // MARK: - Clearly Unrelated Topics

    // Topics that have no plausible connection to tic management.
    // Keep this list SHORT and high-confidence only — false positives are costly.
    private let unrelatedPhrases: [String] = [
        "do my homework",
        "write my essay",
        "solve this math",
        "what's the weather",
        "who won the game",
        "tell me a joke",     // fine for Ziggy to redirect warmly
        "play a game with me",
        "what's 2 plus 2",
        "search the internet",
        "browse the web",
        "send an email",
        "call my mom",
        "book a flight",
        "order food",
        "stock price",
        "cryptocurrency",
        "invest in",
        "politics",
        "who should i vote",
        "write code for me",
        "program a",
    ]

    private func checkUnrelated(_ normalized: String) -> ClassificationResult? {
        guard unrelatedPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return .outOfScope(category: .unrelated, redirect: unrelatedRedirect)
    }

    // MARK: - Redirect Messages (warm, age-neutral)

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
}
