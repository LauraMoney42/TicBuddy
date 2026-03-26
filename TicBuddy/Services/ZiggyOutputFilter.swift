// TicBuddy — ZiggyOutputFilter.swift
// Outbound safety filter — scans Claude's response BEFORE it is shown to the user.
// If a response contains prohibited content, it is replaced with a safe fallback.
// (tb-rag-004)
//
// WHY OUTBOUND FILTERING:
//   Even with a strong system prompt + inbound filter, LLM outputs can occasionally
//   drift into prohibited territory (especially via multi-turn context drift or
//   unexpected prompt injection in user messages). This filter is the last line of
//   defence before content reaches the user's screen.
//
// Categories filtered (hard blocks):
//   1. MEDICATION — Named medication references in Claude's output
//      (system prompt says never, but defence-in-depth)
//   2. DIAGNOSIS — "You have X", "It sounds like you have X", "I think you have X"
//   3. MEDICAL ADVICE — "You should take", "I recommend", "Try taking"
//   4. AI IDENTITY DENIAL — "I am a real therapist", "I'm a licensed professional"
//      (must not falsely claim to be human/licensed)
//   5. CRISIS ESCALATION — Response that discusses self-harm methods in detail
//
// On block: the response is replaced with a warm safe fallback.
// The regeneration path (re-calling Claude) is intentionally NOT used here to
// avoid infinite loops and latency spikes — a safe static fallback is more reliable.

import Foundation

// MARK: - Output Filter Result

enum OutputFilterResult {
    /// Response is safe — show to user as-is.
    case pass(response: String)
    /// Response was blocked — show fallback message instead.
    case blocked(category: String, fallback: String)
}

// MARK: - Ziggy Output Filter

final class ZiggyOutputFilter: @unchecked Sendable {
    static let shared = ZiggyOutputFilter()
    private init() {}

    // MARK: - Public API

    /// Filter a Claude response before delivering it to the user.
    /// Call this immediately after receiving the response from ClaudeService.
    func filter(_ response: String) -> OutputFilterResult {
        let normalized = response.lowercased()

        if let (category, fallback) = checkMedicationInOutput(normalized) {
            return .blocked(category: category, fallback: fallback)
        }
        if let (category, fallback) = checkDiagnosisInOutput(normalized) {
            return .blocked(category: category, fallback: fallback)
        }
        if let (category, fallback) = checkMedicalAdviceInOutput(normalized) {
            return .blocked(category: category, fallback: fallback)
        }
        if let (category, fallback) = checkIdentityDenialInOutput(normalized) {
            return .blocked(category: category, fallback: fallback)
        }
        if let (category, fallback) = checkCrisisMethodsInOutput(normalized) {
            return .blocked(category: category, fallback: fallback)
        }

        return .pass(response: response)
    }

    // MARK: - Medication in Output

    // Ziggy should never mention medication names — if Claude outputs one, block it.
    private let outputMedicationNames: [String] = [
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

    private func checkMedicationInOutput(_ normalized: String) -> (String, String)? {
        guard outputMedicationNames.contains(where: { normalized.contains($0) }) else { return nil }
        return ("medication", medicationFallback)
    }

    // MARK: - Diagnosis in Output

    // Ziggy must never diagnose. Pattern: "you have X", "sounds like you have X",
    // "it seems like you have X", "I think you have X", "you might have X"
    private let diagnosisPhrases: [String] = [
        "you have tourette",
        "you have ocd",
        "you have adhd",
        "you have anxiety disorder",
        "you have depression",
        "you might have tourette",
        "you might have ocd",
        "you might have adhd",
        "sounds like you have",
        "it sounds like you have",
        "seems like you have",
        "it seems like you have",
        "i think you have",
        "i believe you have",
        "you may have a diagnosis",
        "you could be diagnosed",
        "this sounds like a diagnosis"
    ]

    private func checkDiagnosisInOutput(_ normalized: String) -> (String, String)? {
        guard diagnosisPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return ("diagnosis", diagnosisFallback)
    }

    // MARK: - Medical Advice in Output

    // Ziggy must never give direct medical instructions.
    private let medicalAdvicePhrases: [String] = [
        "you should take",
        "i recommend taking",
        "try taking",
        "you need to take",
        "take this medication",
        "increase your dose",
        "decrease your dose",
        "stop taking your",
        "start taking",
        "switch to",
        "ask your doctor to prescribe",
        "you should see a psychiatrist",  // too directive — redirect instead
        "i recommend seeing a",
        "go to the emergency"              // crisis should use crisis redirect
    ]

    private func checkMedicalAdviceInOutput(_ normalized: String) -> (String, String)? {
        guard medicalAdvicePhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return ("medical_advice", medicalAdviceFallback)
    }

    // MARK: - AI Identity Denial in Output

    // Ziggy must always be transparent about being an AI. Block any response
    // that claims to be a real person, therapist, or licensed professional.
    private let identityDenialPhrases: [String] = [
        "i am a real therapist",
        "i'm a real therapist",
        "i am a licensed",
        "i'm a licensed",
        "i am a certified",
        "i'm a certified therapist",
        "i am not an ai",
        "i'm not an ai",
        "i am a human",
        "i'm a human",
        "i am a doctor",
        "i'm a doctor",
        "i am a psychologist",
        "i'm a psychologist"
    ]

    private func checkIdentityDenialInOutput(_ normalized: String) -> (String, String)? {
        guard identityDenialPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return ("identity_denial", identityFallback)
    }

    // MARK: - Crisis Methods in Output

    // Never describe methods of self-harm, even in a warning context.
    private let crisisMethodPhrases: [String] = [
        "how to cut",
        "how to hurt yourself",
        "ways to harm",
        "method of suicide",
        "how to kill yourself",
        "ways to end your life"
    ]

    private func checkCrisisMethodsInOutput(_ normalized: String) -> (String, String)? {
        guard crisisMethodPhrases.contains(where: { normalized.contains($0) }) else { return nil }
        return ("crisis_methods", crisisFallback)
    }

    // MARK: - Safe Fallback Messages

    private let medicationFallback = """
    That question is really one for your doctor or psychiatrist — they're the right person \
    to help with medication. I'm just here to support your tic practice! 💙

    Is there something about your CBIT exercises I can help with today?
    """

    private let diagnosisFallback = """
    Diagnosing conditions is something only a qualified doctor or psychologist can do — \
    that's not something I'm able to help with. If you have questions about a diagnosis, \
    your doctor is the best person to talk to! 💙

    I'm here to help you practice your CBIT skills — want to keep working on those?
    """

    private let medicalAdviceFallback = """
    That kind of advice is best coming from your doctor or a qualified healthcare provider — \
    they know your full situation in a way I can't. I'm just here to support your tic practice! 💙

    Is there something about CBIT or tic management I can help with today?
    """

    private let identityFallback = """
    Just to be clear — I'm Ziggy, an AI companion, not a real therapist or licensed professional. \
    For clinical advice or therapy, please reach out to a qualified provider. \
    I'm here to help with CBIT practice and tic education! 💙
    """

    private let crisisFallback = """
    I'm really glad you said something, and I care about you. 💛 \
    Please talk to a trusted adult — a parent, teacher, or counselor — right now.

    If you need someone to talk to immediately, you can text or call 988 (Suicide & Crisis Lifeline). \
    They're there for you, any time, day or night.

    I'm just a tic-training buddy and I'm not the right support for this — but the people at 988 are. 💙
    """
}

// MARK: - OutputFilterResult Helpers

extension OutputFilterResult {
    /// The message that should be shown to the user (original or fallback).
    var displayMessage: String {
        switch self {
        case .pass(let response): return response
        case .blocked(_, let fallback): return fallback
        }
    }

    var wasBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    var blockedCategory: String? {
        if case .blocked(let category, _) = self { return category }
        return nil
    }
}
