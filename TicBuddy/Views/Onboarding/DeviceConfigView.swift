// TicBuddy — DeviceConfigView.swift
// Caregiver selects how their family will use TicBuddy during setup.
//
// Three modes (from DeviceConfig enum in FamilyUnit.swift):
//   separateDevices — child has own device, linked by code (V2 QR flow)
//   singleDevice    — all profiles share one device, PIN-switched
//   caregiverOnly   — caregiver-managed only, child too young to use solo
//
// Used by: NewFamilyOnboardingView (tb-mvp2-003), SettingsView family section

import SwiftUI

// MARK: - Device Config Selection View

/// Embeddable step: caregiver picks their device setup for the new child profile.
/// Pass a `DeviceConfig` binding; parent drives navigation on confirmation.
struct DeviceConfigSelectionView: View {
    let childName: String
    @Binding var selectedConfig: DeviceConfig

    var body: some View {
        VStack(spacing: 24) {

            // ── Header ─────────────────────────────────────────────────────
            VStack(spacing: 10) {
                Text("📱")
                    .font(.system(size: 64))
                    .accessibilityHidden(true)

                Text("How will \(childName.isEmpty ? "your child" : childName) use TicBuddy?")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("You can change this later in Settings.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            }
            .padding(.horizontal, 24)

            // ── Option Cards ───────────────────────────────────────────────
            VStack(spacing: 12) {
                ForEach(DeviceConfig.allCases, id: \.self) { config in
                    DeviceConfigCard(
                        config: config,
                        isSelected: selectedConfig == config
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedConfig = config
                        }
                    }
                }
            }
            .padding(.horizontal, 24)

            // ── Setup Note (context-sensitive) ─────────────────────────────
            DeviceConfigSetupNote(config: selectedConfig)
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .id(selectedConfig) // re-animate when selection changes
        }
    }
}

// MARK: - Config Option Card

private struct DeviceConfigCard: View {
    let config: DeviceConfig
    let isSelected: Bool
    let action: () -> Void

    private var icon: String {
        switch config {
        case .separateDevices: return "iphone.and.iphone"
        case .singleDevice:    return "iphone"
        case .caregiverOnly:   return "person.fill"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {

                // Icon circle
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(hex: "764BA2") : Color.white.opacity(0.18))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }

                // Title + description
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.rawValue)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(config.description)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.4))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected ? Color.white.opacity(0.22) : Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Setup Note (per config)

/// Shown below the selection cards — explains what will happen next for the chosen config.
private struct DeviceConfigSetupNote: View {
    let config: DeviceConfig

    private var noteEmoji: String {
        switch config {
        case .separateDevices: return "🔗"
        case .singleDevice:    return "🔒"
        case .caregiverOnly:   return "✅"
        }
    }

    private var noteText: String {
        switch config {
        case .separateDevices:
            return "We'll give you a setup code to enter on their device. Their app will sync to your family account."
        case .singleDevice:
            return "You'll switch between profiles from the home screen. A PIN keeps each profile private."
        case .caregiverOnly:
            return "You're all set! You'll manage everything from your caregiver view. You can add child access anytime."
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(noteEmoji)
                .font(.system(size: 22))
                .accessibilityHidden(true)

            Text(noteText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.13))
        .cornerRadius(14)
    }
}

// MARK: - Device Config Detail View (post-selection, full-screen instructions)

/// Full-screen view shown after config is confirmed — gives next-step instructions per mode.
/// Parent dismisses or navigates away when the user taps the action button.
struct DeviceConfigDetailView: View {
    let config: DeviceConfig
    let childName: String
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Hero
                    Text(heroEmoji)
                        .font(.system(size: 80))
                        .padding(.top, 32)

                    Text(heroTitle)
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Step cards
                    VStack(spacing: 14) {
                        ForEach(Array(setupSteps.enumerated()), id: \.offset) { index, step in
                            SetupStepCard(number: index + 1, emoji: step.emoji, text: step.text)
                        }
                    }
                    .padding(.horizontal, 24)

                    // Continue button
                    Button(action: onContinue) {
                        Text(continueLabel)
                            .font(.headline.bold())
                            .foregroundColor(Color(hex: "764BA2"))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(28)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
    }

    // MARK: - Per-Config Content

    private var heroEmoji: String {
        switch config {
        case .separateDevices: return "📲"
        case .singleDevice:    return "🔒"
        case .caregiverOnly:   return "🌟"
        }
    }

    private var heroTitle: String {
        let name = childName.isEmpty ? "Your Child" : childName
        switch config {
        case .separateDevices: return "Set Up \(name)'s Device"
        case .singleDevice:    return "Set Up Profile Switching"
        case .caregiverOnly:   return "You're All Set!"
        }
    }

    private var continueLabel: String {
        switch config {
        case .caregiverOnly: return "Go to Dashboard 🎉"
        default:             return "Got It! Let's Go 🚀"
        }
    }

    private struct Step { let emoji: String; let text: String }

    private var setupSteps: [Step] {
        switch config {
        case .separateDevices:
            return [
                Step(emoji: "📋", text: "After setup, you'll get a 6-digit family code."),
                Step(emoji: "📱", text: "On \(childName.isEmpty ? "their" : childName + "'s") device, download TicBuddy and tap \"Join Family.\""),
                Step(emoji: "🔑", text: "Enter the code — their profile will sync automatically."),
                Step(emoji: "✅", text: "Each device stays in sync. Progress, rewards, and sessions update for both of you.")
            ]
        case .singleDevice:
            return [
                Step(emoji: "🔒", text: "You'll set a caregiver PIN to keep your dashboard private."),
                Step(emoji: "👤", text: "\(childName.isEmpty ? "Your child" : childName) will have their own profile with a separate PIN (age 7+)."),
                Step(emoji: "🔄", text: "Switch profiles from the home screen anytime — tap the profile icon in the top corner."),
                Step(emoji: "🔐", text: "Ages 10+ can set their own private PIN that only they know.")
            ]
        case .caregiverOnly:
            return [
                Step(emoji: "📊", text: "You manage everything from your caregiver dashboard."),
                Step(emoji: "👁️", text: "Log tics, review progress, and run CBIT sessions on their behalf."),
                Step(emoji: "🚀", text: "When they're ready to use the app themselves, add child access in Settings > Family."),
                Step(emoji: "💡", text: "Great for ages 4–6, or any time you want full oversight.")
            ]
        }
    }
}

// MARK: - Setup Step Card

private struct SetupStepCard: View {
    let number: Int
    let emoji: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Number badge
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 36, height: 36)
                Text("\(number)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Emoji + text
            HStack(alignment: .top, spacing: 10) {
                Text(emoji)
                    .font(.system(size: 20))
                    .accessibilityHidden(true)

                Text(text)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(14)
        .background(Color.white.opacity(0.12))
        .cornerRadius(14)
    }
}

// MARK: - Preview

#Preview("Selection") {
    ZStack {
        LinearGradient(
            colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
            DeviceConfigSelectionView(
                childName: "Alex",
                selectedConfig: .constant(.singleDevice)
            )
            .padding(.vertical, 32)
        }
    }
}

#Preview("Detail — Separate Devices") {
    DeviceConfigDetailView(
        config: .separateDevices,
        childName: "Alex"
    ) { }
}

#Preview("Detail — Caregiver Only") {
    DeviceConfigDetailView(
        config: .caregiverOnly,
        childName: ""
    ) { }
}
