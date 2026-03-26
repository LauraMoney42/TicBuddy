// TicBuddy — ZiggyContentFilter.swift
// Client-side safety filter for Ziggy chat (tb-mvp2-020 + tb-mvp2-021).
//
// Intercepts out-of-scope messages BEFORE they reach the Claude API.
// Three categories, checked in priority order:
//
//   1. CRISIS / SELF-HARM — Always redirect. Highest priority. No tic-context exception.
//      "I want to die because of my tics" → 988 redirect (tic context ignored).
//      Shows immediate 988 Lifeline connection.
//
//   2. MEDICATION — Always redirect. No exceptions.
//      Covers medication names, dosage questions, start/stop/change requests.
//
//   3. MENTAL HEALTH COUNSELING — Redirect UNLESS tic-context is present.
//      "I feel anxious about my tic" → safe (tic context present).
//      "Am I depressed?" → redirect (no tic context).
//      "OCD vs tic difference" → safe (tic context present).
//
// WHY CLIENT-SIDE:
//   The filter runs before the message reaches Claude so the API never
//   receives the content at all. This is a hard safety boundary, not a
//   prompt instruction that could be overridden by jailbreak attempts.
//
// CONTEXT-AWARENESS (tb-mvp2-021):
//   A tic-context whitelist prevents false positives on valid tic-related questions.
//   Crisis signals deliberately bypass this whitelist — "want to die" always redirects
//   to 988 regardless of whether tic context is present.

import Foundation

// MARK: - Filter Result

enum ZiggyFilterResult {
    case safe                    // Message is fine — send to Claude
    case redirect(message: String) // Blocked — show this warm redirect in chat UI instead
}

// MARK: - Ziggy Content Filter

final class ZiggyContentFilter: @unchecked Sendable {
    static let shared = ZiggyContentFilter()
    private init() {}

    // MARK: - Public API

    /// Check a user message before sending it to Claude.
    /// Returns .safe or .redirect(message:).
    ///
    /// Priority order:
    ///   1. Crisis signals — ALWAYS redirect (no tic-context exception, 988 shown)
    ///   2. Medication query — ALWAYS redirect (no exceptions)
    ///   3. Mental health counseling — redirect ONLY if no tic context present
    func check(_ input: String) -> ZiggyFilterResult {
        let normalized = input.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Crisis / self-harm check — hard block regardless of any context.
        //    "I want to die because of my tics" must still show the 988 redirect,
        //    not be allowed through just because "tics" is present.
        if isCrisisSignal(normalized) {
            return .redirect(message: crisisRedirect)
        }

        // 2. Medication check — hard block regardless of context
        if isMedicationQuery(normalized) {
            return .redirect(message: medicationRedirect)
        }

        // 3. Mental health OOS check — only block if no tic context present
        if isMentalHealthCounseling(normalized) && !hasticContext(normalized) {
            return .redirect(message: mentalHealthRedirect)
        }

        return .safe
    }

    // MARK: - Warm Redirect Messages

    /// Shown for crisis/self-harm signals — prioritizes 988 connection above everything.
    private let crisisRedirect = """
    I'm really glad you said something, and I care about you. 💛 \
    Please talk to a trusted adult — a parent, teacher, or counselor — right now.

    If you need someone to talk to immediately, you can text or call 988 (Suicide & Crisis Lifeline). \
    They're there for you, any time, day or night.

    I'm just a tic-training buddy and I'm not the right support for this — but the people at 988 are. 💙
    """

    private let medicationRedirect = """
    That's really a question for your doctor or psychiatrist — they know your full picture. \
    I'm just here to help with tic practice! 💙

    Is there something about your tics or CBIT practice I can help with today?
    """

    private let mentalHealthRedirect = """
    That's really a question for your doctor or a counselor — they're the right person to help with that. \
    I'm just here to support your tic practice! 💙

    If you're going through something hard, talking to a trusted adult is always a great idea. \
    And if you ever feel really overwhelmed, you can always text or call 988 — they're there for you. 💛

    Is there something about your tics I can help with today?
    """

    // MARK: - Tic Context Whitelist
    // If a message contains ANY of these terms alongside flagged content,
    // it's considered tic-context and allowed through.

    private let ticContextTerms: [String] = [
        "tic", "tics", "ticking",
        "tourette", "tourettes", "ts",
        "cbit", "competing response", "habit reversal",
        "premonitory", "urge", "motor", "vocal",
        "blink", "shrug", "throat clear", "sniff", "grunt",
        "eye roll", "head jerk", "twitch",
        "suppressing", "suppress my", "holding back"
    ]

    private func hasticContext(_ text: String) -> Bool {
        ticContextTerms.contains { text.contains($0) }
    }

    // MARK: - Medication Detection

    // Common psychiatric/neurological medications used in Tourette's, ADHD, anxiety, OCD.
    // Includes both generic names and common brand names.
    private let medicationNames: [String] = [
        // Dopamine blockers / antipsychotics (TS-specific)
        "haloperidol", "haldol",
        "fluphenazine", "prolixin",
        "pimozide", "orap",
        "risperidone", "risperdal",
        "aripiprazole", "abilify",
        "ziprasidone", "geodon",
        "quetiapine", "seroquel",
        "olanzapine", "zyprexa",
        // Alpha-2 agonists (TS-common)
        "clonidine", "catapres", "kapvay",
        "guanfacine", "tenex", "intuniv",
        // ADHD medications
        "adderall", "amphetamine",
        "ritalin", "methylphenidate", "concerta", "focalin",
        "vyvanse", "lisdexamfetamine",
        "strattera", "atomoxetine",
        "wellbutrin", "bupropion",
        // Antidepressants / SSRIs (OCD, anxiety)
        "sertraline", "zoloft",
        "fluoxetine", "prozac",
        "fluvoxamine", "luvox",
        "escitalopram", "lexapro",
        "citalopram", "celexa",
        "paroxetine", "paxil",
        "venlafaxine", "effexor",
        "duloxetine", "cymbalta",
        "clomipramine", "anafranil",
        // Benzodiazepines
        "clonazepam", "klonopin",
        "lorazepam", "ativan",
        "diazepam", "valium",
        "alprazolam", "xanax",
        // Generic / catch-all medication terms
        "topamax", "topiramate",
        "naltrexone", "baclofen",
        "tetrabenazine", "xenazine",
        "valbenazine", "ingrezza",
        "deutetrabenazine", "austedo"
    ]

    // Dosage and medication management patterns
    private let medicationPhrases: [String] = [
        "should i take",
        "should i stop",
        "should i start",
        "can i take more",
        "can i take less",
        "how much do i take",
        "how much should i take",
        "what dose",
        "what dosage",
        "forgot my",
        "forgot to take",
        "missed my dose",
        "missed my medication",
        "missed my meds",
        "my medication",
        "my meds",
        "my pills",
        "my dose",
        "my dosage",
        "change my medication",
        "switch my medication",
        "off my meds",
        "without my meds",
        "side effect",
        "side effects"
    ]

    private func isMedicationQuery(_ text: String) -> Bool {
        // Direct medication name match
        if medicationNames.contains(where: { text.contains($0) }) {
            return true
        }
        // Medication management phrase match
        if medicationPhrases.contains(where: { text.contains($0) }) {
            return true
        }
        return false
    }

    // MARK: - Crisis / Self-Harm Detection
    // Hard block — shown regardless of tic context.
    // These signals always get the 988 redirect, no exceptions.

    private let crisisPhrases: [String] = [
        "hurt myself",
        "hurting myself",
        "want to die",
        "don't want to be here",
        "do not want to be here",
        "kill myself",
        "killing myself",
        "end my life",
        "take my life",
        "not want to live",
        "don't want to live",
        "suicidal",
        "suicide",
        "cutting myself",
        "cut myself",
        "self harm",
        "self-harm",
        "harm myself"
    ]

    private func isCrisisSignal(_ text: String) -> Bool {
        crisisPhrases.contains { text.contains($0) }
    }

    // MARK: - Mental Health Counseling Detection
    // These phrases signal requests for diagnosis, therapy, or counseling
    // that are out of scope for a tic-coaching app.
    // NOTE: Crisis phrases are intentionally NOT in this list —
    //       they live in crisisPhrases above with no tic-context bypass.

    private let mentalHealthPhrases: [String] = [
        // Self-diagnosis / "what's wrong with me"
        "am i crazy",
        "what's wrong with me",
        "what is wrong with me",
        "why am i like this",
        "am i broken",
        "something wrong with me",
        "there's something wrong",
        // Depression
        "am i depressed",
        "i think i'm depressed",
        "i might be depressed",
        "i feel depressed",
        "i have depression",
        "do i have depression",
        // Anxiety (standalone — "anxious about my tic" is caught by tic-context whitelist)
        "do i have anxiety",
        "i think i have anxiety",
        "i might have anxiety disorder",
        "generalized anxiety",
        "panic attack",
        "panic disorder",
        // OCD (standalone — "OCD vs tic" is caught by tic-context whitelist)
        "do i have ocd",
        "i think i have ocd",
        "i might have ocd",
        "is this ocd",
        // Therapy/counseling requests
        "do i need therapy",
        "do i need a therapist",
        "should i see a therapist",
        "should i see a counselor",
        "should i see a psychiatrist",
        "do i need medication",
        "do i need meds"
    ]

    private func isMentalHealthCounseling(_ text: String) -> Bool {
        mentalHealthPhrases.contains { text.contains($0) }
    }
}

// MARK: - ZiggyFilterResult Helpers

extension ZiggyFilterResult {
    var isBlocked: Bool {
        if case .redirect = self { return true }
        return false
    }

    var redirectMessage: String? {
        if case .redirect(let message) = self { return message }
        return nil
    }
}
