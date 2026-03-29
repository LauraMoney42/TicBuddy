// TicBuddy — ChatUsageLimiter.swift
// Daily chat usage tracking and soft/hard limits (tb-mvp2-013).
//
// WHY:
//   A child with Tourette's should use Ziggy for structured CBIT practice — not
//   spend all day chatting. Limits prevent dependency, protect the API budget,
//   and ensure quality practice over quantity.
//
// HOW:
//   - Tracks messages sent per child per calendar day (UserDefaults, local only)
//   - Caregiver configures the daily limit in Settings (default: 20 messages/day)
//   - At 75% of limit → soft warning injected into Ziggy's context
//   - At 100% of limit → session gracefully ends; Ziggy sends a wrap-up message
//   - Limit resets at midnight local time automatically
//
// DESIGN DECISION (tb-mvp2-021):
//   Limit is intentionally NOT caregiver-adjustable — prevents a child from
//   exhausting the daily quota by playing with the app all day.
//   The 15-exchange limit applies every day, including formal CBIT session days.
//
// PRIVACY: counts only, keyed by child UUID. No message content stored here.

import Foundation

// MARK: - Usage Limit Status

enum UsageLimitStatus {
    case withinLimit(used: Int, limit: Int)
    case approaching(used: Int, limit: Int)  // ≥75% used
    case reached(used: Int, limit: Int)       // 100% used
    case unlimited                             // limit == 0
}

// MARK: - Chat Usage Limiter

final class ChatUsageLimiter: @unchecked Sendable {
    static let shared = ChatUsageLimiter()
    private init() {}

    /// tb-tic-ziggy-001: Set true during the one-time Ziggy tic mapping onboarding session.
    /// Exempts that session from all daily message limits (never increments or blocks).
    /// ZiggyTicMappingView sets this on appear and clears it on disappear.
    /// nonisolated(unsafe): only ever read/written on MainActor (SwiftUI lifecycle). Safe.
    nonisolated(unsafe) static var isOnboardingTicMappingActive: Bool = false

    /// Hard daily exchange limit — NOT caregiver-adjustable (tb-mvp2-021 product spec).
    /// One "exchange" = one user message + one Ziggy reply.
    static let defaultDailyLimit = 15

    /// Doubled limit for the child's scheduled weekly session day.
    /// Session days benefit from longer conversations (lesson + homework delivery).
    static let sessionDayLimit = 30

    /// Show countdown when remaining drops to this number: "5 questions left today 🌟"
    static let countdownThreshold = 5

    // Soft warning threshold — injected into system prompt when ≥75% used
    private static let softWarningThreshold = 0.75

    // Session-day homework threshold — injected at 70% on session days so Ziggy
    // has time to naturally deliver homework before the session closes.
    private static let sessionDayHomeworkThreshold = 0.70

    // UserDefaults key for the child's scheduled session weekday (1=Sunday … 7=Saturday).
    // Matches SessionSchedulerService.Keys.weekday.
    private static let sessionWeekdayKey = "ticbuddy_session_weekday"

    // MARK: - Session Day Detection

    /// Returns true when today matches the user's scheduled CBIT session weekday.
    /// Falls back to false if no schedule is set (scheduledWeekday == 0).
    static func isSessionDay() -> Bool {
        let scheduledWeekday = UserDefaults.standard.integer(forKey: sessionWeekdayKey)
        guard scheduledWeekday > 0 else { return false }
        let todayWeekday = Calendar.current.component(.weekday, from: Date())
        return todayWeekday == scheduledWeekday
    }

    // MARK: - Storage

    private func storageKey(for childID: UUID) -> String {
        let dateKey = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        return "ticbuddy_usage_\(childID.uuidString)_\(dateKey)"
    }

    // MARK: - Read

    func messagesUsedToday(for childID: UUID) -> Int {
        UserDefaults.standard.integer(forKey: storageKey(for: childID))
    }

    func status(for childID: UUID, limit: Int) -> UsageLimitStatus {
        guard !Self.isOnboardingTicMappingActive else { return .unlimited }
        guard limit > 0 else { return .unlimited }
        let used = messagesUsedToday(for: childID)
        if used >= limit {
            return .reached(used: used, limit: limit)
        } else if Double(used) / Double(limit) >= Self.softWarningThreshold {
            return .approaching(used: used, limit: limit)
        } else {
            return .withinLimit(used: used, limit: limit)
        }
    }

    /// True when the child has hit their daily limit and cannot send more messages.
    func isLimitReached(for childID: UUID, limit: Int) -> Bool {
        guard !Self.isOnboardingTicMappingActive else { return false }
        guard limit > 0 else { return false }
        return messagesUsedToday(for: childID) >= limit
    }

    /// Friendly countdown shown in chat header when ≤ countdownThreshold exchanges remain.
    /// Shown to BOTH caregiver and child views. Returns nil when plenty remain.
    /// e.g. "5 questions left today 🌟"  /  "1 question left today 🌟"
    func countdownMessage(for childID: UUID, limit: Int) -> String? {
        guard limit > 0 else { return nil }
        let remaining = max(0, limit - messagesUsedToday(for: childID))
        guard remaining <= Self.countdownThreshold, remaining > 0 else { return nil }
        let noun = remaining == 1 ? "question" : "questions"
        return "\(remaining) \(noun) left today 🌟"
    }

    // MARK: - Write

    /// Call once per user message sent (NOT for assistant responses).
    func incrementCount(for childID: UUID) {
        let key = storageKey(for: childID)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    /// Reset today's count for a child (e.g., caregiver override / testing).
    func resetToday(for childID: UUID) {
        UserDefaults.standard.removeObject(forKey: storageKey(for: childID))
    }

    // MARK: - System Prompt Injection

    /// Returns a usage-aware addendum for Ziggy's system prompt.
    /// Nil when no action needed (within limit or unlimited).
    ///
    /// Session days (double limit) have an additional 70% checkpoint: Ziggy is instructed
    /// to begin steering toward homework delivery so it's never skipped before the limit hits.
    func systemPromptAddendum(for childID: UUID, limit: Int) -> String? {
        guard !Self.isOnboardingTicMappingActive else { return nil }
        let used = messagesUsedToday(for: childID)
        guard limit > 0 else { return nil }
        let fraction = Double(used) / Double(limit)
        let onSessionDay = Self.isSessionDay()

        // Session day — 70% checkpoint: homework delivery guarantee
        if onSessionDay && fraction >= Self.sessionDayHomeworkThreshold && fraction < 1.0 {
            let remaining = limit - used
            return """
            USAGE NOTE (SESSION DAY): This is a scheduled CBIT session day. The user has used \(used) of \
            \(limit) messages (\(remaining) remaining). Begin working toward a natural close. \
            You MUST deliver today's homework assignment before this session ends — do not finish \
            without giving the child specific, actionable homework to practice this week. \
            After delivering homework, gently wrap up with encouragement.
            """
        }

        // Standard 75% approaching threshold
        if fraction >= Self.softWarningThreshold && fraction < 1.0 {
            let remaining = limit - used
            return """
            USAGE NOTE: This child has used \(used) of their \(limit) daily messages (\(remaining) remaining). \
            Gently guide toward a natural session close within the next few exchanges. \
            Celebrate what was accomplished today and suggest continuing tomorrow.
            """
        }

        // Hard limit reached
        if fraction >= 1.0 {
            return """
            USAGE NOTE: This child has reached their daily message limit. \
            This must be your final response. Warmly close the session: celebrate what they did today, \
            remind them their progress is saved, and encourage them to come back tomorrow. \
            Keep it to 2–3 sentences. End with a specific thing to practice before next time.
            """
        }

        return nil
    }

    /// Friendly wrap-up message shown in chat UI when limit is hit.
    /// Shown as a Ziggy message — reads naturally as encouragement, not a wall.
    static func limitReachedMessage(childName: String, messagesUsed: Int) -> String {
        let name = childName.isEmpty ? "you" : childName
        return """
        Great session today, \(name)! 🌟 You've been working really hard on your CBIT practice — \
        \(messagesUsed) messages worth! 💪

        I need to take a little break now so you can go practice what we talked about. \
        Your brain does its best rewiring BETWEEN sessions, not during them!

        Come back tomorrow and tell me how it went. I'll remember everything. See you then! 🧠✨
        """
    }
}

// MARK: - ChildProfile Usage Limit Extension

extension ChildProfile {
    /// Daily message limit for this child's Ziggy sessions.
    /// 0 = unlimited (for caregivers or therapist-supervised use).
    /// On the child's scheduled CBIT session day, the limit doubles to sessionDayLimit (30)
    /// so there is room for lesson discussion, homework delivery, and wrap-up.
    var effectiveDailyLimit: Int {
        guard dailyMessageLimit != 0 else { return 0 }           // unlimited override
        let base = max(dailyMessageLimit, 5)                      // floor of 5 to prevent lockout bugs
        if ChatUsageLimiter.isSessionDay() {
            return max(base, ChatUsageLimiter.sessionDayLimit)    // at least 30 on session days
        }
        return base
    }
}
