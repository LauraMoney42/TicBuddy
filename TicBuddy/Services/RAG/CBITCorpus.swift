// TicBuddy — CBITCorpus.swift
// The curated Tourette's / CBIT research corpus, on-device. (tb-rag-ondevice-001)
//
// SOURCE OF TRUTH
// ---------------
// Every chunk below is derived verbatim (lightly re-flowed for retrieval) from the
// project's curated clinical reference `RESEARCH.md`, which in turn cites:
//   1. Woods, D.W. et al. (2011). CBIT — JAMA.
//   2. Piacentini, J. et al. (2010). Behavior therapy for children with Tourette
//      disorder. JAMA, 303(19), 1929–1937.
//   3. Tourette Association of America — CBIT training materials.
//   4. Chang, S. et al. (2016). Behavior therapy for Tourette Syndrome. JCPP.
//   5. American Academy of Neurology (2019) practice guidelines for TS.
//
// WHY A SWIFT ARRAY (not a bundled file)
// --------------------------------------
// Keeping the corpus as a plain Swift value with NO app-specific dependencies means
// the *exact same* corpus + retrieval code compiles into (a) the iOS app and
// (b) the standalone CLI self-test in Tools/. There is one source of truth for what
// is indexed, so the tested behavior is the shipped behavior.
//
// This file intentionally imports only Foundation — no UIKit, no app models.

import Foundation

/// One retrievable unit of CBIT knowledge plus the light metadata used for
/// optional filtering and for interview-honest provenance.
struct CBITChunk: Identifiable, Hashable {
    let id: Int
    /// The retrieval text. Self-contained: each chunk reads sensibly on its own,
    /// because retrieval returns individual chunks out of document order.
    let text: String
    /// Human-readable section of RESEARCH.md this came from (for provenance/citation).
    let section: String
    /// Optional CBIT phase this chunk is most relevant to (nil = all phases).
    /// Values mirror the app's CBITPhase.ragKey strings but are kept as plain
    /// strings so this file has zero app-type dependencies.
    let sessionStage: String?
    /// Optional tic modality this chunk applies to: "motor", "vocal", or nil (both).
    let ticType: String?
}

/// The curated on-device corpus. Small by design (a clinician-vetted reference,
/// not the open web), which is exactly why brute-force in-memory cosine is the
/// right index: ~three dozen chunks × 512 dims is microseconds per query.
enum CBITCorpus {

    static let chunks: [CBITChunk] = [
        // MARK: Epidemiology & nature of tics
        CBITChunk(id: 1,
            text: "Tourette syndrome affects about one percent of school-age children (1 in 100), is three to four times more common in males, and typically onsets at age 5 to 7, peaking around age 10 to 12. Tics often improve significantly in late adolescence and early adulthood.",
            section: "Epidemiology", sessionStage: nil, ticType: nil),
        CBITChunk(id: 2,
            text: "Tics wax and wane: they naturally fluctuate in type, frequency, and severity over time. A harder week is the disorder fluctuating, not the child failing. Normalize the wax-and-wane pattern.",
            section: "Epidemiology", sessionStage: nil, ticType: nil),
        CBITChunk(id: 3,
            text: "Simple motor tics involve a single muscle group: eye blinking, eye rolling, head jerking, shoulder shrugging, facial grimacing, nose wrinkling. Complex motor tics are coordinated multi-muscle movements such as touching objects or self, jumping, spinning, or echopraxia (imitating others' movements).",
            section: "Tic Types", sessionStage: nil, ticType: "motor"),
        CBITChunk(id: 4,
            text: "Simple vocal tics are simple sounds: throat clearing, sniffing, grunting, coughing, squeaking, humming. Complex vocal tics are words or phrases: echolalia (repeating others), palilalia (repeating one's own words), and coprolalia (involuntary swearing, which is rare, about 10 to 15 percent of cases).",
            section: "Tic Types", sessionStage: nil, ticType: "vocal"),

        // MARK: Premonitory urge
        CBITChunk(id: 5,
            text: "The premonitory urge is an uncomfortable sensation of tension or pressure that precedes a tic, often described as being like needing to sneeze. Kids may call it 'the feeling before' a tic, a 'signal feeling', or a warning feeling that comes right before the tic. Performing the tic relieves it temporarily. Eighty to ninety percent of people with Tourette syndrome report this urge.",
            section: "Premonitory Urge", sessionStage: "week2_competing", ticType: nil),
        CBITChunk(id: 6,
            text: "Learning to notice the premonitory urge before the tic fires is the foundation of competing response training. Younger children under 10 often have less awareness of the premonitory urge, so awareness work must be adapted and expectations kept gentle for them.",
            section: "Premonitory Urge", sessionStage: "week1_awareness", ticType: nil),

        // MARK: What makes tics better / worse
        CBITChunk(id: 7,
            text: "Tics tend to get worse with stress and anxiety (the most common trigger), excitement (including positive events), fatigue and poor sleep, illness or fever, excessive screen time, socially judged situations, boredom, and anticipating or monitoring tics.",
            section: "What Makes Tics Worse", sessionStage: nil, ticType: nil),
        CBITChunk(id: 8,
            text: "Tics tend to ease with relaxation and calm, focused flow-state activity, physical exercise, an acceptance-based mindset, and understanding from family and teachers. CBIT has the strongest behavioral evidence of any approach.",
            section: "What Helps", sessionStage: nil, ticType: nil),

        // MARK: Co-occurring conditions
        CBITChunk(id: 9,
            text: "Conditions that commonly co-occur with Tourette syndrome: ADHD (50 to 60 percent), OCD (20 to 60 percent), anxiety (30 to 40 percent), and learning disabilities (20 to 30 percent).",
            section: "Co-occurring Conditions", sessionStage: nil, ticType: nil),

        // MARK: CBIT foundation
        CBITChunk(id: 10,
            text: "Comprehensive Behavioral Intervention for Tics (CBIT) is a first-line behavioral treatment for Tourette syndrome with Level 1 evidence. In the key randomized controlled trial (Piacentini/Woods, JAMA 2010), 52.5 percent of participants showed meaningful improvement versus 18.5 percent of controls, with effects maintained at six-month follow-up. It works for ages 9 and up and is adapted for younger children, delivered as about 8 sessions over 10 weeks.",
            section: "CBIT Foundation", sessionStage: nil, ticType: nil),
        CBITChunk(id: 11,
            text: "CBIT begins with psychoeducation: explain Tourette syndrome in non-stigmatizing terms, explain the CBIT rationale grounded in neuroplasticity, and set realistic expectations. Success is defined as consistent practice, not the elimination of tics.",
            section: "CBIT Components", sessionStage: nil, ticType: nil),

        // MARK: Awareness training
        CBITChunk(id: 12,
            text: "Awareness training (the first CBIT phase) teaches the person to accurately describe and identify each tic and to recognize the premonitory urge. Steps: (1) detailed behavioral tic description, (2) self-monitoring to notice the tic as it happens rather than after, (3) antecedent awareness of situations and feelings that precede tics, and (4) early detection of the first movement.",
            section: "Awareness Training", sessionStage: "week1_awareness", ticType: nil),
        CBITChunk(id: 13,
            text: "Increased awareness may temporarily increase tic frequency early in CBIT. This is expected and must be normalized: noticing more tics is a sign the awareness work is happening, not a sign of getting worse.",
            section: "Awareness Training", sessionStage: "week1_awareness", ticType: nil),

        // MARK: Competing response — principles
        CBITChunk(id: 14,
            text: "A good competing response has four properties: it is physically incompatible with the tic (you cannot do both at once), it can be maintained for about one minute, it is socially inconspicuous, and it is not uncomfortable or painful.",
            section: "Competing Response", sessionStage: "week2_competing", ticType: nil),
        CBITChunk(id: 15,
            text: "Competing response training process: (1) identify the best competing response for the most bothersome tic, (2) practice it when NOT feeling the urge, (3) practice it WHEN feeling the urge, (4) use it at the first sign of the premonitory urge or early tic movement, and (5) hold it for one full minute or until the urge passes, whichever is longer.",
            section: "Competing Response", sessionStage: "week3_building", ticType: nil),
        CBITChunk(id: 16,
            text: "Universal competing responses that work for most tics: slow diaphragmatic breathing (the most versatile) and isometric tension in the muscle opposing the tic.",
            section: "Competing Response", sessionStage: "week2_competing", ticType: nil),

        // MARK: Competing response — by tic (motor)
        CBITChunk(id: 17,
            text: "Competing response for an eye-blink tic: a slow controlled blink followed by sustained, relaxed eye opening. Competing response for a facial grimace: a relaxed neutral face with a gentle lip press.",
            section: "Competing Response by Tic", sessionStage: "week3_building", ticType: "motor"),
        CBITChunk(id: 18,
            text: "Competing response for a head-jerk tic: isometric neck tension with no visible movement and a slight downward chin tuck. Competing response for an arm-jerk tic: tense the arm firmly against the body.",
            section: "Competing Response by Tic", sessionStage: "week3_building", ticType: "motor"),
        CBITChunk(id: 19,
            text: "Competing response for a shoulder-shrug tic: shoulder depression, pushing the shoulders firmly and steadily down.",
            section: "Competing Response by Tic", sessionStage: "week3_building", ticType: "motor"),

        // MARK: Competing response — by tic (vocal)
        CBITChunk(id: 20,
            text: "Competing response for a throat-clearing tic: slow nasal breathing with the mouth closed and the throat relaxed. Competing response for a sniffing tic: a controlled slow nasal exhale, then a return to regular nasal breathing.",
            section: "Competing Response by Tic", sessionStage: "week3_building", ticType: "vocal"),
        CBITChunk(id: 21,
            text: "Competing response for a grunting tic: slow rhythmic nasal breathing with the mouth closed.",
            section: "Competing Response by Tic", sessionStage: "week3_building", ticType: "vocal"),

        // MARK: Function-based assessment, relaxation, social support
        CBITChunk(id: 22,
            text: "Function-based assessment identifies situations where tics are consistently worse and pairs each with a strategy: socially judged settings get relaxation and acceptance work, homework and concentration tasks get examined for ADHD overlap, and transitions get prepared strategies.",
            section: "Function-Based Assessment", sessionStage: "week4_advanced", ticType: nil),
        CBITChunk(id: 23,
            text: "Relaxation training in CBIT includes progressive muscle relaxation, diaphragmatic breathing, and applied cue-controlled relaxation. It is introduced later to manage the stress that amplifies tics.",
            section: "Relaxation Training", sessionStage: "week4_advanced", ticType: nil),
        CBITChunk(id: 24,
            text: "The social support component: parents learn to notice and praise competing-response use, teachers can be informed optionally, and the family works to reduce inadvertently reinforcing tics. Praise the effort of noticing and redirecting, not tic-free time.",
            section: "Social Support", sessionStage: nil, ticType: nil),

        // MARK: Neuroplasticity
        CBITChunk(id: 25,
            text: "Neuroplasticity rationale: tics involve basal ganglia-thalamocortical circuits, and a repeated tic becomes a well-worn neural pathway, like a rut in mud. CBIT builds a competing pathway so the brain learns a new route. Consolidation takes about 8 to 12 weeks, and changes are visible on fMRI after CBIT.",
            section: "Neuroplasticity", sessionStage: nil, ticType: nil),
        CBITChunk(id: 26,
            text: "Kid-friendly framing for brain change: the brain is like Play-Doh that reshapes with practice; tics are trains on old tracks and CBIT builds new tracks; competing responses are like leveling up with XP; and catching a tic before it happens is literally a superpower.",
            section: "Neuroplasticity", sessionStage: nil, ticType: nil),

        // MARK: Communication principles
        CBITChunk(id: 27,
            text: "Communication principles: never shame, and never frame tics as something to control or stop, because tics are not the child's fault. Celebrate noticing, because catching a tic counts as winning even when no redirect happens. Normalize the wax-and-wane pattern.",
            section: "Communication Principles", sessionStage: nil, ticType: nil),
        CBITChunk(id: 28,
            text: "Frame progress correctly: success is consistent practice, not tic elimination. Tie motivation to the child's own goals such as sports, friendships, or school, so the drive is intrinsic.",
            section: "Communication Principles", sessionStage: nil, ticType: nil),

        // MARK: Week-by-week program
        CBITChunk(id: 29,
            text: "Week 1 (Detective Mode) focuses on awareness training: log tics, describe them, and notice when they happen. Do not introduce competing responses yet. Talk about what tics are, how everyone is different, and that the child is not alone.",
            section: "Week-by-Week", sessionStage: "week1_awareness", ticType: nil),
        CBITChunk(id: 30,
            text: "Week 2 (Signal Spotter) focuses on premonitory-urge recognition: log tics and note whether the child felt the feeling beforehand. Explain the urge and normalize that some people feel it more than others.",
            section: "Week-by-Week", sessionStage: "week2_competing", ticType: nil),
        CBITChunk(id: 31,
            text: "Weeks 3 and 4 (Power Move Intro and Practice) introduce the first competing response and build the habit: choose a Power Move, practice it, and log its use. Emphasize that the brain is changing even when it is not yet obvious, and that it is normal for it to feel hard at first.",
            section: "Week-by-Week", sessionStage: "week3_building", ticType: nil),
        CBITChunk(id: 32,
            text: "Later weeks generalize and consolidate: add competing responses for more tic types, practice in progressively harder environments and locations, build daily-logging streaks toward automaticity, and add relaxation and stress-management work. Maintenance covers what to do when tics worsen with illness or stress.",
            section: "Week-by-Week", sessionStage: "week4_advanced", ticType: nil),

        // MARK: Safety / scope (grounds the guardrail and refusals)
        CBITChunk(id: 33,
            text: "Safety scope for the assistant: never diagnose or suggest a diagnosis, never recommend starting or stopping medication, and never give medical advice. Do suggest consulting a doctor or therapist for medical questions, including medication, dosages, side effects, and diagnosis.",
            section: "Safety Guidelines", sessionStage: nil, ticType: nil),
        CBITChunk(id: 34,
            text: "If a child expresses distress or hopelessness, respond supportively and suggest talking to a trusted adult; for any sign of self-harm, direct them to a trusted adult or a crisis line immediately rather than attempting to counsel. The assistant's role is CBIT skills practice, encouragement, and psychoeducation about tics.",
            section: "Safety Guidelines", sessionStage: nil, ticType: nil),

        // MARK: Kid-friendly vocabulary (maps clinical terms to the words kids use)
        CBITChunk(id: 35,
            text: "Kid-friendly words for clinical terms: the premonitory urge is 'the feeling before' or a 'signal feeling'; a competing response is a 'Power Move' or 'redirect'; CBIT is 'brain training'; awareness training is 'Detective Mode' or 'noticing'; a baseline is 'your starting point'. Use the child's own goals to stay motivating.",
            section: "Language Guidelines", sessionStage: nil, ticType: nil),
    ]

    /// Total number of curated chunks. Cited in docs so the resume can be specific.
    static var count: Int { chunks.count }
}
