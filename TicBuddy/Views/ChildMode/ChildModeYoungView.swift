// TicBuddy — ChildModeYoungView.swift
// Child-facing home screen for the Young sub-mode: ages 4–8 (veryYoung + young AgeGroups).
// tb-mvp2-007
//
// Design rules for this age group:
//   - NO free-text input anywhere — tap buttons only (prevents abuse surface, age-appropriate)
//   - Oversized touch targets (min 60pt) — easy for small fingers
//   - Every action gives immediate celebration feedback
//   - Simple 1–2 word labels with large supporting emoji
//   - Tic logging = two taps: "I had a tic!" → pick which one
//   - Competing response = tap to see the move, tap "I tried it!" to log
//   - No session limits visible to this age group (handled silently)

import SwiftUI

// MARK: - Young Child Mode Home

struct ChildModeYoungView: View {
    @EnvironmentObject var dataService: TicDataService

    @State private var showTicPicker = false
    @State private var showCelebration = false
    @State private var lastEarnedStar = false
    @State private var celebrationMessage = ""
    @State private var showCompetingResponse = false
    @State private var showMilestone = false        // tb-mvp2-016
    @State private var showEveningCheckIn = false   // tb-mvp2-018

    private var child: ChildProfile? { dataService.familyUnit.activeChild }
    private var profile: UserProfile { dataService.activeUserProfile }
    private var shared: SharedFamilyData { dataService.familyUnit.sharedData }
    private var isEveningTime: Bool { Calendar.current.component(.hour, from: Date()) >= 17 }

    var body: some View {
        ZStack {
            // Background gradient — warm, friendly
            LinearGradient(
                colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Top: Greeting + Stars ───────────────────────────────────
                YoungTopBar(
                    nickname: child?.nickname ?? profile.name,
                    starCount: shared.rewardPoints
                )
                .padding(.top, 16)
                .padding(.horizontal, 20)

                Spacer(minLength: 24)

                // ── Center: Big Tic Log Button ──────────────────────────────
                BigTicButton {
                    showTicPicker = true
                }
                .padding(.horizontal, 40)

                Spacer(minLength: 28)

                // ── Competing Response Card (Week 2+) ───────────────────────
                if profile.currentPhase != .week1Awareness, let targetTic = child?.currentTargetTic {
                    YoungCRCard(ticEntry: targetTic) {
                        showCompetingResponse = true
                    }
                    .padding(.horizontal, 24)
                } else {
                    YoungDetectiveCard()
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 28)

                // ── Bottom: Today's Stars ───────────────────────────────────
                YoungStarRow(
                    totalToday: dataService.totalTicsToday(),
                    redirected: dataService.redirectionsToday()
                )
                .padding(.horizontal, 24)

                // ── Evening Check-In (tb-mvp2-018) — shown after 5pm ────────
                if isEveningTime, dataService.todayEveningCheckIn() == nil {
                    Button {
                        showEveningCheckIn = true
                    } label: {
                        HStack(spacing: 10) {
                            Text("🌙").font(.system(size: 22))
                            Text("Bedtime check-in!")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "1A1F36").opacity(0.6))
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 16).frame(height: 16)
            }

            // ── Overlays ────────────────────────────────────────────────────
            if showCelebration {
                YoungCelebrationOverlay(message: celebrationMessage) {
                    withAnimation { showCelebration = false }
                }
            }
        }
        // Tic picker sheet
        .sheet(isPresented: $showTicPicker) {
            YoungTicPickerSheet(childProfile: child) { entry in
                logTic(entry)
                showTicPicker = false
            }
        }
        // Competing response detail sheet
        .sheet(isPresented: $showCompetingResponse) {
            if let targetTic = child?.currentTargetTic {
                YoungCRDetailSheet(ticEntry: targetTic) { didTry in
                    showCompetingResponse = false
                    if didTry { logRedirection(targetTic) }
                }
            }
        }
        // tb-mvp2-016: Milestone tier celebration
        .sheet(isPresented: $showMilestone) {
            RewardMilestoneSheet(
                totalPoints: shared.rewardPoints,
                ageGroup: child?.ageGroup ?? .young
            )
        }
        // tb-mvp2-018: Evening check-in
        .sheet(isPresented: $showEveningCheckIn) {
            EveningCheckInSheet(childAgeGroup: child?.ageGroup ?? .young)
                .environmentObject(dataService)
        }
    }

    // MARK: - Logging Actions

    private func logTic(_ entry: TicEntry) {
        dataService.addTicEntry(entry)
        let isRedirected = entry.outcome == .redirected
        // tb-mvp2-016: Award points — redirected = 2pts (used the CR!), other outcomes = 1pt
        let milestone = dataService.awardPoints(isRedirected ? 2 : 1)
        celebrationMessage = isRedirected
            ? "🌟 Amazing! You did it! +2 ⭐️"
            : "👀 Nice job noticing! +1 ⭐️"
        withAnimation(.spring()) { showCelebration = true }
        if milestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showMilestone = true }
        }
    }

    private func logRedirection(_ ticEntry: TicHierarchyEntry) {
        let entry = TicEntry(
            category: ticEntry.category,
            outcome: .redirected
        )
        dataService.addTicEntry(entry)
        // tb-mvp2-016: Full redirect = 2 points
        let milestone = dataService.awardPoints(2)
        celebrationMessage = "🌟 You tried your superpower move! +2 ⭐️"
        withAnimation(.spring()) { showCelebration = true }
        if milestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showMilestone = true }
        }
    }
}

// MARK: - Top Bar

private struct YoungTopBar: View {
    let nickname: String
    let starCount: Int

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let first = nickname.split(separator: " ").first.map(String.init) ?? nickname
        if hour < 12 { return "Good morning, \(first)! ☀️" }
        if hour < 17 { return "Hey \(first)! 👋" }
        return "Hi \(first)! 🌙"
    }

    var body: some View {
        HStack {
            Text(greeting)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            // Star counter — always visible
            HStack(spacing: 6) {
                Text("⭐️")
                    .font(.system(size: 24))
                Text("\(starCount)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.25))
            .cornerRadius(20)
        }
    }
}

// MARK: - Big Tic Log Button

private struct BigTicButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Text("🧠")
                    .font(.system(size: 72))

                Text("I had a tic!")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "2D5016"))

                Text("Tap to log it")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "2D5016").opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 36)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.2)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.3)) { isPressed = false } }
        )
    }
}

// MARK: - Detective Card (Week 1)

private struct YoungDetectiveCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🔍")
                .font(.system(size: 48))
            Text("This week: be a tic detective!")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text("Just notice your tics and tap the button. You're already a superstar!")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(Color.white.opacity(0.2))
        .cornerRadius(24)
    }
}

// MARK: - Competing Response Card (Week 2+)

private struct YoungCRCard: View {
    let ticEntry: TicHierarchyEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text("💪")
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your superpower move!")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text(ticEntry.competingResponse.isEmpty
                         ? "Tap to see your move"
                         : ticEntry.competingResponse)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
            .background(Color.white.opacity(0.22))
            .cornerRadius(22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Star Row (today's progress)

private struct YoungStarRow: View {
    let totalToday: Int
    let redirected: Int

    var body: some View {
        HStack(spacing: 16) {
            YoungStatBubble(emoji: "👀", value: totalToday, label: "noticed")
            YoungStatBubble(emoji: "🌟", value: redirected, label: "redirected")
        }
    }
}

private struct YoungStatBubble: View {
    let emoji: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji)
                .font(.system(size: 22))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(Color.white.opacity(0.18))
        .cornerRadius(18)
    }
}

// MARK: - Celebration Overlay

private struct YoungCelebrationOverlay: View {
    let message: String
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(spacing: 20) {
                Text(message)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Yay! 🎉", action: onDismiss)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "43E97B"))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .cornerRadius(32)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(hex: "43E97B"))
            )
            .padding(.horizontal, 32)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                scale = 1.0
                opacity = 1.0
            }
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: onDismiss)
        }
    }
}

// MARK: - Tic Picker Sheet

/// Two-step tap: first pick the tic type, then it auto-logs with .noticed outcome.
/// No free text anywhere.
struct YoungTicPickerSheet: View {
    let childProfile: ChildProfile?
    let onLog: (TicEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Only show tics from the child's hierarchy (if set), else show all types
    private var ticOptions: [(emoji: String, name: String, category: TicCategory)] {
        if let hierarchy = childProfile?.ticHierarchy, !hierarchy.isEmpty {
            return hierarchy.map { entry in
                (emoji: entry.category == .motor ? "💪" : "🗣️",
                 name: entry.ticName,
                 category: entry.category)
            }
        }
        // Fallback: common tic buttons
        return [
            ("👁️", "Eye Blink", .motor),
            ("🔄", "Head Move", .motor),
            ("🤷", "Shoulder", .motor),
            ("😬", "Face Move", .motor),
            ("🗣️", "Throat Clear", .vocal),
            ("👃", "Sniffing", .vocal),
            ("😤", "Grunt", .vocal),
            ("⚡️", "Other", .motor),
        ]
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle bar
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("Which tic?")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                // Grid of tic buttons — 2 columns, oversized targets
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(ticOptions, id: \.name) { option in
                        YoungTicOptionButton(
                            emoji: option.emoji,
                            name: option.name
                        ) {
                            let entry = TicEntry(
                                category: option.category,
                                customLabel: option.name,
                                outcome: .noticed
                            )
                            onLog(entry)
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button("Never mind") { dismiss() }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 32)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct YoungTicOptionButton: View {
    let emoji: String
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Text(emoji)
                    .font(.system(size: 40))
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color.white.opacity(0.2))
            .cornerRadius(22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Competing Response Detail Sheet

/// Shows the child's competing response move with visual instructions.
/// Two buttons: "I tried it! 🌟" and "Maybe later".
struct YoungCRDetailSheet: View {
    let ticEntry: TicHierarchyEntry
    let onDone: (Bool) -> Void  // true = tried it, false = skipped

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)

                Text("💪")
                    .font(.system(size: 72))

                Text("Your superpower move!")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                // The competing response — big, readable
                Text(ticEntry.competingResponse.isEmpty
                     ? "Your therapist or parent will set your move soon!"
                     : ticEntry.competingResponse)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(20)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(20)
                    .padding(.horizontal, 24)

                Text("Try it now — hold for 60 seconds if you can! ⏱")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 14) {
                    // Primary: tried it
                    Button {
                        onDone(true)
                    } label: {
                        Text("I tried it! 🌟")
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(hex: "764BA2"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .cornerRadius(32)
                    }
                    .buttonStyle(.plain)

                    // Secondary: skip
                    Button("Maybe later") { onDone(false) }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Preview

#Preview {
    ChildModeYoungView()
        .environmentObject(TicDataService.shared)
}
