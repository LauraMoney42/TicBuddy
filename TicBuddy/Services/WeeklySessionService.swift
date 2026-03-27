// TicBuddy — WeeklySessionService.swift
// Drives the weekly CBIT session auto-launch (tb-mvp2-026).
//
// Behaviour:
//   - First app open in a 7-day window → shouldAutoLaunch returns true
//   - Fires once per window; subsequent opens return false until next 7-day period
//   - Caregiver "Read Ahead" content mirrors the child's current session stage
//   - All content keyed by CBITSessionStage (8 sessions per CBIT protocol)

import Foundation

// MARK: - Data Models

/// Content shown to the child when Ziggy auto-launches the weekly session intro.
struct WeeklySessionIntro {
    let stage: CBITSessionStage
    let greeting: String       // "Hey [name]! 👋"
    let lastWeekRecap: String  // What they worked on last session (empty for session 1)
    let thisWeekFocus: String  // Brief focus statement
    let ziggyMessage: String   // Full Ziggy opening message shown word by word
}

/// Content shown on the caregiver dashboard so they can read ahead before the session.
struct CaregiverReadAheadContent {
    let stage: CBITSessionStage
    let headline: String
    let summary: String
    let bulletPoints: [String]
    let therapistNote: String?
}

// MARK: - Weekly Session Service

@MainActor
final class WeeklySessionService: ObservableObject {
    static let shared = WeeklySessionService()
    private init() {}

    // MARK: - Keys

    private func lastLaunchKey(_ childID: UUID) -> String {
        "ticbuddy_weekly_intro_\(childID.uuidString)"
    }

    // MARK: - Launch Logic

    /// Returns true if the child hasn't seen the weekly intro yet this week,
    /// or has never seen it (first ever open).
    func shouldAutoLaunch(for childID: UUID) -> Bool {
        guard let last = UserDefaults.standard.object(forKey: lastLaunchKey(childID)) as? Date else {
            return true // Never launched → always show on first open
        }
        let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
        return days >= 7
    }

    /// Call once the intro has been displayed to prevent re-showing this week.
    func markLaunched(for childID: UUID) {
        UserDefaults.standard.set(Date(), forKey: lastLaunchKey(childID))
    }

    // MARK: - Child Session Intro Content

    // tb-mvp2-038: practiceCalendar enables consistency acknowledgment in ziggyMessage.
    // Defaults to empty so all existing callers compile without changes.
    func sessionIntro(
        stage: CBITSessionStage,
        childName: String,
        practiceCalendar: [String: PracticeStatus] = [:]
    ) -> WeeklySessionIntro {
        let name = childName.isEmpty ? "friend" : childName
        let practicesThisWeek = weeklyPracticeCount(from: practiceCalendar)

        // tb-mvp2-038: Consistency acknowledgment — injected into ziggyMessage for sessions 2+
        // when the child logged 3+ days in the current week. Reinforces the logging behaviour.
        let consistencyCallout: String = {
            switch practicesThisWeek {
            case 5...: return "\n\nI also noticed you logged 5 days this week — that is HUGE. That kind of consistency is exactly what makes this work. 🔥"
            case 4:    return "\n\nI see you logged 4 days this week. That's the streak doing its thing — keep it going. 💪"
            case 3:    return "\n\nI noticed you've been showing up consistently this week. That matters more than you might think. ⭐️"
            default:   return ""
            }
        }()

        // tb-mvp2-038: Tic check-in closing — added to sessions 2–7 to give Ziggy session context
        // before the lesson begins. Session 1 = first ever open (no prior tics to check in on).
        // Session 8 = graduation (we lead with celebration, not a check-in).
        let ticCheckIn = "\n\nBefore we dive in — how have your tics been since we last spoke? Anything that stood out this week?"

        switch stage {
        case .session1:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! 👋 Welcome to TicBuddy!",
                lastWeekRecap: "",
                // tb-mvp2-039: Session 1 = awareness training ONLY.
                // Introduce the premonitory urge concept + frame catching it as a superpower.
                // Homework: count urge catches and log daily — no competing response yet.
                thisWeekFocus: "This week: discover the secret signal your body sends before a tic. That's your superpower. 💪",
                ziggyMessage: "Hey \(name)! I'm Ziggy — your tic-busting buddy. ⚡✨\n\nHere's something cool most people never know: your body actually sends a tiny secret signal RIGHT before a tic happens. 🔍 It's like a little warning — a tingle, a pressure, or an uh-oh feeling.\n\nThis week, our only job is to start catching that signal. Every time you notice the feeling BEFORE the tic fires, that's a catch — and catches are your superpower. 💪\n\nHomework: count your catches each day and log them in TicBuddy. That's it! No pressure — just a little detective work. Ready to find your secret signal? 🚀"
            )
        case .session2:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! Great to see you again! 👋",
                lastWeekRecap: "Last week you did an awesome job learning to notice your tics.",
                thisWeekFocus: "This week we try your very first competing response — your secret counter-move.",
                ziggyMessage: "Hey \(name)! You're back — and I'm pumped to see you. 🎉\(consistencyCallout)\n\nLast week you were a champ at noticing your tics. That awareness? It's actually the hardest part, and you nailed it.\n\nThis week? We're going to try something called a competing response. Think of it as your brain's special counter-move. 🥋\(ticCheckIn)"
            )
        case .session3:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! You're on a roll! 🔥",
                lastWeekRecap: "Last week you tried your competing response for the first time — that took real courage.",
                thisWeekFocus: "This week we fine-tune your move and make it even stronger.",
                ziggyMessage: "Hey \(name)! Seriously — you're doing amazing. 🌟\(consistencyCallout)\n\nLast week you tried your competing response for the first time. Using it at all is the biggest step, and you did it.\n\nThis week we look at when it worked best and when it was harder. No wrong answers — we just figure out what to tweak.\(ticCheckIn)"
            )
        case .session4:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! You're getting really good at this! 🏆",
                lastWeekRecap: "Last week you sharpened your competing response and started to feel more in control.",
                thisWeekFocus: "This week we add a second tic to work on — because you're ready.",
                ziggyMessage: "Hey \(name)! Four sessions in — that's something to feel proud of. 🏆\(consistencyCallout)\n\nYou've built something real. Your brain has been practising a new pattern, and that kind of change takes work.\n\nThis week we're going to add a second tic to your toolkit. Same process — you already know how it works.\(ticCheckIn)"
            )
        case .session5:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! Almost to the biweekly phase! 🎯",
                lastWeekRecap: "Last week you made great progress working on your second competing response.",
                thisWeekFocus: "This week is about independence — making everything stick on your own.",
                ziggyMessage: "Hey \(name)! Big one — this is the last of our weekly check-ins before we go biweekly. 🎯\(consistencyCallout)\n\nThat means you're actually doing it. You're building real independence. This week we focus on what to do when things get hard without me right there.\(ticCheckIn)"
            )
        case .session6:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! Biweekly check-in time! ⭐️",
                lastWeekRecap: "Last session you were building independence with your competing responses.",
                thisWeekFocus: "This check-in is about reviewing what's working and celebrating your progress.",
                ziggyMessage: "Hey \(name)! Two whole weeks — and I've been thinking about you. ⭐️\(consistencyCallout)\n\nBiweekly check-in time. This is when we zoom out and see the bigger picture.\n\nHow have your competing responses been feeling? Any tics getting easier?\(ticCheckIn)"
            )
        case .session7:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! Monthly check-in! 🌙",
                lastWeekRecap: "You've been in maintenance for a while now — that's a really big deal.",
                thisWeekFocus: "This monthly check-in is about making sure your tools stay sharp.",
                ziggyMessage: "Hey \(name)! Monthly check-in — that means you've been at this for a while now. 🌙\(consistencyCallout)\n\nThat's not a small thing. A lot of people give up before reaching this point. You didn't.\n\nToday we check in on your whole toolkit. Which CRs feel automatic? Which ones might need a tune-up?\(ticCheckIn)"
            )
        case .session8:
            return WeeklySessionIntro(
                stage: stage,
                greeting: "Hey \(name)! This is our final session. 🌟",
                lastWeekRecap: "You've come so incredibly far since Session 1.",
                thisWeekFocus: "Today we celebrate everything you've built and create your plan for the future.",
                // Session 8: graduation framing — no tic check-in, open with celebration
                ziggyMessage: "Hey \(name). Session 8. The final one. 🌟\(consistencyCallout)\n\nI want you to think back to Session 1 — remember how it felt just to notice a tic? And look at you now.\n\nYou built something real and lasting. Competing responses that actually work. Awareness that now feels automatic.\n\nToday we create your personal playbook to keep this going without me. Because honestly? You don't need me anymore. You've got this. 💙"
            )
        }
    }

    // MARK: - Helpers

    /// Counts how many practices were logged in the current ISO week.
    /// Inlined here (mirrors DailyInstructionEngine.weeklyPracticeCount) so WeeklySessionService
    /// doesn't depend on DailyInstructionEngine for session intro content. (tb-mvp2-038)
    private func weeklyPracticeCount(from calendar: [String: PracticeStatus]) -> Int {
        let formatter = ISO8601DateFormatter()
        var components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2  // Monday
        let weekStart = Calendar.current.date(from: components) ?? Date()
        return calendar.keys.filter { key in
            guard let date = formatter.date(from: key) else { return false }
            return date >= weekStart && date <= Date()
        }.count
    }

    // MARK: - Caregiver Read Ahead Content

    /// Returns what the caregiver can read ahead about the child's CURRENT session.
    func caregiverReadAhead(currentStage: CBITSessionStage) -> CaregiverReadAheadContent {
        switch currentStage {
        case .session1:
            return CaregiverReadAheadContent(
                stage: .session1,
                headline: "Lesson 1 — Foundation",
                summary: "This week Ziggy introduces psychoeducation: what tics are, why they happen, and what CBIT involves. The goal is curiosity and safety — not pressure or fixing.",
                bulletPoints: [
                    "Tic awareness training begins — noticing without judging",
                    "Building the tic hierarchy: which tics to target first",
                    "No competing response yet — just observation",
                    "Expect your child to feel relieved that someone 'gets it'"
                ],
                therapistNote: "If working with a therapist, they'll complete a formal assessment this session. Coordinate baseline tic frequency data with them."
            )
        case .session2:
            return CaregiverReadAheadContent(
                stage: .session2,
                headline: "Session 2 — First Competing Response",
                summary: "The first competing response (CR) is introduced for the highest-priority tic. This is the cornerstone of CBIT — a physical behaviour that's incompatible with the tic.",
                bulletPoints: [
                    "Competing response selected for the top-ranked tic",
                    "Practised in session until it feels natural",
                    "Your child will need reminders to use it — that's completely expected",
                    "Praise effort, not outcome — any attempt counts"
                ],
                therapistNote: "Your therapist will formally introduce Habit Reversal Training (HRT) today. Review the assigned CR together after the session."
            )
        case .session3:
            return CaregiverReadAheadContent(
                stage: .session3,
                headline: "Session 3 — Troubleshoot & Deepen",
                summary: "The first CR gets refined based on real-world use. You'll learn how to support your child without nagging. A relaxation technique is introduced for urge management.",
                bulletPoints: [
                    "Review what worked and what felt hard with the CR",
                    "Your role: one gentle reminder per tic — then let it go",
                    "Relaxation technique introduced (diaphragmatic breathing)",
                    "Urge awareness deepens: 'I feel it coming' is the target state"
                ],
                therapistNote: "Ask your therapist how to prompt your child optimally — every family has a different dynamic."
            )
        case .session4:
            return CaregiverReadAheadContent(
                stage: .session4,
                headline: "Session 4 — Consolidate + Second Tic",
                summary: "With the first CR feeling more natural, a second tic from the hierarchy gets its own competing response. Your child is building a full toolkit.",
                bulletPoints: [
                    "Review progress on CR #1 — adjust if needed",
                    "Second competing response introduced and practised",
                    "Your child may feel busy — normal; validate the hard work",
                    "Keep the reward system active — it matters now more than ever"
                ],
                therapistNote: nil
            )
        case .session5:
            return CaregiverReadAheadContent(
                stage: .session5,
                headline: "Session 5 — Building Independence",
                summary: "The last weekly session before biweekly spacing. Focus shifts to internal motivation and self-monitoring — your child becoming their own coach.",
                bulletPoints: [
                    "Self-monitoring skill: child tracks their own CR use",
                    "Identify high-risk situations: stress, tired, transitions",
                    "Family discusses spacing to biweekly — a genuine sign of progress",
                    "Celebrate specifically: name exactly what you've seen them do"
                ],
                therapistNote: "Discuss the transition to biweekly appointments with your therapist today."
            )
        case .session6:
            return CaregiverReadAheadContent(
                stage: .session6,
                headline: "Session 6 — Biweekly Check-In",
                summary: "Two weeks between sessions is the new rhythm. Review what's working and what's drifted. The goal is managing, not solving — maintenance is success.",
                bulletPoints: [
                    "Review CR use over the past two weeks",
                    "Any new tics? Re-rank hierarchy if needed",
                    "Acknowledge any regression without alarm — it's part of the process",
                    "Specific praise for sustained effort goes a long way"
                ],
                therapistNote: nil
            )
        case .session7:
            return CaregiverReadAheadContent(
                stage: .session7,
                headline: "Session 7 — Monthly Maintenance",
                summary: "Monthly rhythm now. The skills are established — this session checks that they're still fresh and addresses anything that has drifted.",
                bulletPoints: [
                    "Which CRs feel automatic? Which need reactivation?",
                    "Check in on emotional wellbeing — tics are just one dimension",
                    "Plan ahead for upcoming stressors if any are on the horizon",
                    "Reinforce: they have built something that will last"
                ],
                therapistNote: "Your therapist may begin spacing to every 2–3 months at this stage."
            )
        case .session8:
            return CaregiverReadAheadContent(
                stage: .session8,
                headline: "Session 8 — Graduation 🎓",
                summary: "The final CBIT session. A relapse prevention plan is created so your child knows exactly what to do if tics intensify in the future. This is a moment to celebrate.",
                bulletPoints: [
                    "Create the relapse prevention plan together",
                    "Define 'early warning signs' so your child can self-monitor",
                    "Agree on what a 'booster session' trigger looks like",
                    "Plan a meaningful celebration — they earned it"
                ],
                therapistNote: "Ask your therapist for their written relapse prevention protocol to keep on file."
            )
        }
    }
}
