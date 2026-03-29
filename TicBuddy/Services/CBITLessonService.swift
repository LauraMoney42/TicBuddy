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
        case .session2: return session2
        case .session3: return session3
        case .session4: return session4
        case .session5: return session5
        case .session6: return session6
        case .session7: return session7
        default:        return nil   // Session 8 pending authoring
        }
    }

    // MARK: - Session 1: Foundation
    // Psychoeducation, tic inventory, awareness training + premonitory urge intro.

    private static let session1 = CBITLesson(
        session: 1,
        // tb-mvp2-132: renamed from "Session 1" → "Lesson 1" across all display strings.
        title: "Lesson 1: Foundation",
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
                body: "TicBuddy is here to help you learn about your tics and explore techniques that may help you feel more in control.\n\nTicBuddy is built around CBIT — Comprehensive Behavioral Intervention for Tics — a research-backed approach to learning about and managing tics. TicBuddy is an educational app, not a medical or clinical service.\n\nHere's how it works:\n• One lesson per week — short, easy, and yours to keep\n• Daily check-ins between lessons to practice what you learned\n• TicBuddy helps you track your tics and see your progress over time\n\n💡 One tip: For each lesson, find a quiet spot with no distractions — even 15 minutes of focus makes a big difference.\n\nAnd Ziggy — your AI companion — is always here to chat about TS, answer questions, or just listen.\n\nReady? Let's go!",
                audioHint: "Warm, upbeat, and welcoming. Smile through the voice. Pause briefly before 'Here's how it works' and before 'Ready? Let's go!'",
                emoji: "😉"
            ),
            // tb-mvp2-128: App feature tour — brief, exciting overview of the three
            // core tools before the CBIT education begins. Keeps slide 0 focused on
            // the mission and lets this slide handle the "what can I actually do?" question.
            LessonSlide(
                id: 1,
                title: "Your TicBuddy Toolkit",
                body: "Here's what you'll be using every day:\n\n📅 **Calendar** — log tics daily and spot patterns over time. See what days are harder, and watch yourself improve week by week.\n\n🔢 **Tic counter** — tap it in the moment to count tics as they happen, or enter your totals at the end of the day. Either way works! If it's easier to keep track on paper, that's fine too — just enter the number at the end of the day in TicBuddy.\n\n🏆 **Reward points** — start by picking a prize for yourself! Every tic you notice earns 1 point. Collect 10 points and claim your reward — then set a new one. Noticing your tics builds real awareness, and every catch counts!\n\nThat's it. Simple tools, real results.",
                audioHint: "Upbeat and quick — this is a features highlight, not a lecture. Each bullet gets a beat of emphasis. End punchy: 'Simple tools, real results.'",
                emoji: "🛠️"
            ),
            // tb-mvp2-075: "What is Tourette's?" — restored as slide 2 (shifted from 1).
            // tb-mvp2-132: title updated to include lesson label per user request.
            LessonSlide(
                id: 2,
                title: "What Is Tourette's?",
                body: "Tourette Syndrome — or TS — is when the brain sends little extra signals that cause movements or sounds called tics. Things like blinking, sniffing, or clearing your throat.\n\nTS is more common than most people think — about 1 in 100 kids has it. It's not dangerous, it's not your fault, and it doesn't define you.\n\nLots of people with TS live full, happy lives. And there are real things you can do to feel more in control. That's exactly what TicBuddy is here to help with.\n\nSome tics are socially awkward — and that's something we'll talk about specifically. You're not alone in that.\n\nOne more thing worth knowing: you may notice your tics briefly increase as you focus on them during CBIT — this is normal, temporary, and a well-documented part of the process.",
                audioHint: "Gentle, warm, reassuring. Speak like you're talking to a nervous kid who needs to feel safe.",
                emoji: "👋"
            ),
            // tb-mvp2-107: Expanded to cover all 4 tic categories (simple/complex × motor/vocal).
            LessonSlide(
                id: 3,
                title: "What Are Tics?",
                body: "Tics come in two main types — motor (movements) and vocal (sounds) — and each can be simple or complex.\n\n• Simple tics: brief, sudden — like eye blinking, sniffing, or throat clearing.\n• Complex tics: longer sequences — like touching objects, jumping, repeating words, or saying a whole sentence.\n\nTics happen on their own — your brain sends a signal and the tic follows, without you choosing it. That's the opposite of a habit, which is something you repeat intentionally.",
                audioHint: "Clear and steady. Slight pause before the bullet points. Let 'not a choice, not a habit' land.",
                emoji: "🧠"
            ),
            LessonSlide(
                id: 4,
                title: "Tics Change Over Time",
                body: "Tics naturally wax and wane — they get better, worse, or change type depending on stress, illness, excitement, and focus. This is completely normal.\n\nMany people with tics see them improve significantly as they get older — and CBIT can speed that up. CBIT can help reduce tic frequency and the distress they cause — right now, not just someday.",
                audioHint: "Reassuring tone. Emphasize 'right now, not just someday'.",
                emoji: "🌱"
            ),
            LessonSlide(
                id: 5,
                title: "The Premonitory Urge",
                body: "Most people with tics experience a premonitory urge — an uncomfortable sensation that builds just before a tic happens. It might feel like an itch, pressure, or a sense that something is 'not right.' Some describe it as needing to move, or like your body is waiting for something.\n\nDoing the tic temporarily relieves this feeling — which is why tics are so hard to stop.\n\nRecognizing the urge is the first step in CBIT. You can't fight what you can't feel.",
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
            // CLINICAL NOTE — VERY YOUNG CHILDREN (ages ~4–7):
            // Some young children cannot yet feel the premonitory urge at all — this is
            // developmentally normal, not a failure. Ziggy will work with them gently across
            // sessions to try to detect any body signal before the tic. If a child genuinely
            // cannot feel any urge after several sessions, they are NOT yet a strong CBIT
            // candidate. Caregivers should be guided to revisit with a CBIT therapist when
            // the child is older or their sensory awareness has matured.
            // TODO (age-group content): When veryYoung lesson variants are built, this slide
            // should be adapted or skipped — replace with Ziggy-led exploration rather than
            // a self-directed exercise the child may not be able to complete.
            LessonSlide(
                id: 6,
                title: "What If I Can't Feel It Yet?",
                // tb-mvp2-130: Road metaphor paragraphs moved to "How CBIT Works" (id:7).
                body: "That's okay — and really common.\n\n• The urge can be so faint you miss it at first. Some people only notice it after the tic, like a quiet 'oh, there it was.' That still counts as awareness.\n\n• Try this: do your tic on purpose, slowly, and pay close attention just before. Do you feel tightness in your throat? Tension building in your shoulder, thigh, or fingers? That small sensation — however subtle — is your urge.\n\n• For some tics, the urge shows up in an unexpected place. An eye blink might start as pressure behind the eye. A vocal tic might feel like a tickle or fullness in the throat.\n\n• Even noticing the tic after it happens is awareness training. It gets sharper with practice — and that's exactly what the next few weeks are for.",
                audioHint: "Warm and reassuring throughout. Slight pause before 'Try this' — frame it as a gentle experiment, not a test. Slow down for the body-sensation examples.",
                emoji: "🤔",
                ziggyPrompt: "I just went through the lesson on the premonitory urge, but I'm honestly not sure I can feel the urge before my tics. Is that normal? How do I learn to notice it?"
            ),
            // tb-mvp2-077: Added concrete example so the concept lands for a 15-year-old.
            // tb-mvp2-133: Split from one ~900-char slide into two slides — road metaphor
            // moved to its own slide (id:8) so neither slide times out Railway TTS.
            LessonSlide(
                id: 7,
                title: "How CBIT Works",
                body: "CBIT teaches a competing response — a specific action your body does instead of the tic — and you literally can't do both at the same time. When the premonitory urge appears, the competing response is performed instead.\n\nFor example: if the tic is a throat clear, the competing response might be pressing the lips firmly together and breathing slowly through the nose. It's nearly impossible to throat-clear while doing that — and that's exactly the point.\n\nOver time, the brain learns a new pathway. The urge weakens, and the tic loses power.\n\nCBIT does not suppress tics through willpower. It retrains the brain through practice — like learning a sport or an instrument. The more you practice, the easier it gets.",
                audioHint: "Confident, clear tone. Slow down for the eye-blink example — let it land. Pause before 'CBIT does not suppress tics' for emphasis.",
                emoji: "🛠️"
            ),
            // tb-tts-001: Efficacy claim extracted from id:7 into its own slide to keep
            // both slides under the Railway TTS fetch limit (~400 chars each).
            LessonSlide(
                id: 8,
                title: "Why CBIT Works",
                body: "Research shows CBIT can reduce tics as effectively as many commonly prescribed medications — and without the side effects. It's recommended as a first-line approach by leading medical organizations.",
                audioHint: "Confident and matter-of-fact. Let the research claim land clearly. Warm finish.",
                emoji: "🏆"
            ),
            // tb-mvp2-133: Road metaphor extracted from id:7 into its own slide.
            // Keeps both slides well under Railway TTS fetch timeout (~400 chars each).
            // tb-tts-001: Shifted from id:8 → id:9 to accommodate new "Why CBIT Works" slide.
            LessonSlide(
                id: 9,
                title: "Paving a Better Road",
                body: "Here's something cool about your brain: every time a tic happens, it travels the same pathway — like a road your brain has worn smooth from use. The more it fires, the easier that road gets.\n\nBut roads that aren't used? They grow over. Weeds, grass, brush — nature takes them back.\n\nThat's what CBIT does. It builds a new road — your competing response — and each time you take it, it gets a little smoother. The old tic road slowly grows over from disuse.\n\nYou're not fighting your brain. You're just paving a better road.",
                audioHint: "Ease into this one — it's the emotional core of why CBIT works. Slow, warm, almost storytelling. End on 'paving a better road' with real warmth.",
                emoji: "🧠"
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

            // tb-mvp2-098: Consistency slide — bridges brain-retraining concept to the scheduling
            // feature introduced right after Lesson 1 completes. Placed before the tic-mapping
            // handoff so users understand *why* they are being asked to set a weekly time.
            LessonSlide(
                id: 10,
                title: "Making Time for Practice",
                // tb-lesson1-flow-002: This slide now carries the scheduling CTA.
                // Closing line bridges to the "Schedule My Sessions →" button below.
                body: "CBIT works best with consistency — one session per week keeps your progress moving. We'll help you set a weekly time that works for you.\n\n💡 One tip: For each lesson, find a quiet spot where you won't be interrupted. Set aside about 20–30 minutes — that's all it takes.\n\nTap below to pick your weekly session day now — it only takes a second.",
                audioHint: "Warm and motivating. Short slide — let each sentence breathe. Pause before the tip line. End with a light, forward energy on the last line.",
                emoji: "📅"
            ),
            // tb-mvp2-085: Closing handoff slide — intentional bridge to tic assessment.
            // CTA on this slide routes to TicIntakeAssessmentView (see FamilyModeRouter).
            // Gradient cycles back to teal (index 9 % 8 = 1 → palette wraps) — bookends the welcome slide.
            // tb-mvp2-136: Reordered to id:10 (before "What's Next" which is now the final slide).
            LessonSlide(
                id: 11,
                title: "Let's Map Your Tics",
                // tb-mvp2-113: Removed "Once you're done" daily check-in paragraph — duplicate of What's Next slide.
                body: "Now that you know what tics are, let's make a list of yours.\n\nYou'll document each tic — what it looks like, how often it happens, and how it feels. This becomes your personal tic map, and it's the foundation for everything we'll do together.\n\nTap below when you're ready — it only takes a few minutes!",
                audioHint: "Warm and forward-looking. Pause before 'Tap below when you're ready'. Light emphasis on 'your personal tic map'.",
                emoji: "🗺️"
            ),
            // tb-mvp2-079: "What's Next" — homework to catch tic urges + log via counter.
            // tb-mvp2-102: ziggyPrompt seeds a contextual Ziggy chat for users unsure
            // whether they can feel the premonitory urge. Shows "Ask Ziggy →" CTA on this slide only.
            // tb-mvp2-136: Reordered to id:10 (final slide, after "Let's Map Your Tics").
            // tb-mvp2-098: Shifted to id:11 — new consistency slide inserted before tic-map handoff.
            // Added awareness-only callout per user request — clarify goal is ONLY to notice urges.
            LessonSlide(
                id: 12,
                title: "What's Next",
                // tb-mvp2-093: "## Your Homework" renders as a large bold section header in LessonSlideView.
                // plainTextBody() strips the marker before TTS so Ziggy reads it naturally.
                // tb-mvp2-100: Made the daily logging CTA explicit — "once a day" sets a clear habit.
                // tb-mvp2-112: Added Session 2 next-week reminder + calendar CTA per user feedback.
                // tb-mvp2-122: Rewrote tic counter line to mention tally marks as a no-phone fallback.
                // tb-mvp2-127: Added reward points line so users know logging earns points.
                body: "Now that you know what tics and the premonitory urge are, it's time to start noticing them in real life.\n\n**Here's the key:** Right now, your only job is to *notice* the urge. No stopping, suppressing, or changing anything. Just awareness. Competing responses come later — one step at a time.\n\n## Your Homework\n**Core homework:** Log tics + schedule your next session.\n**Bonus:** Set a goal and choose a reward to work toward.\n\nPick your most bothersome tic — just one. This week, try to notice the urge before that tic happens. That little warning signal — the itch, pressure, or 'something's building' feeling — that's what we're training your brain to catch.\n\n📅 Schedule your next session — add it to your calendar right now, same day next week.\n📱 Catch a tic? Log it in the moment with the tic counter — or jot it down with tally marks if your phone isn't handy. At the end of the day, enter your totals. Either way works!\n🏆 Earn points as you go — catching a tic urge = 1 point. Every 10 points = a new reward tier! (You'll unlock more ways to earn points as you learn new techniques in coming sessions.)\n\n🎯 Set a weekly tic-counting goal — pick a number that feels challenging but doable. Even just 'log tics 3 days this week' counts. Small wins add up.\n\n🎁 Choose your reward — decide now what you'll treat yourself to if you hit your goal. A favourite snack, extra screen time, a small purchase — anything that feels worth working for. Write it down so it's real.\n\n🗺️ Ready to map your tics? Let's do it now →",
                // tb-mvp2-134: Added goal-setting + personal reward prompts per user request.
                // tb-option-b: Added tic mapping CTA bridge at end — "What's Next" is now the
                // final handoff slide. ctaSlideTitle updated to "What's Next" in FamilyModeRouter.
                audioHint: "Energetic and encouraging. Pause after 'that's it'. The daily check-in line is a direct call to action. End warm and forward-looking — the last line is a direct invitation to map tics.",
                emoji: "📚"
            )
        ],
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 1 and mapped my tics for the first time. This is our first chat. Can you introduce yourself and tell me how you can help me with Tourette's?"
    )

    // MARK: - Session 2: First Competing Response
    // Introduces the competing response (CR) — the core CBIT technique.
    // Covers what a CR is, how to choose one, practice instructions, and homework.

    private static let session2 = CBITLesson(
        session: 2,
        title: "Lesson 2: First Competing Response",
        subtitle: "The Technique That Changes Everything",
        slides: [
            LessonSlide(
                id: 0,
                title: "Welcome Back!",
                body: "Great to see you again. Before we jump in — how did last week go?\n\nIf you noticed your tic urges even once, that's a win. Awareness is the whole foundation. Every time you caught that little 'something building' feeling, you were doing the work.\n\nThis week, we're taking the next step. You already know what the premonitory urge is. Now you're going to learn what to *do* with it.\n\nToday's session introduces the competing response — the core technique of CBIT. It's simpler than it sounds, and it really works.",
                audioHint: "Warm and welcoming — like catching up with a friend. Pause after 'that's a win.' Energy builds toward the end — 'it really works' should land with genuine enthusiasm.",
                emoji: "👋"
            ),
            LessonSlide(
                id: 1,
                title: "What Is a Competing Response?",
                body: "A competing response (CR) is a specific action you do when you feel a tic urge coming — one that your body physically cannot do at the same time as the tic.\n\nThat's the key: it's not about willpower. It's about physics. You're giving your body something else to do that the tic literally can't happen alongside.\n\nExamples:\n• If your tic is a head jerk → gently tense your neck muscles downward and hold\n• If your tic is eye blinking → slowly and softly lower your eyelids, hold 2 seconds, release\n• If your tic is shoulder shrugging → press your shoulders down and slightly back, hold\n• If your tic is a throat clear → swallow and breathe slowly through your nose\n\nThe action should be subtle enough that nobody around you would notice. That's by design.",
                audioHint: "Clear, confident, instructional. Pause before 'Examples' — let each one land. Emphasize 'nobody around you would notice' warmly, like it's a secret advantage.",
                emoji: "🛡️"
            ),
            LessonSlide(
                id: 2,
                title: "Why Does It Work?",
                body: "Here's what's happening in your brain:\n\nWhen you feel the premonitory urge, your brain is revving up the tic pathway — building pressure until the tic fires and relief comes.\n\nThe competing response interrupts that cycle. Instead of relieving the urge by doing the tic, you're holding a different action long enough for the urge to pass on its own.\n\nAnd here's the surprising part: urges pass. They always do. They build, peak, and fade — usually within 30–60 seconds. The CR gives you something to hold onto while that happens.\n\nOver time, your brain starts to learn: 'the urge doesn't have to end in a tic.' The pathway weakens. The urge gets quieter. That's not magic — that's how brains rewire through practice.",
                audioHint: "Measured, reassuring, slightly wonder-filled. The phrase 'urges pass — they always do' should sound like good news. End with warmth on 'that's how brains rewire through practice.'",
                emoji: "🧠"
            ),
            LessonSlide(
                id: 3,
                title: "How to Choose Your CR",
                body: "A good competing response has three qualities:\n\n1. **Physically incompatible** — you can't do both the tic and the CR at the same time\n2. **Subtle** — it shouldn't draw attention or feel embarrassing in public\n3. **Holdable** — you can sustain it for 30–60 seconds without it being painful or exhausting\n\nStart with your most noticeable tic — the one that bothers you most or feels most disruptive. That's your first target.\n\nIf you're unsure what CR to use, try this: do your tic intentionally and slowly. What muscles fire? Now find an action that uses those same muscles in the *opposite* direction, or tenses them in a way that prevents the tic movement.\n\nYou'll practice this in just a moment.",
                audioHint: "Step-by-step, practical. Number the three qualities with a slight beat between each. The 'try this' paragraph is a gentle invitation — not a command.",
                emoji: "🎯"
            ),
            LessonSlide(
                id: 4,
                title: "Let's Practice",
                body: "Time to try it.\n\nThink about your most noticeable tic right now. Got it?\n\n**Step 1:** Feel for the urge. If you don't feel it naturally, try doing the tic slowly on purpose — notice the sensation just before it fires.\n\n**Step 2:** As soon as you feel the urge, start your competing response. Engage the muscles. Hold.\n\n**Step 3:** Keep holding for about 30 seconds, or until the urge fades — whichever comes first.\n\n**Step 4:** Release, breathe, notice.\n\nYou don't have to be perfect. The goal right now is just to feel what it's like to hold a CR while an urge is present. Even 10 seconds counts as practice.",
                audioHint: "Calm and coaching. Guide each step slowly — let there be natural pauses between them, like you're walking someone through a physical exercise. End gently: 'Even 10 seconds counts as practice.'",
                emoji: "💪"
            ),
            LessonSlide(
                id: 5,
                title: "One CR at a Time",
                body: "You might be tempted to tackle every tic at once. Don't — at least not yet.\n\nResearch on CBIT is clear: mastering one competing response first leads to better outcomes than trying to address multiple tics simultaneously. There are a few reasons:\n\n• It builds confidence. Getting good at one CR shows you the technique works — and that matters.\n• Awareness sharpens. Focusing on one tic trains your detection skills more effectively.\n• Tics sometimes influence each other. When one tic is reduced, others sometimes follow.\n\nPick your one target tic. Commit to it for this week. Other tics will get their turn.",
                audioHint: "Reassuring and practical. The phrase 'don't — at least not yet' should sound friendly, not scolding. Pause before the bullet list.",
                emoji: "🎯"
            ),
            LessonSlide(
                id: 6,
                title: "What's Next",
                body: "You now have the core CBIT technique. Here's your practice plan for this week:\n\n## Your Homework\n**Core:** Try your competing response at least 3 times this week — once in a low-pressure moment, once during a harder situation, once whenever the urge naturally appears.\n\n📅 Schedule your next session — same day next week.\n📱 Log your tics daily — even a quick tally count helps you see patterns.\n🏆 Earn points — each time you use your CR, that's 2 points toward your reward.\n\n💡 **Tip:** If the CR feels awkward or hard to hold, that's normal. It gets more natural with practice. If it truly doesn't feel incompatible with the tic, we'll troubleshoot next session.\n\n🎁 Check your reward goal — are you on track? If you haven't picked a reward yet, do it now. It makes the practice feel worth it.",
                audioHint: "Energetic and encouraging. Pause after 'You now have the core CBIT technique.' The homework list should feel actionable, not overwhelming. End warmly — next session is something to look forward to.",
                emoji: "🎯"
            )
        ],
        // tb-lesson2-homework: Ziggy CTA seed for Lesson 2 complete card.
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 2 and learned how to design a competing response. Can you help me think through how to practice it this week, or check whether my CR is truly incompatible with my tic?"
    )

    // MARK: - Session 3: Troubleshoot + Relaxation Intro
    // CR troubleshooting (incompatibility, forgetting), diaphragmatic breathing,
    // relaxation as a tic management tool. Homework: daily breathing practice.

    private static let session3 = CBITLesson(
        session: 3,
        title: "Lesson 3: Troubleshoot + Relax",
        subtitle: "When the CR Isn't Clicking — and Your Body as an Ally",
        slides: [
            LessonSlide(
                id: 0,
                title: "Welcome Back!",
                body: "You've had a week with your first competing response. How did it go?\n\nMaybe it worked great. Maybe you forgot to use it half the time. Maybe it felt awkward and you're not sure it's doing anything.\n\nAll of that is completely normal — and all of it is useful information.\n\nToday we do two things: troubleshoot your competing response so it actually works, and add a new tool to your kit — one that helps your whole body get quieter. Let's dig in.",
                audioHint: "Warm and conversational, like catching up with a friend. Light pause after each 'maybe'. End with forward momentum.",
                emoji: "👋"
            ),
            LessonSlide(
                id: 1,
                title: "The #1 Reason CRs Don't Work",
                body: "Here's the most common reason a competing response doesn't block a tic:\n\nIt's not physically incompatible enough.\n\nA competing response needs to make your tic difficult or impossible to do at the same time. If you can still perform the tic while doing the CR, the two aren't truly incompatible — and your brain won't learn to take the new road.\n\nQuick test: try doing your competing response right now. Can you still do your tic while doing it? If yes, the CR needs to be adjusted.\n\nThis isn't a failure — it's a data point. Fixing it is exactly what today is for.",
                audioHint: "Clear and direct. Slow down slightly for 'not physically incompatible enough' — let the concept land. The test question is conversational. End reassuringly.",
                emoji: "🔧"
            ),
            LessonSlide(
                id: 2,
                title: "Making It More Incompatible",
                body: "A strong competing response physically blocks the tic by using the same muscles or body part.\n\nExamples:\n• Throat clearing tic → press your lips together firmly and breathe through your nose. You literally can't throat-clear while doing this.\n• Head or neck jerk → press your chin slightly down toward your chest and tense your neck muscles gently. Hard to jerk when muscles are already engaged.\n• Shoulder shrug → pull your shoulders down and back, pressing lightly against your sides. Shrugging upward is now an active effort.\n• Eye blink → gently and slowly close your eyelids, hold for 2 counts, release. Forceful blinking is incompatible with a controlled, slow close.\n\nThe goal isn't to look unusual or cause discomfort — it's to create just enough physical opposition that the tic can't sneak through.",
                audioHint: "Read examples at a measured pace — let each one land. The last paragraph is reassuring — soften the tone.",
                emoji: "💪"
            ),
            LessonSlide(
                id: 3,
                title: "When You Forget to Use It",
                body: "The second most common problem: you don't forget that you have a competing response — you just forget to use it in the moment.\n\nThis is a habit-building challenge, not a willpower problem.\n\nYour brain is fast. The urge arrives and the tic fires before you've even registered it. Building the reflex takes time — and a few tricks help:\n\n• **Link it to the urge:** As soon as you feel the premonitory urge — that building sensation — that's your cue. Think of the urge as a doorbell. The CR is you answering it.\n• **Cue cards:** A small note on your desk, phone lock screen, or mirror serves as a daily reminder during the early weeks.\n• **Count your catches:** Every time you notice the urge and use the CR — even imperfectly — that counts. Even catching it *after* the tic strengthens awareness for next time.\n\nConsistency matters more than perfection.",
                audioHint: "Warm and patient. Emphasize 'habit-building challenge, not a willpower problem.' Read bullet tips at a natural pace — each one is a small gift.",
                emoji: "🧠"
            ),
            LessonSlide(
                id: 4,
                title: "Stress Makes Tics Louder",
                body: "Here's something you may have already noticed: your tics are worse when you're stressed, anxious, tired, or keyed up.\n\nStress doesn't cause tics — but it turns up the volume on them. When your nervous system is activated (heart racing, muscles tense, breathing shallow), tic signals fire more easily.\n\nThe good news: the reverse is also true. When your body is calm and relaxed, tic signals are quieter and easier to catch before they fire.\n\nThis means relaxation isn't just a nice-to-have — it's an active part of managing tics. And one of the most effective relaxation tools is one you already have with you everywhere you go.\n\nYour breath.",
                audioHint: "Build slowly and warmly. Pause briefly before 'Your breath.' — let it feel like a reveal.",
                emoji: "🌊"
            ),
            LessonSlide(
                id: 5,
                title: "Diaphragmatic Breathing",
                body: "Most of us breathe with our chest — short, shallow breaths that keep the nervous system slightly on edge.\n\nDiaphragmatic breathing (belly breathing) activates the body's calming response. It slows your heart rate, relaxes your muscles, and signals to your brain that everything is okay.\n\n**How to do it:**\n1. Sit comfortably or lie down. Place one hand on your belly, one on your chest.\n2. Breathe in slowly through your nose for 4 counts. Your belly should rise — your chest stays mostly still.\n3. Hold gently for 2 counts.\n4. Breathe out slowly through your mouth for 6 counts. Your belly falls.\n5. Repeat 3–10 times.\n\nIf your chest rises more than your belly at first, that's normal. The belly breath comes with repetition.\n\nTry it right now before moving on — even just 3 cycles is enough to feel the shift.",
                audioHint: "Read the steps slowly and clearly — this is instructional. Pause between each step. 'Try it right now' is a warm, direct invitation — not a command.",
                emoji: "🌬️"
            ),
            LessonSlide(
                id: 6,
                title: "Why This Helps Tics",
                body: "When you breathe slowly and deeply, a few things happen:\n\n• Your heart rate slows down.\n• Muscle tension decreases — especially in the neck, shoulders, and face.\n• Your nervous system shifts from 'alert' mode to 'rest' mode.\n\nAll of these reduce the background activation that makes tic urges stronger and more frequent.\n\nResearch on CBIT consistently shows that people who also practice relaxation techniques alongside their competing responses report better results than those who use CRs alone.\n\nBreathing doesn't replace the competing response — it supports it. Think of it as turning down the background noise so you can catch the urge signal more easily.",
                audioHint: "Calm and measured — match the content. The research reference is matter-of-fact, not academic. End warmly with the 'background noise' metaphor.",
                emoji: "🌿"
            ),
            LessonSlide(
                id: 7,
                title: "Making It a Daily Habit",
                body: "Like the competing response, diaphragmatic breathing works best when it becomes automatic — not something you only reach for in a crisis.\n\nThe goal: one intentional breathing session per day. It doesn't need to be long.\n\n• Morning works well — 5 minutes before you look at your phone.\n• A quiet moment after school or work.\n• Before bed as a wind-down.\n\nThe benefits build over time. After 2–3 weeks of daily practice, most people find they can shift their breathing quickly and feel the calming effect within seconds.\n\nStart small. One session a day. That's it.",
                audioHint: "Encouraging and low-pressure. Each timing suggestion feels like a friendly offer, not a requirement. End with warmth: 'One session a day. That's it.'",
                emoji: "📅"
            ),
            LessonSlide(
                id: 8,
                title: "What's Next",
                body: "Great work today. You've got two powerful tools now — and this week you're putting both into daily practice.\n\n## Your Homework\n**Core:** Practice diaphragmatic breathing once a day — even just 5 minutes. Morning, evening, any time that sticks.\n**Core:** Keep using your competing response for your Session 2 tic. If it wasn't working, try the adjusted version you identified today.\n**Log:** Keep catching and logging tics. Every noticed urge = 1 point. Every CR used = 2 points.\n\n💨 Try the breathing exercise right after you wake up tomorrow — it takes less than 5 minutes and sets a calmer tone for the whole day.\n\n🔧 If your competing response still feels off after adjusting, don't worry — we'll check in next session and fine-tune it together.\n\n📅 Schedule Session 4 now — same day next week. Consistency is the whole game.\n\nYou're doing the work. That matters.",
                audioHint: "Warm and affirming. Read homework bullets clearly but naturally. Pause briefly before the closing line — 'You're doing the work. That matters.' — and deliver it with genuine warmth.",
                emoji: "🎯"
            )
        ],
        // tb-lesson3-homework: Ziggy CTA seed for Lesson 3 complete card.
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 3. Can you walk me through a quick diaphragmatic breathing practice, or help me check whether my competing response is physically incompatible enough?"
    )

    // MARK: - Session 4: Consolidation + Second Tic CR
    // Review first CR progress, address waxing/waning, introduce second tic targeting.

    private static let session4 = CBITLesson(
        session: 4,
        title: "Lesson 4: Consolidation",
        subtitle: "Reviewing Your Progress + Targeting a Second Tic",
        slides: [
            LessonSlide(
                id: 0,
                title: "Welcome Back! 🎉",
                body: "Three sessions in — that's real. You've learned what tics are, what the premonitory urge feels like, and how to build a competing response. That's a lot.\n\nToday we do two things:\n• Check in on how your first competing response is going\n• Start building a second one\n\nBut first — take a breath. Whatever your week looked like, you showed up. That matters more than a perfect practice record.",
                audioHint: "Warm, celebratory but low-key. Like a coach who's genuinely proud. Pause before the two bullet items.",
                emoji: "🎉"
            ),
            LessonSlide(
                id: 1,
                title: "How Did Your First CR Go?",
                body: "Think about the past week. When you noticed the urge for your first tic, did the competing response come to mind?\n\nMaybe you caught it every time. Maybe you caught it once. Maybe the week was a blur and it barely happened.\n\nAll of those are okay — and all of them tell us something useful.\n\n• Caught it often → the habit is forming. Keep going.\n• Caught it sometimes → awareness is there, the habit just needs more reps.\n• Barely caught it → let's troubleshoot. The CR might need adjusting, or the urge might still be hard to detect.\n\nThere's no grade here. We're just collecting information.",
                audioHint: "Non-judgmental, steady. The three bullet outcomes should feel like options, not a grading rubric. Warm emphasis on 'collecting information.'",
                emoji: "🔍"
            ),
            LessonSlide(
                id: 2,
                title: "Tics Wax and Wane — That's Biology",
                body: "Here's something worth knowing: tic frequency naturally goes up and down, and the things that spike it are usually out of your control.\n\nStress, excitement, illness, even good days with lots of social activity — all of these can increase tic frequency temporarily. It doesn't mean the practice isn't working.\n\nIt just means your nervous system is responding to your environment, the way it always has.\n\nThe goal of CBIT isn't to eliminate every tic immediately. It's to build a skill that keeps getting stronger — so that over time, the tics have less hold on your day.",
                audioHint: "Reassuring and grounded. Slow down for 'It just means your nervous system...' — this reframe is important. End with warmth on 'less hold on your day.'",
                emoji: "🌊"
            ),
            LessonSlide(
                id: 3,
                title: "What Progress Actually Looks Like",
                body: "Progress in CBIT is subtle at first — and easy to miss if you're looking for the wrong thing.\n\nYou might not have fewer tics yet. But look for these signs instead:\n\n✅ You noticed the urge before or during the tic — even once\n✅ You used the competing response at least a few times\n✅ The tic feels slightly less automatic in those moments\n✅ You logged your tics consistently, even on bad days\n\nAny of those = progress. Real, measurable, meaningful progress.\n\nThe visible reduction in tics comes later — after awareness and the competing response are locked in. You're building the foundation right now.",
                audioHint: "Encouraging but honest. Each checkmark should sound like a real win. Pause before 'Any of those = progress.' Let it land.",
                emoji: "📈"
            ),
            LessonSlide(
                id: 4,
                title: "Celebrate Your Wins",
                body: "Before we move on — take a moment to acknowledge what you've actually done.\n\nYou learned what a premonitory urge is. You identified a real tic. You designed a competing response. And you practiced it in the real world, where life is messy and distracting and doesn't stop for CBIT sessions.\n\nThat's not small.\n\nA lot of people learn about tics and never go further. You did.\n\nSo whatever your week looked like — give yourself credit. You're doing something hard, and it's working — even if you can't see it yet.",
                audioHint: "Genuine warmth here — this isn't a pep talk, it's real acknowledgment. Slow, sincere. Pause after 'That's not small.' Let it breathe.",
                emoji: "🏆"
            ),
            LessonSlide(
                id: 5,
                title: "Time for Tic #2",
                body: "Now let's target a second tic.\n\nYou don't need to master tic #1 before moving on — in fact, working on two tics helps your brain generalize the skill faster.\n\nHow to pick your second tic:\n• Choose one that's noticeable — something you can reliably feel or see\n• Aim for a tic that causes some distress or gets in the way socially\n• Avoid picking the most complex or severe tic right away — build momentum first\n\nIf you're not sure which one to pick, open your tic inventory and look at what you logged. Your most frequent tic is usually a solid choice.",
                audioHint: "Forward-moving, practical. This slide is action-oriented. The three bullet criteria should sound like simple guidance, not rules.",
                emoji: "🎯"
            ),
            LessonSlide(
                id: 6,
                title: "Designing Your Second Competing Response",
                body: "Same process as last time — just applied to a different tic.\n\n1. **Identify the urge.** Where do you feel it? What does it feel like just before the tic fires?\n\n2. **Design the competing response.** It needs to be physically incompatible with the tic — you can't do both at the same time. Hold a position, press lightly against a surface, take a slow breath — whatever blocks the tic movement without looking strange.\n\n3. **Practice in a low-stakes moment first.** Try the CR when you're relaxed. Then move to real-life moments when the urge shows up.\n\nIf you need help designing it, ask Ziggy — just describe the tic and the urge, and Ziggy can suggest some options.",
                audioHint: "Practical and clear. Number each step with a slight beat between them. The Ziggy mention at the end should feel like a natural tip, not an ad.",
                emoji: "🛠️",
                ziggyPrompt: "I'm trying to design a competing response for a new tic. Can you help me figure out what would work?"
            ),
            LessonSlide(
                id: 7,
                title: "Managing Two CRs",
                body: "Running two competing responses at once can feel like a lot. Here's how to keep it manageable:\n\n• **Don't try to do both perfectly at once.** Give tic #1's CR priority — it's more practiced. Tic #2's CR is new and needs more conscious effort.\n\n• **Keep each CR simple.** The simpler it is, the more automatic it becomes. Complex CRs are harder to remember under pressure.\n\n• **Log both tics separately.** Tracking them independently helps you see which one is responding faster — and motivates you to keep going.\n\nOver the coming weeks, both CRs will become more automatic. For now, doing your best on both is exactly enough.",
                audioHint: "Steady, reassuring. This is permission to not be perfect. End warmly: 'doing your best on both is exactly enough.'",
                emoji: "⚖️"
            ),
            LessonSlide(
                id: 8,
                title: "What's Next",
                body: "This week you're working on two things at once — be intentional about it.\n\n## Your Homework\n**Core:** Practice both CRs whenever you feel the urge. Log tics for both tics daily.\n**CR #1:** Keep building the habit — aim for at least 3 uses this week.\n**CR #2:** Just get familiar. Try it 2–3 times in low-stakes moments first.\n\n📅 Schedule your next session — same day next week.\n📱 Log both tics each day — even a rough count is useful.\n🏆 You're now earning points on two tics — every urge caught = 1 pt, every CR used = 2 pts!\n\nRemember: tics waxing this week doesn't mean anything is wrong. Stay consistent, stay curious, and notice what you notice.",
                audioHint: "Energetic but not overwhelming. The separate homework items for CR #1 and CR #2 should feel like achievable goals. End warm and forward-looking.",
                emoji: "🎯"
            )
        ],
        // tb-lesson4-homework: Ziggy CTA seed for Lesson 4 complete card.
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 4 and I'm starting to work on a second tic. Can you help me design a competing response for my second target tic?"
    )

    // MARK: - Session 5: Pre-biweekly Transition
    // Prepare user for less frequent check-ins, build self-monitoring skills.

    private static let session5 = CBITLesson(
        session: 5,
        title: "Lesson 5: Becoming Your Own Coach",
        subtitle: "Self-Monitoring + Preparing for Less Frequent Sessions",
        slides: [
            LessonSlide(
                id: 0,
                title: "Five Sessions In 🌟",
                body: "Stop for a second and look at what you've built.\n\nYou know what tics are and why they happen. You understand the premonitory urge and can often feel it coming. You've built two competing responses and you're practicing both in real life.\n\nThat's not just learning. That's a skill. A real, working skill that lives in your nervous system now.\n\nToday's session is a little different. Instead of introducing a new technique, we're going to talk about how you keep this going on your own — because the next phase involves less frequent sessions and more self-directed practice.",
                audioHint: "Warm, reflective, proud. This is a milestone moment. Speak slowly and let 'five sessions in' land. Pause after 'That's a skill.'",
                emoji: "🌟"
            ),
            LessonSlide(
                id: 1,
                title: "What Changes Now?",
                body: "Starting after today, your sessions will become less frequent — roughly every two weeks instead of every week. And as your skills develop further, they'll eventually move to monthly — the final stage of the programme.\n\nEach spacing-out is a sign of progress, not a step back.\n\nLess frequent sessions mean:\n• You've built enough skill to practice independently\n• The focus shifts from learning to reinforcing\n• You're transitioning from guided practice to self-directed habit\n\nThink of it like learning to drive. At first you need someone in the passenger seat for every trip. Eventually, you drive alone — and that's the whole point.\n\nZiggy and your daily check-ins stay exactly the same. The formal lessons just spread out a bit.",
                audioHint: "Reassuring and forward-moving. Less frequent doesn't mean abandoned. The driving analogy should sound natural, not forced.",
                emoji: "🚗"
            ),
            LessonSlide(
                id: 2,
                title: "What Is Self-Monitoring?",
                body: "Self-monitoring is the ability to notice what's happening with your tics — without anyone telling you.\n\nIt means:\n• Noticing when a tic is happening more often\n• Recognizing what's driving it (stress? poor sleep? a lot of socializing?)\n• Knowing when to use your CR versus when to let a tic pass\n• Checking in with yourself at the end of each day, even briefly\n\nYou've already been doing a version of this — every time you logged a tic or noticed an urge, that was self-monitoring.\n\nNow we're making it intentional. This skill is what carries CBIT forward for years after the sessions end.",
                audioHint: "Calm, steady, informative. Let each bullet item breathe. End with emphasis on 'years after the sessions end' — this is a long-term skill.",
                emoji: "🔍"
            ),
            LessonSlide(
                id: 3,
                title: "Your Daily Practice Routine",
                body: "Between now and your next session, your daily routine looks like this:\n\n**Morning:** Take 30 seconds to notice how your body feels. Any tightness or urges you've been carrying overnight?\n\n**During the day:** When a tic urge comes — use the CR. Log it. Move on. Don't overthink it.\n\n**Evening check-in:** Spend 2 minutes reviewing the day. How many tics? Were there patterns — times of day, situations, stress levels? Log your count in the app.\n\nThat's it. Under 5 minutes total per day.\n\nConsistency matters more than perfection. Showing up every day, even briefly, is worth more than one intense practice session per week.",
                audioHint: "Practical and clear. The morning/during/evening structure should feel like a routine, not a burden. End with warmth on 'every day, even briefly.'",
                emoji: "📅"
            ),
            LessonSlide(
                id: 4,
                title: "When a Hard Week Hits",
                body: "Some weeks will be harder. Tics will spike. The CRs will feel effortful. You'll forget to log. That's not failure — that's being human.\n\nHere's what to do when things get hard:\n\n1. **Don't catastrophize.** One bad week doesn't undo months of progress. The skill is still there, even when it's hard to access.\n\n2. **Lower the bar.** Instead of 'use both CRs perfectly,' aim for 'notice one urge today.' Small wins rebuild momentum.\n\n3. **Identify the trigger.** Big exam? Social event? Poor sleep? Naming the trigger helps you realize it's temporary — not a sign that CBIT isn't working.\n\n4. **Talk to Ziggy.** Describe what's happening. Sometimes just articulating it out loud helps reset.",
                audioHint: "Grounded and practical. Not cheerleading — this is real talk for real hard weeks. The numbered steps should feel like tools, not commands.",
                emoji: "⛈️",
                ziggyPrompt: "I'm having a hard week — my tics are spiking and I'm struggling to use my competing responses. What should I do?"
            ),
            LessonSlide(
                id: 5,
                title: "Using Ziggy Between Sessions",
                body: "Between now and your next formal session, Ziggy is your main point of contact.\n\nYou can use Ziggy to:\n• Talk through a hard moment with your tics\n• Get help adjusting a competing response\n• Understand why a tic changed or got worse\n• Just check in and feel heard\n\nOne tip: the more specific you are, the more useful Ziggy's responses will be. 'My eye-blinking tic is worse this week, especially after school' is more useful than 'I'm struggling.' Give Ziggy context.",
                audioHint: "Warm and encouraging. The specificity tip at the end is practical — deliver it clearly.",
                emoji: "😉",
                ziggyPrompt: "I want to check in between sessions. Here's what's been happening with my tics this week..."
            ),
            LessonSlide(
                id: 6,
                title: "Preparing for Your Next Session",
                body: "When your next session comes around (in about two weeks), here's what will make it most useful:\n\n📊 **Your logs.** The more you've logged, the more we can see patterns. Even rough numbers help.\n\n🔄 **CR update.** Which competing response is feeling more automatic? Which one still needs work?\n\n❓ **Your questions.** Anything confusing, unexpected, or frustrating from the past two weeks is worth naming. Write it down now so you don't forget.\n\n😮 **Surprises.** Did anything happen that you didn't expect — a tic that improved, a situation that was harder than usual, a moment where the CR clicked?\n\nYou don't need to have everything figured out. Just bring what happened. That's enough.",
                audioHint: "Forward-looking and organized. Each bullet should feel like a helpful prompt. End warmly on 'That's enough.'",
                emoji: "📝"
            ),
            LessonSlide(
                id: 7,
                title: "What's Next",
                body: "You're entering a new phase — one where the practice is yours to own.\n\n## Your Homework\n**Core:** Daily check-in (morning notice + evening log). 5 minutes or less.\n**CRs:** Use both CRs when urges appear. Aim for at least 3 uses each over the next two weeks.\n**Ziggy:** Check in at least twice between now and your next session.\n\n📅 Schedule your next session in about two weeks — put it in your calendar now.\n📱 Log daily — patterns are gold, and you can only see them in the data.\n🏆 Keep earning points on both tics — the streak is yours to maintain!\n\nYou know what you're doing now. The next two weeks are yours.\n\nWe'll be right here when you get back.",
                audioHint: "Warm, proud, and closing. This is a send-off — not 'good luck,' more like 'you've got this.' End on 'We'll be right here when you get back' with real warmth.",
                emoji: "🚀"
            )
        ],
        // tb-lesson2-homework: Ziggy CTA seed for Lesson 5 complete card.
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 5 and I'm moving to biweekly sessions. Can you help me set up a self-monitoring routine and check in on how both my competing responses are going?"
    )


    // MARK: - Session 6: Biweekly Maintenance
    // Check-in format, reviewing CR habit, handling hard weeks, self-monitoring between sessions.

    private static let session6 = CBITLesson(
        session: 6,
        title: "Lesson 6: Biweekly Maintenance",
        subtitle: "Keeping the Habit Alive",
        slides: [
            LessonSlide(
                id: 0,
                title: "Welcome Back",
                body: "Two weeks since your last session — that's a big deal. Every day you showed up and practiced, you were strengthening the same neural pathways we've been building together.\n\nThis session is a check-in, not a test. We're here to look at what's working, notice what's changed, and figure out if anything needs adjusting.\n\nYou don't need to have had a perfect two weeks. Real progress is rarely a straight line — and honest check-ins are where the real learning happens.",
                audioHint: "Warm and welcoming. Unhurried. Emphasise 'not a test' — remove any pressure. Let the final line land with genuine reassurance.",
                emoji: "👋"
            ),
            LessonSlide(
                id: 1,
                title: "How Were the Last Two Weeks?",
                body: "Before we look forward, let's look back. Think about the past two weeks honestly:\n\n• Did you use your competing response when you noticed the urge? Even sometimes?\n• Were there moments it felt automatic — like your body just did it?\n• Were there hard days where tics seemed louder or the CR felt impossible?\n• Did anything surprise you — a new tic, a situation that made things harder, or a moment where you felt genuinely in control?\n\nAll of these count. The wins and the hard days are both information — and both move you forward.",
                audioHint: "Conversational and reflective. Read the bullet points like questions you're genuinely curious about — not a checklist. Slow down after 'Did anything surprise you'.",
                emoji: "🔍"
            ),
            LessonSlide(
                id: 2,
                title: "Is Your CR Becoming Automatic?",
                body: "Early on, a competing response takes real mental effort — you have to consciously catch the urge, remember the CR, and choose to do it. That's hard work.\n\nBut here's what happens with practice: it starts to feel less like a decision.\n\nYou might notice:\n• The CR kicks in before you fully 'think' about it\n• The urge feels less urgent — like the pressure peaks lower than before\n• You catch yourself mid-tic and redirect, rather than finishing it\n\nIf you're not there yet, that's completely normal at week 6. This process takes months, not days. The goal right now is consistency — not perfection.",
                audioHint: "Encouraging and grounded. The three bullet points should each get a small beat of enthusiasm. End on 'not perfection' with warmth — not a consolation, but a genuine truth.",
                emoji: "⚙️"
            ),
            LessonSlide(
                id: 3,
                title: "Handling Hard Weeks",
                body: "You're months in now — which means when a hard week hits, you have something you didn't have at the start: data and perspective.\n\n• **Check your logs.** When exactly did tics spike? A specific day, situation, or trigger? At this stage, pattern recognition is your most powerful tool.\n• **Don't undo the habit.** One hard week doesn't erase months of neural rewiring. The pathways are still there — they need re-engagement, not rebuilding from scratch.\n• **Adjust, don't abandon.** If a CR is feeling less effective, refine it. A CR that's 70% effective is still far better than nothing.\n• **Rest counts.** Sleep and stress management reduce tic frequency — especially now that your baseline has shifted after months of practice.\n\nYou've been through hard weeks before. You know they pass.",
                audioHint: "Steady and reassuring. 'Don't panic' should feel like a calm hand on the shoulder — not dismissive. Pause before each bullet. End on 'rest counts' with real emphasis.",
                emoji: "🌧️"
            ),
            LessonSlide(
                id: 4,
                title: "Tune Your Competing Response",
                body: "By now you know your tic and your CR pretty well. This is a good time to check: is the CR still working as well as it did?\n\nSigns your CR might need adjusting:\n• You can still do the tic while doing the CR (it's not incompatible enough)\n• The CR is too obvious or embarrassing in public, so you skip it\n• You've started a new tic that doesn't have a CR yet\n\nIf any of these apply, that's not a setback — it's just useful information. Chat with Ziggy to work through a revised or additional CR. The technique adapts as you do.",
                audioHint: "Practical and matter-of-fact. This slide is about fine-tuning, not troubleshooting failure. Keep the tone curious and problem-solving rather than concerned.",
                emoji: "🔧"
            ),
            LessonSlide(
                id: 5,
                title: "Between Sessions: Self-Monitoring",
                body: "With sessions now every two weeks, more of the work happens between check-ins. Here's what self-monitoring looks like in practice:\n\n📱 **Log daily** — even a rough count keeps your awareness sharp. You can't improve what you're not tracking.\n\n🧠 **Notice patterns** — are tics worse on school nights? Before social events? Noticing the context helps you prepare.\n\n💬 **Use Ziggy** — mid-week questions, frustrations, or wins are all worth talking through. You don't have to wait for a scheduled session.\n\n🎯 **Keep your goal visible** — look at it. Adjust it if it stopped feeling relevant. Goals that feel real get worked toward.",
                audioHint: "Clear and practical. Each bullet is a tool — give each one a distinct beat. The Ziggy line is warm, not just functional. End on the goal line with gentle encouragement.",
                emoji: "📊"
            ),
            LessonSlide(
                id: 6,
                title: "What's Next",
                body: "You're in a rhythm now — and that rhythm is the most powerful thing you have.\n\n## Your Homework\n**Core:** Keep logging daily. Keep using both CRs whenever urges arise. Notice what's shifting.\n**Tune:** Check that each CR still feels physically incompatible — if anything has slipped, adjust it before next session.\n**Bonus:** Write down one moment from the past two weeks where you felt more in control — even a small one. Keep it somewhere you'll see it.\n\n📅 Schedule your next biweekly session\n📱 Log both tics daily — patterns across two weeks reveal more than single-day snapshots\n🏆 Earn points: catch an urge = 1 point, use your CR = 2 points\n💬 Chat with Ziggy any time — no need to wait\n\nSee you in two weeks. You're doing the work.",
                audioHint: "Warm and forward-looking. The homework section is direct and confident — not rushed. End on 'You're doing the work' like you really mean it.",
                emoji: "🎯"
            )
        ],
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 6 — biweekly maintenance. Let's check in on my competing response. Is it still working well, or does it need tuning?"
    )

    // MARK: - Session 7: Monthly Maintenance
    // Long-term thinking, tic changes over time, identity beyond tics, sustaining momentum.

    private static let session7 = CBITLesson(
        session: 7,
        title: "Lesson 7: Monthly Maintenance",
        subtitle: "The Long Game",
        slides: [
            LessonSlide(
                id: 0,
                title: "You're Playing the Long Game",
                body: "Monthly sessions mean something important: you've built enough consistency that you don't need weekly or biweekly check-ins to stay on track.\n\nThat's not a step down — it's a step up. It means the skills are becoming yours. The competing response isn't a new technique anymore — it's part of how you move through the world.\n\nThis session is about zooming out. Looking at the bigger picture: where you started, where you are, and where this goes long-term.",
                audioHint: "Grounded and proud. The tone should feel like a quiet milestone — not a celebration exactly, but a genuine acknowledgment of real progress. Unhurried.",
                emoji: "🗓️"
            ),
            LessonSlide(
                id: 1,
                title: "How Tics Change Over Months",
                body: "When you look back over the past few months, you might notice things that are hard to see week to week:\n\n• A tic that used to happen dozens of times a day might have dropped significantly\n• The premonitory urge might feel less urgent — like the pressure peaks lower\n• Some tics may have faded on their own — this is normal, especially in younger people\n• New tics may have appeared — also normal, and now you have tools to address them\n\nTics change. They always have. What's different now is that you have an active role in that change — instead of just waiting and hoping.",
                audioHint: "Reflective and warm. The bullet points are observations, not scorecards. Slow down for 'you have an active role in that change' — that's the emotional core of this slide.",
                emoji: "🌱"
            ),
            LessonSlide(
                id: 2,
                title: "When Motivation Dips",
                body: "Here's something nobody talks about enough: motivation dips. It happens to everyone.\n\nAfter months of practice, the novelty is gone. The urgency from early sessions has faded. Some days it's hard to remember why you're still logging, still using the CR, still checking in.\n\nThis is normal — and it's not a sign you should stop. It's a sign you're in the middle part, which is the hardest part of any long-term skill.\n\nWhat helps:\n• **Lower the bar on hard days.** Notice one urge. Do one CR. That's enough.\n• **Look at your history.** Open the calendar view. You've built something real.\n• **Talk to Ziggy.** Saying 'I'm losing motivation' out loud is the first step to finding it again.",
                audioHint: "Honest and real. This slide should feel like someone who's been through it talking to someone who's in it. Not cheerful — grounded. The 'what helps' bullets are practical lifelines.",
                emoji: "🔋"
            ),
            LessonSlide(
                id: 3,
                title: "Tics and Identity",
                body: "Something worth saying out loud: you are not your tics.\n\nTS is part of your neurology — it's not your personality, your worth, or your future. Many people with TS are creative, driven, funny, and socially sharp. Tics do not predict any of that.\n\nBut it's also okay to feel frustrated, embarrassed, or tired of it sometimes. Those feelings are valid. They don't mean you're weak — they mean you're human.\n\nCBIT doesn't ask you to pretend tics don't affect you. It asks you to build skills so they affect you less — and to keep living fully while you do.",
                audioHint: "Warm and genuine. This slide carries emotional weight — let it breathe. Slow down for 'you are not your tics'. The last paragraph should feel affirming, not dismissive of the hard parts.",
                emoji: "💙"
            ),
            LessonSlide(
                id: 4,
                title: "Long-Term Thinking",
                body: "CBIT isn't a short course — it's a skill set you carry for life.\n\nAs you get older, tics often naturally reduce. Many people in their 20s find that tics that were prominent in their teens have significantly diminished. CBIT accelerates and deepens that process.\n\nWhat you're building right now — awareness of the urge, the competing response habit, the ability to self-monitor — these are yours forever. You can pick them back up any time, even after a gap.\n\nAnd if tics change or new challenges appear, you know what to do: identify, map, build a response, practice. The framework works every time.",
                audioHint: "Confident and reassuring. Slow down for 'these are yours forever'. The closing 'the framework works every time' should land like a quiet, solid truth.",
                emoji: "🔭"
            ),
            LessonSlide(
                id: 5,
                title: "Ziggy Is Still Here",
                body: "Monthly sessions mean longer gaps between check-ins — but Ziggy is available every day.\n\nBetween sessions, Ziggy can:\n• Help you troubleshoot a CR that's stopped working\n• Talk through a hard week or a new tic\n• Answer questions about TS you haven't asked yet\n• Just be there on a day when tics are frustrating\n\nYou don't need a 'reason' big enough to open a chat. Checking in when things are going fine is just as valuable as reaching out when they're not.",
                audioHint: "Warm and accessible. Ziggy should feel like a steady presence — not a helpline for emergencies, just someone who's always there. End on the last line with genuine warmth.",
                emoji: "🤖"
            ),
            LessonSlide(
                id: 6,
                title: "What's Next",
                body: "One more month of practice ahead — and you've got everything you need.\n\n## Your Homework\n**Core:** Keep the daily logging habit. Use your CR. Notice what's changed since you started.\n**Bonus:** Write a note to yourself — what would you tell someone who's just starting CBIT? What do you wish you'd known? Keep it. You'll want it later.\n\n📅 Schedule your next monthly session\n🏆 Points: catch an urge = 1 point, use your CR = 2 points\n💬 Chat with Ziggy any time — you don't have to wait\n\nOne month. You've got this.",
                audioHint: "Warm and forward-looking. The bonus homework is genuinely meaningful — read it with care. End on 'You've got this' like you really believe it.",
                emoji: "🎯"
            )
        ],
        ziggyHandoffPrompt: "Hi Ziggy! I just finished Lesson 7 — monthly maintenance. I've been doing CBIT for a while now. Can we do a long-term check-in and talk about how things have been going?"
    )

    // MARK: - Session 8: Final Session + Relapse Prevention
    // Graduation, celebrating progress, relapse plan, what to do if tics return, life beyond CBIT.

    private static let session8 = CBITLesson(
        session: 8,
        title: "Lesson 8: Final Session",
        subtitle: "Graduation & What Comes Next",
        slides: [
            LessonSlide(
                id: 0,
                title: "You Made It",
                body: "This is your final structured CBIT session — and that's worth stopping to acknowledge.\n\nYou started this knowing almost nothing about why tics happen. You learned about the premonitory urge, built a competing response, practiced through hard weeks, and kept showing up even when motivation dipped.\n\nThat's not a small thing. A lot of people learn about CBIT and never start. You started — and you finished.\n\nToday we're going to celebrate what you've built, talk about what to do if tics ever spike again, and make sure you leave with everything you need.",
                audioHint: "Genuinely warm and celebratory — but not over the top. Let 'you started and you finished' land with real weight. Pause before 'Today we're going to...'",
                emoji: "🎓"
            ),
            LessonSlide(
                id: 1,
                title: "Look How Far You've Come",
                body: "Think back to when you started. What were your tics like? How often did they happen? How much did they bother you day to day?\n\nNow compare that to today.\n\nYou may not have eliminated tics — that was never the goal. But you've almost certainly:\n• Built awareness of the premonitory urge that you didn't have before\n• Developed at least one competing response that reduces a tic\n• Gotten better at noticing when tics spike and why\n• Learned that tics are manageable — not something that just happens to you\n\nOpen your tic calendar and take a look. The data tells a real story.",
                audioHint: "Reflective and proud. Slow down for the bullet points — let each one register. End on 'the data tells a real story' with genuine warmth.",
                emoji: "📈"
            ),
            LessonSlide(
                id: 2,
                title: "The Skills You've Built",
                body: "The real outcome of CBIT isn't 'fewer tics' — it's a set of skills you now carry everywhere.\n\n🧠 **Awareness** — you can notice the premonitory urge before a tic completes. Most people never develop this.\n\n⚙️ **Competing response** — you have at least one reliable technique for reducing a specific tic.\n\n📊 **Self-monitoring** — you know how to track tics, spot patterns, and use that information.\n\n💬 **Language for TS** — you can explain what tics are, why they happen, and what helps. That matters in real life.\n\nThese skills don't expire. They're yours — whether tics stay quiet or flare up.",
                audioHint: "Confident and affirming. Each skill should feel like a real thing being handed over. Pause before each emoji-led point. End strong: 'They're yours'.",
                emoji: "🛠️"
            ),
            LessonSlide(
                id: 3,
                title: "What If Tics Come Back?",
                body: "Here's the honest truth: tics may spike again. Stress, illness, major life changes, new environments — any of these can temporarily push tics back up. This is normal, and it does not mean you've lost the progress you made.\n\nWhen tics spike, here's what to do:\n\n1. **Don't catastrophise.** A spike is not a return to square one. Your neural pathways haven't disappeared — they just need reactivation.\n2. **Pull out your tic map.** Identify which tic is most prominent right now. Build or refresh its competing response.\n3. **Return to daily logging.** Even a week of consistent logging will sharpen awareness quickly.\n4. **Open TicBuddy.** Revisit earlier lessons if needed. Start Ziggy conversations. Use the tools you have.\n5. **Give it time.** Most spikes settle within weeks when you re-engage with the practice.",
                audioHint: "Steady and reassuring. 'Does not mean you've lost the progress you made' needs real emphasis. The numbered list is practical — read it like instructions you trust.",
                emoji: "🌊"
            ),
            LessonSlide(
                id: 4,
                title: "Your Relapse Plan",
                body: "Before you leave today, build your relapse plan. Write it down — or tap through to Ziggy and talk it through.\n\nYour plan should answer three questions:\n\n**1. What's my early warning sign?**\nWhat tells you tics are spiking beyond normal waxing and waning? (e.g., logging shows a significant increase, tics are getting comments from others, you feel the urge more than 10x a day)\n\n**2. What's my first move?**\nWhat will you do in the first 48 hours of a spike? (e.g., reopen TicBuddy, log tics for three days, chat with Ziggy, revisit the competing response for the most frequent tic)\n\n**3. What's my support?**\nWho or what can you lean on? (Ziggy, a trusted person in your life, this app)\n\nA plan written in advance is used. A plan not written is forgotten.",
                audioHint: "Clear and practical. Pause before each bold question. End on the last line with weight — it's a real truth.",
                emoji: "📋"
            ),
            LessonSlide(
                id: 5,
                title: "Life Beyond CBIT",
                body: "Finishing structured CBIT sessions doesn't mean TicBuddy goes away.\n\nZiggy is still here. The tic calendar still works. The counter still works. You can log, chat, and check in any time — with no schedule, no sessions, no homework.\n\nA lot of people find that after finishing structured sessions, they settle into a lighter rhythm:\n• Logging when things feel off\n• Chatting with Ziggy during stressful periods\n• Revisiting earlier lessons when a new tic appears\n\nTicBuddy is not a course you graduate from and put on a shelf. It's a tool that stays useful as long as you want it to.\n\nYou know what you're doing now. Trust that.",
                audioHint: "Warm, unhurried, genuine. The final line should feel like a quiet, confident handoff: 'You know what you're doing now. Trust that.'",
                emoji: "🌟"
            ),
            LessonSlide(
                id: 6,
                title: "Congratulations",
                body: "That's it. You're done with structured sessions — and you've earned every bit of this.\n\nYou put in real effort over real weeks. You learned something hard and practiced it even when it was inconvenient. That's not easy, and not everyone does it.\n\nRemember:\n• Tics do not define you\n• You have real skills now — awareness, technique, self-monitoring\n• Hard weeks are temporary\n• Ziggy is always one tap away\n\nGo live your life. You've got what you need.",
                audioHint: "Warm, genuine, celebratory — but grounded. This is the final slide of the entire programme. 'Go live your life. You've got what you need.' should land like a real, earned send-off.",
                emoji: "🎉"
            )
        ]
    )
}