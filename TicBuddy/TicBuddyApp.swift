// TicBuddy — TicBuddyApp.swift
// Main entry point. Routes to FamilyOnboarding or Main tab view based on setup state.
// V1 users (legacy userProfile.hasCompletedOnboarding) bypass family onboarding for compat.

import SwiftUI

@main
struct TicBuddyApp: App {
    @StateObject private var dataService = TicDataService.shared
    @StateObject private var legalConsent = LegalConsentService.shared  // tb-mvp2-029
    @State private var showingSplash = true

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

                if showingSplash {
                    KindCodeSplashView(isShowing: $showingSplash)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .animation(.easeOut(duration: 0.3), value: showingSplash)
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
