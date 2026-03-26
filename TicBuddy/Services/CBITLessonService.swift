// TicBuddy — CBITLessonService.swift
// Provides pre-written CBIT lesson slide content for each of the 8 sessions.
// Content is embedded as JSON strings — clinician-reviewed, zero hallucination
// risk. Future: migrate to external JSON files in app bundle for easier updates.
// (tb-mvp2-059)

import Foundation

enum CBITLessonService {

    // MARK: - Public API

    /// Returns the lesson for a given CBIT session stage, or nil if not yet authored.
    static func lesson(for stage: CBITSessionStage) -> CBITLesson? {
        switch stage {
        case .session1: return session1
        default:        return nil   // Sessions 2–8 authored in future sprints
        }
    }

    // MARK: - Session 1: Foundation
    // Psychoeducation, tic inventory, awareness training + premonitory urge intro.

    private static let session1 = CBITLesson(
        session: 1,
        title: "Session 1: Foundation",
        subtitle: "Understanding Tics & the Premonitory Urge",
        slides: [
            // tb-mvp2-084: Welcome slide — app-intro framing before TS education begins.
            // Legal guardrails: no "treatment", "therapy", or "medical" — learning + tracking only.
            // Design: teal gradient (index 0 in LessonSlideView palette), 😉 hero emoji.
            LessonSlide(
                id: 0,
                title: "Welcome to TicBuddy!",
                // tb-mvp2-099: Added quiet-environment suggestion — gentle, not preachy.
                // Placed just before the CTA so it lands as practical prep, not a lecture.
                body: "TicBuddy is here to help you learn about your tics and explore techniques that may help you feel more in control.\n\nHere's how it works:\n• One session per week — short, easy, and yours to keep\n• Daily check-ins between sessions to practice what you learned\n• TicBuddy helps you track your tics and see your progress over time\n\n💡 One tip: find a quiet spot with no distractions — even 15 minutes of focus makes a big difference.\n\nAnd Ziggy — your AI companion — is always here to chat about TS, answer questions, or just listen.\n\nReady? Let's go!",
                audioHint: "Warm, upbeat, and welcoming. Smile through the voice. Pause briefly before 'Here's how it works' and before 'Ready? Let's go!'",
                emoji: "😉"
            ),
            // tb-mvp2-075: "What is Tourette's?" — restored as slide 1 per user request
            // (tb-mvp2-084 incorrectly replaced it; this slide must stay, not be overwritten).
            LessonSlide(
                id: 1,
                title: "What is Tourette's?",
                body: "Tourette Syndrome — or TS — is when the brain sends little extra signals that cause movements or sounds called tics. Things like blinking, sniffing, or clearing your throat.\n\nTS is more common than most people think — about 1 in 100 kids has it. It's not dangerous, it's not your fault, and it doesn't define you.\n\nLots of people with TS live full, happy lives. And there are real things you can do to feel more in control. That's exactly what TicBuddy is here to help with.",
                audioHint: "Gentle, warm, reassuring. Speak like you're talking to a nervous kid who needs to feel safe.",
                emoji: "👋"
            ),
            // tb-mvp2-107: Expanded to cover all 4 tic categories (simple/complex × motor/vocal).
            // Kept teen-friendly — no clinical jargon (no copropraxia/echolalia/palilalia).
            // Simple vs complex distinction grouped under shared bullets to stay readable.
            LessonSlide(
                id: 2,
                title: "What Are Tics?",
                body: "Tics come in two main types — motor (movements) and vocal (sounds) — and each can be simple or complex.\n\n• Simple tics: brief, sudden — like eye blinking, sniffing, or throat clearing.\n• Complex tics: longer sequences — like touching objects, jumping, repeating words, or making phrases.\n\nTics are unintentional. They're caused by how the brain processes signals — not a choice, not a habit.",
                audioHint: "Clear and steady. Slight pause before the bullet points. Let 'not a choice, not a habit' land.",
                emoji: "🧠"
            ),
            LessonSlide(
                id: 3,
                title: "Tics Change Over Time",
                body: "Tics naturally wax and wane — they get better, worse, or change type depending on stress, illness, excitement, and focus. This is completely normal.\n\nMany children see tics improve significantly by late adolescence. CBIT can help reduce tic frequency and the distress they cause — right now, not just someday.",
                audioHint: "Reassuring tone. Emphasize 'right now, not just someday'.",
                emoji: "🌱"
            ),
            LessonSlide(
                id: 4,
                title: "The Premonitory Urge",
                body: "Most people with tics experience a premonitory urge — an uncomfortable sensation that builds just before a tic happens. It might feel like an itch, pressure, or a sense that something is 'not right.'\n\nDoing the tic temporarily relieves this feeling — which is why tics are so hard to stop.\n\nRecognizing the urge is the first step in CBIT. You can't fight what you can't feel.",
                audioHint: "Measured pace. The last line is important — slight emphasis.",
                emoji: "⚡️"
            ),
            // tb-mvp2-101: Normalizing slide for users who can't clearly feel the premonitory urge.
            // Placed immediately after "The Premonitory Urge" so the homework ask (next week) lands
            // without confusion. Includes body-sensation exercise per user guidance: try reproducing
            // the tic slowly and notice where the tension lives (throat, shoulder, thigh, etc.).
            // tb-mvp2-110: Added neural pathway road metaphor to explain brain retraining.
            // Placed after the voluntary tic reproduction technique so it builds on the exercise.
            // Connects awareness training to CBIT mechanism using accessible metaphor.
            LessonSlide(
                id: 5,
                title: "What If I Can't Feel It Yet?",
                body: "That's okay — and really common.\n\n• The urge can be so faint you miss it at first. Some people only notice it after the tic, like a quiet 'oh, there it was.' That still counts as awareness.\n\n• Try this: do your tic on purpose, slowly, and pay close attention just before. Do you feel tightness in your throat? Tension building in your shoulder, thigh, or fingers? That small sensation — however subtle — is your urge.\n\nHere's something cool about your brain: every time a tic happens, it travels the same pathway — like a road your brain has worn smooth from use. The more it fires, the easier that road gets.\n\nBut roads that aren't used? They grow over. Weeds, grass, brush — nature takes them back.\n\nThat's what CBIT does. It builds a new road — your competing response — and each time you take it, it gets a little smoother. The old tic road slowly grows over from disuse.\n\nYou're not fighting your brain. You're just paving a better road.\n\n• For some tics, the urge hides in a surprising spot. An eye blink might start as pressure behind the eye. A vocal tic might feel like a tickle or fullness in the throat.\n\n• Even noticing the tic after it happens is awareness training. It gets sharper with practice — and that's exactly what the next few weeks are for.",
                audioHint: "Warm and reassuring throughout. Slight pause before 'Try this' — frame it as a gentle experiment, not a test. Slow down for the body-sensation examples. When you reach the road metaphor, let it land clearly — this is the science behind why the next weeks matter.",
                emoji: "🤔",
                ziggyPrompt: "I just went through the lesson on the premonitory urge, but I'm honestly not sure I can feel the urge before my tics. Is that normal? How do I learn to notice it?"
            ),
            // tb-mvp2-077: Added concrete example so the concept lands for a 15-year-old.
            LessonSlide(
                id: 6,
                title: "How CBIT Works",
                body: "CBIT teaches a competing response — a specific action that is physically incompatible with the tic. When the premonitory urge appears, your child performs the competing response instead.\n\nFor example: if the tic is an eye blink, the competing response might be slowly and gently closing the eyelids for a count of two, then relaxing. It's hard to forcefully blink while doing that — and that's exactly the point.\n\nOver time, the brain learns a new pathway. The urge weakens, and the tic loses power.\n\nCBIT does not suppress tics through willpower. It retrains the brain through practice.",
                audioHint: "Confident, clear tone. Slow down for the example. Let it land before moving on.",
                emoji: "🛠️"
            ),
            // TODO: caregiver flow — tb-mvp2-078: Caregiver Role slide removed from
            // independent user flow. Restore when caregiver mode is built out.
            // LessonSlide(
            //     id: 7,
            //     title: "Your Role as a Caregiver",
            //     body: "Research shows that caregiver involvement is one of the strongest predictors of CBIT success. Your job is to:\n\n• Stay calm and neutral around tics — attention (even sympathetic) can increase tic frequency.\n• Encourage practice without pressure.\n• Celebrate effort, not just outcomes.\n\nZiggy will coach both you and your child through each step. You don't need to be an expert — just present.",
            //     audioHint: "Warm and encouraging. List items can be read naturally.",
            //     emoji: "💙"
            // ),

            // tb-mvp2-079: "What's Next" — homework to catch tic urges + log via counter.
            // tb-mvp2-102: ziggyPrompt seeds a contextual Ziggy chat for users unsure
            // whether they can feel the premonitory urge. Shows "Ask Ziggy →" CTA on this slide only.
            LessonSlide(
                id: 7,
                title: "What's Next",
                // tb-mvp2-093: "## Your Homework" renders as a large bold section header in LessonSlideView.
                // plainTextBody() strips the marker before TTS so Ziggy reads it naturally.
                // tb-mvp2-100: Made the daily logging CTA explicit — "once a day" sets a clear habit.
                // tb-mvp2-112: Added Session 2 next-week reminder + calendar CTA per user feedback.
                // tb-mvp2-122: Rewrote tic counter line to mention tally marks as a no-phone fallback.
                body: "Now that you know what tics and the premonitory urge are, it's time to start noticing them in real life.\n\n## Your Homework\nTry to catch your tics before they happen. When you feel that little urge — the itch, the pressure, the 'something's building' feeling — that's it. That's what we're looking for.\n\n📅 Schedule your next session — add it to your calendar right now, same day next week.\n📱 Catch a tic? Log it in the moment with the tic counter — or jot it down with tally marks if your phone isn't handy. At the end of the day, enter your totals. Either way works!",
                audioHint: "Energetic and encouraging. Pause after 'that's it'. The daily check-in line is a direct call to action. End on a warm, forward-looking note for the Session 2 reminder.",
                emoji: "🎯"
            ),
            // tb-mvp2-085: Closing handoff slide — intentional bridge to tic assessment.
            // CTA on this slide routes to TicIntakeAssessmentView (see FamilyModeRouter).
            // Gradient cycles back to teal (index 7 % 8 = 7 → palette wraps) — bookends the welcome slide.
            LessonSlide(
                id: 8,
                title: "Let's Map Your Tics",
                // tb-mvp2-113: Removed "Once you're done" daily check-in paragraph — duplicate of What's Next slide.
                body: "Now that you know what tics are, let's make a list of yours.\n\nYou'll document each tic — what it looks like, how often it happens, and how it feels. This becomes your personal tic map, and it's the foundation for everything we'll do together.\n\nTap below when you're ready — it only takes a few minutes!",
                audioHint: "Warm and forward-looking. Pause before 'Tap below when you're ready'. Light emphasis on 'your personal tic map'.",
                emoji: "🗺️"
            )
        ]
    )
}
