// TicBuddy — ChildModeAdolescentView.swift
// Child-facing home screen for the Adolescent sub-mode: ages 13–17 (youngTeen + teen).
// tb-mvp2-009
//
// Design rules for this age group:
//   - Privacy-first: "Your caregiver sees summary only — not your notes or logs."
//   - Peer tone, not parental. No "Amazing!" popups — understated acknowledgment.
//   - Private journal: notes on tic logs, stored per child UUID, never shown to caregiver.
//   - Trigger tagging: one-tap context tags on tic logs (stress, tired, school, social).
//   - 7-day insight strip: shows their own redirect trend (data ownership).
//   - Dark theme: cool slate/navy, not bright child palette.
//   - Full text Ziggy chat with remaining exchange count visible.
//   - Urge slider (1–5) + optional private note on every log.
//   - Per AgeGroup.parentSeesDetailedLogs == false: caregiver gets summary only.

import SwiftUI

// MARK: - Private Journal (adolescent-only, keyed per child UUID)

struct AdolescentJournalEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String
    var ticLogID: UUID?   // optional link to the TicEntry that prompted this note
}

/// Lightweight local store — UserDefaults, keyed per child, never leaves device.
/// Caregiver views never read this key.
final class AdolescentJournalStore {
    static func key(for childID: UUID) -> String { "teen_journal_\(childID.uuidString)" }

    static func load(for childID: UUID) -> [AdolescentJournalEntry] {
        guard let data = UserDefaults.standard.data(forKey: key(for: childID)),
              let entries = try? JSONDecoder().decode([AdolescentJournalEntry].self, from: data)
        else { return [] }
        return entries
    }

    static func save(_ entries: [AdolescentJournalEntry], for childID: UUID) {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: key(for: childID))
        }
    }

    static func append(_ entry: AdolescentJournalEntry, for childID: UUID) {
        var current = load(for: childID)
        current.insert(entry, at: 0)
        // Keep last 200 entries max
        if current.count > 200 { current = Array(current.prefix(200)) }
        save(current, for: childID)
    }
}

// MARK: - Trigger Tags

enum TicTriggerTag: String, CaseIterable {
    case stressed   = "😤 Stressed"
    case tired      = "😴 Tired"
    case school     = "🏫 School"
    case social     = "👥 Social"
    case excited    = "⚡️ Excited"
    case screen     = "📱 Screens"
    case exercise   = "🏃 Exercise"
    case other      = "❓ Other"

    var hashtag: String { "#" + rawValue.lowercased().components(separatedBy: " ").last! }
}

// MARK: - Teen Crisis Detector (tb-mvp2-015)
//
// Client-side keyword scan for adolescent private journal entries and tic-log notes.
// Fires ONLY on content typed by the teen — never reads caregiver content.
// On detection: shows AdolCrisisFlagSheet (resources + warm check-in) to the teen.
// Does NOT alert parent. Entry is still saved privately as-is.

struct TeenCrisisDetector {
    // Phrases that indicate acute distress or self-harm ideation.
    // Kept intentionally broad — false positives are fine; missed signals are not.
    private static let crisisPhrases: [String] = [
        "hurt myself", "harm myself", "want to die", "want to be dead",
        "kill myself", "killing myself", "end my life", "end it all",
        "suicidal", "suicide", "self harm", "self-harm",
        "cut myself", "cutting myself", "don't want to live",
        "no reason to live", "nobody would care", "nobody cares if i die",
        "better off dead", "better off without me", "i hate myself",
        "can't go on", "can't do this anymore", "give up on life",
        "not worth living", "wish i was dead", "wish i wasn't here"
    ]

    /// Returns true if `text` contains any crisis phrase (case-insensitive).
    static func isCrisis(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return crisisPhrases.contains { normalized.contains($0) }
    }
}

// MARK: - Adolescent Mode Home

struct ChildModeAdolescentView: View {
    @EnvironmentObject var dataService: TicDataService

    @State private var showTicLogger = false
    @State private var showJournal = false
    @State private var showZiggy = false
    @State private var showCrisisFlag = false       // tb-mvp2-015
    @State private var showMilestone = false        // tb-mvp2-016
    @State private var showEveningCheckIn = false   // tb-mvp2-018
    @State private var logFeedback: String? = nil  // brief inline feedback, auto-clears

    private var isEveningTime: Bool { Calendar.current.component(.hour, from: Date()) >= 17 }

    private var child: ChildProfile? { dataService.familyUnit.activeChild }
    private var childID: UUID { child?.id ?? dataService.userProfile.id }
    private var profile: UserProfile { dataService.activeUserProfile }
    private var phase: CBITPhase { profile.recommendedPhase }
    private var nickname: String { child?.nickname ?? profile.name }
    private var firstName: String {
        nickname.split(separator: " ").first.map(String.init) ?? nickname
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                // ── Dark gradient background ───────────────────────────────────
                LinearGradient(
                    colors: [Color(hex: "0D1117"), Color(hex: "1A1F36")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {

                        // ── Header ──────────────────────────────────────────────
                        AdolHeader(
                            firstName: firstName,
                            streak: dataService.currentStreak,
                            phase: phase
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        // ── Privacy pill ────────────────────────────────────────
                        PrivacyPill()
                            .padding(.horizontal, 20)

                        // ── Today's snapshot ─────────────────────────────────────
                        AdolTodayCard(
                            noticed: dataService.totalTicsToday(),
                            caught: dataService.entries(for: Date()).filter { $0.outcome == .caught }.count,
                            redirected: dataService.redirectionsToday(),
                            phase: phase
                        )
                        .padding(.horizontal, 20)

                        // ── 7-day insight strip ──────────────────────────────────
                        AdolWeekStrip(dataService: dataService)
                            .padding(.horizontal, 20)

                        // ── Competing response card ──────────────────────────────
                        if phase != .week1Awareness, let targetTic = child?.currentTargetTic {
                            AdolCRCard(ticEntry: targetTic)
                                .padding(.horizontal, 20)
                        } else if phase == .week1Awareness {
                            AdolAwarenessCard()
                                .padding(.horizontal, 20)
                        }

                        // ── Ziggy + Journal shortcuts ────────────────────────────
                        HStack(spacing: 14) {
                            AdolShortcut(
                                icon: "🤖",
                                title: "Ziggy",
                                subtitle: "Chat about tics",
                                action: { showZiggy = true }
                            )
                            AdolShortcut(
                                icon: "📓",
                                title: "My Journal",
                                subtitle: "Private — just yours",
                                action: { showJournal = true }
                            )
                        }
                        .padding(.horizontal, 20)

                        // ── Evening check-in (tb-mvp2-018) — shown after 5pm ─────
                        if isEveningTime, dataService.todayEveningCheckIn() == nil {
                            Button {
                                showEveningCheckIn = true
                            } label: {
                                HStack(spacing: 10) {
                                    Text("🌙").font(.system(size: 18))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Evening check-in")
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                        Text("30 sec • your caregiver sees mood only")
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundColor(Color(hex: "8899AA"))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(Color(hex: "8899AA"))
                                }
                                .padding(14)
                                .background(Color(hex: "1E2540"))
                                .cornerRadius(14)
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }

                        // ── Inline feedback (brief, auto-clears) ────────────────
                        if let feedback = logFeedback {
                            Text(feedback)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "A8D8A8"))
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Spacer for FAB
                        Color.clear.frame(height: 80)
                    }
                }

                // ── Floating log button ────────────────────────────────────────
                AdolLogFAB { showTicLogger = true }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
            }
            .navigationBarHidden(true)
        }
        // Tic logger
        .sheet(isPresented: $showTicLogger) {
            AdolTicLogSheet(childProfile: child, phase: phase) { entry, journalNote, triggerTags in
                logTic(entry, journalNote: journalNote, triggerTags: triggerTags)
                showTicLogger = false
            }
        }
        // Private journal
        .sheet(isPresented: $showJournal) {
            AdolJournalView(childID: childID)
        }
        // Ziggy chat
        .sheet(isPresented: $showZiggy) {
            ChatView()
                .environmentObject(dataService)
        }
        // tb-mvp2-015: Teen private crisis flag — shown to teen only, does NOT alert parent
        .sheet(isPresented: $showCrisisFlag) {
            AdolCrisisFlagSheet()
        }
        // tb-mvp2-016: Milestone tier celebration (understated — peer tone for this age group)
        .sheet(isPresented: $showMilestone) {
            RewardMilestoneSheet(
                totalPoints: dataService.familyUnit.sharedData.rewardPoints,
                ageGroup: child?.ageGroup ?? .youngTeen
            )
        }
        // tb-mvp2-018: Evening check-in — teens self-initiate, shown as menu item after 5pm
        .sheet(isPresented: $showEveningCheckIn) {
            EveningCheckInSheet(childAgeGroup: child?.ageGroup ?? .youngTeen)
                .environmentObject(dataService)
        }
    }

    // MARK: - Logging

    private func logTic(
        _ entry: TicEntry,
        journalNote: String,
        triggerTags: Set<TicTriggerTag>
    ) {
        // Build note from tags + any free text
        var noteParts: [String] = triggerTags.map { $0.hashtag }
        if !journalNote.trimmingCharacters(in: .whitespaces).isEmpty {
            noteParts.append(journalNote.trimmingCharacters(in: .whitespaces))
        }
        var entryWithNote = entry
        entryWithNote = TicEntry(
            id: entry.id,
            date: entry.date,
            category: entry.category,
            motorType: entry.motorType,
            vocalType: entry.vocalType,
            customLabel: entry.customLabel,
            outcome: entry.outcome,
            urgeStrength: entry.urgeStrength,
            note: noteParts.isEmpty ? nil : noteParts.joined(separator: " ")
        )
        dataService.addTicEntry(entryWithNote)

        // tb-mvp2-016: Award points — redirected = 2pts, caught/noticed = 1pt, ticHappened = 0
        // Understated for teens: no point announcement in feedback text, milestone sheet handles it
        let pointsDelta: Int
        switch entry.outcome {
        case .redirected:  pointsDelta = 2
        case .caught:      pointsDelta = 1
        case .noticed:     pointsDelta = 1
        case .ticHappened: pointsDelta = 0
        }
        let milestone = dataService.awardPoints(pointsDelta)
        if milestone {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showMilestone = true }
        }

        // Save private journal note if typed
        if !journalNote.trimmingCharacters(in: .whitespaces).isEmpty {
            let journalEntry = AdolescentJournalEntry(
                text: journalNote,
                ticLogID: entry.id
            )
            AdolescentJournalStore.append(journalEntry, for: childID)

            // tb-mvp2-015: Crisis flag — check note for acute distress signals.
            // Entry already saved privately. Sheet shown to teen only. Parent never notified.
            if TeenCrisisDetector.isCrisis(journalNote) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    showCrisisFlag = true
                }
            }
        }

        // Understated feedback (peer tone — no "Amazing!" for teens)
        let feedback: String
        switch entry.outcome {
        case .redirected:  feedback = "Redirected. Your brain just made that pathway stronger. 💪"
        case .caught:      feedback = "Caught the urge before the tic. That's awareness working."
        case .noticed:     feedback = "Logged. Noticing is the whole point right now."
        case .ticHappened: feedback = "Logged. Tics wax and wane — this is just data."
        }

        withAnimation(.easeOut(duration: 0.25)) { logFeedback = feedback }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeOut(duration: 0.3)) { logFeedback = nil }
        }
    }
}

// MARK: - Header

private struct AdolHeader: View {
    let firstName: String
    let streak: Int
    let phase: CBITPhase

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning, \(firstName)." }
        if hour < 17 { return "Hey, \(firstName)." }
        return "Evening, \(firstName)."
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(phase.title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "8899AA"))
                    .lineLimit(1)
            }

            Spacer()

            // Streak — shown only when > 0, understated
            if streak > 0 {
                HStack(spacing: 5) {
                    Text("🔥")
                    Text("\(streak)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)
            }
        }
    }
}

// MARK: - Privacy Pill

private struct PrivacyPill: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "8899AA"))
            Text("Your notes and logs are private. Caregiver sees summary only.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.06))
        .cornerRadius(20)
    }
}

// MARK: - Today Card

private struct AdolTodayCard: View {
    let noticed: Int
    let caught: Int
    let redirected: Int
    let phase: CBITPhase

    private var redirectRate: String {
        let total = noticed + caught + redirected
        guard total > 0, phase != .week1Awareness else { return "—" }
        let pct = Int(Double(redirected + caught) / Double(total) * 100)
        return "\(pct)%"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 0) {
                AdolStatBlock(value: noticed, label: "noticed", emoji: "👀")
                Divider()
                    .frame(height: 36)
                    .overlay(Color.white.opacity(0.12))
                AdolStatBlock(value: caught, label: "caught", emoji: "⚡️")
                Divider()
                    .frame(height: 36)
                    .overlay(Color.white.opacity(0.12))
                AdolStatBlock(value: redirected, label: "redirected", emoji: "↩️")
                Divider()
                    .frame(height: 36)
                    .overlay(Color.white.opacity(0.12))

                VStack(spacing: 2) {
                    Text(redirectRate)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(
                            redirectRate == "—" ? Color(hex: "8899AA")
                            : Color(hex: "A8D8A8")
                        )
                    Text("rate")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(18)
        .background(Color(hex: "1E2540"))
        .cornerRadius(18)
    }
}

private struct AdolStatBlock: View {
    let value: Int
    let label: String
    let emoji: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 7-Day Insight Strip

private struct AdolWeekStrip: View {
    @ObservedObject var dataService: TicDataService

    /// Last 7 days' redirect counts — most recent on right
    private var weekData: [(label: String, redirected: Int, total: Int)] {
        let cal = Calendar.current
        return (0..<7).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: Date()) ?? Date()
            let entries = dataService.entries(for: day)
            let shortLabel = offset == 0 ? "Today"
                : cal.shortWeekdaySymbols[cal.component(.weekday, from: day) - 1]
            return (shortLabel, entries.filter { $0.outcome == .redirected }.count, entries.count)
        }
    }

    private var maxTotal: Int {
        max(1, weekData.map { $0.total }.max() ?? 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("7-Day Trend")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weekData, id: \.label) { day in
                    VStack(spacing: 5) {
                        // Stacked bar: redirected (teal) over total (gray)
                        ZStack(alignment: .bottom) {
                            // Total bar (background)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.1))
                                .frame(
                                    width: 28,
                                    height: max(4, CGFloat(day.total) / CGFloat(maxTotal) * 56)
                                )
                            // Redirected bar (foreground)
                            if day.redirected > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(hex: "667EEA").opacity(0.8))
                                    .frame(
                                        width: 28,
                                        height: max(4, CGFloat(day.redirected) / CGFloat(maxTotal) * 56)
                                    )
                            }
                        }
                        .frame(height: 56, alignment: .bottom)

                        Text(day.label.prefix(3))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "8899AA"))
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: "667EEA").opacity(0.8))
                        .frame(width: 10, height: 10)
                    Text("redirected")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.1))
                        .frame(width: 10, height: 10)
                    Text("total tics")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                }
            }
        }
        .padding(18)
        .background(Color(hex: "1E2540"))
        .cornerRadius(18)
    }
}

// MARK: - Awareness Card (Week 1)

private struct AdolAwarenessCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("🔍")
                    .font(.system(size: 20))
                Text("Right now: just notice")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            Text("This phase is pure awareness — log every tic you catch, no matter what. You're literally training the part of your brain that watches for tics. That awareness is what makes competing responses possible later.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(Color(hex: "1E2540"))
        .cornerRadius(18)
    }
}

// MARK: - Competing Response Card

private struct AdolCRCard: View {
    let ticEntry: TicHierarchyEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Competing Response")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text("For: \(ticEntry.ticName)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3)) { isExpanded.toggle() }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "8899AA"))
                        .padding(8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
            }

            // CR text
            Text(ticEntry.competingResponse.isEmpty
                 ? "Your therapist or parent will set this up soon."
                 : ticEntry.competingResponse)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(ticEntry.competingResponse.isEmpty ? Color(hex: "8899AA") : .white)
                .fixedSize(horizontal: false, vertical: true)

            // Expanded: urge description + science
            if isExpanded {
                Divider().overlay(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 10) {
                    if !ticEntry.urgeDescription.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your urge signal:")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                                .textCase(.uppercase)
                                .tracking(0.5)
                            Text("\"\(ticEntry.urgeDescription)\"")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Why this actually works:")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "8899AA"))
                            .textCase(.uppercase)
                            .tracking(0.5)
                        Text("Competing responses activate motor pathways that physically conflict with the tic. Over time (weeks), your brain strengthens the competing pathway and the tic urge weakens. This is real neuroplasticity — not willpower.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundColor(.white.opacity(0.65))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Distress change if tracked
                    if ticEntry.baselineDistress > 0 {
                        HStack(spacing: 8) {
                            Label("Baseline: \(ticEntry.baselineDistress)/10", systemImage: "arrow.down.circle")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                            Text("→")
                                .foregroundColor(Color(hex: "8899AA"))
                            Label("Now: \(ticEntry.currentDistress)/10", systemImage: "chart.line.downtrend.xyaxis")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(
                                    ticEntry.currentDistress < ticEntry.baselineDistress
                                    ? Color(hex: "A8D8A8") : Color(hex: "8899AA")
                                )
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(Color(hex: "1E2540"))
        .cornerRadius(18)
    }
}

// MARK: - Shortcut Tiles (Ziggy + Journal)

private struct AdolShortcut: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 24))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                }
                Spacer()
            }
            .padding(16)
            .background(Color(hex: "1E2540"))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Log Button

private struct AdolLogFAB: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Log tic")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundColor(Color(hex: "0D1117"))
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.white)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.spring(response: 0.15)) { isPressed = true } }
                .onEnded   { _ in withAnimation(.spring(response: 0.25)) { isPressed = false } }
        )
    }
}

// MARK: - Tic Log Sheet

struct AdolTicLogSheet: View {
    let childProfile: ChildProfile?
    let phase: CBITPhase
    /// Returns: entry, optional private journal note, selected trigger tags
    let onLog: (TicEntry, String, Set<TicTriggerTag>) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTicName = ""
    @State private var selectedCategory: TicCategory = .motor
    @State private var selectedOutcome: TicOutcome = .noticed
    @State private var urgeStrength: Int = 3
    @State private var privateNote = ""
    @State private var selectedTriggers: Set<TicTriggerTag> = []

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
                Color(hex: "0D1117").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // ── Which tic? ──────────────────────────────────────────
                        LogSection(title: "Which tic?") {
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
                                            Text(opt.emoji).font(.system(size: 16))
                                            Text(opt.name)
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(selectedTicName == opt.name
                                                      ? Color(hex: "667EEA").opacity(0.35)
                                                      : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedTicName == opt.name
                                                        ? Color(hex: "667EEA")
                                                        : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // ── What happened? ──────────────────────────────────────
                        LogSection(title: "What happened?") {
                            let outcomes: [TicOutcome] = phase == .week1Awareness
                                ? [.noticed, .ticHappened]
                                : [.redirected, .caught, .noticed, .ticHappened]

                            VStack(spacing: 8) {
                                ForEach(outcomes, id: \.self) { outcome in
                                    Button {
                                        withAnimation(.spring(response: 0.2)) {
                                            selectedOutcome = outcome
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Text(outcome.emoji).font(.system(size: 18))
                                            Text(outcome.rawValue)
                                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Image(systemName: selectedOutcome == outcome
                                                  ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 20))
                                                .foregroundColor(
                                                    selectedOutcome == outcome
                                                    ? Color(hex: "667EEA") : Color.white.opacity(0.25)
                                                )
                                        }
                                        .padding(14)
                                        .background(
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(selectedOutcome == outcome
                                                      ? Color(hex: "667EEA").opacity(0.2)
                                                      : Color.white.opacity(0.06))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // ── Urge strength ───────────────────────────────────────
                        LogSection(title: "Urge strength: \(urgeStrength)/5") {
                            HStack(spacing: 0) {
                                ForEach(1...5, id: \.self) { level in
                                    Button {
                                        withAnimation(.spring(response: 0.2)) { urgeStrength = level }
                                    } label: {
                                        Text(level <= urgeStrength ? "●" : "○")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundColor(
                                                level <= urgeStrength
                                                ? Color(hex: "667EEA")
                                                : Color.white.opacity(0.2)
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        // ── Trigger tags ────────────────────────────────────────
                        LogSection(title: "Context (optional)") {
                            FlowTagPicker(
                                tags: TicTriggerTag.allCases,
                                selected: $selectedTriggers
                            )
                        }

                        // ── Private note ────────────────────────────────────────
                        LogSection(title: "Private note (optional)") {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("What was going on? Only you see this.", text: $privateNote, axis: .vertical)
                                    .lineLimit(3...6)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(14)
                                    .background(Color.white.opacity(0.07))
                                    .cornerRadius(14)
                                HStack(spacing: 5) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                    Text("Saved to your private journal — not visible to your caregiver.")
                                        .font(.system(size: 11, design: .rounded))
                                }
                                .foregroundColor(Color(hex: "8899AA"))
                            }
                        }

                        // ── Log button ──────────────────────────────────────────
                        Button {
                            guard !selectedTicName.isEmpty else { return }
                            let entry = TicEntry(
                                category: selectedCategory,
                                customLabel: selectedTicName,
                                outcome: selectedOutcome,
                                urgeStrength: urgeStrength
                            )
                            onLog(entry, privateNote, selectedTriggers)
                        } label: {
                            Text(selectedTicName.isEmpty ? "Pick a tic first" : "Log it")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(selectedTicName.isEmpty ? Color(hex: "8899AA") : Color(hex: "0D1117"))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    selectedTicName.isEmpty
                                    ? Color.white.opacity(0.1)
                                    : Color.white
                                )
                                .cornerRadius(28)
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedTicName.isEmpty)
                        .padding(.bottom, 32)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Log a Tic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "8899AA"))
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Log Sheet Section Helper

private struct LogSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
                .textCase(.uppercase)
                .tracking(0.7)
            content()
        }
    }
}

// MARK: - Flow Tag Picker

private struct FlowTagPicker: View {
    let tags: [TicTriggerTag]
    @Binding var selected: Set<TicTriggerTag>

    var body: some View {
        // Simple wrapping layout using LazyVGrid
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                let isOn = selected.contains(tag)
                Button {
                    withAnimation(.spring(response: 0.2)) {
                        if isOn { selected.remove(tag) }
                        else { selected.insert(tag) }
                    }
                } label: {
                    Text(tag.rawValue)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isOn ? .white : Color(hex: "8899AA"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            isOn ? Color(hex: "667EEA").opacity(0.35) : Color.white.opacity(0.07)
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isOn ? Color(hex: "667EEA") : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Private Journal View

struct AdolJournalView: View {
    let childID: UUID
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [AdolescentJournalEntry] = []
    @State private var newEntryText = ""
    @State private var showCrisisFlag = false   // tb-mvp2-015
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1117").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Write new entry
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("What's on your mind?", text: $newEntryText, axis: .vertical)
                            .lineLimit(2...5)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(.white)
                            .focused($focused)
                            .padding(14)
                            .background(Color(hex: "1E2540"))
                            .cornerRadius(14)

                        HStack {
                            HStack(spacing: 5) {
                                Image(systemName: "lock.fill").font(.system(size: 10))
                                Text("Only visible to you")
                                    .font(.system(size: 11, design: .rounded))
                            }
                            .foregroundColor(Color(hex: "8899AA"))
                            Spacer()
                            Button("Save") {
                                let trimmed = newEntryText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                let entry = AdolescentJournalEntry(text: trimmed)
                                AdolescentJournalStore.append(entry, for: childID)
                                entries.insert(entry, at: 0)
                                // tb-mvp2-015: Crisis flag — scan before clearing text
                                let needsCrisisFlag = TeenCrisisDetector.isCrisis(trimmed)
                                newEntryText = ""
                                focused = false
                                if needsCrisisFlag {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        showCrisisFlag = true
                                    }
                                }
                            }
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(
                                newEntryText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color(hex: "8899AA") : Color.white
                            )
                            .disabled(newEntryText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    .padding(16)

                    Divider().overlay(Color.white.opacity(0.08))

                    // Past entries
                    if entries.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Text("📓")
                                .font(.system(size: 48))
                            Text("Your journal is empty.")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                            Text("Log tics with notes, or write here anytime.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA").opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(entries) { entry in
                                    JournalEntryRow(entry: entry)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("My Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            entries = AdolescentJournalStore.load(for: childID)
        }
        // tb-mvp2-015: Crisis flag sheet — teen-only, private
        .sheet(isPresented: $showCrisisFlag) {
            AdolCrisisFlagSheet()
        }
    }
}

private struct JournalEntryRow: View {
    let entry: AdolescentJournalEntry

    private var timeLabel: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.date, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timeLabel)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color(hex: "8899AA"))
            Text(entry.text)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(hex: "1E2540"))
        .cornerRadius(14)
    }
}

// MARK: - Teen Crisis Flag Sheet (tb-mvp2-015)
//
// Shown privately to the teen when crisis-signal keywords are detected in their
// journal or tic-log notes. Entry was already saved — this is a quiet check-in,
// not a block or alarm. Parent is NEVER notified. Tone: warm, non-clinical, peer.

struct AdolCrisisFlagSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D1117").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // Icon + headline
                        VStack(spacing: 12) {
                            Text("💙")
                                .font(.system(size: 64))
                                .padding(.top, 32)

                            Text("Hey — you okay?")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)

                            Text("Something in what you wrote made me want to check in.\nYour note is saved privately — only you can see it.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 8)
                        }

                        // "You're not alone" card
                        VStack(alignment: .leading, spacing: 12) {
                            Text("You don't have to carry this alone.")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("If you're going through something really hard right now, there are people who get it — and they're ready to listen, not judge.")
                                .font(.system(size: 14, design: .rounded))
                                .foregroundColor(Color(hex: "AABBCC"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .background(Color(hex: "1E2540"))
                        .cornerRadius(16)
                        .padding(.horizontal, 24)

                        // Crisis line
                        VStack(spacing: 12) {
                            CrisisResourceRow(
                                emoji: "📞",
                                title: "988 Suicide & Crisis Lifeline",
                                detail: "Call or text 988 — free, confidential, 24/7",
                                actionLabel: "Call or Text 988",
                                url: "tel:988"
                            )
                            CrisisResourceRow(
                                emoji: "💬",
                                title: "Crisis Text Line",
                                detail: "Text HOME to 741741 — text-only if calling feels hard",
                                actionLabel: "Text HOME to 741741",
                                url: "sms:741741&body=HOME"
                            )
                        }
                        .padding(.horizontal, 24)

                        // Trusted adult prompt
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Talking to someone you trust")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("A parent, counselor, coach, or any adult you feel safe with — sometimes just saying it out loud to someone who cares makes a real difference.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(Color(hex: "1A2035"))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)

                        // Privacy note
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "8899AA"))
                            Text("This check-in is private. Your caregiver was not notified.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(Color(hex: "8899AA"))
                        }
                        .padding(.horizontal, 24)

                        // Dismiss
                        Button {
                            dismiss()
                        } label: {
                            Text("I'm okay, thanks")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(hex: "1E2540"))
                                .cornerRadius(14)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "8899AA"))
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct CrisisResourceRow: View {
    let emoji: String
    let title: String
    let detail: String
    let actionLabel: String
    let url: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(emoji).font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text(detail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(Color(hex: "8899AA"))
                }
            }

            if let linkURL = URL(string: url) {
                Link(destination: linkURL) {
                    Text(actionLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "0D1117"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(Color(hex: "5B9BF0"))
                        .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "1E2540"))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    ChildModeAdolescentView()
        .environmentObject(TicDataService.shared)
}
