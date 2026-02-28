// TicBuddy — OnboardingView.swift
// 6-step onboarding: welcome → name/age → Tourette's → CBIT → neuroplasticity → tic setup + awareness
// Large text, colorful, encouraging. Designed for ages 8–18.

import SwiftUI

// MARK: - Total onboarding steps
private let kTotalSteps = 6

struct OnboardingView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var currentStep = 0
    @State private var profile = UserProfile()
    @State private var showKindnessScreen = true  // First screen: kindness message

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            // MARK: — Kindness welcome screen (shown before step 1)
            if showKindnessScreen {
                WelcomeKindnessView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showKindnessScreen = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }

            // Dynamic gradient shifts subtly per step
            LinearGradient(
                colors: gradientColors(for: currentStep),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentStep)

            VStack(spacing: 0) {
                // Progress bar + step label
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        ForEach(0..<kTotalSteps, id: \.self) { i in
                            Capsule()
                                .fill(i <= currentStep ? Color.white : Color.white.opacity(0.3))
                                .frame(height: i == currentStep ? 6 : 4)
                                .animation(.spring(response: 0.4), value: currentStep)
                        }
                    }
                    .padding(.horizontal, 30)

                    Text("Step \(currentStep + 1) of \(kTotalSteps)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                }
                .padding(.top, 24)

                Spacer()

                // Step content
                Group {
                    switch currentStep {
                    case 0: WelcomeStepView(profile: $profile)
                    case 1: NameAgeStepView(profile: $profile)
                    case 2: TourettesExplainView()
                    case 3: CBITExplainView()
                    case 4: NeuroplasticityExplainView()
                    case 5: TicSetupView(profile: $profile)
                    default: EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .id(currentStep)

                Spacer()

                // Navigation
                HStack {
                    if currentStep > 0 {
                        Button(action: { withAnimation(.spring()) { currentStep -= 1 } }) {
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
                            Text(nextButtonLabel)
                                .font(.headline.bold())
                            if currentStep < kTotalSteps - 1 {
                                Image(systemName: "arrow.right")
                                    .font(.subheadline.bold())
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
                .padding(.horizontal, 30)
                .padding(.bottom, 44)
            }
        }
    }

    // MARK: - Helpers

    private var nextButtonLabel: String {
        switch currentStep {
        case 0:              return "Let's Start! 🎉"
        case kTotalSteps-1:  return "Let's Go! 🚀"
        default:             return "Next"
        }
    }

    private var isNextDisabled: Bool {
        if currentStep == 1 { return profile.name.trimmingCharacters(in: .whitespaces).isEmpty }
        if currentStep == 5 { return profile.primaryTics.isEmpty }
        return false
    }

    private func handleNext() {
        if currentStep < kTotalSteps - 1 {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { currentStep += 1 }
        } else {
            profile.hasCompletedOnboarding = true
            profile.programStartDate = Date()
            dataService.updateProfile(profile)
            onComplete()
        }
    }

    private func gradientColors(for step: Int) -> [Color] {
        switch step {
        case 0: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        case 1: return [Color(hex: "F093FB"), Color(hex: "764BA2")]
        case 2: return [Color(hex: "4FACFE"), Color(hex: "00F2FE")]
        case 3: return [Color(hex: "43E97B"), Color(hex: "38F9D7")]
        case 4: return [Color(hex: "FA709A"), Color(hex: "FEE140")]
        case 5: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        default: return [Color(hex: "667EEA"), Color(hex: "764BA2")]
        }
    }
}

// MARK: - Step 0: Welcome

struct WelcomeStepView: View {
    @Binding var profile: UserProfile
    @State private var animatePulse = false

    var body: some View {
        VStack(spacing: 28) {
            // Animated hero emoji
            Text("🧠✨")
                .font(.system(size: 96))
                .scaleEffect(animatePulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: animatePulse)
                .onAppear { animatePulse = true }

            VStack(spacing: 10) {
                Text("Welcome to")
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                Text("TicBuddy!")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .multilineTextAlignment(.center)

            Text("Your personal tic-fighting sidekick 🦸")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.88))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 14) {
                FeatureRow(emoji: "💬", text: "Chat with your AI tic coach")
                FeatureRow(emoji: "📅", text: "Track your tics on a calendar")
                FeatureRow(emoji: "🏆", text: "Build real tic-fighting superpowers")
                FeatureRow(emoji: "🧠", text: "Learn how YOUR brain works")
            }
            .padding(20)
            .background(Color.white.opacity(0.15))
            .cornerRadius(20)
            .padding(.horizontal, 24)
        }
        .padding(.horizontal, 24)
    }
}

struct FeatureRow: View {
    let emoji: String
    let text: String
    var body: some View {
        HStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 26))
                .frame(width: 36)
            Text(text)
                .foregroundColor(.white)
                .font(.system(size: 17, weight: .medium, design: .rounded))
        }
    }
}

// MARK: - Step 1: Name & Age

struct NameAgeStepView: View {
    @Binding var profile: UserProfile
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 30) {
            Text("👋")
                .font(.system(size: 80))

            Text("Nice to meet you!")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 10) {
                Text("What's your name?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                TextField("Type your name here…", text: $profile.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .padding(16)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(18)
                    .foregroundColor(.white)
                    .focused($nameFocused)
                    .onAppear { nameFocused = true }
            }
            .padding(.horizontal, 30)

            VStack(spacing: 12) {
                Text("How old are you?")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))

                // Primary age chips (most common for Tourette's)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach([8, 9, 10, 11, 12, 13, 14, 15], id: \.self) { age in
                        Button(action: { profile.age = age }) {
                            Text("\(age)")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(profile.age == age ? Color(hex: "764BA2") : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(profile.age == age ? Color.white : Color.white.opacity(0.2))
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Manual stepper for ages outside the grid
                HStack {
                    Text("Other age:")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.subheadline)
                    Stepper("\(profile.age)", value: $profile.age, in: 4...99)
                        .foregroundColor(.white)
                        .labelsHidden()
                    Text("\(profile.age)")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(width: 36)
                }
                .padding(.horizontal, 30)
            }
        }
    }
}

// MARK: - Step 2: Tourette's Explained

struct TourettesExplainView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("🧠")
                    .font(.system(size: 70))

                Text("What is\nTourette's?")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                ExplainCard(
                    emoji: "⚡️",
                    title: "Brain Signals",
                    bodyText: "Tourette's means your brain sometimes sends signals your body didn't ask for. These signals cause tics — movements or sounds you don't fully control."
                )

                ExplainCard(
                    emoji: "🤷",
                    title: "Not Your Fault!",
                    bodyText: "Tics are NOT your fault. You didn't choose to have them, and having them doesn't mean anything is wrong with you. Lots of amazing people have Tourette's — athletes, artists, musicians, and scientists!"
                )

                ExplainCard(
                    emoji: "🌊",
                    title: "Tics Come and Go",
                    bodyText: "Tics naturally get stronger and weaker over time — that's called 'waxing and waning.' A bad tic week doesn't mean you're going backwards. It's just how TS works!"
                )

                ExplainCard(
                    emoji: "⚡️",
                    title: "The Urge",
                    bodyText: "Before most tics, there's a feeling — like a tickle, pressure, or buildup. It's called the premonitory urge. Learning to notice it is your very first superpower! (Some people feel it more than others — both are totally normal.)"
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 3: CBIT Explained

struct CBITExplainView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("🦸")
                    .font(.system(size: 70))

                Text("Your Training\nProgram: CBIT")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                ExplainCard(
                    emoji: "🎯",
                    title: "What is CBIT?",
                    bodyText: "CBIT stands for Comprehensive Behavioral Intervention for Tics. It's a proven program that helps people manage their tics by training their brains!"
                )

                ExplainCard(
                    emoji: "🕵️",
                    title: "Week 1: Detective Mode",
                    bodyText: "First, we practice noticing tics AS they happen — and the urge BEFORE they happen. You're a tic detective, gathering clues! Don't try to stop them yet. Just notice."
                )

                ExplainCard(
                    emoji: "💪",
                    title: "Week 3+: Power Moves",
                    bodyText: "Once you're good at noticing, you learn a 'Power Move' — a special action your body does INSTEAD of the tic. The urge gets satisfied a different way. Your brain builds a new path!"
                )

                ExplainCard(
                    emoji: "🏆",
                    title: "It Really Works!",
                    bodyText: "Research (JAMA 2010) shows CBIT helps 8 out of 10 people reduce their tics — and the results last! The more consistently you practice, the stronger the effect."
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 4: Neuroplasticity

struct NeuroplasticityExplainView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("🌱")
                .font(.system(size: 70))

            Text("Your Brain\nCan Change!")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            ExplainCard(
                emoji: "🎨",
                title: "Play-Doh Brain",
                bodyText: "Your brain is like Play-Doh — it physically changes shape when you practice! Scientists call this neuroplasticity. Every time you catch a tic, you're literally reshaping your brain."
            )

            ExplainCard(
                emoji: "🛤️",
                title: "Build New Trails",
                bodyText: "Tics are well-worn trails in your brain's forest. CBIT helps you build a NEW trail right next to the old one. The more you practice, the stronger your new trail gets — until it feels automatic!"
            )

            ExplainCard(
                emoji: "⏱️",
                title: "8–12 Weeks to Rewire",
                bodyText: "New brain pathways take 8–12 weeks of practice to feel natural. Some days tics will be worse — that's just TS waxing and waning, not you failing. Every single practice counts!"
            )
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Step 5: Tic Setup + Awareness Scale

struct TicSetupView: View {
    @Binding var profile: UserProfile
    @State private var selectedMotor: Set<TicMotorType> = []
    @State private var selectedVocal: Set<TicVocalType> = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                Text("🎯")
                    .font(.system(size: 64))

                Text("What tics do you have?")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Tap ALL that apply — we'll track these!")
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 16, weight: .medium, design: .rounded))

                // Motor tics
                SectionHeader(title: "Motor Tics", subtitle: "Body movements")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TicMotorType.allCases) { type in
                        TicChip(
                            emoji: type.emoji,
                            label: type.rawValue,
                            isSelected: selectedMotor.contains(type)
                        ) {
                            if selectedMotor.contains(type) { selectedMotor.remove(type) }
                            else { selectedMotor.insert(type) }
                            updateProfile()
                        }
                    }
                }

                // Vocal tics
                SectionHeader(title: "Vocal Tics", subtitle: "Sounds or words")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(TicVocalType.allCases) { type in
                        TicChip(
                            emoji: type.emoji,
                            label: type.rawValue,
                            isSelected: selectedVocal.contains(type)
                        ) {
                            if selectedVocal.contains(type) { selectedVocal.remove(type) }
                            else { selectedVocal.insert(type) }
                            updateProfile()
                        }
                    }
                }

                if selectedMotor.isEmpty && selectedVocal.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap")
                        Text("Pick at least one tic to continue")
                    }
                    .font(.footnote.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.vertical, 4)
                }

                // ── Awareness Scale ──────────────────────────────────────────
                Divider().overlay(Color.white.opacity(0.3))

                TicAwarenessScaleView(level: $profile.ticAwarenessLevel)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func updateProfile() {
        profile.primaryTics = selectedMotor.map { $0.rawValue } + selectedVocal.map { $0.rawValue }
        profile.primaryTicCategories = (selectedMotor.isEmpty ? [] : [TicCategory.motor]) +
                                       (selectedVocal.isEmpty ? [] : [TicCategory.vocal])
    }
}

// MARK: - Tic Awareness Scale (1–5)

struct TicAwarenessScaleView: View {
    @Binding var level: Int

    private let labels = [
        (1, "😶", "Almost never"),
        (2, "🤔", "Sometimes"),
        (3, "👀", "Often"),
        (4, "🔍", "Most of the time"),
        (5, "🦸", "Almost always")
    ]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("How often do you notice\nyour tics as they happen?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("There's NO wrong answer — this helps us start at the right spot! 🎯")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // 5-button scale
            HStack(spacing: 8) {
                ForEach(labels, id: \.0) { value, emoji, _ in
                    Button(action: { withAnimation(.spring(response: 0.3)) { level = value } }) {
                        VStack(spacing: 4) {
                            Text(emoji)
                                .font(.system(size: level == value ? 32 : 26))
                            Text("\(value)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(level == value ? Color(hex: "764BA2") : .white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(level == value ? Color.white : Color.white.opacity(0.18))
                        .cornerRadius(14)
                        .scaleEffect(level == value ? 1.08 : 1.0)
                    }
                }
            }

            // Current selection label
            if let match = labels.first(where: { $0.0 == level }) {
                Text(match.2)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(20)
                    .transition(.opacity.combined(with: .scale))
                    .id(level)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Section Header helper

struct SectionHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Reusable Components

struct ExplainCard: View {
    let emoji: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(emoji)
                .font(.title)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text(bodyText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.15))
        .cornerRadius(16)
    }
}

struct TicChip: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(label)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.white : Color.white.opacity(0.15))
            .foregroundColor(isSelected ? Color(hex: "764BA2") : .white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
        }
    }
}

// Color(hex:) is defined in Extensions.swift
