// TicBuddy — SettingsView.swift
// Shows CBIT program info, privacy details, app version, and support options.
// V2 (tb-mvp2-017): shows FamilyManagementView link for family unit users.

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var showResetConfirm: Bool = false
    @State private var showOnboarding: Bool = false
    // tb-mvp2-049: Hidden TTS preview — triple-tap version label to open
    @State private var showTTSPreview: Bool = false
    @State private var versionTapCount: Int = 0

    private var isV2FamilyUser: Bool {
        dataService.familyUnit.hasCompletedSetup
    }

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - V2 Family Management (shown to family unit users only)
                if isV2FamilyUser {
                    Section {
                        NavigationLink(destination: FamilyManagementView()
                            .environmentObject(dataService)) {
                            Label("Family Profiles", systemImage: "person.2.circle.fill")
                        }
                        // tb-mvp2-018: Evening practice reminder settings
                        NavigationLink(destination: EveningReminderSettingsView()) {
                            Label("Practice Reminder", systemImage: "moon.fill")
                        }
                        // tb-mvp2-024: Optional PIN gate when returning to caregiver mode
                        Toggle(isOn: Binding(
                            get: { dataService.familyUnit.sharedData.requirePINForCaregiverSwitch },
                            set: { newValue in
                                dataService.familyUnit.sharedData.requirePINForCaregiverSwitch = newValue
                                dataService.saveFamilyUnit()
                            }
                        )) {
                            Label("Require PIN to exit child mode", systemImage: "lock.shield")
                        }
                    } header: {
                        Text("Family")
                    } footer: {
                        Text("Manage child profiles, PINs, session settings, and daily reminders. When PIN lock is on, a caregiver PIN or Face ID is required to leave child mode.")
                    }
                }

                // MARK: - Onboarding
                Section("Getting Started") {
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("View Onboarding Again", systemImage: "sparkles")
                    }
                }

                // MARK: - Resources (visible to all: teens, parents, self-guided users)
                Section {
                    NavigationLink(destination: ParentResourceGuideView()) {
                        Label("CBIT & TS Resources", systemImage: "books.vertical.fill")
                    }
                } header: {
                    Text("Resources")
                } footer: {
                    Text("What is CBIT, how habit reversal works, Tourette's info, school accommodations, and medication guidance.")
                }

                // MARK: - For Adults / Parent Resources
                Section {
                    NavigationLink(destination: CaregiversView()) {
                        Label("For Adults", systemImage: "person.2.fill")
                    }
                } header: {
                    Text("Parents & Caregivers")
                } footer: {
                    Text("Therapist finder, family support resources, and caregiver guides.")
                }

                // MARK: - Privacy Section
                Section("Privacy") {
                    Label("All tic data stored on-device only", systemImage: "iphone.and.arrow.forward")
                    Label("No analytics or tracking SDKs", systemImage: "eye.slash.fill")
                    Label("Only your chat messages sent to Anthropic", systemImage: "bubble.left.fill")
                    Label("Name & age never sent to API", systemImage: "person.fill.checkmark")
                }

                // MARK: - Program Section (V1 legacy users only)
                if !isV2FamilyUser {
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
                }

                // MARK: - Support Section
                Section {
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
                    // tb-mvp2-049: Triple-tap to open hidden TTS voice preview
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(isV2FamilyUser ? "2.0 (MVP2)" : "1.0 (MVP1)")
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 3 {
                            versionTapCount = 0
                            showTTSPreview = true
                        }
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
            .sheet(isPresented: $showTTSPreview) {
                TTSVoicePreviewView()
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
