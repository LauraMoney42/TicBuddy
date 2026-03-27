// TicBuddy — LessonSlideView.swift
// Slide-based CBIT lesson presenter (tb-mvp2-059).
// Ziggy TTS reads each slide aloud via OpenAI Nova (or AVSpeechSynthesizer
// fallback). On completion, onFinished() is called to launch Ziggy chat for
// Q&A + competing response practice.

import SwiftUI

// MARK: - LessonSlideView

struct LessonSlideView: View {

    let lesson: CBITLesson
    let voiceProfile: ZiggyVoiceProfile
    /// tb-mvp2-080: Label for the final-slide CTA. Session 1 passes "Start Tic Assessment →"
    /// (routes to intake) or "Continue →" (replay, hierarchy already filled).
    /// tb-mvp2-094: Default updated from "Chat with Ziggy" — no longer a valid CTA for Session 1.
    var finalCTALabel: String = "Start Tic Assessment →"
    /// tb-mvp2-136: When set, the assessment CTA fires on the slide with this title rather than
    /// the last slide. Allows "What's Next" to be the final slide (dismiss/done) while
    /// "Let's Map Your Tics" keeps the "Start Tic Assessment →" action.
    /// nil = legacy behaviour (CTA fires on last slide).
    var ctaSlideTitle: String? = nil
    /// Called when the user taps the assessment CTA button (or Done on the last slide).
    let onFinished: () -> Void

    @StateObject private var ttsService = ZiggyTTSService.shared
    @State private var currentIndex: Int = 0
    @State private var isTransitioning: Bool = false
    // tb-mvp2-102: Ziggy context chat — opened from "Ask Ziggy →" CTA on slides with a ziggyPrompt.
    @State private var showZiggyFromLesson = false
    @State private var capturedZiggyPrompt: String? = nil
    // tb-mvp2-126: Speaker toggle — on by default, persisted across sessions.
    @AppStorage("lessonTTSEnabled") var ttsEnabled: Bool = true

    private var currentSlide: LessonSlide { lesson.slides[currentIndex] }
    private var isLastSlide: Bool { currentIndex == lesson.slides.count - 1 }
    /// tb-mvp2-136: True when the current slide should show the assessment CTA.
    /// If ctaSlideTitle is set, fires on that slide; otherwise falls back to last slide.
    private var isCTASlide: Bool {
        if let title = ctaSlideTitle { return currentSlide.title == title }
        return isLastSlide
    }
    private var progress: Double { Double(currentIndex + 1) / Double(lesson.slides.count) }

    // tb-mvp2-118: Replaced dark moody gradients with bright upbeat ombré palette
    // matching OnboardingView.gradientColors() — cycles through 5 onboarding hues.
    // White text remains readable on all entries (all are vivid mid-to-dark tones).
    private static let slideGradients: [(String, String)] = [
        ("667EEA", "764BA2"),   // 0: purple→violet  — 😉 welcome
        ("F093FB", "764BA2"),   // 1: pink→purple    — 👋 What is Tourette's
        ("4FACFE", "00F2FE"),   // 2: sky→cyan       — 🧠 What Are Tics
        ("43E97B", "38F9D7"),   // 3: green→teal     — 🌱 Tics Change Over Time
        ("FA709A", "FEE140"),   // 4: pink→yellow    — ⚡️ Premonitory Urge
        ("667EEA", "764BA2"),   // 5: purple→violet  — 🤔 What If I Can't Feel It
        ("F093FB", "764BA2"),   // 6: pink→purple    — 🛠️ How CBIT Works
        ("4FACFE", "00F2FE"),   // 7: sky→cyan       — 🎯 What's Next / 🗺️ Map Your Tics
    ]

    private var slideGradientColors: [Color] {
        let idx = currentIndex % Self.slideGradients.count
        return [Color(hex: Self.slideGradients[idx].0),
                Color(hex: Self.slideGradients[idx].1)]
    }

    var body: some View {
        ZStack {
            // tb-mvp2-074: ombré gradient shifts per slide — each screen has its own
            // emotional hue. Animates smoothly on slide advance/back.
            LinearGradient(
                colors: slideGradientColors,
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.45), value: currentIndex)

            VStack(spacing: 0) {
                lessonHeader
                progressBar
                slideCard
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Spacer()
                navigationControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .onAppear { speakCurrentSlide() }
        // tb-mvp2-126: React to speaker toggle changes mid-session.
        // Toggle OFF → stop immediately. Toggle ON → start speaking current slide.
        .onChange(of: ttsEnabled) { enabled in
            if enabled {
                speakCurrentSlide()
            } else {
                ttsService.stopSpeaking()
            }
        }
        // tb-mvp2-073: clear lesson audio cache when sheet is dismissed
        .onDisappear {
            ttsService.stopSpeaking()
            ttsService.clearLessonCache()
        }
        // tb-mvp2-102: Ziggy contextual chat — pre-seeded with the awareness coaching prompt
        // captured from the tapped slide. TicDataService.shared used directly (singleton) so no
        // @EnvironmentObject needed on LessonSlideView.
        .sheet(isPresented: $showZiggyFromLesson) {
            NavigationStack {
                ChatView(seedPrompt: capturedZiggyPrompt)
                    .environmentObject(TicDataService.shared)
            }
        }
    }

    // MARK: - Header

    private var lessonHeader: some View {
        HStack(spacing: 12) {
            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(lesson.subtitle)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Slide counter
            Text("\(currentIndex + 1) / \(lesson.slides.count)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))

            // tb-mvp2-126: Speaker toggle button — mutes/unmutes Ziggy TTS for lessons.
            Button {
                ttsEnabled.toggle()
            } label: {
                Image(systemName: ttsEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(ttsEnabled ? .white.opacity(0.8) : .white.opacity(0.35))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(ttsEnabled ? 0.12 : 0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 3)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 3)
                    .animation(.easeInOut(duration: 0.3), value: progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 20)
    }

    // MARK: - Slide Card

    private var slideCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            // tb-mvp2-071: Hero emoji — gives each slide a visual anchor so the
            // screen isn't wall-to-wall text. Nil-safe: renders nothing if unset.
            if let emoji = currentSlide.emoji {
                Text(emoji)
                    .font(.system(size: 52))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentIndex)
            }

            Text(currentSlide.title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            ScrollView(.vertical, showsIndicators: false) {
                // tb-mvp2-093: styledBody parses "## Heading" markers as section headers.
                styledBody(currentSlide.body)
            }

            // tb-mvp2-102: "Ask Ziggy →" — only on slides that have a ziggyPrompt set
            // (currently: "What's Next"). Opens Ziggy pre-seeded with an awareness coaching question.
            if let prompt = currentSlide.ziggyPrompt {
                Button {
                    capturedZiggyPrompt = prompt
                    showZiggyFromLesson = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Not sure what to look for? Ask Ziggy →")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "A8EDEA"))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeInOut(duration: 0.25), value: currentIndex)
            }
        }
        .padding(24)
        .background(
            // tb-mvp2-074: Ombré gradient tint — each slide has a unique accent colour
            // so the deck feels alive rather than a wall of identical dark cards.
            // Colours are low-opacity against the navy background to stay readable.
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: slideGradientColors(for: currentIndex),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .id(currentIndex)   // Forces re-render + re-scroll on slide change
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    // MARK: - Navigation Controls

    private var navigationControls: some View {
        HStack(spacing: 16) {
            // Back button — hidden on first slide
            if currentIndex > 0 {
                Button(action: goBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.white.opacity(0.08))
                    )
                }
            }

            Spacer()

            // Primary action button
            // tb-mvp2-136: isCTASlide shows the assessment CTA (may be a non-last slide
            // when ctaSlideTitle is set). isLastSlide without isCTASlide shows "Done →".
            Button(action: primaryAction) {
                HStack(spacing: 8) {
                    Text(isCTASlide ? finalCTALabel : (isLastSlide ? "Done →" : "Next"))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Image(systemName: isCTASlide ? "clipboard.fill" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isCTASlide
                                    ? [Color(hex: "43E97B"), Color(hex: "38F9D7")]
                                    : [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
        }
    }

    // MARK: - Actions

    private func primaryAction() {
        if isCTASlide {
            // Assessment CTA — fires on ctaSlideTitle match (or last slide if no title set)
            ttsService.stopSpeaking()
            onFinished()
        } else if isLastSlide {
            // tb-mvp2-136: Last slide is "What's Next" (homework summary) — just dismiss
            ttsService.stopSpeaking()
            onFinished()
        } else {
            goForward()
        }
    }

    private func goForward() {
        guard currentIndex < lesson.slides.count - 1 else { return }
        ttsService.stopSpeaking()
        withAnimation { currentIndex += 1 }
        speakCurrentSlide()
    }

    private func goBack() {
        guard currentIndex > 0 else { return }
        ttsService.stopSpeaking()
        withAnimation { currentIndex -= 1 }
        speakCurrentSlide()
    }

    /// tb-mvp2-074: Returns a two-stop ombré gradient for the slide card background.
    /// Cycles through 8 accent palettes — one per slide in Session 1.
    /// Kept low-opacity so the dark navy bg stays dominant and text stays readable.
    private func slideGradientColors(for index: Int) -> [Color] {
        let palettes: [[Color]] = [
            // 0 — What is Tourette's: warm teal welcome
            [Color(hex: "00B4DB").opacity(0.18), Color(hex: "0083B0").opacity(0.08)],
            // 1 — Welcome to CBIT: brand purple/indigo
            [Color(hex: "667EEA").opacity(0.20), Color(hex: "764BA2").opacity(0.10)],
            // 2 — What Are Tics: electric blue (neurology)
            [Color(hex: "4776E6").opacity(0.18), Color(hex: "8E54E9").opacity(0.08)],
            // 3 — Tics Change Over Time: amber/gold (growth, hope)
            [Color(hex: "F7971E").opacity(0.18), Color(hex: "FFD200").opacity(0.08)],
            // 4 — The Premonitory Urge: orange-coral (sensation, signal)
            [Color(hex: "FF512F").opacity(0.18), Color(hex: "F09819").opacity(0.08)],
            // 5 — How CBIT Works: green (progress, tools working)
            [Color(hex: "11998E").opacity(0.18), Color(hex: "38EF7D").opacity(0.08)],
            // 6 — Caregiver Role: rose/pink (warmth, connection)
            [Color(hex: "FC466B").opacity(0.18), Color(hex: "3F5EFB").opacity(0.08)],
            // 7 — What's Next: cyan launch
            [Color(hex: "43E97B").opacity(0.18), Color(hex: "38F9D7").opacity(0.08)],
        ]
        let safeIndex = index % palettes.count
        return palettes[safeIndex]
    }

    // MARK: - Styled Body (tb-mvp2-093)

    /// Renders slide body text with support for `## Section` markers.
    /// Lines starting with "## " become bold, larger, accent-colored section headers.
    /// All other content renders as normal body text, preserving line breaks.
    @ViewBuilder
    private func styledBody(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(bodySegments(text).enumerated()), id: \.offset) { _, segment in
                if segment.isHeader {
                    Text(segment.text)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "A8EDEA"))  // light teal — readable on all dark gradients
                        .padding(.top, 4)
                } else {
                    Text(segment.text)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private struct BodySegment { let text: String; let isHeader: Bool }

    /// Splits body text into styled segments. Lines prefixed with "## " become headers;
    /// consecutive non-header lines are grouped into a single block.
    private func bodySegments(_ text: String) -> [BodySegment] {
        var segments: [BodySegment] = []
        var pendingLines: [String] = []
        for line in text.components(separatedBy: "\n") {
            if line.hasPrefix("## ") {
                if !pendingLines.isEmpty {
                    segments.append(BodySegment(text: pendingLines.joined(separator: "\n"), isHeader: false))
                    pendingLines = []
                }
                segments.append(BodySegment(text: String(line.dropFirst(3)), isHeader: true))
            } else {
                pendingLines.append(line)
            }
        }
        if !pendingLines.isEmpty {
            segments.append(BodySegment(text: pendingLines.joined(separator: "\n"), isHeader: false))
        }
        return segments
    }

    /// Strips "## " markers from body text so TTS reads clean prose.
    private func plainTextBody(_ text: String) -> String {
        text.components(separatedBy: "\n")
            .map { $0.hasPrefix("## ") ? String($0.dropFirst(3)) : $0 }
            .joined(separator: "\n")
    }

    /// Reads the current slide aloud and pre-fetches the next slide's audio in the background.
    /// tb-mvp2-070: speakLesson() bypasses the isEnabled gate — lesson TTS is always on.
    /// tb-mvp2-073: Passes slideIndex so speakLesson() can hit the cache for instant
    /// playback. Immediately after starting, kicks off a background prefetch for slideIndex+1
    /// so the next tap on Next is latency-free.
    private func speakCurrentSlide() {
        // tb-mvp2-126: Respect speaker toggle — skip TTS entirely if user muted.
        guard ttsEnabled else { return }
        let idx = currentIndex
        let nextIdx = idx + 1
        // Small delay lets the slide transition animation complete first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            // tb-mvp2-087: slide.spokenText = "Title. body" — title acts as audio heading.
            // tb-mvp2-093: ## stripping now consolidated inside LessonSlide.spokenText.
            // All call sites use .spokenText so the cache key is always consistent.
            ttsService.speakLesson(text: currentSlide.spokenText, voiceProfile: voiceProfile, slideIndex: idx)

            // Pre-fetch next slide in background while user reads current one
            if nextIdx < lesson.slides.count {
                let nextSpoken = lesson.slides[nextIdx].spokenText
                let profile = voiceProfile
                Task {
                    await ttsService.prefetchLessonSlide(
                        text: nextSpoken,
                        voiceProfile: profile,
                        slideIndex: nextIdx
                    )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    if let lesson = CBITLessonService.lesson(for: .session1) {
        LessonSlideView(lesson: lesson, voiceProfile: .caregiver) {}
    }
}
