// TicBuddy — ZiggyVoiceProfileService.swift
// Defines the 4 Ziggy voice profiles (tb-mvp2-010).
//
// Each profile shapes how Ziggy communicates — tone, vocabulary, response length,
// and personality framing — without changing the clinical safety rules.
//
// Profiles are selected automatically from the active AgeGroup:
//   .youngChild  → ages 4–8  (veryYoung, young)
//   .olderChild  → ages 9–12 (olderChild)
//   .adolescent  → ages 13+  (youngTeen, teen)
//   .caregiver   → when no child profile is active (caregiver mode)
//
// The voice profile injects a PERSONA block into the system prompt.
// Safety rules are always appended after and cannot be overridden by the profile.

import Foundation
import SwiftUI

// MARK: - Voice Profile

enum ZiggyVoiceProfile: String, CaseIterable {
    case youngChild  = "young_child"
    case olderChild  = "older_child"
    case adolescent  = "adolescent"
    case caregiver   = "caregiver"

    // MARK: Automatic Selection

    /// Selects the correct profile for an active child's age group.
    static func profile(for ageGroup: AgeGroup) -> ZiggyVoiceProfile {
        switch ageGroup {
        case .veryYoung, .young: return .youngChild
        case .olderChild:        return .olderChild
        case .youngTeen, .teen: return .adolescent
        }
    }

    /// Returns the caregiver profile when no child is active.
    static func caregiverProfile() -> ZiggyVoiceProfile { .caregiver }

    /// tb-mvp2-054: Maps an OpenAI voice name to the nearest ZiggyVoiceProfile for
    /// AVSpeechSynthesizer fallback rate/pitch tuning when the proxy is not configured.
    static func fromPreviewVoice(_ voice: String) -> ZiggyVoiceProfile {
        switch voice.lowercased() {
        case "shimmer", "fable":  return .youngChild   // lighter, warmer voices
        case "alloy", "echo":     return .olderChild   // neutral, clear voices
        case "onyx":              return .adolescent   // deeper, more serious
        default:                  return .caregiver    // nova + anything else → caregiver rate
        }
    }

    // MARK: Display

    var displayName: String {
        switch self {
        case .youngChild:  return "Ziggy Jr. 🌈"
        case .olderChild:  return "Ziggy 💪"
        case .adolescent:  return "Ziggy"
        case .caregiver:   return "Ziggy"
        }
    }

    // MARK: Proxy Model Selection
    //
    // Lighter model for young child (simpler responses, lower latency feels more playful).
    // Sonnet for older profiles — richer, more nuanced responses worth the extra latency.

    var preferredModel: String {
        switch self {
        case .youngChild: return "claude-haiku-4-6"
        default:          return "claude-sonnet-4-6"
        }
    }

    // MARK: Chat UI Properties (tb-mvp2-012)
    //
    // Each profile gets its own avatar emoji, gradient, chat title, subtitle,
    // input placeholder, and quick-action chips. These adapt the ChatView UI
    // so the experience feels age-appropriate without changing clinical content.

    var avatarEmoji: String {
        switch self {
        case .youngChild:  return "🌈"
        case .olderChild:  return "😉"
        case .adolescent:  return "😎"
        case .caregiver:   return "😉"
        }
    }

    /// Gradient colors for the avatar circle in ChatHeaderView.
    var avatarGradient: [Color] {
        switch self {
        case .youngChild:  return [Color(hex: "FF9A9E"), Color(hex: "FAD0C4")]
        case .olderChild:  return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case .adolescent:  return [Color(hex: "2C3E50"), Color(hex: "4CA1AF")]
        case .caregiver:   return [Color(hex: "43E97B"), Color(hex: "38F9D7")]
        }
    }

    /// Name shown in the chat header.
    var chatTitle: String {
        switch self {
        case .youngChild:  return "Ziggy Jr. 🌈"
        case .olderChild:  return "Ziggy"
        case .adolescent:  return "Ziggy"
        case .caregiver:   return "Ziggy"
        }
    }

    /// Subtitle shown below the name (when no countdown is active).
    func chatSubtitle(phase: CBITPhase) -> String {
        switch self {
        case .youngChild:  return "Your tic-training buddy! 🌟"
        case .olderChild:  return "Here to help • \(phase.title)"
        case .adolescent:  return phase.title
        case .caregiver:   return "Caregiver support mode"
        }
    }

    /// Placeholder text in the chat input field.
    var inputPlaceholder: String {
        switch self {
        case .youngChild:  return "Tell Ziggy what happened! 😊"
        case .olderChild:  return "Tell Ziggy what's happening..."
        case .adolescent:  return "Ask anything about tics or CBIT..."
        case .caregiver:   return "Ask a caregiver question..."
        }
    }

    /// Age-appropriate quick-action chips for the chip bar.
    var quickActionChips: [String] {
        switch self {
        case .youngChild:
            return [
                "I had a brain wiggle 😔",
                "I used my special move! 🌟",
                "I feel the tickle feeling 😬",
                "Tell me I'm doing great 💙"
            ]
        case .olderChild:
            return [
                "I just had a tic 😔",
                "I caught my urge! ⚡️",
                "I redirected it! 🌟",
                "How do I redirect?",
                "I need encouragement 💙"
            ]
        case .adolescent:
            return [
                "I had a tic",
                "CR worked today",
                "Struggling with urges",
                "What does the research say?",
                "This is really hard today"
            ]
        case .caregiver:
            return [
                "How do I support my child today?",
                "What should we practice this week?",
                "My child is struggling with...",
                "What is a competing response?",
                "How does CBIT work?"
            ]
        }
    }

    // MARK: System Prompt Persona Block
    //
    // Injected at the TOP of the system prompt, before CBIT coaching instructions.
    // Written as persona instructions, not character constraints — Claude performs better.

    var personaPromptBlock: String {
        switch self {

        case .youngChild:
            return """
            VOICE PROFILE: Ziggy Jr. (ages 4–8)
            - You are Ziggy, a super friendly, silly, and encouraging tic-training buddy
            - Use VERY simple words — a 5-year-old should understand everything you say
            - Maximum 2 short sentences per reply (never more than 30 words total)
            - Use lots of emojis 🌟🎉💪 — they make reading fun!
            - Speak in an excited, warm, high-energy voice
            - Every tic logged = a HUGE celebration ("WOW! You're so smart! 🌟")
            - NEVER use words like "premonitory", "competing response", "neuroplasticity"
              — say "your special move" / "that funny feeling" / "brain training" instead
            - Replace clinical terms: tic → "brain wiggle", CBIT → "tic training", urge → "tickle feeling"
            """

        case .olderChild:
            return """
            VOICE PROFILE: Ziggy (ages 9–12)
            - You are Ziggy, a friendly and encouraging CBIT coach who is also kind of like a cool older sibling
            - Use friendly, clear language — not babyish, not too adult
            - 3–4 sentences per reply — enough to explain, not so much it's overwhelming
            - Emojis are great, but use them to punctuate, not dominate
            - Speak with genuine enthusiasm — celebrate every effort, not just successes
            - You CAN use terms like "competing response", "premonitory urge", "CBIT"
              but always define them the first time with a simple parenthetical
            - When something is hard: validate first ("That's genuinely difficult"), then encourage
            """

        case .adolescent:
            return """
            VOICE PROFILE: Ziggy (ages 13–17 / self-user)
            - You are Ziggy, a knowledgeable and supportive tic-training coach
            - tb-mvp2-117: You are speaking DIRECTLY to the person who HAS tics — always use
              "you" and "your tics". NEVER say "your child", "your kid", or refer to a third party.
              This user is managing their own tics, not a parent managing someone else's.
            - Tone: peer-like, genuine, and direct — NOT patronizing, NOT overly enthusiastic
            - 4–5 sentences per reply — substantive but not overwhelming
            - Minimal emojis — use them sparingly and authentically, never performatively
            - Respect the user's intelligence: explain the actual neuroscience when relevant
              (e.g., "The prefrontal cortex is being recruited to override the basal ganglia...")
            - Respect privacy: never ask probing personal questions; let the user lead
            - Validate frustration without minimizing: "Yeah, this is genuinely hard. The research shows..."
            - NEVER say "buddy", "sport", "champ" or other condescending nicknames
            - When celebrating: understated and genuine ("That's actually a big deal.")
            """

        case .caregiver:
            return """
            VOICE PROFILE: Ziggy (Caregiver / Therapist mode)
            - You are Ziggy, a clinical CBIT support assistant for caregivers and therapists
            - Tone: professional, warm, evidence-based — like a knowledgeable colleague
            - 4–6 sentences per reply; use clinical terminology accurately
            - You CAN discuss CBIT protocol specifics, session staging, habit reversal training (HRT)
            - Reference research when helpful: "According to the Woods et al. 2008 CBIT trial..."
            - When discussing the child, always use respectful language about the child's experience
            - Emphasize: caregivers are coaches, not enforcers — positive reinforcement always
            - You can suggest session structures, competing response options, and functional analysis approaches
            - Do NOT make treatment decisions — always frame suggestions as options for their clinical team
            """
        }
    }
}

// MARK: - Voice Profile Service

final class ZiggyVoiceProfileService: @unchecked Sendable {
    static let shared = ZiggyVoiceProfileService()
    private init() {}

    /// Returns the correct voice profile for the current session context.
    /// tb-mvp2-117: selfUser has no child profiles by design — must not fall through
    /// to .caregiver. Route to .adolescent so Ziggy addresses the teen/adult as "you".
    func activeProfile(familyUnit: FamilyUnit) -> ZiggyVoiceProfile {
        if familyUnit.accountType == .selfUser { return .adolescent }
        guard let child = familyUnit.activeChild else { return .caregiver }
        return ZiggyVoiceProfile.profile(for: child.ageGroup)
    }

    /// Returns the correct voice profile given just an age group (for preview/testing).
    func profile(for ageGroup: AgeGroup) -> ZiggyVoiceProfile {
        ZiggyVoiceProfile.profile(for: ageGroup)
    }
}
