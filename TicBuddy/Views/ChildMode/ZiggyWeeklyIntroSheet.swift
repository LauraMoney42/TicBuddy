// TicBuddy — ZiggyWeeklyIntroSheet.swift
// Auto-shown on first child-mode open each week (tb-mvp2-026).
//
// Presented by ChildModeRouter on appear when WeeklySessionService.shouldAutoLaunch() is true.
// Mimics a CBIT therapist opening the weekly session:
//   1. Ziggy greets the child by name
//   2. Brief recap of last session (empty for Session 1)
//   3. This week's focus
//   4. Full Ziggy message displayed word-by-word (typewriter effect)
//
// On dismiss: WeeklySessionService.markLaunched() is called so it won't re-show this week.

import SwiftUI

// MARK: - Ziggy Weekly Intro Sheet

struct ZiggyWeeklyIntroSheet: View {
    let intro: WeeklySessionIntro
    let onDismiss: () -> Void

    @State private var displayedText = ""
    @State private var typingDone = false
    @State private var showContent = false

    private let typingInterval: Double = 0.025 // seconds per character

    var body: some View {
        ZStack {
            // Background gradient matches child mode palette
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 32)

                // ── Ziggy avatar ─────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Text("😉")
                        .font(.system(size: 56))
                }
                .scaleEffect(showContent ? 1.0 : 0.7)
                .opacity(showContent ? 1.0 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: showContent)

                Spacer(minLength: 20)

                // ── Greeting ─────────────────────────────────────────────
                Text(intro.greeting)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 10)
                    .animation(.easeOut(duration: 0.4).delay(0.25), value: showContent)

                Spacer(minLength: 16)

                // ── Recap badge (hidden for Session 1) ───────────────────
                if !intro.lastWeekRecap.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        Text(intro.lastWeekRecap)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(12)
                    .padding(.horizontal, 28)
                    .opacity(showContent ? 1 : 0)
                    .animation(.easeOut(duration: 0.4).delay(0.4), value: showContent)

                    Spacer(minLength: 12)
                }

                // ── This week focus badge ────────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(hex: "FEE140"))
                    Text(intro.thisWeekFocus)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.18))
                .cornerRadius(12)
                .padding(.horizontal, 28)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.5), value: showContent)

                Spacer(minLength: 20)

                // ── Ziggy speech bubble (typewriter) ─────────────────────
                ScrollView {
                    HStack(alignment: .top, spacing: 12) {
                        Text("😉")
                            .font(.system(size: 24))
                            .padding(.top, 2)

                        (Text(displayedText)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            + Text(typingDone ? "" : "▌")
                                .foregroundColor(.white.opacity(0.7)))
                            .fixedSize(horizontal: false, vertical: true)
                            .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)
                }
                .frame(maxHeight: 240)
                .opacity(showContent ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.6), value: showContent)

                Spacer(minLength: 24)

                // ── Let's go button ──────────────────────────────────────
                if typingDone {
                    Button(action: onDismiss) {
                        Text("Let's go! 🚀")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "764BA2"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .cornerRadius(28)
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // "Skip" — tap to jump to end
                    Button {
                        displayedText = intro.ziggyMessage
                        typingDone = true
                    } label: {
                        Text("Skip")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 40)
            }
        }
        .animation(.spring(response: 0.35), value: typingDone)
        .onAppear {
            showContent = true
            // Start typewriter after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                startTypewriter()
            }
        }
    }

    // MARK: - Typewriter

    private func startTypewriter() {
        let fullText = intro.ziggyMessage
        var index = fullText.startIndex
        displayedText = ""

        func typeNext() {
            guard index < fullText.endIndex else {
                withAnimation { typingDone = true }
                return
            }
            displayedText.append(fullText[index])
            index = fullText.index(after: index)
            DispatchQueue.main.asyncAfter(deadline: .now() + typingInterval) {
                typeNext()
            }
        }
        typeNext()
    }
}

// MARK: - Preview

#Preview {
    ZiggyWeeklyIntroSheet(
        intro: WeeklySessionService.shared.sessionIntro(stage: .session2, childName: "Alex")
    ) { }
}
