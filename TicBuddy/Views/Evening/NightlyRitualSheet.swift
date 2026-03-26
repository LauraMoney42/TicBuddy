// TicBuddy — NightlyRitualSheet.swift
// tb-mvp2-018: Caregiver-facing nightly ritual guide (5-10 min), shown after child
// submits their evening check-in.
//
// Three phases per CBIT protocol:
//   Phase 1: Brief debrief (2-3 min) — one opening question, reflect back, no evaluation
//   Phase 2: Reward update (1-2 min) — child leads, parent names specific behavior per point
//   Phase 3: Calendar update (1 min) — log today in practice calendar
//   Sunday: Weekly review (10-15 min) — bonus phase shown on Sundays
//
// PRIVACY: Only reads EveningCheckInSummary (mood + practice flag). Never reads journal text.

import SwiftUI

// MARK: - Nightly Ritual Sheet

struct NightlyRitualSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let checkIn: EveningCheckInSummary
    let childName: String
    let totalPoints: Int

    @State private var currentPhase: RitualPhase = .overview
    @State private var phase1Done = false
    @State private var phase2Done = false
    @State private var phase3Done = false

    private var isSunday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 1
    }

    private var allPhasesComplete: Bool {
        phase1Done && phase2Done && phase3Done
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    switch currentPhase {
                    case .overview:
                        overviewSection
                    case .phase1:
                        Phase1View(childName: childName, checkIn: checkIn) {
                            withAnimation { phase1Done = true; currentPhase = .phase2 }
                        }
                    case .phase2:
                        Phase2View(childName: childName, totalPoints: totalPoints, checkIn: checkIn) {
                            withAnimation { phase2Done = true; currentPhase = .phase3 }
                        }
                    case .phase3:
                        Phase3View(dataService: dataService) {
                            withAnimation { phase3Done = true
                                currentPhase = isSunday ? .weeklyReview : .complete
                            }
                        }
                    case .weeklyReview:
                        WeeklyReviewView(childName: childName, dataService: dataService) {
                            withAnimation { currentPhase = .complete }
                        }
                    case .complete:
                        RitualCompleteView(childName: childName) { dismiss() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(currentPhase == .overview ? "🌙 Nightly Ritual" : currentPhase.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(spacing: 20) {

            // Child's check-in card
            CheckInSummaryCard(checkIn: checkIn, childName: childName)

            // Phase list
            VStack(spacing: 12) {
                Text("Tonight's ritual")
                    .font(.headline.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                PhaseRow(
                    number: 1, title: "Brief Debrief",
                    duration: "2–3 min", isDone: phase1Done,
                    description: "One question, reflect back, no evaluation"
                )
                PhaseRow(
                    number: 2, title: "Reward Update",
                    duration: "1–2 min", isDone: phase2Done,
                    description: "Child leads, you name the specific behavior"
                )
                PhaseRow(
                    number: 3, title: "Calendar Update",
                    duration: "1 min", isDone: phase3Done,
                    description: "Log today's practice together"
                )
                if isSunday {
                    PhaseRow(
                        number: 4, title: "Weekly Review",
                        duration: "10–15 min", isDone: false,
                        description: "Sunday check-in on the full week"
                    )
                }
            }
            .padding(18)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)

            // Start button
            Button {
                withAnimation { currentPhase = .phase1 }
            } label: {
                Text("Start ritual →")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .cornerRadius(16)
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Ritual Phases

enum RitualPhase {
    case overview, phase1, phase2, phase3, weeklyReview, complete

    var title: String {
        switch self {
        case .overview:     return "🌙 Nightly Ritual"
        case .phase1:       return "Phase 1: Brief Debrief"
        case .phase2:       return "Phase 2: Reward Update"
        case .phase3:       return "Phase 3: Calendar"
        case .weeklyReview: return "Sunday Weekly Review"
        case .complete:     return "All done! 🌟"
        }
    }
}

// MARK: - Phase 1: Brief Debrief (2-3 min)

private struct Phase1View: View {
    let childName: String
    let checkIn: EveningCheckInSummary
    let onDone: () -> Void

    private var openingQuestion: String {
        switch checkIn.moodEmoji {
        case "😊": return "You seemed to have a pretty good day — what was the best part?"
        case "😣": return "Looks like today was tough. What was the hardest moment?"
        default:   return "How did today feel overall? What stood out?"
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            TimerBadge(minutes: "2–3 min")

            RitualCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Opening Question")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Text("\"\(openingQuestion)\"")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    GuidanceRow(emoji: "👂", text: "Listen fully before responding. Let \(childName) finish their thought.")
                    GuidanceRow(emoji: "🪞", text: "Reflect back what you heard: \"So it sounds like...\"")
                    GuidanceRow(emoji: "🚫", text: "No evaluation. No \"you should have...\" Acknowledge only.")
                }
            }

            CoachingTip(text: "Children who feel heard without judgment are 3× more likely to open up tomorrow. The goal is connection, not problem-solving.")

            PhaseNextButton(label: "Phase 1 done →", action: onDone)
        }
    }
}

// MARK: - Phase 2: Reward Update (1-2 min)

private struct Phase2View: View {
    let childName: String
    let totalPoints: Int
    let checkIn: EveningCheckInSummary
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            TimerBadge(minutes: "1–2 min")

            RitualCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Text("⭐️").font(.title)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current total: \(totalPoints) points")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                            Text("Tier \(totalPoints / 10) — \(10 - (totalPoints % 10)) to next")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    if checkIn.practiceDoneToday {
                        GuidanceRow(emoji: "🎯",
                            text: "\(childName) practiced today! Name exactly what you saw: \"I noticed you pressed your fingers together instead of twitching — that's the move.\"")
                        GuidanceRow(emoji: "💡",
                            text: "Specific praise matters more than general praise. Point to the exact behavior.")
                    } else {
                        GuidanceRow(emoji: "💙",
                            text: "No practice today — that's okay. Tics wax and wane. Acknowledge the check-in itself: \"Thanks for being honest.\"")
                        GuidanceRow(emoji: "🔄",
                            text: "Ask: \"Is there anything that made practicing hard today? No pressure — just curious.\"")
                    }

                    GuidanceRow(emoji: "👦",
                        text: "Let \(childName) lead: \"Do you want to tell me about your points, or should I?\"")
                }
            }

            CoachingTip(text: "Child-led reward conversations build intrinsic motivation. When the child narrates their own success, they own it.")

            PhaseNextButton(label: "Phase 2 done →", action: onDone)
        }
    }
}

// MARK: - Phase 3: Calendar Update (1 min)

private struct Phase3View: View {
    let dataService: TicDataService
    let onDone: () -> Void

    @State private var selectedStatus: PracticeStatus? = nil

    private var todayKey: String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }

    private var alreadyLogged: PracticeStatus? {
        dataService.familyUnit.sharedData.practiceCalendar[todayKey]
    }

    var body: some View {
        VStack(spacing: 20) {
            TimerBadge(minutes: "1 min")

            RitualCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Log today's practice")
                        .font(.headline.bold())

                    if let status = alreadyLogged {
                        HStack(spacing: 10) {
                            Text(statusEmoji(status)).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Already logged: \(statusLabel(status))")
                                    .font(.subheadline.bold())
                                Button("Change") {
                                    logPractice(.fullPractice)
                                }
                                .font(.caption)
                                .foregroundColor(Color(hex: "667EEA"))
                            }
                        }
                    } else {
                        Text("How did today's practice go?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            CalendarLogButton(label: "✅ Full", color: .green) { logPractice(.fullPractice) }
                            CalendarLogButton(label: "🌤 Partial", color: .orange) { logPractice(.partial) }
                            CalendarLogButton(label: "💙 Hard day", color: Color(hex: "667EEA")) { logPractice(.hardDay) }
                        }
                    }
                }
            }

            PhaseNextButton(
                label: alreadyLogged != nil ? "Phase 3 done →" : "Skip calendar →",
                action: onDone
            )
        }
    }

    private func logPractice(_ status: PracticeStatus) {
        dataService.familyUnit.sharedData.practiceCalendar[todayKey] = status
        dataService.familyUnit.sharedData.lastModified = Date()
        dataService.saveFamilyUnit()
        selectedStatus = status
    }

    private func statusEmoji(_ s: PracticeStatus) -> String {
        switch s { case .fullPractice: return "✅"; case .partial: return "🌤"; case .hardDay: return "💙" }
    }
    private func statusLabel(_ s: PracticeStatus) -> String {
        switch s { case .fullPractice: return "Full practice"; case .partial: return "Partial"; case .hardDay: return "Hard day" }
    }
}

// MARK: - Sunday Weekly Review (10-15 min)

private struct WeeklyReviewView: View {
    let childName: String
    let dataService: TicDataService
    let onDone: () -> Void

    private var weekSummary: (full: Int, partial: Int, hard: Int, total: Int) {
        let cal = Calendar.current
        let today = Date()
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let fmt = ISO8601DateFormatter()
        var full = 0, partial = 0, hard = 0
        for day in days {
            let key = fmt.string(from: cal.startOfDay(for: day))
            switch dataService.familyUnit.sharedData.practiceCalendar[key] {
            case .fullPractice: full += 1
            case .partial: partial += 1
            case .hardDay: hard += 1
            default: break
            }
        }
        return (full, partial, hard, full + partial + hard)
    }

    var body: some View {
        VStack(spacing: 20) {
            TimerBadge(minutes: "10–15 min")

            RitualCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("This week's practice")
                        .font(.headline.bold())

                    HStack(spacing: 16) {
                        WeekStat(emoji: "✅", count: weekSummary.full, label: "Full")
                        WeekStat(emoji: "🌤", count: weekSummary.partial, label: "Partial")
                        WeekStat(emoji: "💙", count: weekSummary.hard, label: "Hard days")
                    }

                    Divider()

                    Text("Weekly review questions")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    GuidanceRow(emoji: "📈", text: "What progress did you notice this week — even tiny improvements?")
                    GuidanceRow(emoji: "🧩", text: "Were there any patterns? (Time of day, stress, certain situations?)")
                    GuidanceRow(emoji: "🎯", text: "What's the plan for next week? Same CR, or is it time to discuss with a therapist?")
                    GuidanceRow(emoji: "🏆", text: "Name one specific thing \(childName) did well this week. Be exact.")
                }
            }

            CoachingTip(text: "Weekly reviews work best when they feel collaborative, not evaluative. Aim for a 4:1 ratio of positive observations to concerns.")

            PhaseNextButton(label: "Weekly review done →", action: onDone)
        }
    }
}

// MARK: - Completion Screen

private struct RitualCompleteView: View {
    let childName: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("🌙")
                .font(.system(size: 72))
            Text("Ritual complete!")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("Great job showing up for \(childName) tonight. Consistent connection is the bedrock of CBIT success.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Spacer()
            Button(action: onDone) {
                Text("Done for tonight")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "667EEA"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Reusable sub-components

private struct CheckInSummaryCard: View {
    let checkIn: EveningCheckInSummary
    let childName: String

    private var energyLabel: String {
        switch checkIn.energyLevel {
        case 1: return "🔋 Low"
        case 3: return "🚀 High"
        default: return "⚡️ Medium"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(childName)'s check-in")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text(checkIn.moodEmoji).font(.system(size: 36))
                    Text("Mood").font(.caption2).foregroundColor(.secondary)
                }
                VStack(spacing: 4) {
                    Text(energyLabel).font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text("Energy").font(.caption2).foregroundColor(.secondary)
                }
                Spacer()
                VStack(spacing: 4) {
                    Text(checkIn.practiceDoneToday ? "✅" : "💙").font(.system(size: 28))
                    Text(checkIn.practiceDoneToday ? "Practiced" : "Skipped today")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

private struct RitualCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

private struct GuidanceRow: View {
    let emoji: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).font(.system(size: 18))
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct CoachingTip: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill").foregroundColor(.orange).font(.system(size: 13)).padding(.top, 2)
            Text(text).font(.caption).foregroundColor(.secondary).italic().fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color.orange.opacity(0.07))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.2), lineWidth: 1))
    }
}

private struct TimerBadge: View {
    let minutes: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "timer").font(.caption.bold())
            Text(minutes).font(.caption.bold())
        }
        .foregroundColor(Color(hex: "764BA2"))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: "764BA2").opacity(0.1))
        .cornerRadius(20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PhaseRow: View {
    let number: Int
    let title: String
    let duration: String
    let isDone: Bool
    let description: String
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(isDone ? Color.green : Color(hex: "667EEA").opacity(0.15)).frame(width: 32, height: 32)
                Text(isDone ? "✓" : "\(number)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isDone ? .white : Color(hex: "667EEA"))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(title).font(.subheadline.bold())
                    Spacer()
                    Text(duration).font(.caption).foregroundColor(.secondary)
                }
                Text(description).font(.caption).foregroundColor(.secondary)
            }
        }
    }
}

private struct PhaseNextButton: View {
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(16)
        }
    }
}

private struct WeekStat: View {
    let emoji: String
    let count: Int
    let label: String
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2)
            Text("\(count)").font(.system(size: 20, weight: .heavy, design: .rounded))
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
}

private struct CalendarLogButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption.bold()).foregroundColor(color)
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(color.opacity(0.1)).cornerRadius(10)
        }.buttonStyle(.plain)
    }
}
