// TicBuddy — HomeView.swift
// Main dashboard: greeting, CBIT phase, today's stats, quick log button.

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var showAddTic = false
    @State private var showPhaseDetail = false

    var profile: UserProfile { dataService.userProfile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting card
                    GreetingCard(profile: profile, dataService: dataService)
                        .padding(.horizontal, 16)

                    // CBIT Phase card
                    CBITPhaseCard(phase: profile.recommendedPhase, showDetail: $showPhaseDetail)
                        .padding(.horizontal, 16)

                    // tb-mvp2-067: Quick tic counter — instant +1 tap, no form required.
                    // CBIT homework = observe and tally tics throughout the day.
                    QuickTicCounterCard(dataService: dataService, onDetailTap: { showAddTic = true })
                        .padding(.horizontal, 16)

                    // Today's stats
                    TodayStatsCard(dataService: dataService)
                        .padding(.horizontal, 16)

                    // ── Competing response reminder (week 2+) ─────────────────
                    if profile.recommendedPhase != .week1Awareness {
                        CompetingResponseCard(profile: profile)
                            .padding(.horizontal, 16)
                    }

                    // Streak card
                    StreakCard(streak: dataService.currentStreak)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(profile.greeting)
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showAddTic) {
                AddTicView(date: Date())
                    .environmentObject(dataService)
            }
            .sheet(isPresented: $showPhaseDetail) {
                PhaseDetailView(phase: profile.recommendedPhase)
            }
        }
    }
}

// MARK: - Quick Tic Counter (tb-mvp2-067)
// Zero-friction tic tally widget: one tap = +1 tic logged for today.
// Creates a TicEntry with sensible CBIT-session-1 defaults (outcome: .noticed)
// so entries flow into the Calendar/DayLog without any form friction.
// A secondary "Add detail →" link opens AddTicView for full categorisation.

struct QuickTicCounterCard: View {
    @ObservedObject var dataService: TicDataService
    let onDetailTap: () -> Void

    // Animated bounce on tap
    @State private var bounce: Bool = false

    private var todayCount: Int { dataService.entries(for: Date()).count }

    var body: some View {
        HStack(spacing: 0) {

            // ── Left: Count Display ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Tics")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))

                Text("\(todayCount)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .scaleEffect(bounce ? 1.18 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.45), value: bounce)
                    .contentTransition(.numericText())

                Button(action: onDetailTap) {
                    Text("Add detail →")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.55))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)

            // ── Right: +1 Tap Button ─────────────────────────────────────────
            Button(action: quickLog) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 76, height: 76)
                    Image(systemName: "plus")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(18)
        .shadow(color: Color(hex: "667EEA").opacity(0.38), radius: 10, y: 4)
    }

    /// Instantly creates a TicEntry with CBIT Session-1 defaults (just noticing).
    /// No form required — full detail can be added via onDetailTap.
    private func quickLog() {
        let entry = TicEntry(
            date: Date(),
            category: .motor,
            motorType: .other,
            outcome: .noticed,
            urgeStrength: 3
        )
        dataService.addTicEntry(entry)

        // Brief scale-bounce to confirm the tap registered
        bounce = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { bounce = false }

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
}

// MARK: - Greeting Card

struct GreetingCard: View {
    let profile: UserProfile
    let dataService: TicDataService

    var todayCount: Int { dataService.totalTicsToday() }

    var motivationalMessage: String {
        if todayCount == 0 {
            return "Ready to be a tic detective today? 🕵️"
        } else if todayCount < 5 {
            return "You're doing great — keep noticing! 👀"
        } else {
            return "Wow, you've noticed \(todayCount) tics today! That takes courage! 💙"
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("🌟")
                .font(.system(size: 50))

            VStack(alignment: .leading, spacing: 6) {
                Text(motivationalMessage)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                if let best = dataService.bestOutcomeToday() {
                    HStack(spacing: 6) {
                        Text(best.emoji)
                        Text("Best today: \(best.rawValue)")
                            .font(.subheadline)
                            .foregroundColor(Color(hex: "667EEA"))
                            .bold()
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: "667EEA").opacity(0.08), Color(hex: "764BA2").opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(hex: "667EEA").opacity(0.2), lineWidth: 1))
    }
}

// MARK: - CBIT Phase Card

struct CBITPhaseCard: View {
    let phase: CBITPhase
    @Binding var showDetail: Bool

    var body: some View {
        Button(action: { showDetail = true }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(phase.title)
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundColor(.white.opacity(0.7))
                }

                Text(phase.goalText)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(18)
            .shadow(color: Color(hex: "667EEA").opacity(0.35), radius: 10, y: 4)
        }
    }
}

// MARK: - Today's Stats

struct TodayStatsCard: View {
    @ObservedObject var dataService: TicDataService

    var entries: [TicEntry] { dataService.entries(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's Progress")
                .font(.headline.bold())

            HStack(spacing: 0) {
                BigStat(value: entries.count, label: "Tics\nNoticed", emoji: "👀", color: .orange)
                Divider().frame(height: 50)
                BigStat(value: entries.filter { $0.outcome == .caught }.count, label: "Urge\nCaught", emoji: "⚡️", color: .yellow)
                Divider().frame(height: 50)
                BigStat(value: entries.filter { $0.outcome == .redirected }.count, label: "Tics\nRedirected", emoji: "🌟", color: .green)
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct BigStat: View {
    let value: Int
    let label: String
    let emoji: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2)
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Competing Response Card

struct CompetingResponseCard: View {
    let profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("💪 Your Superpower Move")
                    .font(.headline.bold())
                Spacer()
            }

            Text("When you feel the urge to tic:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                CompetingStep(number: "1", text: "Notice the feeling (the urge)")
                CompetingStep(number: "2", text: "Take a slow, deep breath")
                CompetingStep(number: "3", text: "Tense the opposite muscle gently for 1 minute")
                CompetingStep(number: "4", text: "The urge usually passes! 🎉")
            }
        }
        .padding(18)
        .background(Color.green.opacity(0.08))
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }
}

struct CompetingStep: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(Color.green)
                .cornerRadius(11)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Streak Card

struct StreakCard: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 16) {
            Text(streak > 0 ? "🔥" : "💙")
                .font(.system(size: 44))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(streak) Day Streak!")
                    .font(.title2.bold())
                Text(streak > 0 ? "You logged tics \(streak) days in a row. Amazing!" : "Log a tic today to start your streak!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Phase Detail Sheet

struct PhaseDetailView: View {
    let phase: CBITPhase
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text(phase.title)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)

                    Text(phase.description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    Text(phase.goalText)
                        .font(.headline)
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "667EEA").opacity(0.1))
                        .cornerRadius(14)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 40)
            }
            .navigationTitle("Your Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it! 👍") { dismiss() }.bold()
                }
            }
        }
    }
}
