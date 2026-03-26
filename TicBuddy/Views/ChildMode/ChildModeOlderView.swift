// TicBuddy — ChildModeOlderView.swift
// Child-facing home screen for the Older Child sub-mode: ages 9–12 (olderChild AgeGroup).
// tb-mvp2-008
//
// Design differences from YoungChildView (4–8):
//   - Free-text chat IS available (ZiggyContentFilter guards it)
//   - Urge strength slider (1–5) on tic log sheet — builds premonitory urge awareness
//   - Outcome selection: noticed / caught / redirected (not just auto-noticed)
//   - Competing response shown with clinical detail + "Why this works" explanation
//   - Streak card visible (motivating for this age group)
//   - Privacy notice for ages 10+: "Your PIN is yours — your caregiver won't see it"
//   - Weekly progress ring — visual motivator without exposing raw data to caregiver
//   - Access to Ziggy chat tab (older children can handle text interaction)

import SwiftUI

// MARK: - Older Child Mode Home

struct ChildModeOlderView: View {
    @EnvironmentObject var dataService: TicDataService

    @State private var showTicLogger = false
    @State private var showCelebration = false
    @State private var celebrationText = ""
    @State private var showZiggyChat = false
    @State private var showMilestone = false        // tb-mvp2-016
    @State private var showEveningCheckIn = false   // tb-mvp2-018

    private var child: ChildProfile? { dataService.familyUnit.activeChild }
    private var profile: UserProfile { dataService.activeUserProfile }
    private var shared: SharedFamilyData { dataService.familyUnit.sharedData }
    private var phase: CBITPhase { profile.recommendedPhase }
    private var isEveningTime: Bool { Calendar.current.component(.hour, from: Date()) >= 17 }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {

                        // ── Greeting header ─────────────────────────────────────
                        OlderGreetingCard(
                            nickname: child?.nickname ?? profile.name,
                            phase: phase,
                            streak: dataService.currentStreak
                        )
                        .padding(.horizontal, 20)

                        // ── Today's progress ring ────────────────────────────────
                        OlderProgressRing(
                            noticed: dataService.totalTicsToday(),
                            redirected: dataService.redirectionsToday(),
                            phase: phase
                        )
                        .padding(.horizontal, 20)

                        // ── Competing response card (Week 2+) ────────────────────
                        if phase != .week1Awareness {
                            if let targetTic = child?.currentTargetTic {
                                OlderCRCard(ticEntry: targetTic)
                                    .padding(.horizontal, 20)
                            }
                        } else {
                            OlderAwarenessCard()
                                .padding(.horizontal, 20)
                        }

                        // ── Ziggy chat shortcut ──────────────────────────────────
                        OlderZiggyButton {
                            showZiggyChat = true
                        }
                        .padding(.horizontal, 20)

                        // ── Privacy note (ages 10+) ──────────────────────────────
                        if child?.ageGroup == .olderChild {
                            OlderPrivacyNote()
                                .padding(.horizontal, 20)
                        }

                        // Bottom spacer for FAB
                        Color.clear.frame(height: 90)
                    }
                    .padding(.top, 16)
                }

                // ── Floating log button ──────────────────────────────────────────
                OlderLogFAB {
                    showTicLogger = true
                }
                .padding(.bottom, 24)
                .padding(.horizontal, 40)
            }
            .background(
                LinearGradient(
                    colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationBarHidden(true)
            // Celebration overlay
            .overlay {
                if showCelebration {
                    OlderCelebrationBanner(message: celebrationText) {
                        withAnimation { showCelebration = false }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
                }
            }
        }
        // Tic logger sheet
        .sheet(isPresented: $showTicLogger) {
            OlderTicLogSheet(childProfile: child, phase: phase) { entry in
                logTic(entry)
                showTicLogger = false
            }
        }
        // Ziggy chat
        .sheet(isPresented: $showZiggyChat) {
            ChatView()
                .environmentObject(dataService)
        }
        // tb-mvp2-016: Milestone celebration
        .sheet(isPresented: $showMilestone) {
            RewardMilestoneSheet(
                totalPoints: dataService.familyUnit.sharedData.rewardPoints,
                ageGroup: child?.ageGroup ?? .olderChild
            )
        }
        // tb-mvp2-018: Evening check-in
        .sheet(isPresented: $showEveningCheckIn) {
            EveningCheckInSheet(childAgeGroup: child?.ageGroup ?? .olderChild)
                .environmentObject(dataService)
        }
        // tb-mvp2-018: Evening check-in button visible after 5pm in toolbar
        .toolbar {
            if isEveningTime, dataService.todayEveningCheckIn() == nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEveningCheckIn = true
                    } label: {
                        Label("Check in", systemImage: "moon.stars.fill")
                            .labelStyle(.iconOnly)
                            .foregroundColor(Color(hex: "764BA2"))
                    }
                }
            }
        }
    }

    // MARK: - Logging

    private func logTic(_ entry: TicEntry) {
        dataService.addTicEntry(entry)
        // tb-mvp2-016: Award points based on outcome; redirected = 2pts, caught/noticed = 1pt
        let points: Int
        switch entry.outcome {
        case .redirected:
            points = 2
            celebrationText = "🌟 You redirected it! Your brain is literally rewiring right now! +2 ⭐️"
        case .caught:
            points = 1
            celebrationText = "⚡️ You caught the urge before the tic! That's huge! +1 ⭐️"
        case .noticed:
            points = 1
            celebrationText = "👀 Great job noticing. That's exactly what CBIT is all about. +1 ⭐️"
        case .ticHappened:
            points = 0
            celebrationText = "💙 That's okay — noticing it still counts. Keep going!"
        }
        let milestone = dataService.awardPoints(points)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation { showCelebration = false }
        }
        if milestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { showMilestone = true }
        }
    }
}

// MARK: - Greeting Card

private struct OlderGreetingCard: View {
    let nickname: String
    let phase: CBITPhase
    let streak: Int

    private var greeting: String {
        let first = nickname.split(separator: " ").first.map(String.init) ?? nickname
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning, \(first)! ☀️" }
        if hour < 17 { return "Hey \(first)! 👋" }
        return "Good evening, \(first)! 🌙"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(greeting)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                // Streak badge
                if streak > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 18))
                        Text("\(streak)d")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.22))
                    .cornerRadius(16)
                }
            }

            Text(phase.goalText)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(18)
        .background(Color.white.opacity(0.18))
        .cornerRadius(22)
    }
}

// MARK: - Progress Ring

private struct OlderProgressRing: View {
    let noticed: Int
    let redirected: Int
    let phase: CBITPhase

    private var ringProgress: Double {
        guard noticed > 0 else { return 0 }
        return min(1.0, Double(redirected) / Double(max(noticed, 1)))
    }

    var body: some View {
        HStack(spacing: 20) {
            // Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 10)
                    .frame(width: 90, height: 90)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.8), value: ringProgress)
                VStack(spacing: 0) {
                    Text("\(redirected)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("done")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Stats
            VStack(alignment: .leading, spacing: 10) {
                OlderStatRow(emoji: "👀", value: noticed, label: "noticed today")
                OlderStatRow(emoji: "⚡️", value: redirected, label: "redirected")
                if phase == .week1Awareness {
                    Text("Week 1: just notice and log! 🔍")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(18)
        .background(Color.white.opacity(0.15))
        .cornerRadius(22)
    }
}

private struct OlderStatRow: View {
    let emoji: String
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 16))
            Text("\(value)")
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Awareness Card (Week 1)

private struct OlderAwarenessCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🔍")
                    .font(.system(size: 32))
                Text("Week 1: Tic Detective")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("This week your only job is to NOTICE your tics and log them. That's it. You're training your brain's awareness system — which is actually the first step to changing things.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
            Text("Every log is a win. 💙")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(18)
        .background(Color.white.opacity(0.18))
        .cornerRadius(22)
    }
}

// MARK: - Competing Response Card (Week 2+)

private struct OlderCRCard: View {
    let ticEntry: TicHierarchyEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💪 Your competing response")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Text("For: \(ticEntry.ticName)")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    withAnimation(.spring()) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // CR description — always visible
            if ticEntry.competingResponse.isEmpty {
                Text("Your therapist or parent will add your competing response here soon.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            } else {
                Text(ticEntry.competingResponse)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            // Expanded: why it works
            if isExpanded {
                Divider().overlay(Color.white.opacity(0.3))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Why this works:")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Competing responses use muscles that physically can't do the tic at the same time. Your brain starts to choose the new path over the old one. The more you practice, the stronger that new path gets.")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))

                    if !ticEntry.urgeDescription.isEmpty {
                        Text("Your urge feeling: \"\(ticEntry.urgeDescription)\"")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .italic()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.18))
        .cornerRadius(22)
    }
}

// MARK: - Ziggy Chat Button

private struct OlderZiggyButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text("🤖")
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chat with Ziggy")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                    Text("Ask anything about your tics or CBIT")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(18)
            .background(Color.white.opacity(0.18))
            .cornerRadius(22)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Privacy Note (ages 10+)

private struct OlderPrivacyNote: View {
    var body: some View {
        HStack(spacing: 12) {
            Text("🔒")
                .font(.system(size: 20))
            Text("Your PIN is yours. Your caregiver can't see what you type to Ziggy.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.75))
        }
        .padding(14)
        .background(Color.white.opacity(0.12))
        .cornerRadius(16)
    }
}

// MARK: - Floating Log Button

private struct OlderLogFAB: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                Text("Log a tic")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundColor(Color(hex: "764BA2"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.white)
            .cornerRadius(32)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.15)) { isPressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.25)) { isPressed = false } }
        )
    }
}

// MARK: - Tic Log Sheet

struct OlderTicLogSheet: View {
    let childProfile: ChildProfile?
    let phase: CBITPhase
    let onLog: (TicEntry) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicName = ""
    @State private var selectedCategory: TicCategory = .motor
    @State private var selectedOutcome: TicOutcome = .noticed
    @State private var urgeStrength: Int = 3

    private var ticOptions: [(name: String, emoji: String, category: TicCategory)] {
        if let hierarchy = childProfile?.ticHierarchy, !hierarchy.isEmpty {
            return hierarchy.map { ($0.ticName, $0.category == .motor ? "💪" : "🗣️", $0.category) }
        }
        return [
            ("Eye Blink", "👁️", .motor), ("Head Jerk", "🔄", .motor),
            ("Shoulder Shrug", "🤷", .motor), ("Facial Grimace", "😬", .motor),
            ("Throat Clearing", "🗣️", .vocal), ("Sniffing", "👃", .vocal),
            ("Grunting", "😤", .vocal), ("Other", "⚡️", .motor)
        ]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // ── Tic type ────────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Which tic?")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 4)

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(ticOptions, id: \.name) { opt in
                                    Button {
                                        selectedTicName = opt.name
                                        selectedCategory = opt.category
                                    } label: {
                                        HStack(spacing: 8) {
                                            Text(opt.emoji).font(.system(size: 18))
                                            Text(opt.name)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(selectedTicName == opt.name
                                                      ? Color.white.opacity(0.35)
                                                      : Color.white.opacity(0.15))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(selectedTicName == opt.name ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Outcome (Week 2+ only shows all options) ────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What happened?")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))

                            VStack(spacing: 8) {
                                let outcomes: [TicOutcome] = phase == .week1Awareness
                                    ? [.noticed, .ticHappened]
                                    : [.noticed, .caught, .redirected, .ticHappened]

                                ForEach(outcomes, id: \.self) { outcome in
                                    Button {
                                        withAnimation(.spring()) { selectedOutcome = outcome }
                                    } label: {
                                        HStack(spacing: 14) {
                                            Text(outcome.emoji).font(.system(size: 22))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(outcome.rawValue)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundColor(.white)
                                            }
                                            Spacer()
                                            Image(systemName: selectedOutcome == outcome
                                                  ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 22))
                                                .foregroundColor(selectedOutcome == outcome ? .white : .white.opacity(0.4))
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(selectedOutcome == outcome
                                                      ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        // ── Urge strength ────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            Text("How strong was the urge? \(urgeStrength)/5")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.8))

                            HStack(spacing: 0) {
                                ForEach(1...5, id: \.self) { level in
                                    Button {
                                        withAnimation(.spring(response: 0.2)) { urgeStrength = level }
                                    } label: {
                                        Text(level <= urgeStrength ? "🔥" : "○")
                                            .font(.system(size: 28))
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(16)

                            Text(urgeStrength <= 2 ? "Low urge — that's fine, log it anyway"
                                 : urgeStrength == 3 ? "Medium urge — noticed the warning signal"
                                 : "Strong urge — great awareness!")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.65))
                        }
                        .padding(.horizontal, 20)

                        // ── Log button ───────────────────────────────────────────
                        Button {
                            guard !selectedTicName.isEmpty else { return }
                            let entry = TicEntry(
                                category: selectedCategory,
                                customLabel: selectedTicName,
                                outcome: selectedOutcome,
                                urgeStrength: urgeStrength
                            )
                            onLog(entry)
                        } label: {
                            Text(selectedTicName.isEmpty ? "Pick a tic first" : "Log it ✓")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundColor(Color(hex: "764BA2"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(selectedTicName.isEmpty ? Color.white.opacity(0.4) : Color.white)
                                .cornerRadius(28)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTicName.isEmpty)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Log a Tic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.clear, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Celebration Banner (top-of-screen, auto-dismisses)

private struct OlderCelebrationBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 12) {
                Text(message)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(16)
            .background(Color(hex: "43E97B"))
            .cornerRadius(18)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    ChildModeOlderView()
        .environmentObject(TicDataService.shared)
}
