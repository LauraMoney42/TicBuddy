// TicBuddy — ZiggySessionContext.swift
// Centralised context object describing the user's current CBIT session.
// Assembled from ChildProfile, CBITLessonService, WeeklySessionService, and
// CBITSessionStore, then passed into ClaudeService.buildSystemPrompt() so
// Ziggy always has accurate, up-to-date session awareness.
//
// tb-optC-002: Created to unblock per-lesson Ziggy handoffs. Previously session
// context was scattered across ChatViewModel, ClaudeService, and WeeklySessionService
// with no single source of truth. ZiggySessionContext centralises it.
//
// Usage:
//   let ctx = ZiggySessionContext(
//       sessionStage: child.sessionStage,
//       childProfile: child,
//       currentLesson: CBITLessonService.lesson(for: child.sessionStage),
//       weeklySessionIntro: WeeklySessionService.intro(for: child, familyUnit: unit),
//       priorSessionMemories: sessionStore.memories(for: child.id),
//       weeklyPracticeCount: practiceStore.countThisWeek(for: child.id)
//   )

import Foundation

// MARK: - ZiggySessionContext

/// All context Ziggy (Claude) needs to give accurate, session-aware CBIT coaching.
/// Passed to ClaudeService.buildSystemPrompt() and optionally stored per-session.
struct ZiggySessionContext: Codable {

    // MARK: Session Identity

    /// Which of the 8 CBIT sessions the user is currently in.
    /// Drives hard rules (e.g. Session 1: no CR mention) and coaching tone.
    let sessionStage: CBITSessionStage

    /// UUID of the active ChildProfile. Never exposes PII externally.
    let childProfileID: UUID

    // MARK: Tic Hierarchy & Competing Responses

    /// Full ordered tic list, most distressing first.
    /// Lets Ziggy know which tics exist and their severity context.
    let ticHierarchy: [TicHierarchyEntry]

    /// The highest-priority tic currently being targeted.
    /// nil for Session 1 (inventory not yet complete) or if hierarchy is empty.
    let currentTargetTic: TicHierarchyEntry?

    /// Competing responses keyed by tic display name.
    /// e.g. ["Eye Blink": "Slow blink — hold lids closed for a count of 2"]
    /// Empty for Session 1 (CRs are introduced in Session 2+).
    let assignedCompetingResponses: [String: String]

    // MARK: Current Lesson

    /// The full lesson content for this session, or nil if not yet authored.
    /// Used to give Ziggy precise knowledge of what the user just learned.
    let currentLesson: CBITLesson?

    /// One-line summary of the lesson's learning objective.
    /// e.g. "Understanding Tics & the Premonitory Urge"
    let lessonSummary: String?

    /// Optional contextual prompt from a specific lesson slide's "Ask Ziggy" CTA.
    /// When present, Ziggy should open with this topic rather than a generic greeting.
    /// e.g. "I just learned about the premonitory urge but I'm not sure I can feel it..."
    let lessonZiggyPrompt: String?

    // MARK: Weekly Session Handoff

    /// Short greeting string from WeeklySessionService.
    /// e.g. "Hey Alex! 👋"
    let weeklyGreeting: String?

    /// Recap of what was covered/practiced last session.
    /// Empty string for Session 1 (no prior session to recap).
    let lastWeekRecap: String?

    /// This session's focus statement.
    /// e.g. "This week we're trying your very first competing response."
    let thisWeekFocus: String?

    /// Full opening message Ziggy shows at the start of the session.
    /// Displayed word-by-word before the user sends their first message.
    let ziggyOpeningMessage: String?

    /// Whether Ziggy should open with "How have your tics been since we last spoke?"
    /// False for Session 1 (no baseline to compare to) and Session 8 (closing session).
    let shouldAskTicCheckIn: Bool

    // MARK: Prior Session Memories

    /// Memories extracted from prior sessions via CBITSessionStore.
    /// Breakthroughs, pain reports, goals set, emotional flags, etc.
    /// Injected into system prompt so Ziggy can reference them naturally.
    /// nil for first-ever session (nothing to recall yet).
    let priorSessionMemories: [SessionMemoryItem]?

    // MARK: Child Profile Calibration

    /// Age group — drives voice profile selection and content complexity.
    let ageGroup: AgeGroup

    /// 1–5 scale of how well the user detects the premonitory urge.
    /// Low (1–2): Ziggy emphasises urge awareness over CR use.
    /// High (4–5): Ziggy can focus on CR refinement and consistency.
    let ticAwarenessLevel: Int

    /// True when child is under 13 — triggers COPPA content logging suppression.
    let isCOPPAApplicable: Bool

    // MARK: Session Progress Markers

    /// True when no prior session memories exist (literally the first session ever).
    let isFirstSession: Bool

    /// Number of practice days logged in the current week (0–7).
    let weeklyPracticeCount: Int

    /// True when weeklyPracticeCount >= 3 — triggers encouragement callout in Ziggy greeting.
    let isConsistentWeek: Bool

    // MARK: - Initialiser

    /// Assembles ZiggySessionContext from raw model objects.
    /// Call at the point where ChatView is about to open (post-lesson or standalone session).
    ///
    /// - Parameters:
    ///   - sessionStage: The current CBIT session (from ChildProfile.sessionStage)
    ///   - childProfile: The active ChildProfile for this session
    ///   - currentLesson: Lesson content for this session (from CBITLessonService)
    ///   - lessonZiggyPrompt: Optional slide-level prompt if user tapped "Ask Ziggy" CTA
    ///   - weeklySessionIntro: Greeting/recap/focus from WeeklySessionService
    ///   - priorSessionMemories: Extracted memories from CBITSessionStore
    ///   - weeklyPracticeCount: Days practiced this week from practice log
    init(
        sessionStage: CBITSessionStage,
        childProfile: ChildProfile,
        currentLesson: CBITLesson?,
        lessonZiggyPrompt: String? = nil,
        weeklySessionIntro: WeeklySessionIntro? = nil,
        priorSessionMemories: [SessionMemoryItem]? = nil,
        weeklyPracticeCount: Int = 0
    ) {
        self.sessionStage = sessionStage
        self.childProfileID = childProfile.id
        self.ticHierarchy = childProfile.ticHierarchy

        // currentTargetTic is only meaningful for Session 2+ where a CR is assigned
        self.currentTargetTic = sessionStage == .session1 ? nil : childProfile.currentTargetTic

        // Build CR dictionary from tic hierarchy entries that have a CR assigned
        // Session 1: no CRs exist yet; suppress to avoid confusing Ziggy
        if sessionStage == .session1 {
            self.assignedCompetingResponses = [:]
        } else {
            var crMap: [String: String] = [:]
            for entry in childProfile.ticHierarchy where !entry.competingResponse.isEmpty {
                crMap[entry.displayName] = entry.competingResponse
            }
            self.assignedCompetingResponses = crMap
        }

        self.currentLesson = currentLesson
        self.lessonSummary = currentLesson?.subtitle
        self.lessonZiggyPrompt = lessonZiggyPrompt

        self.weeklyGreeting = weeklySessionIntro?.greeting
        self.lastWeekRecap = weeklySessionIntro?.lastWeekRecap
        self.thisWeekFocus = weeklySessionIntro?.thisWeekFocus
        self.ziggyOpeningMessage = weeklySessionIntro?.ziggyMessage

        // Tic check-in is appropriate for Sessions 2–7 only
        // Session 1: no prior baseline. Session 8: closing session, different focus.
        self.shouldAskTicCheckIn = sessionStage != .session1 && sessionStage != .session8

        self.priorSessionMemories = priorSessionMemories

        self.ageGroup = childProfile.ageGroup
        self.ticAwarenessLevel = childProfile.userProfile.ticAwarenessLevel

        // COPPA applies to children under 13
        // AgeGroup: .veryYoung (4-6), .young (7-9), .olderChild (10-12) are all under 13
        let ageGroupValue = childProfile.ageGroup
        self.isCOPPAApplicable = (ageGroupValue == .veryYoung || ageGroupValue == .young || ageGroupValue == .olderChild)

        let hasMemories = priorSessionMemories != nil && !(priorSessionMemories?.isEmpty ?? true)
        self.isFirstSession = !hasMemories && sessionStage == .session1

        self.weeklyPracticeCount = weeklyPracticeCount
        self.isConsistentWeek = weeklyPracticeCount >= 3
    }
}

// MARK: - System Prompt Injection

extension ZiggySessionContext {

    /// Builds the session-context block injected into ClaudeService.buildSystemPrompt().
    /// Returns a formatted string ready to append to the system prompt.
    /// Keeps each section conditional so the prompt stays lean when data is absent.
    func systemPromptBlock() -> String {
        var lines: [String] = []

        // Session stage — always present
        lines.append("CURRENT CBIT SESSION: \(sessionStage.title) (Session \(sessionStage.rawValue) of 8)")

        // Lesson context
        if let summary = lessonSummary {
            lines.append("LESSON JUST COMPLETED: \(summary)")
        }
        if let prompt = lessonZiggyPrompt {
            lines.append("USER'S LESSON QUESTION (from 'Ask Ziggy' CTA): \"\(prompt)\"")
        }

        // This week's focus
        if let focus = thisWeekFocus, !focus.isEmpty {
            lines.append("THIS WEEK'S FOCUS: \(focus)")
        }
        if let recap = lastWeekRecap, !recap.isEmpty {
            lines.append("LAST SESSION RECAP: \(recap)")
        }

        // Tic hierarchy summary
        if !ticHierarchy.isEmpty {
            let ticList = ticHierarchy.prefix(5).map { entry -> String in
                var desc = "• \(entry.displayName) (distress \(entry.distressRating)/10)"
                // tb-tic-assessment-001: Include user-entered description when present —
                // gives Ziggy richer context for personalised coaching.
                if !entry.userDescription.isEmpty {
                    desc += " [\(entry.userDescription)]"
                }
                if !entry.competingResponse.isEmpty {
                    desc += " — CR: \(entry.competingResponse)"
                }
                return desc
            }.joined(separator: "\n")
            lines.append("USER'S TIC HIERARCHY:\n\(ticList)")
        }

        // Current target tic
        if let target = currentTargetTic {
            var targetLine = "CURRENT TARGET TIC: \(target.displayName)"
            if !target.userDescription.isEmpty {
                targetLine += " [\(target.userDescription)]"
            }
            if !target.competingResponse.isEmpty {
                targetLine += " | Assigned CR: \(target.competingResponse)"
            }
            if !target.urgeDescription.isEmpty {
                targetLine += " | User describes urge as: \"\(target.urgeDescription)\""
            }
            lines.append(targetLine)
        }

        // Consistency callout
        if isConsistentWeek {
            lines.append("CONSISTENCY NOTE: User logged \(weeklyPracticeCount) practice days this week — acknowledge this naturally.")
        }

        // Tic check-in flag
        if shouldAskTicCheckIn {
            lines.append("TIC CHECK-IN: Ask 'How have your tics been since we last spoke?' early in the conversation.")
        }

        return lines.joined(separator: "\n")
    }
}
