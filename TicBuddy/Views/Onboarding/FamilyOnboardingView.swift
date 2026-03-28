// TicBuddy — FamilyOnboardingView.swift
// Expanded family-aware onboarding (tb-mvp2-003).
//
// Two paths through the same 6-step flow:
//   Caregiver path — parent/guardian/therapist sets up on behalf of a child
//   Self path      — adolescent (13+) or adult sets up their own account
//
// Step layout (both paths share the same step numbers):
//   0 — Role selection (who's setting this up?)
//   1 — About you (caregiver name + relationship  OR  your nickname)
//   2 — About the child (nickname + age group  OR  your age group)
//   3 — Device config (reuses DeviceConfigSelectionView)
//   4 — Treatment stage (where are you in CBIT?)
//   5 — All set! (summary + family unit creation)
//
// On completion: creates a FamilyUnit, persists it via TicDataService,
// and updates the legacy userProfile for backward compatibility.

import SwiftUI

// MARK: - Path

enum OnboardingPath {
    case undecided
    case caregiver   // parent / grandparent / guardian / therapist
    case selfSetup   // the person with tics sets up their own account (teen or adult)
}

// MARK: - Family Onboarding View

struct FamilyOnboardingView: View {
    @EnvironmentObject var dataService: TicDataService

    @State private var step: Int = 0
    @State private var path: OnboardingPath = .undecided

    // Caregiver fields
    @State private var caregiverName: String = ""

    // tb-mvp2-014: COPPA consent gate — shown before final save for under-13 children
    @State private var showCOPPAConsent = false
    @State private var pendingChildForCOPPA: ChildProfile? = nil

    // Child / self fields
    @State private var childNickname: String = ""
    @State private var childAgeGroup: AgeGroup = .olderChild

    // Shared
    @State private var deviceConfig: DeviceConfig = .singleDevice
    @State private var sessionStage: CBITSessionStage = .session1
    @State private var hasTherapist: Bool = false

    let onComplete: () -> Void

    private let totalSteps = 6  // steps 0–5; step 0 has no progress bar

    var body: some View {
        ZStack {
            gradientBackground

            VStack(spacing: 0) {
                if step > 0 {
                    progressHeader
                        .padding(.top, 20)
                }

                ScrollView(showsIndicators: false) {
                    stepContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                        .id(step)
                        .padding(.vertical, 24)
                        .padding(.horizontal, 4)
                }

                if step > 0 {
                    navButtons
                        .padding(.horizontal, 30)
                        .padding(.bottom, 44)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: step)
        // tb-mvp2-014: COPPA consent gate — blocks profile creation until consent given
        .sheet(isPresented: $showCOPPAConsent) {
            if let child = pendingChildForCOPPA {
                COPPAConsentSheet(
                    childNickname: child.nickname,
                    childAgeGroup: child.ageGroup,
                    onAccept: { caregiverEmail in
                        // Record consent before saving any child data
                        COPPAConsentService.shared.recordConsent(
                            childID: child.id,
                            caregiverEmail: caregiverEmail,
                            acknowledgedDataCollection: true,
                            acknowledgedNoThirdPartySharing: true
                        )
                        showCOPPAConsent = false
                        pendingChildForCOPPA = nil
                        buildFamilyUnitAndComplete(with: child)
                    },
                    onCancel: {
                        // Caregiver cancelled — discard pending child, stay on last step
                        showCOPPAConsent = false
                        pendingChildForCOPPA = nil
                    }
                )
            }
        }
    }

    // MARK: - Gradient

    private var gradientBackground: some View {
        LinearGradient(
            colors: gradientColors(for: step),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.5), value: step)
    }

    private func gradientColors(for step: Int) -> [Color] {
        switch step {
        case 0: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case 1: return [Color(hex: "F093FB"), Color(hex: "764BA2")]
        case 2: return [Color(hex: "4FACFE"), Color(hex: "00F2FE")]
        case 3: return [Color(hex: "134E5E"), Color(hex: "38A3A5")]
        case 4: return [Color(hex: "FA709A"), Color(hex: "FEE140")]
        case 5: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        default: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                ForEach(1..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.white : Color.white.opacity(0.3))
                        .frame(height: i == step ? 6 : 4)
                        .animation(.spring(response: 0.4), value: step)
                }
            }
            .padding(.horizontal, 30)

            Text("Step \(step) of \(totalSteps - 1)")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.95))
                .tracking(1)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }

    // MARK: - Step Content Router

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            FamilyRoleSelectionStep(path: $path) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step = 1 }
            }
        case 1:
            if path == .caregiver {
                FamilyCaregiverAboutYouStep(name: $caregiverName)
            } else {
                FamilySelfNicknameStep(nickname: $caregiverName)
            }
        case 2:
            if path == .caregiver {
                FamilyAboutChildStep(nickname: $childNickname, ageGroup: $childAgeGroup)
            } else {
                FamilySelfAgeGroupStep(ageGroup: $childAgeGroup)
            }
        case 3:
            // Reuse the existing DeviceConfigSelectionView component
            DeviceConfigSelectionView(
                childName: path == .caregiver ? childNickname : caregiverName,
                selectedConfig: $deviceConfig
            )
        case 4:
            FamilyTreatmentStageStep(sessionStage: $sessionStage, hasTherapist: $hasTherapist)
        case 5:
            FamilyAllSetStep(
                caregiverName: caregiverName,
                childNickname: path == .caregiver ? childNickname : nil,
                ageGroup: childAgeGroup,
                deviceConfig: deviceConfig,
                sessionStage: sessionStage,
                path: path == .caregiver ? "caregiver" : "self"
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Navigation Buttons

    private var navButtons: some View {
        HStack {
            if step > 1 {
                Button { withAnimation(.spring()) { step -= 1 } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.left")
                        Text("Back")
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(22)
                }
            }

            Spacer()

            Button(action: handleNext) {
                HStack(spacing: 8) {
                    Text(nextLabel)
                        .font(.headline.bold())
                    if step < totalSteps - 1 {
                        Image(systemName: "arrow.right").font(.subheadline.bold())
                    }
                }
                .foregroundColor(Color(hex: "764BA2"))
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(Color.white)
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .disabled(isNextDisabled)
            .opacity(isNextDisabled ? 0.5 : 1.0)
        }
    }

    private var nextLabel: String {
        switch step {
        case totalSteps - 1: return "Let's Go! 🚀"
        case 3: return "Got It!"
        default: return "Next"
        }
    }

    private var isNextDisabled: Bool {
        switch step {
        case 1:
            // Name must be non-empty on step 1 (caregiver or self-setup)
            return caregiverName.trimmingCharacters(in: .whitespaces).isEmpty
        case 2:
            // Child nickname must be non-empty on caregiver path
            return path == .caregiver && childNickname.trimmingCharacters(in: .whitespaces).isEmpty
        default:
            return false
        }
    }

    private func handleNext() {
        if step < totalSteps - 1 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { step += 1 }
        } else {
            // tb-mvp2-014: COPPA gate — show consent sheet for under-13 children
            // before persisting any data. Consent must be accepted to complete setup.
            if path == .caregiver && childAgeGroup.isCOPPAApplicable {
                pendingChildForCOPPA = buildChildProfile()
                showCOPPAConsent = true
            } else {
                buildFamilyUnitAndComplete()
            }
        }
    }

    // MARK: - Family Unit Creation

    /// Builds the ChildProfile without saving — used by COPPA gate to get a stable UUID
    /// before recording consent, then passed to buildFamilyUnitAndComplete(with:).
    private func buildChildProfile() -> ChildProfile {
        var child = ChildProfile()
        child.nickname    = path == .caregiver ? childNickname : caregiverName
        child.ageGroup    = childAgeGroup
        child.deviceConfig = deviceConfig
        child.sessionStage = sessionStage
        child.userProfile.name = child.nickname
        child.userProfile.age  = childAgeGroup.minimumAge + 2
        child.userProfile.programStartDate = Date()
        return child
    }

    private func buildFamilyUnitAndComplete(with prebuiltChild: ChildProfile? = nil) {
        var unit = FamilyUnit()
        unit.hasCompletedSetup = true
        unit.accountType = (path == .selfSetup) ? .selfUser : .caregiver
        unit.sharedData.currentSessionStage = sessionStage
        unit.sharedData.hasTherapist = hasTherapist

        // Caregiver profile
        var caregiver = CaregiverProfile()
        caregiver.displayName = caregiverName
        // tb-mvp2-022: relationship field removed from onboarding; defaults to .parent (may return for V2 therapist tier)
        unit.caregivers = [caregiver]

        // Child profile — use prebuilt (COPPA path) or build fresh (non-COPPA path)
        let child = prebuiltChild ?? buildChildProfile()
        unit.children = [child]

        // Persist family unit
        dataService.familyUnit = unit
        dataService.saveFamilyUnit()

        // Update legacy userProfile for backward compat with existing tab views
        var legacyProfile = dataService.userProfile
        legacyProfile.name = child.nickname
        legacyProfile.age  = child.userProfile.age
        legacyProfile.hasCompletedOnboarding = true
        legacyProfile.programStartDate = Date()
        dataService.updateProfile(legacyProfile)

        onComplete()
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 0 — Role Selection
// ─────────────────────────────────────────────────────────────────────────

struct FamilyRoleSelectionStep: View {
    @Binding var path: OnboardingPath
    let onSelected: () -> Void

    var body: some View {
        VStack(spacing: 32) {

            VStack(spacing: 12) {
                Text("👋")
                    .font(.system(size: 80))
                Text("Welcome to TicBuddy!")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Let's get set up.\nWho's here today?")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            VStack(spacing: 16) {
                RoleCard(
                    emoji: "👨‍👩‍👧",
                    title: "I'm a parent or caregiver",
                    subtitle: "Setting this up for my child or someone I support"
                ) {
                    path = .caregiver
                    onSelected()
                }

                RoleCard(
                    emoji: "🙋",
                    title: "I'm the one with tics",
                    subtitle: "Setting up my own account (ages 13+)"
                ) {
                    path = .selfSetup
                    onSelected()
                }
            }
            .padding(.horizontal, 24)

            Text("No accounts, no passwords — just your data, on your device.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct RoleCard: View {
    let emoji: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 38))
                    .frame(width: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
            .background(Color.white.opacity(0.18))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 1A — Caregiver: About You
// ─────────────────────────────────────────────────────────────────────────

struct FamilyCaregiverAboutYouStep: View {
    @Binding var name: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("🧑‍💼")
                    .font(.system(size: 72))
                Text("Nice to meet you!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("Tell us a little about yourself.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 20) {
                // Name only — relationship field removed (tb-mvp2-022)
                VStack(alignment: .leading, spacing: 8) {
                    Label("What's your name?", systemImage: "person.fill")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    TextField("Your first name…", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(18)
                        .foregroundColor(.white)
                        .focused($focused)
                        .onAppear { focused = true }
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 1B — Self: Nickname
// ─────────────────────────────────────────────────────────────────────────

struct FamilySelfNicknameStep: View {
    @Binding var nickname: String
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Text("👋 Hi! What should\nwe call you?")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("A nickname is fine — no last names needed.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                TextField("Type your name here…", text: $nickname)
                    .textFieldStyle(.plain)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .padding(18)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .focused($focused)
                    .onAppear { focused = true }
                    .padding(.horizontal, 30)

                Text("Your name is only stored on this device.\nIt's never sent anywhere.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.vertical, 20)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 2A — Caregiver: About Your Child
// ─────────────────────────────────────────────────────────────────────────

struct FamilyAboutChildStep: View {
    @Binding var nickname: String
    @Binding var ageGroup: AgeGroup
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("🧒")
                    .font(.system(size: 72))
                Text("Now, about your child.")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("We keep their info private\nand safe on your device.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 20) {
                // Nickname
                VStack(alignment: .leading, spacing: 8) {
                    Label("Their nickname (no last names)", systemImage: "person.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    TextField("e.g. Alex, Jordan, Sam…", text: $nickname)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(16)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(18)
                        .foregroundColor(.white)
                        .focused($focused)
                        .onAppear { focused = true }
                }

                // Age group
                VStack(alignment: .leading, spacing: 10) {
                    Label("How old are they?", systemImage: "birthday.cake.fill")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(AgeGroup.allCases, id: \.self) { group in
                            AgeGroupCard(group: group, isSelected: ageGroup == group) {
                                withAnimation(.spring(response: 0.3)) { ageGroup = group }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
        }
    }
}

private struct AgeGroupCard: View {
    let group: AgeGroup
    let isSelected: Bool
    let action: () -> Void

    private var emoji: String {
        switch group {
        case .veryYoung:  return "🌱"
        case .young:      return "🌿"
        case .olderChild: return "🌳"
        case .youngTeen:  return "🌟"
        case .teen:       return "⚡️"
        case .adult:      return "🌠"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 28))
                Text(group.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.white.opacity(0.28) : Color.white.opacity(0.12))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 2B — Self: Age Group
// ─────────────────────────────────────────────────────────────────────────

struct FamilySelfAgeGroupStep: View {
    @Binding var ageGroup: AgeGroup

    // Self-setup is 13+ only; .adult is now a real enum case so no workarounds needed
    private let validGroups: [AgeGroup] = [.youngTeen, .teen, .adult]

    var body: some View {
        // Nested ScrollView removed — parent FamilyOnboardingView already provides ScrollView.
        // Inner ScrollView caused gesture conflicts, making the 18+ (bottom) button untappable.
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("🎂")
                    .font(.system(size: 72))
                Text("How old are you?")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text("This shapes how TicBuddy talks to you.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)

            VStack(spacing: 12) {
                ForEach(validGroups, id: \.self) { group in
                    Button {
                        withAnimation(.spring(response: 0.3)) { ageGroup = group }
                    } label: {
                        HStack {
                            Text(group.displayName)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: ageGroup == group ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 26))
                                .foregroundColor(ageGroup == group ? .white : .white.opacity(0.4))
                        }
                        .padding(18)
                        .background(ageGroup == group ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(ageGroup == group ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 28)
        }
        .padding(.vertical)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 4 — Treatment Stage
// ─────────────────────────────────────────────────────────────────────────

struct FamilyTreatmentStageStep: View {
    @Binding var sessionStage: CBITSessionStage
    @Binding var hasTherapist: Bool

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 10) {
                Text("🗺️")
                    .font(.system(size: 72))
                Text("Where are you in treatment?")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("We'll pick the right starting point.\nYou can always adjust this later.")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            // Therapist toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Working with a CBIT therapist?")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("TicBuddy works great alongside therapy")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
                Toggle("", isOn: $hasTherapist)
                    .tint(.white)
                    .labelsHidden()
            }
            .padding(16)
            .background(Color.white.opacity(0.15))
            .cornerRadius(16)
            .padding(.horizontal, 28)

            // Session stage picker
            VStack(alignment: .leading, spacing: 10) {
                Text("Pick your session:")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 8) {
                        // Quick shortcuts
                        StageQuickOption(
                            emoji: "🌱",
                            label: "Just starting out",
                            sublabel: "Session 1 — best if this is brand new",
                            isSelected: sessionStage == .session1
                        ) { sessionStage = .session1 }

                        StageQuickOption(
                            emoji: "🔧",
                            label: "We've done some work",
                            sublabel: "Session 2–3 — have 1+ competing responses",
                            isSelected: sessionStage == .session2 || sessionStage == .session3
                        ) { sessionStage = .session2 }

                        StageQuickOption(
                            emoji: "💪",
                            label: "Getting more advanced",
                            sublabel: "Session 4–5 — working on multiple tics",
                            isSelected: sessionStage == .session4 || sessionStage == .session5
                        ) { sessionStage = .session4 }

                        StageQuickOption(
                            emoji: "🏆",
                            label: "Maintenance phase",
                            sublabel: "Session 6+ — practicing and maintaining",
                            isSelected: sessionStage.rawValue >= 6
                        ) { sessionStage = .session6 }
                    }
                    .padding(.horizontal, 28)
                }
            }
        }
    }
}

private struct StageQuickOption: View {
    let emoji: String
    let label: String
    let sublabel: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(emoji).font(.system(size: 30)).frame(width: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(sublabel)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            }
            .padding(14)
            .background(isSelected ? Color.white.opacity(0.25) : Color.white.opacity(0.12))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3), value: isSelected)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: Step 5 — All Set!
// ─────────────────────────────────────────────────────────────────────────

struct FamilyAllSetStep: View {
    let caregiverName: String
    let childNickname: String?  // nil = self-setup path
    let ageGroup: AgeGroup
    let deviceConfig: DeviceConfig
    let sessionStage: CBITSessionStage
    let path: String  // "caregiver" or "self"

    @State private var animateStar = false

    private var firstName: String {
        caregiverName.components(separatedBy: " ").first ?? caregiverName
    }

    private var childName: String {
        childNickname ?? caregiverName
    }

    var body: some View {
        VStack(spacing: 28) {
            // Hero
            Text("🎉")
                .font(.system(size: 96))
                .scaleEffect(animateStar ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: animateStar)
                .onAppear { animateStar = true }

            VStack(spacing: 8) {
                Text("You're all set\(firstName.isEmpty ? "" : ", \(firstName)")!")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                Text("Here's what we set up:")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 24)

            // Summary cards
            VStack(spacing: 12) {
                if path == "caregiver" {
                    SummaryRow(emoji: "🧒", label: "Child profile", value: "\(childName), \(ageGroup.displayName)")
                    SummaryRow(emoji: "📱", label: "Device setup", value: deviceConfig.rawValue)
                } else {
                    SummaryRow(emoji: "🙋", label: "Your profile", value: "\(childName), \(ageGroup.displayName)")
                }
                SummaryRow(emoji: "🗺️", label: "Starting point", value: sessionStage.shortLabel)
            }
            .padding(.horizontal, 28)

            // Warm close message
            Text(path == "caregiver"
                ? "TicBuddy will guide you and \(childName) through CBIT step by step. You've got this. 💪"
                : "TicBuddy is here for you every step of the way. You've got this. 💪"
            )
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.88))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
    }
}

private struct SummaryRow: View {
    let emoji: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Text(emoji).font(.system(size: 24)).frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.15))
        .cornerRadius(14)
    }
}

// MARK: - Preview

#Preview("Role Selection") {
    FamilyOnboardingView { }
        .environmentObject(TicDataService.shared)
}
