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
    // tb-mvp2-098: Linear post-Session-1 flow (Scheduler → Tic Assessment). Single sheet,
    // step state driven internally by PostSession1FlowView. First-run only.
    @State private var showPostSession1Flow = false
    @AppStorage("hasCompletedSession1Flow") private var hasCompletedSession1Flow = false

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
        // tb-mvp2-098: On first run (hasCompletedSession1Flow == false), completion triggers the
        // linear post-Session-1 flow (Scheduler → Tic Assessment) via PostSession1FlowView.
        // On replay, hierarchy is already filled so CTA just dismisses.
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
                    // "Start Tic Assessment →" on first run; "Update Tics →" on replay.
                    finalCTALabel: isFirstRun ? "Start Tic Assessment →" : "Update Tics →"
                ) {
                    // Always route to post-Session-1 flow (Scheduler → Tic Assessment).
                    // asyncAfter avoids iOS 16 sheet presentation race condition.
                    showLesson = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showPostSession1Flow = true
                    }
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
///   Step 1 — SessionSchedulerView: user picks day + time for weekly sessions
///   Step 2 — TicIntakeAssessmentView: user documents their tics
///
/// Hosted in a single sheet from ChildModeRouter. Internal `postSession1Step` state
/// advances forward only; user cannot skip either step on first run.
/// `onComplete` fires when intake finishes — caller marks hasCompletedSession1Flow = true.
private struct PostSession1FlowView: View {
    @EnvironmentObject var dataService: TicDataService
    let child: ChildProfile
    let onComplete: () -> Void

    /// tb-mvp2-098: Step enum drives navigation within the single-sheet flow.
    private enum PostSession1Step { case scheduling, ticAssessment }
    @State private var step: PostSession1Step = .scheduling

    var body: some View {
        switch step {
        case .scheduling:
            // onContinue advances to tic assessment without dismissing the sheet
            SessionSchedulerView {
                step = .ticAssessment
            }
        case .ticAssessment:
            TicIntakeAssessmentView(child: child) {
                onComplete()
            }
            .environmentObject(dataService)
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
