// TicBuddy — TicBuddyApp.swift
// Main entry point. Routes to Onboarding or Main tab view based on profile state.

import SwiftUI

@main
struct TicBuddyApp: App {
    @StateObject private var dataService = TicDataService.shared

    var body: some Scene {
        WindowGroup {
            if dataService.userProfile.hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(dataService)
            } else {
                OnboardingView {
                    // Profile saved inside OnboardingView — no extra work needed
                }
                .environmentObject(dataService)
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
