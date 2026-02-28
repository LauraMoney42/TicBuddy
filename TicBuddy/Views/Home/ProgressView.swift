// TicBuddy — ProgressView.swift
// Weekly progress chart and insights for the user.

import SwiftUI

struct TicProgressView: View {
    @EnvironmentObject var dataService: TicDataService

    private let calendar = Calendar.current

    var last7Days: [DaySummary] {
        (0..<7).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let entries = dataService.entries(for: date)
            return DaySummary(date: date, entries: entries)
        }
    }

    var totalThisWeek: Int { last7Days.reduce(0) { $0 + $1.total } }
    var redirectionsThisWeek: Int { last7Days.reduce(0) { $0 + $1.redirected } }
    var successRate: Int {
        guard totalThisWeek > 0 else { return 0 }
        return Int(Double(redirectionsThisWeek + last7Days.reduce(0) { $0 + $1.caught }) / Double(totalThisWeek) * 100)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Week summary banner
                    WeekSummaryBanner(total: totalThisWeek, redirections: redirectionsThisWeek, successRate: successRate)
                        .padding(.horizontal, 16)

                    // 7-day bar chart
                    WeekBarChart(days: last7Days)
                        .padding(.horizontal, 16)

                    // Insight cards
                    InsightsSection(days: last7Days, dataService: dataService)
                        .padding(.horizontal, 16)

                    // My Tics + Competing Responses
                    MyTicsSection(dataService: dataService)
                        .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("My Progress 📊")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Data Model

struct DaySummary: Identifiable {
    let id: Date
    let date: Date
    let entries: [TicEntry]

    init(date: Date, entries: [TicEntry]) {
        self.id = date
        self.date = date
        self.entries = entries
    }

    var total: Int { entries.count }
    var redirected: Int { entries.filter { $0.outcome == .redirected }.count }
    var caught: Int { entries.filter { $0.outcome == .caught }.count }
    var noticed: Int { entries.filter { $0.outcome == .noticed }.count }

    var dayAbbrev: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return fmt.string(from: date)
    }

    var isToday: Bool { Calendar.current.isDateInToday(date) }
}

// MARK: - Week Summary Banner

struct WeekSummaryBanner: View {
    let total: Int
    let redirections: Int
    let successRate: Int

    var encouragement: String {
        switch successRate {
        case 0: return "Start logging to see your progress! 🌱"
        case 1..<25: return "You're just getting started — keep going! 💙"
        case 25..<50: return "You're building new brain pathways! 🧠"
        case 50..<75: return "Over halfway there — your brain is changing! ⚡️"
        case 75..<100: return "You're a tic-fighting superstar! 🌟"
        default: return "PERFECT week! You're incredible! 🏆"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(encouragement)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)

            HStack(spacing: 0) {
                BannerStat(value: "\(total)", label: "This Week", emoji: "📊")
                BannerStat(value: "\(redirections)", label: "Redirected", emoji: "🌟")
                BannerStat(value: "\(successRate)%", label: "Success Rate", emoji: "🎯")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .cornerRadius(20)
        .shadow(color: Color(hex: "667EEA").opacity(0.35), radius: 10, y: 4)
    }
}

struct BannerStat: View {
    let value: String
    let label: String
    let emoji: String

    var body: some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title3)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 7-Day Bar Chart

struct WeekBarChart: View {
    let days: [DaySummary]

    var maxTotal: Int { max(days.map(\.total).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .font(.headline.bold())

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(days) { day in
                    DayBarView(day: day, maxValue: maxTotal)
                }
            }
            .frame(height: 120)

            // Legend
            HStack(spacing: 16) {
                LegendDot(color: .green, label: "Redirected 🌟")
                LegendDot(color: .yellow, label: "Caught ⚡️")
                LegendDot(color: .orange.opacity(0.6), label: "Noticed 👀")
            }
            .font(.caption)
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

struct DayBarView: View {
    let day: DaySummary
    let maxValue: Int

    var redirectedFrac: Double { day.total > 0 ? Double(day.redirected) / Double(maxValue) : 0 }
    var caughtFrac: Double { day.total > 0 ? Double(day.caught) / Double(maxValue) : 0 }
    var noticedFrac: Double { day.total > 0 ? Double(day.noticed) / Double(maxValue) : 0 }

    var body: some View {
        VStack(spacing: 4) {
            if day.total > 0 {
                Text("\(day.total)").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            }

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()
                    // Stacked bar: redirected (bottom) + caught + noticed (top)
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.orange.opacity(0.6))
                            .frame(height: geo.size.height * noticedFrac)
                        Rectangle().fill(Color.yellow)
                            .frame(height: geo.size.height * caughtFrac)
                        Rectangle().fill(Color.green)
                            .frame(height: geo.size.height * redirectedFrac)
                    }
                    .cornerRadius(4)
                }
            }

            Text(day.dayAbbrev)
                .font(.caption2.bold())
                .foregroundColor(day.isToday ? Color(hex: "667EEA") : .secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).foregroundColor(.secondary)
        }
    }
}

// MARK: - Insights Section

struct InsightsSection: View {
    let days: [DaySummary]
    let dataService: TicDataService

    var bestDay: DaySummary? { days.max(by: { $0.redirected < $1.redirected }) }
    var mostFrequentTic: String? {
        let all = days.flatMap(\.entries)
        let counts = Dictionary(grouping: all, by: \.displayName).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key
    }
    var avgPerDay: Int {
        let nonEmpty = days.filter { $0.total > 0 }
        guard !nonEmpty.isEmpty else { return 0 }
        return nonEmpty.reduce(0) { $0 + $1.total } / nonEmpty.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights 🔍")
                .font(.headline.bold())

            if let best = bestDay, best.redirected > 0 {
                InsightCard(emoji: "🏆", title: "Best Day", bodyText: "\(best.dayAbbrev) — \(best.redirected) redirections!")
            }

            if let tic = mostFrequentTic {
                InsightCard(emoji: "📍", title: "Most Tracked Tic", bodyText: "\(tic) — you're really aware of this one! Great detective work.")
            }

            if avgPerDay > 0 {
                InsightCard(emoji: "📈", title: "Average Per Day", bodyText: "About \(avgPerDay) tics per day this week. Every one you notice counts!")
            }

            if days.filter({ $0.total > 0 }).count == 7 {
                InsightCard(emoji: "🔥", title: "Perfect Week!", bodyText: "You logged every single day this week. That's incredible dedication!")
            }
        }
    }
}

struct InsightCard: View {
    let emoji: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.title2).frame(width: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.bold())
                Text(bodyText).font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }
}

// MARK: - My Tics Section

struct MyTicsSection: View {
    let dataService: TicDataService

    var profile: UserProfile { dataService.userProfile }
    var phase: CBITPhase { profile.recommendedPhase }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("My Tics & Superpower Moves 💪")
                .font(.headline.bold())

            ForEach(profile.primaryTics, id: \.self) { ticName in
                TicResponseRow(
                    ticName: ticName,
                    phase: phase,
                    response: CompetingResponseLibrary.response(for: ticName)
                )
            }

            if profile.primaryTics.isEmpty {
                Text("No tics set up yet. Complete onboarding to add your tics!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct TicResponseRow: View {
    let ticName: String
    let phase: CBITPhase
    let response: CompetingResponse?
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring()) { expanded.toggle() } }) {
                HStack {
                    Text(response?.emoji ?? "⚡️").font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ticName).font(.subheadline.bold()).foregroundColor(.primary)
                        if phase == .week1Awareness {
                            Text("Week 1: Just notice this tic").font(.caption).foregroundColor(.secondary)
                        } else if let cr = response {
                            Text("Superpower: \(cr.title)").font(.caption).foregroundColor(Color(hex: "667EEA"))
                        }
                    }
                    Spacer()
                    if response != nil && phase != .week1Awareness {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
            }

            if expanded, let cr = response, phase != .week1Awareness {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                    Text(cr.instruction)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)

                    HStack {
                        Text("💡").font(.title3)
                        Text(cr.kidFriendlyTip)
                            .font(.subheadline.bold())
                            .foregroundColor(Color(hex: "764BA2"))
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 5, y: 1)
    }
}
