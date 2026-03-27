// TicBuddy — TicBuddyApp.swift
// Main entry point. Routes to FamilyOnboarding or Main tab view based on setup state.
// V1 users (legacy userProfile.hasCompletedOnboarding) bypass family onboarding for compat.

import SwiftUI

@main
struct TicBuddyApp: App {
    @StateObject private var dataService = TicDataService.shared
    @StateObject private var legalConsent = LegalConsentService.shared  // tb-mvp2-029
    @State private var showingSplash = true
    // tb-mvp2-065: App walkthrough — shown once after setup, dismissed with AppStorage flag.
    @AppStorage("ticbuddy_walkthrough_complete") private var walkthroughComplete = false
    @State private var showLesson1FromWalkthrough = false
    // tb-mvp2-123: after walkthrough lesson, route directly to tic assessment
    @State private var showIntakeAfterWalkthrough = false

    private var appIsSetUp: Bool {
        dataService.familyUnit.hasCompletedSetup || dataService.userProfile.hasCompletedOnboarding
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Routing logic:
                //   familyUnit.hasCompletedSetup → FamilyModeRouter (V2 multi-profile)
                //     └─ isInChildMode == false → CaregiverTabView
                //     └─ isInChildMode == true  → ChildModeRouter (age-group dispatch)
                //   userProfile.hasCompletedOnboarding (V1 legacy) → MainTabView (compat)
                //   neither → FamilyOnboardingView (fresh install)
                if dataService.familyUnit.hasCompletedSetup {
                    FamilyModeRouter()
                        .environmentObject(dataService)
                } else if dataService.userProfile.hasCompletedOnboarding {
                    MainTabView()
                        .environmentObject(dataService)
                } else {
                    FamilyOnboardingView {
                        // FamilyUnit + legacy userProfile saved inside FamilyOnboardingView
                    }
                    .environmentObject(dataService)
                }

                // tb-mvp2-065: Guided walkthrough — floats above all tab content + tab bar.
                // Only shown once after initial setup; controlled by AppStorage flag.
                if appIsSetUp && !walkthroughComplete && !showingSplash {
                    AppWalkthroughView {
                        // "View Lesson 1" tapped — tb-mvp2-073 fix: await prefetch
                        // before presenting the cover so slide 0 plays instantly.
                        if let slide0 = CBITLessonService.lesson(for: .session1)?.slides.first {
                            Task { @MainActor in
                                let prefetch = Task {
                                    await ZiggyTTSService.shared.prefetchLessonSlide(
                                        text: slide0.spokenText, // tb-mvp2-087: title+body, matches speakCurrentSlide
                                        voiceProfile: .caregiver,
                                        slideIndex: 0
                                    )
                                }
                                Task { try? await Task.sleep(nanoseconds: 3_000_000_000); prefetch.cancel() }
                                await prefetch.value
                                showLesson1FromWalkthrough = true
                            }
                        } else {
                            showLesson1FromWalkthrough = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }

                if showingSplash {
                    KindCodeSplashView(isShowing: $showingSplash)
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showingSplash)
            .animation(.easeOut(duration: 0.4), value: walkthroughComplete)
            // tb-mvp2-029: Legal disclaimer — required before any Program content.
            // fullScreenCover sits above all routing; user cannot dismiss without agreeing.
            .fullScreenCover(isPresented: Binding(
                get: { !legalConsent.hasAcknowledgedDisclaimer && !showingSplash },
                set: { _ in }
            )) {
                LegalDisclaimerView {
                    legalConsent.hasAcknowledgedDisclaimer = true
                }
            }
            // tb-mvp2-065: Lesson 1 sheet launched from walkthrough "View Lesson 1" button.
            // tb-mvp2-123: onFinished now routes to tic assessment instead of just dismissing.
            .fullScreenCover(isPresented: $showLesson1FromWalkthrough) {
                if let lesson = CBITLessonService.lesson(for: .session1) {
                    LessonSlideView(
                        lesson: lesson,
                        voiceProfile: .caregiver,
                        finalCTALabel: "Start Tic Assessment →",
                        ctaSlideTitle: "Let's Map Your Tics",
                        onFinished: {
                            // tb-mvp2-123 fix: explicitly mark walkthrough complete here.
                            // finish() in AppWalkthroughView uses withAnimation which can
                            // race against fullScreenCover presentation — this guarantees
                            // the overlay never re-appears when the cover dismisses.
                            walkthroughComplete = true
                            showLesson1FromWalkthrough = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showIntakeAfterWalkthrough = true
                            }
                        }
                    )
                }
            }
            // tb-mvp2-123: Tic assessment presented after walkthrough lesson completes.
            .fullScreenCover(isPresented: $showIntakeAfterWalkthrough) {
                if let child = dataService.familyUnit.children.first {
                    TicIntakeAssessmentView(child: child) {
                        showIntakeAfterWalkthrough = false
                    }
                    .environmentObject(dataService)
                }
            }
        }
    }
}

// MARK: - Main Tab View

struct MainTabView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            ChatView()
                .tabItem {
                    Label("TicBuddy", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(1)
                .badge(0)

            TicCalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(2)

            TicProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(3)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(Color(hex: "667EEA"))
        .onAppear {
            dataService.checkAndAdvancePhase()
        }
    }
}
