// TicBuddy — SettingsView.swift
// Shows CBIT program info, privacy details, app version, and support options.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var showResetConfirm: Bool = false
    @State private var showOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Onboarding
                Section("Getting Started") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("View Onboarding Again", systemImage: "sparkles")
                    }
                }

                // MARK: - For Adults
                Section {
                    NavigationLink(destination: CaregiversView()) {
                        Label("For Adults", systemImage: "person.2.fill")
                    }
                } header: {
                    Text("Parents & Caregivers")
                } footer: {
                    Text("What is TS, how CBIT works, school accommodations, therapist finder, and family support resources.")
                }

                // MARK: - Privacy Section
                Section("Privacy") {
                    Label("All tic data stored on-device only", systemImage: "iphone.and.arrow.forward")
                    Label("No analytics or tracking SDKs", systemImage: "eye.slash.fill")
                    Label("Only your chat messages sent to Anthropic", systemImage: "bubble.left.fill")
                    Label("Name & age never sent to API", systemImage: "person.fill.checkmark")
                }

                // MARK: - Program Section
                Section("CBIT Program") {
                    HStack {
                        Text("Current Phase")
                        Spacer()
                        Text(dataService.userProfile.recommendedPhase.title)
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    HStack {
                        Text("Day")
                        Spacer()
                        Text("\(dataService.userProfile.daysSinceStart + 1) of program")
                            .foregroundColor(.secondary)
                    }
                    Button("Reset Program Progress", role: .destructive) {
                        showResetConfirm = true
                    }
                }

                // MARK: - Support Section
                Section {
                    // Single button — opens Mail app to KindCode support address
                    Button {
                        let subject = "TicBuddy%20Feedback"
                        let body = "Hi%20KindCode%20team%2C%0A%0A"
                        if let url = URL(string: "mailto:kindcodedevelopment@gmail.com?subject=\(subject)&body=\(body)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Report a Bug or Request a Feature", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Your feedback goes directly to the KindCode team. We read every message! 💙")
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0 (MVP1)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("CBIT Protocol")
                        Spacer()
                        Text("Woods et al. 2011")
                            .foregroundColor(.secondary)
                    }
                    Link("Tourette Association of America", destination: URL(string: "https://tourette.org")!)
                    Link("CBIT Research", destination: URL(string: "https://pubmed.ncbi.nlm.nih.gov/20483968/")!)
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView {
                    showOnboarding = false
                }
                .environmentObject(dataService)
            }
            .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset Progress", role: .destructive) {
                    dataService.resetProgram()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears your CBIT phase and tic logs.")
            }
        }
    }

}

#Preview {
    SettingsView()
        .environmentObject(TicDataService.shared)
}
