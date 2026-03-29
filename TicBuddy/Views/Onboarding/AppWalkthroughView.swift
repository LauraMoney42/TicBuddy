// TicBuddy — AppWalkthroughView.swift
// tb-mvp2-065: First-time guided app walkthrough overlay.
//
// Shows once after onboarding completes, overlaid on top of the main TabView.
// Walks the user through all 5 nav tabs, the Quick Log button, and the Lesson 1 CTA.
// Completion is persisted in AppStorage — replay via Settings (future).
//
// Integration: ZStack in TicBuddyApp wraps this over FamilyModeRouter / MainTabView.
// Gated by AppStorage("ticbuddy_walkthrough_complete").

import SwiftUI

// MARK: - Step Model

private struct WalkthroughStep {
    enum Highlight {
        case none            // Centered card, no spotlight
        case tab(Int)        // Index 0-4 in the bottom tab bar
    }
    let icon: String
    let title: String
    let message: String
    let highlight: Highlight
    var isLesson1Step: Bool = false
}

// MARK: - Step Content

private let walkthroughSteps: [WalkthroughStep] = [
    .init(
        icon: "👋",
        title: "Welcome to TicBuddy!",
        message: "Let me give you a 30-second tour so you know where everything lives.",
        highlight: .none
    ),
    .init(
        icon: "🏠",
        title: "Home",
        message: "Your daily dashboard — tic stats, CBIT phase progress, and streak all in one place.",
        highlight: .tab(0)
    ),
    .init(
        icon: "😉",
        title: "Ziggy — Your AI Coach",
        message: "Chat with Ziggy anytime. Ask about CBIT, report a tic, or just talk through how you're feeling.",
        highlight: .tab(1)
    ),
    .init(
        icon: "📅",
        title: "Calendar",
        message: "Your full tic history day-by-day. Tap any date to see or add entries.",
        highlight: .tab(2)
    ),
    .init(
        icon: "📊",
        title: "Progress",
        message: "Charts showing your tic patterns over time. Great for spotting what helps — and what doesn't.",
        highlight: .tab(3)
    ),
    .init(
        icon: "⚙️",
        title: "Settings",
        message: "Update your profile, pick Ziggy's voice, set reminders, and adjust privacy options.",
        highlight: .tab(4)
    ),
    .init(
        icon: "➕",
        title: "Log a Tic",
        // tb-mvp2-127: Added reward points mention so users know logging earns them something.
        message: "On the Home screen, tap \"Log a Tic Now\" whenever you notice a tic — even tiny ones. The more you log, the better Ziggy can help you. 🏆 Catching an urge earns 1 pt — using a competing response earns 2. Every 10 points = a new reward tier!",
        highlight: .none
    ),
    // tb-mvp2-123/user: "You're all set!" step removed — Lesson 1 step is now the
    // final walkthrough card. "View Lesson 1 Now" is the only exit CTA.
    .init(
        icon: "📚",
        title: "Start with Lesson 1",
        message: "Before diving in, watch Lesson 1 — 7 quick slides explaining what CBIT is and why it works. Only 2 minutes. You can replay it anytime from the Home screen.",
        highlight: .none,
        isLesson1Step: true
    ),
]

// MARK: - AppWalkthroughView

struct AppWalkthroughView: View {
    /// Called when the user taps "View Lesson 1" on the lesson callout step.
    var onLesson1: (() -> Void)? = nil

    @AppStorage("ticbuddy_walkthrough_complete") private var complete = false
    @State private var stepIndex = 0
    @State private var pulse = false

    private var current: WalkthroughStep { walkthroughSteps[stepIndex] }
    private var isFirst: Bool { stepIndex == 0 }
    private var isLast:  Bool { stepIndex == walkthroughSteps.count - 1 }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Dim ──────────────────────────────────────────────────────
                Color.black.opacity(0.65)
                    .ignoresSafeArea()

                // ── Tooltip card ──────────────────────────────────────────────
                tooltipLayout(geo: geo)
            }
        }
        .ignoresSafeArea()
        .transition(.opacity)
        .onAppear {
            // tb-mvp2-105: Pre-warm Session 1 slide 0 + 1 TTS audio as soon as the
            // walkthrough appears. The user steps through ~9 cards before reaching
            // the "View Lesson 1" CTA — that's 15–30s of buffer time, more than enough
            // for the audio to land in cache. By the time they tap, the blocking await
            // in TicBuddyApp resolves instantly (cache hit, ~0ms) instead of waiting
            // for a live fetch. Caregiver profile used — walkthrough is always shown in
            // caregiver/self-user context.
            if let lesson = CBITLessonService.lesson(for: .session1) {
                let slides = lesson.slides
                // tb-mvp2-129: Pre-warm ALL slides (not just 0+1) so every slide —
                // including the long "What If I Can't Feel It Yet?" — is cached before
                // the user ever taps into the lesson. The walkthrough takes 30+ seconds,
                // giving plenty of buffer for sequential fetches (~1-2s each × 10 slides).
                Task {
                    for (index, slide) in slides.enumerated() {
                        await ZiggyTTSService.shared.prefetchLessonSlide(
                            text: slide.spokenText,
                            voiceProfile: .caregiver,
                            slideIndex: index
                        )
                    }
                }
            }
        }
        // Reset pulse when step changes so .onAppear on the new ring fires cleanly
        .onChange(of: stepIndex) { _ in pulse = false }
    }

    // MARK: - Tooltip Layout

    @ViewBuilder
    private func tooltipLayout(geo: GeometryProxy) -> some View {
        if case .tab(_) = current.highlight {
            // Card floats above the tab bar
            VStack(spacing: 0) {
                Spacer()
                card(geo: geo)
                    .padding(.horizontal, 20)
                downArrow
                // Spacer pushes card up above tab bar
                Spacer()
                    .frame(height: geo.safeAreaInsets.bottom + 49 + 12)
            }
        } else {
            // Centered card
            VStack {
                Spacer()
                card(geo: geo)
                    .padding(.horizontal, 24)
                Spacer()
            }
        }
    }

    // MARK: - Card

    private func card(geo: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {

            // ── Header ───────────────────────────────────────────────────────
            HStack(spacing: 10) {
                Text(current.icon)
                    .font(.system(size: 28))
                Text(current.title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
            }

            // ── Body ─────────────────────────────────────────────────────────
            Text(current.message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)

            // ── Lesson 1 CTA ─────────────────────────────────────────────────
            if current.isLesson1Step {
                Button {
                    onLesson1?()
                    // tb-mvp2-119: close the overlay when user taps "View Lesson 1 Now"
                    finish()
                } label: {
                    Label("View Lesson 1 Now", systemImage: "play.circle.fill")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                }
                .padding(.top, 2)
            }

            // ── Navigation row ────────────────────────────────────────────────
            HStack(alignment: .center, spacing: 8) {

                // Step dots
                HStack(spacing: 5) {
                    ForEach(0 ..< walkthroughSteps.count, id: \.self) { i in
                        Capsule()
                            .fill(
                                i == stepIndex
                                    ? Color(hex: "667EEA")
                                    : Color.white.opacity(0.25)
                            )
                            .frame(width: i == stepIndex ? 14 : 6, height: 6)
                            .animation(.easeInOut(duration: 0.2), value: stepIndex)
                    }
                }

                Spacer()

                if !isFirst {
                    Button("← Back") { retreat() }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.50))
                }

                // tb-mvp2-119: hide Next on Lesson 1 step — "View Lesson 1 Now" is the only CTA
                if !current.isLesson1Step {
                Button {
                    if isLast { finish() } else { advance() }
                } label: {
                    Text(isLast ? "Let's Go! 🚀" : "Next  →")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(22)
                }
                } // end if !current.isLesson1Step
            }
            .padding(.top, 2)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "12162A").opacity(0.97))
                .shadow(color: .black.opacity(0.5), radius: 24, y: 8)
        )
    }

    // MARK: - Arrow (points toward tab bar)

    private var downArrow: some View {
        WalkthroughTriangle()
            .fill(Color(hex: "12162A").opacity(0.97))
            .frame(width: 22, height: 11)
            .rotationEffect(.degrees(180)) // Point downward
            .padding(.top, -1)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Navigation helpers

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex += 1 }
    }

    private func retreat() {
        withAnimation(.easeInOut(duration: 0.3)) { stepIndex -= 1 }
    }

    private func finish() {
        withAnimation(.easeOut(duration: 0.3)) { complete = true }
    }
}

// MARK: - Triangle Shape (tooltip arrow)

private struct WalkthroughTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        AppWalkthroughView()
    }
}
