// TicBuddy — FamilyModeRouter.swift
// Top-level routing between caregiver mode and child mode for V2 family unit users.
//
// Routing tree:
//   familyUnit.isInChildMode == false  → CaregiverTabView
//   familyUnit.isInChildMode == true   → ChildModeRouter (age-group dispatch)
//
// Mode switching flow (single-device):
//   Caregiver → child: tap "Switch to [name]" → PIN entry (if required) → child mode
//   Child → caregiver: tap "Exit child mode" → biometric / caregiver PIN → caregiver mode
//
// Device config awareness:
//   .separateDevices  → no "Switch to child" button (child has own device)
//   .singleDevice     → full profile switcher
//   .caregiverOnly    → no child mode UI at all

import SwiftUI
import LocalAuthentication

// MARK: - Family Mode Router

/// Top-level V2 router — shown when familyUnit.hasCompletedSetup == true.
struct FamilyModeRouter: View {
    @EnvironmentObject var dataService: TicDataService

    private var family: FamilyUnit { dataService.familyUnit }

    var body: some View {
        Group {
            if family.isInChildMode {
                ChildModeRouter()
            } else {
                CaregiverTabView(isSelfUser: family.accountType == .selfUser)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: family.isInChildMode)
    }
}

// MARK: - Caregiver Tab View

/// Tab container for caregiver mode. Replaces legacy MainTabView for V2 users.
struct CaregiverTabView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var selectedTab = 0
    @State private var showSwitchToChild = false
    // tb-mvp2-028: first-time Ziggy onboarding (caregiver or self-user framing)
    @StateObject private var caregiverStore = CaregiverSessionStore.shared
    @State private var showCaregiverOnboarding = false
    /// True when the primary user has tics themselves (selfSetup path) — drives
    /// Ziggy onboarding framing and hides the child switcher FAB. (tb-mvp2-034)
    let isSelfUser: Bool

    private var family: FamilyUnit { dataService.familyUnit }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {

                // ── Caregiver dashboard ──────────────────────────────────────
                CaregiverHomeView()
                    .tabItem { Label("Family", systemImage: "house.fill") }
                    .tag(0)

                // ── Ziggy chat (caregiver / therapist mode — no usage cap) ──
                ChatView()
                    .tabItem { Label("Ziggy", systemImage: "bubble.left.and.bubble.right.fill") }
                    .tag(1)

                // ── Shared practice calendar ─────────────────────────────────
                TicCalendarView()
                    .tabItem { Label("Calendar", systemImage: "calendar") }
                    .tag(2)

                // ── Progress charts ───────────────────────────────────────────
                TicProgressView()
                    .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                    .tag(3)

                // ── Settings ──────────────────────────────────────────────────
                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .tint(Color(hex: "667EEA"))
            .onAppear { dataService.checkAndAdvancePhase() }

            // ── "Switch to child" FAB — only shown on single-device config ───
            if shouldShowChildSwitcher {
                Button {
                    showSwitchToChild = true
                } label: {
                    HStack(spacing: 8) {
                        Text("🧒")
                            .font(.system(size: 16))
                        Text(switchLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(24)
                    .shadow(color: Color(hex: "43E97B").opacity(0.4), radius: 8, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 90) // above tab bar
            }
        }
        .sheet(isPresented: $showSwitchToChild) {
            SwitchToChildSheet()
                .environmentObject(dataService)
        }
        // tb-mvp2-028/034: first-time Ziggy onboarding — framing depends on account type
        .fullScreenCover(isPresented: $showCaregiverOnboarding) {
            CaregiverOnboardingZiggyView(isSelfUser: isSelfUser) {
                caregiverStore.hasCompletedOnboarding = true
                showCaregiverOnboarding = false
            }
        }
        .onAppear {
            // tb-mvp2-064: navigate to home page first — do not auto-launch Ziggy on first open.
            // Mark hasCompletedOnboarding true immediately so this never triggers the fullScreenCover.
            // Ziggy onboarding remains accessible via the Ziggy tab or Lesson 1 tile.
            if !caregiverStore.hasCompletedOnboarding {
                caregiverStore.hasCompletedOnboarding = true
            }
        }
    }

    private var shouldShowChildSwitcher: Bool {
        // tb-mvp2-034: self-users have no child profiles to switch to
        guard !isSelfUser else { return false }
        guard !family.children.isEmpty else { return false }
        // Only show switcher for single-device or caregiverOnly configs
        let config = family.children.first?.deviceConfig ?? .singleDevice
        return config == .singleDevice || config == .caregiverOnly
    }

    private var switchLabel: String {
        if family.children.count == 1 {
            return "Switch to \(family.children[0].displayName)"
        }
        return "Switch to child"
    }
}

// MARK: - Child Mode Router

/// Routes to the correct age-specific view based on the active child's AgeGroup.
struct ChildModeRouter: View {
    @EnvironmentObject var dataService: TicDataService

    // tb-mvp2-026: Weekly session auto-launch
    @State private var showWeeklyIntro = false
    // tb-mvp2-059: Slide-based lesson shown after weekly intro when content exists for the session
    @State private var showLesson = false
    // tb-lesson1-flow-002: Scheduler sheet presented inline over the lesson after CTA tap.
    // Dismissal returns user to "Let's Map Your Tics" slide (lesson auto-advanced on CTA tap).
    @State private var showSchedulerFromLesson = false
    // tb-mvp2-098/tb-lesson1-flow-002: Post-Session-1 flow (Tic Assessment → Homework).
    // Scheduler step moved inline to lesson; this sheet now starts at tic assessment.
    @State private var showPostSession1Flow = false
    @AppStorage("hasCompletedSession1Flow") private var hasCompletedSession1Flow = false
    // tb-optC-005: Post-lesson complete screen for Sessions 6–7 (first-time only, per lesson)
    @State private var showPostLessonFlow = false
    @State private var completedLesson: CBITLesson? = nil
    // One-time complete card per lesson (Sessions 2–7). Keyed by session number so adding
    // future sessions requires no new state — just extend the switch case range.
    // UserDefaults used directly (not @AppStorage) since these reads don't need to trigger re-renders.
    private func hasShownHomework(for stage: CBITSessionStage) -> Bool {
        UserDefaults.standard.bool(forKey: "ticbuddy_l\(stage.rawValue)_homework_shown")
    }
    private func markHomeworkShown(for stage: CBITSessionStage) {
        UserDefaults.standard.set(true, forKey: "ticbuddy_l\(stage.rawValue)_homework_shown")
    }

    private var child: ChildProfile? { dataService.familyUnit.activeChild }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Age-group dispatch
            Group {
                switch child?.ageGroup {
                case .veryYoung, .young:
                    ChildModeYoungView()
                case .olderChild:
                    ChildModeOlderView()
                case .youngTeen, .teen, .none:
                    ChildModeAdolescentView()
                }
            }
            .environmentObject(dataService)

            // ── Exit child mode button (top-left, directly under status bar) ──
            // Only shown on single-device config; tapping requires caregiver auth.
            // tb-mvp2-027: padding(.top, 8) only — ZStack already starts below safe area,
            // so adding safeAreaTop here was double-counting and pushed the button past the greeting.
            if child?.deviceConfig == .singleDevice {
                ExitChildModeButton()
                    .padding(.top, 8)
                    .padding(.leading, 16)
                    .zIndex(100)
            }
        }
        // tb-mvp2-026: Auto-show Ziggy session intro once per 7-day window
        .sheet(isPresented: $showWeeklyIntro) {
            if let child = child {
                // tb-mvp2-038: pass practiceCalendar so Ziggy can acknowledge consistency
                let intro = WeeklySessionService.shared.sessionIntro(
                    stage: child.sessionStage,
                    childName: child.displayName,
                    practiceCalendar: dataService.familyUnit.sharedData.practiceCalendar
                )
                ZiggyWeeklyIntroSheet(intro: intro) {
                    WeeklySessionService.shared.markLaunched(for: child.id)
                    showWeeklyIntro = false
                    // tb-mvp2-059: if a lesson exists for this session stage, show it next.
                    // Sessions without authored slides skip straight to child home + Ziggy chat.
                    if let lesson = CBITLessonService.lesson(for: child.sessionStage) {
                        if let slide0 = lesson.slides.first {
                            let profile = ZiggyVoiceProfile.profile(for: child.ageGroup)
                            // tb-mvp2-073 fix: await the prefetch BEFORE opening the sheet.
                            // tb-mvp2-105: AppWalkthroughView pre-warms slide 0+1 cache on its
                            // .onAppear — by the time the user reaches this tap, the cache is
                            // already populated and await prefetch.value resolves in ~0ms.
                            // The blocking pattern is kept as a safety fallback for edge cases
                            // (cache cleared, first launch without walkthrough, etc.).
                            // Timeout reduced 3s → 1s since a warm cache resolves instantly.
                            Task { @MainActor in
                                let prefetch = Task {
                                    await ZiggyTTSService.shared.prefetchLessonSlide(
                                        text: slide0.spokenText, // tb-mvp2-087: title+body, matches speakCurrentSlide
                                        voiceProfile: profile,
                                        slideIndex: 0
                                    )
                                }
                                // Safety: cancel after 1s — cache hit resolves in ~0ms anyway
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    prefetch.cancel()
                                }
                                await prefetch.value
                                showLesson = true
                            }
                        } else {
                            // No slides — show immediately
                            showLesson = true
                        }
                    }
                }
            }
        }
        // tb-mvp2-059: lesson sheet — shown after weekly intro when session has authored slides
        // tb-lesson1-flow-002: CTA on "Making Time for Practice" (id:9) fires onCTATapped,
        // which opens the scheduler sheet over the lesson and auto-advances to "Let's Map Your Tics"
        // (id:10). Last-slide "Done →" on "What's Next" (id:11) fires onFinished → tic assessment.
        .sheet(isPresented: $showLesson) {
            if let child = child,
               let lesson = CBITLessonService.lesson(for: child.sessionStage) {
                let voiceProfile = ZiggyVoiceProfile.profile(for: child.ageGroup)
                // tb-mvp2-114: isFirstRun controls label only — destination is always
                // the tic assessment so returning users can update their hierarchy.
                let isFirstRun = !hasCompletedSession1Flow && child.ticHierarchy.isEmpty
                LessonSlideView(
                    lesson: lesson,
                    voiceProfile: voiceProfile,
                    finalCTALabel: isFirstRun ? "Schedule My Lesson" : "Update Schedule",
                    ctaSlideTitle: "Making Time for Practice",
                    onCTATapped: {
                        // tb-lesson1-flow-002: Show scheduler over the lesson.
                        // LessonSlideView auto-advances to id:10 after this fires,
                        // so dismissing the scheduler reveals "Let's Map Your Tics".
                        showSchedulerFromLesson = true
                    },
                    // tb-audio-001: Pass scheduler state so LessonSlideView suppresses TTS while open.
                    schedulerPresented: showSchedulerFromLesson,
                    // tb-lesson1-flow-003: "Let's Map Your Tics" shows "Map My Tics →" CTA
                    // that fires onFinished directly (dismisses lesson → PostSession1FlowView).
                    dismissActionSlideTitle: "Let's Map Your Tics",
                    dismissActionLabel: "Map My Tics →"
                ) {
                    // Last slide "Done →" → dismiss lesson, then show appropriate post-lesson flow.
                    // asyncAfter avoids iOS sheet presentation race condition.
                    // tb-optC-005: Sessions 6–7 get a dedicated complete screen + homework card
                    // (first time only). All other sessions use the Session-1 flow or dismiss.
                    let capturedStage = child.sessionStage
                    let capturedLesson = lesson
                    showLesson = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        switch capturedStage {
                        case .session2, .session3, .session4, .session5, .session6, .session7:
                            // One-time completion card — gate prevents repeat on replay.
                            if !hasShownHomework(for: capturedStage) {
                                markHomeworkShown(for: capturedStage)
                                completedLesson = capturedLesson
                                showPostLessonFlow = true
                            }
                        default:
                            if !hasCompletedSession1Flow {
                                showPostSession1Flow = true
                            }
                        }
                    }
                }
                // tb-lesson1-flow-002: Scheduler presented as a nested sheet over the lesson
                // (iOS 16.4+ / iOS 17 nested sheet support). onContinue sets binding false
                // to dismiss — reveals lesson at "Let's Map Your Tics" (id:10).
                .sheet(isPresented: $showSchedulerFromLesson) {
                    SessionSchedulerView(onContinue: {
                        showSchedulerFromLesson = false
                    })
                }
            }
        }
        // tb-mvp2-098: Post-Session-1 linear flow — Scheduler → Tic Assessment.
        // Single sheet; internal step enum drives navigation between the two screens.
        // Marks hasCompletedSession1Flow = true on completion so replay never re-enters.
        .sheet(isPresented: $showPostSession1Flow) {
            if let child = child {
                PostSession1FlowView(child: child) {
                    hasCompletedSession1Flow = true
                    showPostSession1Flow = false
                }
                .environmentObject(dataService)
            }
        }
        // tb-optC-005: Sessions 6–7 post-lesson complete screen (AppStorage gated, once per lesson).
        // Shows homework card + Ziggy CTA. completedLesson cleared on dismiss to avoid stale state.
        .sheet(isPresented: $showPostLessonFlow, onDismiss: { completedLesson = nil }) {
            if let lesson = completedLesson {
                PostLessonCompleteView(lesson: lesson, onContinue: {
                    showPostLessonFlow = false
                })
            }
        }
        .onAppear {
            // Small delay so child mode view fully renders before sheet appears
            if let childID = child?.id,
               WeeklySessionService.shared.shouldAutoLaunch(for: childID) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    showWeeklyIntro = true
                }
            }
        }
    }

}

// MARK: - Post-Session-1 Linear Flow

/// tb-mvp2-098: Container view that drives the linear first-run flow after Session 1:
///   Step 1 — TicIntakeAssessmentView: user documents their tics
///   Step 2 — PostLessonCompleteView(lesson1): homework card + Ziggy intro (first time only)
///
/// tb-lesson1-flow-002: SessionSchedulerView was removed from this flow. It is now
/// presented as a nested sheet over the lesson (showSchedulerFromLesson in ChildModeRouter).
/// Scheduler → lesson resumes at "Let's Map Your Tics" → last slide "Done →" → this flow.
///
/// Hosted in a single sheet from ChildModeRouter. Internal `step` state advances
/// forward only. `onComplete` fires at end — caller marks hasCompletedSession1Flow = true.
/// tb-option-c: Step 2 gated by AppStorage("ticbuddy_l1_homework_shown") — shows once.
// tb-lesson1-flow-003: Promoted from private — TicBuddyApp.swift walkthrough path also uses this.
struct PostSession1FlowView: View {
    @EnvironmentObject var dataService: TicDataService
    let child: ChildProfile
    let onComplete: () -> Void

    // tb-tic-ziggy-001: Added ziggyTicMapping step before ticAssessment.
    // Shown once (ticZiggyDone gate). Skip or completion both advance to manual grid.
    private enum PostSession1Step { case ziggyTicMapping, ticAssessment, homeworkSlide }
    @AppStorage("ticbuddy_l1_homework_shown") private var homeworkShown = false
    /// tb-tic-ziggy-001: Prevents re-showing on re-entry (e.g. force-quit mid-flow).
    @AppStorage("ticbuddy_tic_ziggy_done") private var ticZiggyDone = false
    /// tb-tic-ziggy-001: Tics from Ziggy conversation → passed as preloadedHierarchy.
    @State private var ziggyParsedTics: [TicHierarchyEntry] = []
    @State private var step: PostSession1Step = .ziggyTicMapping

    var body: some View {
        switch step {
        case .ziggyTicMapping:
            // tb-lesson1-flow-003: Only skip Ziggy if done AND tics exist.
            // If ticHierarchy is empty, a stale ticZiggyDone flag (e.g. from a test run)
            // must not bypass Ziggy — user still needs to map their tics.
            if ticZiggyDone && !child.ticHierarchy.isEmpty {
                // Already seen + tics mapped — skip straight to grid (re-entry after force-quit)
                TicIntakeAssessmentView(child: child) { advanceFromAssessment() }
                    .environmentObject(dataService)
            } else {
                // tb-tic-ziggy-001: Ziggy discovers top-5 tics via conversation.
                ZiggyTicMappingView(child: child) { parsedTics in
                    ticZiggyDone = true
                    ziggyParsedTics = parsedTics
                    step = .ticAssessment
                } onSkip: {
                    ticZiggyDone = true
                    step = .ticAssessment
                }
                .environmentObject(dataService)
            }

        case .ticAssessment:
            TicIntakeAssessmentView(child: child, preloadedHierarchy: ziggyParsedTics) {
                advanceFromAssessment()
            }
            .environmentObject(dataService)

        case .homeworkSlide:
            // Reuse PostLessonCompleteView — Session 1 bullets + Ziggy CTA live there now.
            if let lesson1 = CBITLessonService.lesson(for: .session1) {
                PostLessonCompleteView(lesson: lesson1, onContinue: onComplete)
            }
        }
    }

    private func advanceFromAssessment() {
        if homeworkShown {
            onComplete()
        } else {
            homeworkShown = true
            step = .homeworkSlide
        }
    }
}


// MARK: - Post-Lesson Complete View (Sessions 1–7)

/// One-time completion screen shown after a lesson finishes.
/// Used for Session 1 (via PostSession1FlowView) and Sessions 2–7 (via ChildModeRouter).
/// AppStorage gating is handled upstream — this view always shows when presented.
/// Homework card + Ziggy CTA (if lesson.ziggyHandoffPrompt is set) + "Go to Dashboard".
private struct PostLessonCompleteView: View {
    let lesson: CBITLesson
    let onContinue: () -> Void
    @State private var showZiggy = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer(minLength: 32)

                    // ── Completion header ────────────────────────────────────
                    VStack(spacing: 8) {
                        Text("✅")
                            .font(.system(size: 56))
                        Text("Lesson \(lesson.session) Complete!")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("That's it for today. Great work.")
                            .font(.system(size: 16, design: .rounded))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // ── Homework card ────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: 10) {
                            Text("📚")
                                .font(.system(size: 28))
                            Text("Your Homework")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        // Homework bullets keyed by session number.
                        // Content mirrors each lesson's "What's Next" slide, distilled to 3 bullets.
                        VStack(alignment: .leading, spacing: 14) {
                            if lesson.session == 1 {
                                // tb-lesson1-complete-001: Updated to clarify homework covers ALL tics.
                                HomeworkBullet(
                                    emoji: "👀",
                                    text: "Every day, try to notice your tics as they happen — all of them. Just observe, don't try to stop them."
                                )
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Count or log them in your calendar when you can."
                                )
                                // tb-lesson1-complete-001: Next-lesson context using scheduled weekday.
                                let weekday = UserDefaults.standard.string(forKey: "ticbuddy_session_weekday")
                                let scheduledDayString = weekday.map { " on \($0)" } ?? ""
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "That's Lesson 1 done for this week! Your next lesson is next week\(scheduledDayString). See you then."
                                )
                            } else if lesson.session == 2 {
                                HomeworkBullet(
                                    emoji: "💪",
                                    text: "Try your competing response at least 3 times this week — a low-pressure moment, a harder situation, and whenever the urge shows up naturally."
                                )
                                HomeworkBullet(
                                    emoji: "📱",
                                    text: "Log your tics daily — even a quick tally helps you see patterns."
                                )
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Schedule your next session — same day next week."
                                )
                            } else if lesson.session == 3 {
                                HomeworkBullet(
                                    emoji: "🌬️",
                                    text: "Practice diaphragmatic breathing once a day — even just 5 minutes. Morning works well."
                                )
                                HomeworkBullet(
                                    emoji: "💪",
                                    text: "Keep using your competing response. If it wasn't working, try the adjusted version you identified today."
                                )
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Schedule Session 4 — same day next week. Consistency is the whole game."
                                )
                            } else if lesson.session == 4 {
                                HomeworkBullet(
                                    emoji: "💪",
                                    text: "Practice both CRs whenever you feel the urge. CR #1: aim for 3 uses. CR #2: try 2–3 times in low-stakes moments first."
                                )
                                HomeworkBullet(
                                    emoji: "📱",
                                    text: "Log both tics each day — even a rough count is useful. Patterns emerge over time."
                                )
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Schedule your next session — same day next week."
                                )
                            } else if lesson.session == 5 {
                                HomeworkBullet(
                                    emoji: "🔍",
                                    text: "Daily check-in: 30 seconds each morning to notice your body, 2 minutes each evening to log tics and patterns."
                                )
                                HomeworkBullet(
                                    emoji: "💪",
                                    text: "Use both CRs when urges appear. Aim for at least 3 uses each over the next two weeks."
                                )
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Schedule your next session in about two weeks — biweekly cadence starts now."
                                )
                            } else if lesson.session == 6 {
                                HomeworkBullet(
                                    emoji: "🔄",
                                    text: "Keep logging daily and use both CRs whenever you notice an urge."
                                )
                                HomeworkBullet(
                                    emoji: "🔧",
                                    text: "Check that each CR still feels physically incompatible — tune it if anything has slipped."
                                )
                                HomeworkBullet(
                                    emoji: "✍️",
                                    text: "Write down one moment from the past two weeks where you felt more in control. Keep it somewhere you'll see it."
                                )
                            } else if lesson.session == 7 {
                                HomeworkBullet(
                                    emoji: "📅",
                                    text: "Keep the daily logging habit. Use your CR. Notice what's changed since you started."
                                )
                                HomeworkBullet(
                                    emoji: "✍️",
                                    text: "Write a note to yourself — what would you tell someone just starting CBIT? What do you wish you'd known? Keep it for later."
                                )
                                HomeworkBullet(
                                    emoji: "💬",
                                    text: "Chat with Ziggy any time between sessions — you don't need to wait."
                                )
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // ── Two-button footer ────────────────────────────────────
                    // Primary: open Ziggy with handoff seed prompt (if lesson has one).
                    // Secondary: skip to dashboard.
                    VStack(spacing: 12) {
                        if lesson.ziggyHandoffPrompt != nil {
                            Button {
                                showZiggy = true
                            } label: {
                                Text("Chat with your TicBuddy")
                                    .font(.system(size: 17, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                                    .background(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
                                                    startPoint: .leading,
                                                    endPoint: .trailing
                                                )
                                            )
                                    )
                            }
                        }

                        Button(action: onContinue) {
                            Text("Go to Dashboard")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.white.opacity(0.10)))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 48)
                }
            }
        }
        // Ziggy handoff session. Dismiss → onContinue → home dashboard.
        .sheet(isPresented: $showZiggy, onDismiss: onContinue) {
            NavigationStack {
                ChatView(seedPrompt: lesson.ziggyHandoffPrompt ?? "")
                    .environmentObject(TicDataService.shared)
            }
        }
    }
}

// MARK: - Homework Bullet Row

private struct HomeworkBullet: View {
    let emoji: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.system(size: 24))
                .frame(width: 32)
            Text(text)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Exit Child Mode Button

/// Small "← Caregiver" button overlaid on child mode views.
/// Requires biometric or caregiver PIN before switching back.
private struct ExitChildModeButton: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var showAuthSheet = false

    private var caregiverIsGated: Bool {
        // tb-mvp2-024: gate only fires when caregiver has opted in via Settings.
        // tb-mvp2-025: even when opted in, only fires if PIN or biometric actually exists.
        guard dataService.familyUnit.sharedData.requirePINForCaregiverSwitch else { return false }
        let id = dataService.familyUnit.primaryCaregiver?.id ?? UUID()
        return FamilyPINService.shared.caregiverHasPIN(profileID: id)
            || FamilyPINService.shared.biometricAuthAvailable
    }

    var body: some View {
        Button {
            if caregiverIsGated {
                showAuthSheet = true
            } else {
                // No PIN set and no biometric — exit child mode immediately (no gate armed)
                dataService.familyUnit.activeChildID = nil
                dataService.saveFamilyUnit()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text("Caregiver")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.black.opacity(0.3))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAuthSheet) {
            CaregiverAuthSheet {
                // On success: clear active child → returns to caregiver mode
                dataService.familyUnit.activeChildID = nil
                dataService.saveFamilyUnit()
            }
            .environmentObject(dataService)
        }
    }
}

// MARK: - Caregiver Auth Sheet

/// Biometric (preferred) or 4-digit PIN auth to return to caregiver mode.
private struct CaregiverAuthSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let onAuthenticated: () -> Void

    @State private var pin = ""
    @State private var authFailed = false
    @State private var biometricAttempted = false

    private let pinService = FamilyPINService.shared
    private var caregiverID: UUID? { dataService.familyUnit.primaryCaregiver?.id }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("🔐")
                        .font(.system(size: 64))
                    Text("Switch to caregiver view")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("Enter caregiver PIN to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 4-dot PIN indicator
                HStack(spacing: 16) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i < pin.count ? Color(hex: "667EEA") : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }

                // Error message
                if authFailed {
                    Text("Incorrect PIN. Try again.")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }

                // Number pad
                PINPad(pin: $pin, maxLength: 4) {
                    attemptPINAuth()
                }
                .padding(.horizontal, 60)

                // Biometric option
                if pinService.biometricAuthAvailable {
                    Button {
                        Task { await attemptBiometric() }
                    } label: {
                        Label(
                            pinService.biometricType == .faceID ? "Use Face ID" : "Use Touch ID",
                            systemImage: pinService.biometricType == .faceID
                                ? "faceid" : "touchid"
                        )
                        .font(.subheadline.bold())
                        .foregroundColor(Color(hex: "667EEA"))
                    }
                }

                Spacer()
            }
            .navigationTitle("Caregiver Access")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                // Try biometric first on appear
                if pinService.biometricAuthAvailable && !biometricAttempted {
                    Task { await attemptBiometric() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func attemptPINAuth() {
        guard pin.count == 4 else { return }
        // tb-mvp2-025: NEVER allow arbitrary input when no PIN is set.
        // The no-PIN case is handled upstream (ExitChildModeButton skips this sheet).
        // Here we only accept input when a stored PIN matches exactly.
        if let id = caregiverID, pinService.verifyCaregiverPIN(pin, profileID: id) {
            dismiss()
            onAuthenticated()
        } else {
            authFailed = true
            pin = ""
        }
    }

    @MainActor
    private func attemptBiometric() async {
        biometricAttempted = true
        let success = await pinService.authenticateCaregiverBiometric(reason: "Switch to caregiver view")
        if success {
            dismiss()
            onAuthenticated()
        }
    }
}

// MARK: - Switch To Child Sheet

/// Shown when caregiver taps "Switch to [child]".
/// Lists all children; taps with PIN prompt if needed.
struct SwitchToChildSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    @State private var pendingChildID: UUID? = nil
    @State private var showPINEntry = false

    private var family: FamilyUnit { dataService.familyUnit }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(family.children) { child in
                        Button {
                            switchTo(child)
                        } label: {
                            HStack(spacing: 16) {
                                Text(child.ageGroup.subModeName == "Adolescent" ? "🧑" : "🧒")
                                    .font(.system(size: 30))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(child.displayName)
                                        .font(.headline.bold())
                                        .foregroundColor(.primary)
                                    Text(child.ageGroup.displayName + " · " + child.ageGroup.subModeName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                if child.hasPIN {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Choose a profile")
                } footer: {
                    Text("The app will switch to child mode. Lock icon means a PIN is required.")
                }
            }
            .navigationTitle("Switch Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showPINEntry) {
            if let childID = pendingChildID,
               let child = family.children.first(where: { $0.id == childID }) {
                ChildPINEntrySheet(child: child) {
                    activateChild(childID)
                }
                .environmentObject(dataService)
            }
        }
    }

    private func switchTo(_ child: ChildProfile) {
        if child.isOpenAccess {
            // No PIN required — switch immediately
            activateChild(child.id)
        } else {
            // PIN required
            pendingChildID = child.id
            showPINEntry = true
        }
    }

    private func activateChild(_ id: UUID) {
        dataService.familyUnit.activeChildID = id
        // Bridge active child into legacy userProfile for backward compat
        if let child = family.children.first(where: { $0.id == id }) {
            dataService.userProfile = child.userProfile
        }
        dataService.saveFamilyUnit()
        dismiss()
    }
}

// MARK: - Child PIN Entry Sheet

/// 4-digit PIN pad for entering a child's profile PIN.
private struct ChildPINEntrySheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let child: ChildProfile
    let onAuthenticated: () -> Void

    @State private var pin = ""
    @State private var authFailed = false

    private let pinService = FamilyPINService.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Text("🔒")
                        .font(.system(size: 64))
                    Text("\(child.displayName)'s PIN")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(child.ageGroup.childPINIsPrivate
                         ? "Only \(child.displayName) knows this PIN."
                         : "Enter \(child.displayName)'s 4-digit PIN.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 16) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i < pin.count ? Color(hex: "43E97B") : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }

                if authFailed {
                    Text("Incorrect PIN. Try again.")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }

                PINPad(pin: $pin, maxLength: 4) {
                    if pinService.verifyChildPIN(pin, profileID: child.id) {
                        dismiss()
                        onAuthenticated()
                    } else {
                        authFailed = true
                        pin = ""
                    }
                }
                .padding(.horizontal, 60)

                Spacer()
            }
            .navigationTitle("Enter PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - PIN Pad Component

/// Reusable 4×3 numeric keypad for PIN entry.
struct PINPad: View {
    @Binding var pin: String
    var maxLength: Int = 4
    var onComplete: () -> Void

    private let digits: [[String] ] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["",  "0", "⌫"]
    ]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(digits, id: \.self) { row in
                HStack(spacing: 20) {
                    ForEach(row, id: \.self) { key in
                        if key.isEmpty {
                            Color.clear.frame(width: 72, height: 56)
                        } else {
                            Button {
                                handleKey(key)
                            } label: {
                                Text(key)
                                    .font(.system(size: key == "⌫" ? 22 : 24,
                                                  weight: .semibold,
                                                  design: .rounded))
                                    .foregroundColor(.primary)
                                    .frame(width: 72, height: 56)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func handleKey(_ key: String) {
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
        } else if pin.count < maxLength {
            pin.append(key)
            if pin.count == maxLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    onComplete()
                }
            }
        }
    }
}
