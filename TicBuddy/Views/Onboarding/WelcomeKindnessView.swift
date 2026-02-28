// TicBuddy — WelcomeKindnessView.swift
// First screen of onboarding: a message of kindness and acceptance.
// This app helps redirect bothersome tics — not change who you are.
// Tap anywhere to continue.

import SwiftUI

struct WelcomeKindnessView: View {
    let onContinue: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            // Teal gradient — wider color range to match other onboarding pages
            LinearGradient(
                colors: [Color(hex: "00D4E8"), Color(hex: "006E8C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // App icon hero — loaded via UIKit so AppIcon asset is accessible at runtime
                Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                    .scaleEffect(appeared ? 1.0 : 0.5)
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: appeared)

                // Kindness message
                VStack(spacing: 20) {
                    Text("Hey there! 👋")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .opacity(appeared ? 1.0 : 0)
                        .offset(y: appeared ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.25), value: appeared)

                    VStack(spacing: 14) {
                        KindnessLine(
                            text: "We're so glad you're here.",
                            delay: 0.35,
                            appeared: appeared
                        )
                        KindnessLine(
                            text: "You are perfect just the way you are. 🌟",
                            delay: 0.45,
                            appeared: appeared
                        )
                        KindnessLine(
                            text: "Lots of amazing people have Tourette's — and so do you.",
                            delay: 0.55,
                            appeared: appeared
                        )
                        KindnessLine(
                            text: "But if some tics are bothersome or hurt, we can work on those together.",
                            delay: 0.65,
                            appeared: appeared
                        )
                        KindnessLine(
                            text: "Only if YOU want to.",
                            delay: 0.75,
                            appeared: appeared,
                            weight: .heavy
                        )
                        KindnessLine(
                            text: "This is YOUR journey. 💙",
                            delay: 0.85,
                            appeared: appeared,
                            weight: .heavy
                        )
                    }
                    .padding(.horizontal, 28)
                }

                Spacer()

                // Tap to continue hint
                Text("Tap anywhere to continue")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
                    .opacity(appeared ? 1.0 : 0)
                    .animation(.easeIn(duration: 0.4).delay(1.1), value: appeared)
                    .padding(.bottom, 48)
            }
        }
        .contentShape(Rectangle()) // Makes entire screen tappable
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.4)) {
                onContinue()
            }
        }
        .onAppear {
            appeared = true
        }
    }
}

// MARK: - Animated text line

private struct KindnessLine: View {
    let text: String
    let delay: Double
    let appeared: Bool
    var weight: Font.Weight = .semibold

    var body: some View {
        Text(text)
            .font(.system(size: 19, weight: weight, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .opacity(appeared ? 1.0 : 0)
            .offset(y: appeared ? 0 : 12)
            .animation(.easeOut(duration: 0.45).delay(delay), value: appeared)
    }
}
