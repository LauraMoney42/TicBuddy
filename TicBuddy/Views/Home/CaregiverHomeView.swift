// TicBuddy — CaregiverHomeView.swift
// Caregiver-facing dashboard for the Family Unit platform (tb-mvp2-004).
//
// Shows when familyUnit.isInChildMode == false.
// Data sources:
//   familyUnit.sharedData         — reward points, practice calendar, session stage
//   familyUnit.children           — child profiles + tic hierarchies
//   activeChild.currentTargetTic  — the tic being worked on this session
//
// Routing note: TicBuddyApp / MainTabView routes here vs child mode view.
// That routing lives in tb-mvp2-003 (onboarding) — this file is the view only.

import SwiftUI

// MARK: - Caregiver Home View

struct CaregiverHomeView: View {
    @EnvironmentObject var dataService: TicDataService
    @ObservedObject private var checkInService = EveningCheckInService.shared

    /// Which child's detail card is expanded (nil = show first child by default)
    @State private var selectedChildID: UUID? = nil
    @State private var showAdvanceSession = false   // tb-mvp2-006
    @State private var showResources = false        // tb-mvp2-006
    @State private var showZiggyChat = false        // tb-mvp2-006 / tb-mvp2-010
    @State private var showPracticeLog = false      // tb-mvp2-016
    @State private var showNightlyRitual = false    // tb-mvp2-018
    @State private var showLesson1 = false          // tb-mvp2-066
    @State private var showIntakeAssessment = false // tb-mvp2-039
    @State private var showQuickTicLog = false      // tb-mvp2-067

    private var family: FamilyUnit { dataService.familyUnit }
    private var shared: SharedFamilyData { family.sharedData }

    // tb-mvp2-034: self-users manage their own tics; caregiver-framed copy must be suppressed.
    private var isSelfUser: Bool { family.accountType == .selfUser }

    /// The child whose detail is currently shown — first child if none selected
    private var focusedChild: ChildProfile? {
        if let id = selectedChildID { return family.children.first { $0.id == id } }
        return family.children.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // ── Multi-child picker (only shown when 2+ children) ───────
                    if family.children.count > 1 {
                        ChildSelectorStrip(
                            children: family.children,
                            selectedID: $selectedChildID
                        )
                        .padding(.horizontal, 16)
                    }

                    // ── Evening check-in prompt (tb-mvp2-018) ─────────────────
                    // Shown after the reminder hour when today's practice isn't logged.
                    if checkInService.shouldShowEveningPrompt(practiceCalendar: shared.practiceCalendar) {
                        EveningCheckInBanner {
                            // Tap → scroll to TodayPracticeCard (open practice log sheet)
                            showPracticeLog = true
                        }
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    // ── Session Stage Card ─────────────────────────────────────
                    // tb-mvp2-142: Card is tappable for Session 1 — launches LessonSlideView.
                    // Future sessions will author their own lessons; gate on .session1 for now.
                    let cardStage = focusedChild?.sessionStage ?? shared.currentSessionStage
                    Button {
                        if cardStage == .session1,
                           let lesson1 = CBITLessonService.lesson(for: .session1),
                           let slide0 = lesson1.slides.first {
                            Task { @MainActor in
                                let prefetch = Task {
                                    await ZiggyTTSService.shared.prefetchLessonSlide(
                                        text: slide0.spokenText,
                                        voiceProfile: isSelfUser ? .adolescent : .caregiver,
                                        slideIndex: 0
                                    )
                                }
                                Task { try? await Task.sleep(nanoseconds: 1_000_000_000); prefetch.cancel() }
                                await prefetch.value
                                showLesson1 = true
                            }
                        }
                    } label: {
                        CaregiverSessionCard(
                            stage: cardStage,
                            childName: focusedChild?.displayName ?? "your child",
                            isSelfUser: isSelfUser,
                            isLessonAvailable: cardStage == .session1
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    // ── Next Session Card (tb-mvp2-096) ────────────────────────
                    // Shown once the user has scheduled their weekly session.
                    // tb-mvp2-125: caregiver-only — solo teen users must not see
                    // read-ahead or future session scheduling controls.
                    if !isSelfUser {
                        NextSessionCard()
                            .padding(.horizontal, 16)
                    }

                    // ── Daily Instruction Card (tb-mvp2-005) ──────────────────
                    DailyInstructionCard(
                        instruction: DailyInstructionEngine.instruction(
                            for: focusedChild?.sessionStage ?? shared.currentSessionStage,
                            targetTic: focusedChild?.currentTargetTic,
                            practiceCalendar: shared.practiceCalendar,
                            childName: focusedChild?.displayName ?? "your child",
                            isSelfUser: isSelfUser   // tb-mvp2-034
                        )
                    )
                    .padding(.horizontal, 16)

                    // ── Today's Practice Card ──────────────────────────────────
                    // tb-mvp2-081: pass sessionStage so Week 1 shows awareness copy,
                    // not CR copy (no competing response exists yet in Session 1).
                    TodayPracticeCard(
                        sharedData: shared,
                        sessionStage: focusedChild?.sessionStage ?? shared.currentSessionStage,
                        isSelfUser: isSelfUser,
                        onLogPractice: { status in
                            logPractice(status)
                        }
                    )
                    .padding(.horizontal, 16)

                    // ── Quick Tic Counter (tb-mvp2-067) ───────────────────────
                    // Zero-friction CBIT homework: one tap logs a .noticed tic entry.
                    // Count refreshes live from dataService.ticEntries filtered to today.
                    // Reuses QuickTicCounterCard from HomeView.swift; "Add detail →"
                    // opens TicCalendarView so the user can edit category/outcome.
                    QuickTicCounterCard(
                        dataService: dataService,
                        onDetailTap: { showQuickTicLog = true }
                    )
                    .padding(.horizontal, 16)

                    // ── Reward Points Card ─────────────────────────────────────
                    RewardPointsCard(points: shared.rewardPoints)
                        .padding(.horizontal, 16)

                    // ── Evening Check-In Card (tb-mvp2-018) ───────────────────
                    // Shown when child has submitted today's check-in or it's past reminder time
                    if let checkIn = dataService.todayEveningCheckIn() {
                        NightlyRitualCard(
                            checkIn: checkIn,
                            childName: focusedChild?.displayName ?? "your child"
                        ) { showNightlyRitual = true }
                        .padding(.horizontal, 16)
                    } else if checkInService.shouldShowEveningPrompt(practiceCalendar: shared.practiceCalendar) {
                        EveningPracticePromptCard { showNightlyRitual = true }
                            .padding(.horizontal, 16)
                    }

                    // ── Read Ahead Card (tb-mvp2-026) ─────────────────────────
                    // Shows caregiver what's coming up in the next CBIT session.
                    // tb-mvp2-125: caregiver-only — solo teen users must not see
                    // future session content.
                    if !isSelfUser, let child = focusedChild {
                        let readAhead = WeeklySessionService.shared.caregiverReadAhead(
                            currentStage: child.sessionStage
                        )
                        CaregiverReadAheadCard(content: readAhead)
                            .padding(.horizontal, 16)
                    }

                    // ── Active Tic + CR Card ───────────────────────────────────
                    // Moved here (between Reward Points and CBIT Resources) per user request.
                    if let targetTic = focusedChild?.currentTargetTic {
                        ActiveTicCard(tic: targetTic, childName: focusedChild?.displayName ?? "", isSelfUser: isSelfUser)
                            .padding(.horizontal, 16)
                    } else if let child = focusedChild, child.ticHierarchy.isEmpty {
                        EmptyTicHierarchyCard(
                            childName: child.displayName,
                            isSelfUser: isSelfUser,
                            onStartAssessment: { showIntakeAssessment = true }
                        )
                        .padding(.horizontal, 16)
                    }

                    // ── CBIT Resources button ──────────────────────────────────
                    // tb-mvp2-142: Lesson 1 Replay Tile removed — lesson now launched by
                    // tapping the Session Stage Card at the top of the screen.
                    Button { showResources = true } label: {
                        HStack(spacing: 12) {
                            Text(shared.hasTherapist ? "🩺" : "📖")
                                .font(.system(size: 24))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shared.hasTherapist ? "Therapist Notes" : "CBIT Resources")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                Text(shared.hasTherapist ? "Pre-session prep" : (isSelfUser ? "Your resources" : "For caregivers"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 100)
                }
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(caregiverGreeting)
            .navigationBarTitleDisplayMode(.large)
            // tb-mvp2-006: Session advancement confirmation sheet
            // tb-mvp2-125: caregiver-only — solo teen users must not be able to
            // advance their own session stage (controlled by caregiver or therapist).
            .sheet(isPresented: $showAdvanceSession) {
                if !isSelfUser {
                    SessionAdvanceConfirmSheet(
                        currentStage: focusedChild?.sessionStage ?? shared.currentSessionStage,
                        childName: focusedChild?.displayName ?? "your child",
                        isSelfUser: isSelfUser
                    ) { confirmed in
                        if confirmed { advanceSessionStage() }
                        showAdvanceSession = false
                    }
                }
            }
            // tb-mvp2-006: CBIT resources + therapist prep sheet
            .sheet(isPresented: $showResources) {
                CBITResourcesSheet(hasTherapist: shared.hasTherapist)
            }
            // tb-mvp2-006 + tb-mvp2-010: Ziggy chat (ViewModel auto-selects .caregiver profile
            // since familyUnit.isInChildMode == false when this sheet opens)
            .sheet(isPresented: $showZiggyChat) {
                ChatView()
                    .environmentObject(dataService)
            }
            // tb-mvp2-016: Practice calendar sheet
            .sheet(isPresented: $showPracticeLog) {
                TicCalendarView()
                    .environmentObject(dataService)
            }
            // tb-mvp2-067: Quick tic counter → full log view
            .sheet(isPresented: $showQuickTicLog) {
                TicCalendarView()
                    .environmentObject(dataService)
            }
            // tb-mvp2-066: Lesson 1 replay
            // tb-mvp2-123: onFinished routes to tic assessment (same pattern as FamilyModeRouter).
            .sheet(isPresented: $showLesson1) {
                if let lesson = CBITLessonService.lesson(for: .session1) {
                    LessonSlideView(lesson: lesson, voiceProfile: .caregiver, finalCTALabel: "Update Tics →", ctaSlideTitle: "Let's Map Your Tics") {
                        showLesson1 = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showIntakeAssessment = true
                        }
                    }
                }
            }
            // tb-mvp2-039: Session 1 tic intake assessment
            .sheet(isPresented: $showIntakeAssessment) {
                if let child = focusedChild {
                    TicIntakeAssessmentView(child: child) {
                        showIntakeAssessment = false
                    }
                    .environmentObject(dataService)
                }
            }
            // tb-mvp2-018: Nightly ritual guide
            .sheet(isPresented: $showNightlyRitual) {
                if let checkIn = dataService.todayEveningCheckIn() {
                    NightlyRitualSheet(
                        checkIn: checkIn,
                        childName: focusedChild?.displayName ?? "your child",
                        totalPoints: shared.rewardPoints
                    )
                    .environmentObject(dataService)
                } else {
                    // No check-in yet — open ritual guide with a placeholder summary
                    NightlyRitualSheet(
                        checkIn: EveningCheckInSummary(moodEmoji: "😐", energyLevel: 2, practiceDoneToday: false),
                        childName: focusedChild?.displayName ?? "your child",
                        totalPoints: shared.rewardPoints
                    )
                    .environmentObject(dataService)
                }
            }
        }
    }

    // MARK: - Helpers

    private var caregiverGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = family.primaryCaregiver?.displayName ?? ""
        let greeting: String
        switch hour {
        case 5..<12: greeting = "Good morning"
        case 12..<17: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        return name.isEmpty ? greeting : "\(greeting), \(name) 👋"
    }

    /// Advance the focused child's CBIT session stage by one (tb-mvp2-006).
    /// No-op if already on Session 8 or if user is a solo teen (tb-mvp2-125).
    private func advanceSessionStage() {
        guard !isSelfUser else { return }
        guard let child = focusedChild,
              let nextStage = CBITSessionStage(rawValue: child.sessionStage.rawValue + 1),
              let idx = dataService.familyUnit.children.firstIndex(where: { $0.id == child.id })
        else { return }
        dataService.familyUnit.children[idx].sessionStage = nextStage
        // Keep shared data in sync if this is the active child
        if dataService.familyUnit.activeChildID == child.id {
            dataService.familyUnit.sharedData.currentSessionStage = nextStage
        }
        dataService.familyUnit.sharedData.lastModified = Date()
        dataService.saveFamilyUnit()
    }

    private func logPractice(_ status: PracticeStatus) {
        let key = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        dataService.familyUnit.sharedData.practiceCalendar[key] = status
        dataService.familyUnit.sharedData.lastModified = Date()
        dataService.saveFamilyUnit()
    }
}

// MARK: - Child Selector Strip

/// Horizontal chip strip — shown when there are 2+ children.
private struct ChildSelectorStrip: View {
    let children: [ChildProfile]
    @Binding var selectedID: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(children) { child in
                    let isSelected = (selectedID ?? children.first?.id) == child.id
                    Button {
                        withAnimation(.spring(response: 0.3)) { selectedID = child.id }
                    } label: {
                        HStack(spacing: 6) {
                            Text(child.ageGroup.subModeName == "Adolescent" ? "🧑" : "🧒")
                                .font(.system(size: 18))
                            Text(child.displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(isSelected ? .white : Color(hex: "764BA2"))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color(hex: "764BA2") : Color(hex: "764BA2").opacity(0.1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Session Stage Card

private struct CaregiverSessionCard: View {
    let stage: CBITSessionStage
    let childName: String
    var isSelfUser: Bool = false
    // tb-mvp2-142: When true, shows a "Tap to view lesson →" hint so users discover the tap target.
    var isLessonAvailable: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.shortLabel)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.75))
                        .tracking(0.5)
                        .textCase(.uppercase)

                    Text(stage.title)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // tb-mvp2-142: Show lesson CTA badge when lesson is available, spacing badge otherwise.
                if isLessonAvailable {
                    HStack(spacing: 4) {
                        Text("View lesson")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Image(systemName: "play.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                } else {
                    // Spacing badge (future sessions without a lesson yet)
                    VStack(spacing: 2) {
                        Text(stage.spacingDescription)
                            .font(.caption.bold())
                            .foregroundColor(.white)
                        Text("sessions")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.75))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                }
            }

            // Progress dots (8 sessions)
            HStack(spacing: 6) {
                ForEach(1...8, id: \.self) { n in
                    Circle()
                        .fill(n <= stage.rawValue ? Color.white : Color.white.opacity(0.3))
                        .frame(width: n == stage.rawValue ? 12 : 8, height: n == stage.rawValue ? 12 : 8)
                        .animation(.spring(response: 0.3), value: stage.rawValue)
                }
                Spacer()
                // tb-mvp2-034: self-users see "You're on track" instead of "[Name] is on track"
                Text(isSelfUser ? "You're on track 🎯" : "\(childName.isEmpty ? "Your child" : childName) is on track 🎯")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.85))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(18)
        .shadow(color: Color(hex: "667EEA").opacity(0.35), radius: 10, y: 4)
    }
}

// MARK: - Daily Instruction Card

/// Renders the daily practice instruction generated by DailyInstructionEngine.
/// Shows a full-session card on the first practice of the week,
/// or a compact daily drill card on subsequent days.
private struct DailyInstructionCard: View {
    let instruction: DailyInstruction
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header row
            HStack(spacing: 10) {
                Text(instruction.emoji)
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 2) {
                    Text(instruction.title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(instruction.focus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // Duration badge
                VStack(spacing: 1) {
                    Text("\(instruction.estimatedMinutes)")
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "764BA2"))
                    Text("min")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Steps list — always visible up to 2 steps, expand for rest
            VStack(alignment: .leading, spacing: 8) {
                let visibleSteps = isExpanded ? instruction.steps : Array(instruction.steps.prefix(2))

                ForEach(Array(visibleSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color(hex: "667EEA"))
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                // Expand/collapse toggle
                if instruction.steps.count > 2 {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(isExpanded ? "Show less" : "Show all \(instruction.steps.count) steps")
                                .font(.caption.bold())
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption.bold())
                        }
                        .foregroundColor(Color(hex: "667EEA"))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            // Coaching tip — shown when expanded or when it's a full-session day
            if isExpanded || instruction.isFullSessionDay {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 13))
                        .padding(.top, 2)
                    Text(instruction.coachingTip)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .italic()
                }
                .padding(10)
                .background(Color.orange.opacity(0.07))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .onAppear {
            // Auto-expand full-session days so caregiver sees the full protocol
            isExpanded = instruction.isFullSessionDay
        }
        .onChange(of: instruction.title) { _ in
            // Re-evaluate expansion if session stage changes
            isExpanded = instruction.isFullSessionDay
        }
    }
}

// MARK: - Today's Practice Card

private struct TodayPracticeCard: View {
    let sharedData: SharedFamilyData
    /// tb-mvp2-081: used to gate Week 1 awareness copy vs. CR copy
    var sessionStage: CBITSessionStage = .session1
    var isSelfUser: Bool = false
    let onLogPractice: (PracticeStatus) -> Void

    // tb-mvp2-143: Ephemeral mood picker state — not persisted to data model.
    @State private var selectedMood: String? = nil

    // tb-mvp2-143: Supportive messages shown when user picks 😐.
    // Daily rotation: deterministic per calendar day so it doesn't flicker on re-render.
    private let kindMessages = [
        "Tough days happen. Just showing up is enough. 💙",
        "Not every day feels great — and that's completely normal. You're still here. That counts.",
        "Even on hard days, noticing your tics is a win. You're doing more than you think.",
        "Some days are just like that. Tomorrow's a fresh start. 💜"
    ]
    private var kindMessage: String {
        kindMessages[abs(Calendar.current.component(.day, from: Date())) % kindMessages.count]
    }

    // tb-mvp2-145: Encouraging messages shown when user picks 😊 (middle emoji).
    // Same daily rotation pattern as kindMessages.
    private let goodMessages = [
        "Good job! You're still learning — and that's exactly where you should be. 💜",
        "Nice work today! Every bit of practice adds up. Keep going. 🌟",
        "You're making progress, even when it doesn't feel like it. 💙",
        "Solid day! Showing up and trying is what matters most. 🎯"
    ]
    private var goodMessage: String {
        goodMessages[abs(Calendar.current.component(.day, from: Date())) % goodMessages.count]
    }

    // tb-mvp2-146: Extra-enthusiastic messages for 😁 (big grin) — a genuinely great day.
    private let greatMessages = [
        "YES!! That's what we're talking about! You're crushing it today! 🎉",
        "Amazing day! This is exactly the energy that makes progress happen. Keep it UP! 🚀",
        "Look at you go!! Days like this are what CBIT is all about. You're incredible. ⭐️",
        "That big grin says it all — you showed up and nailed it today. SO proud of you! 🏆"
    ]
    private var greatMessage: String {
        greatMessages[abs(Calendar.current.component(.day, from: Date())) % greatMessages.count]
    }

    /// tb-mvp2-081: Session 1 is awareness-only — no competing response yet.
    private var isWeek1: Bool { sessionStage == .session1 }

    private var todayKey: String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
    }

    private var todayStatus: PracticeStatus? {
        sharedData.practiceCalendar[todayKey]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // tb-mvp2-145: calendar icon restored; PracticeStatusBadge removed.
            Text("📅 Today")
                .font(.headline.bold())

            // tb-mvp2-143: Mood picker — three tappable emoji pills, selection highlighted purple.
            // tb-mvp2-145: centered, larger emojis (.system(size: 44)), no trailing Spacer.
            // Tap again to deselect. Shows a kind message when 😐 is chosen.
            HStack(spacing: 16) {
                Spacer()
                ForEach(["😐", "😊", "😁"], id: \.self) { emoji in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedMood = selectedMood == emoji ? nil : emoji
                        }
                    } label: {
                        Text(emoji)
                            .font(.system(size: 44))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedMood == emoji
                                    ? Color(hex: "667EEA").opacity(0.15)
                                    : Color(.secondarySystemBackground)
                            )
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(
                                        selectedMood == emoji
                                            ? Color(hex: "667EEA").opacity(0.5)
                                            : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if selectedMood == "😐" {
                Text(kindMessage)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "667EEA"))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // tb-mvp2-145: encouraging message for the middle emoji (😊).
            if selectedMood == "😊" {
                Text(goodMessage)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "667EEA"))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // tb-mvp2-146: extra-enthusiastic message for 😁 (big grin).
            if selectedMood == "😁" {
                Text(greatMessage)
                    .font(.subheadline.bold())
                    .foregroundColor(Color(hex: "764BA2"))
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if todayStatus == nil {
                if isWeek1 {
                    // tb-mvp2-081: Week 1 — awareness training, no CR exists yet.
                    // Ask about catching tic urges, not about a competing response.
                    Text(isSelfUser
                         ? "Have you been catching your tic urges today?"
                         : "Has your child been noticing their tic urges today?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        PracticeLogButton(
                            label: "Yes, caught some 👀",
                            color: .green,
                            action: { onLogPractice(.fullPractice) }
                        )
                        PracticeLogButton(
                            label: "Still learning 🌱",
                            color: .orange,
                            action: { onLogPractice(.partial) }
                        )
                        PracticeLogButton(
                            label: "Tough day 💙",
                            color: Color(hex: "667EEA"),
                            action: { onLogPractice(.hardDay) }
                        )
                    }
                } else {
                    // Week 2+: competing response practice is active
                    // tb-mvp2-034: self-users log their own practice, not a child's
                    Text(isSelfUser
                         ? "Have you practiced your competing response today?"
                         : "Has your child practiced their competing response today?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Quick-log buttons
                    HStack(spacing: 10) {
                        PracticeLogButton(
                            label: "Full Session ✅",
                            color: .green,
                            action: { onLogPractice(.fullPractice) }
                        )
                        PracticeLogButton(
                            label: "Partial 🌤",
                            color: .orange,
                            action: { onLogPractice(.partial) }
                        )
                        PracticeLogButton(
                            label: "Hard Day 💙",
                            color: Color(hex: "667EEA"),
                            action: { onLogPractice(.hardDay) }
                        )
                    }
                }
            } else {
                // Already logged — show encouraging message
                Text(encouragementText(for: todayStatus!))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // tb-mvp2-145: "Change today's log" button removed — user taps an emoji to update.
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func encouragementText(for status: PracticeStatus) -> String {
        // tb-mvp2-081: Week 1 is awareness-only — no CR, different affirmations.
        if isWeek1 {
            switch status {
            case .fullPractice: return "Nice — you're catching urges! 👀 That awareness is exactly what CBIT builds on."
            case .partial:      return "Still learning — that's completely normal in Week 1. 🌱 Keep noticing."
            case .hardDay:      return "Tough day — that's okay. 💙 Awareness takes practice. Tomorrow is a fresh start."
            }
        }
        switch status {
        case .fullPractice: return "Full practice logged — incredible work! 🌟 Consistent practice is how CBIT works."
        case .partial:      return "Partial practice logged — every bit counts. 🌤 Showing up is half the battle."
        case .hardDay:      return "Hard day logged — no shame. 💙 Tomorrow is a fresh start. Tics wax and wane."
        }
    }
}

private struct PracticeStatusBadge: View {
    let status: PracticeStatus

    private var label: String {
        switch status {
        case .fullPractice: return "✅ Done"
        case .partial: return "🌤 Partial"
        case .hardDay: return "💙 Hard Day"
        }
    }

    private var color: Color {
        switch status {
        case .fullPractice: return .green
        case .partial: return .orange
        case .hardDay: return Color(hex: "667EEA")
        }
    }

    var body: some View {
        Text(label)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .cornerRadius(10)
    }
}

private struct PracticeLogButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(color.opacity(0.1))
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Active Tic + Competing Response Card

private struct ActiveTicCard: View {
    let tic: TicHierarchyEntry
    let childName: String
    var isSelfUser: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("🎯 Current Target Tic")
                    .font(.headline.bold())
                Spacer()
                Text("Session \(tic.sessionIntroduced.rawValue)")
                    .font(.caption.bold())
                    .foregroundColor(Color(hex: "764BA2"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "764BA2").opacity(0.1))
                    .cornerRadius(8)
            }

            // Tic name + category
            HStack(spacing: 10) {
                Text(tic.category == .motor ? "💪" : "🗣️")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(tic.ticName)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Text(tic.category.rawValue.capitalized + " Tic")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Competing response (if assigned)
            if !tic.competingResponse.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Competing Response")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.green)
                            .font(.system(size: 16))
                        Text(tic.competingResponse)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .background(Color.green.opacity(0.07))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
            }

            // Urge description (child's words — shown to caregiver for coaching context)
            if !tic.urgeDescription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    // tb-mvp2-034: self-users describe the urge in their own words
                    Text(isSelfUser ? "How you describe the urge:" : "How \(childName.isEmpty ? "they" : childName) describes the urge:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\"\(tic.urgeDescription)\"")
                        .font(.subheadline.italic())
                        .foregroundColor(.primary)
                }
            }

            // Distress progress (baseline vs current)
            if tic.baselineDistress > 0 {
                DistressProgressRow(
                    baseline: tic.baselineDistress,
                    current: tic.currentDistress
                )
            }
        }
        .padding(18)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

private struct DistressProgressRow: View {
    let baseline: Int
    let current: Int

    private var improvementPercent: Int {
        guard baseline > 0 else { return 0 }
        return Int(Double(baseline - current) / Double(baseline) * 100)
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text("\(baseline)/10")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("Baseline")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.caption)

            VStack(spacing: 2) {
                Text("\(current)/10")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                Text("Now")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if improvementPercent > 0 {
                Text("↓\(improvementPercent)% distress")
                    .font(.caption.bold())
                    .foregroundColor(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding(10)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(10)
    }
}

// MARK: - Empty Tic Hierarchy Card

private struct EmptyTicHierarchyCard: View {
    let childName: String
    var isSelfUser: Bool = false
    /// tb-mvp2-039: tap to open TicIntakeAssessmentView sheet
    var onStartAssessment: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Text("📋")
                    .font(.system(size: 36))
                VStack(alignment: .leading, spacing: 4) {
                    Text("No tic hierarchy yet")
                        .font(.headline.bold())
                    // tb-mvp2-034: self-users add their own tics, not a child's
                    Text(isSelfUser
                         ? "Add your tics in your profile to track treatment progress."
                         : "Add \(childName.isEmpty ? "your child's" : childName + "'s") tics in their profile to track treatment progress.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // tb-mvp2-039: CTA to launch the Session 1 tic intake assessment
            if let onStart = onStartAssessment {
                Button(action: onStart) {
                    Label("Start Tic Assessment", systemImage: "clipboard.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Reward Points Card

private struct RewardPointsCard: View {
    let points: Int

    private var progressToNextTier: Double {
        // Every 10 points = 1 tier. Show progress within current tier.
        Double(points % 10) / 10.0
    }

    var body: some View {
        HStack(spacing: 16) {
            Text("⭐️")
                .font(.system(size: 44))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(points)")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "764BA2"))
                    Text("reward points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: progressToNextTier)
                    .tint(Color(hex: "764BA2"))
                    .frame(height: 4)

                Text("\(10 - (points % 10)) points to next reward tier")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Quick Actions

private struct CaregiverQuickActions: View {
    let childName: String
    let hasTherapist: Bool
    var isSelfUser: Bool = false
    let onZiggy: () -> Void           // tb-mvp2-010
    let onAdvanceSession: () -> Void  // tb-mvp2-006
    let onResources: () -> Void       // tb-mvp2-006
    let onPracticeLog: () -> Void     // tb-mvp2-016

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline.bold())

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Talk to Ziggy — caregiver voice profile (tb-mvp2-006 + tb-mvp2-010)
                QuickActionTile(
                    emoji: "🤖",
                    title: "Talk to Ziggy",
                    subtitle: "Start a session",
                    color: Color(hex: "667EEA")
                ) {
                    onZiggy()
                }

                // View child's tic log — wired (tb-mvp2-016)
                QuickActionTile(
                    emoji: "📅",
                    title: "Practice Log",
                    subtitle: "View calendar",
                    color: Color(hex: "43E97B")
                ) {
                    onPracticeLog()
                }

                // Advance session — wired (tb-mvp2-006)
                QuickActionTile(
                    emoji: "🚀",
                    title: "Advance Session",
                    subtitle: "Move to next",
                    color: Color(hex: "FA709A")
                ) {
                    onAdvanceSession()
                }

                // Resources / therapist prep — wired (tb-mvp2-006)
                // tb-mvp2-034: subtitle changes for self-users (not caregiver-directed)
                QuickActionTile(
                    emoji: hasTherapist ? "🩺" : "📖",
                    title: hasTherapist ? "Therapist Notes" : "CBIT Resources",
                    subtitle: hasTherapist ? "Pre-session prep" : (isSelfUser ? "Your resources" : "For caregivers"),
                    color: .orange
                ) {
                    onResources()
                }
            }
        }
    }
}

private struct QuickActionTile: View {
    let emoji: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(emoji)
                    .font(.system(size: 30))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(color.opacity(0.08))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Advance Confirmation Sheet (tb-mvp2-006)
//
// Confirms intent before bumping CBITSessionStage so caregivers don't
// accidentally advance mid-session. Shows current → next stage summary.

struct SessionAdvanceConfirmSheet: View {
    let currentStage: CBITSessionStage
    let childName: String
    var isSelfUser: Bool = false
    let onDecision: (Bool) -> Void   // true = confirmed, false = cancelled

    @Environment(\.dismiss) private var dismiss

    private var nextStage: CBITSessionStage? {
        CBITSessionStage(rawValue: currentStage.rawValue + 1)
    }
    private var isLastSession: Bool { currentStage == .session8 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {

                // Icon
                Text(isLastSession ? "🏆" : "🚀")
                    .font(.system(size: 64))
                    .padding(.top, 24)

                // Headline
                VStack(spacing: 8) {
                    Text(isLastSession ? "Final Session Complete!" : "Advance to Next Session?")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    if isLastSession {
                        // tb-mvp2-034: self-user completes their own sessions
                        Text(isSelfUser
                             ? "You've completed all 8 CBIT sessions. Incredible work!"
                             : "\(childName) has completed all 8 CBIT sessions. Incredible work!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else {
                        Text(isSelfUser ? "You're about to move yourself from:" : "You're about to move \(childName) from:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)

                // Stage cards (current → next)
                if !isLastSession, let next = nextStage {
                    HStack(spacing: 12) {
                        StagePreviewCard(stage: currentStage, isCurrent: true)
                        Image(systemName: "arrow.right")
                            .font(.title3.bold())
                            .foregroundColor(.secondary)
                        StagePreviewCard(stage: next, isCurrent: false)
                    }
                    .padding(.horizontal, 20)
                } else {
                    // All 8 done — show final session card
                    StagePreviewCard(stage: currentStage, isCurrent: true)
                        .padding(.horizontal, 40)
                }

                // Note
                if !isLastSession {
                    // tb-mvp2-034: self-user framing — "you're ready" vs "[child] is ready"
                    Text(isSelfUser
                         ? "Only advance when you've completed today's full practice session and you're ready to move forward."
                         : "Only advance when you've completed today's full practice session and \(childName) is ready to move forward.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    if !isLastSession {
                        Button {
                            onDecision(true)
                        } label: {
                            Text("Yes, advance to \(nextStage?.title ?? "")")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "FA709A"))
                                .cornerRadius(14)
                        }
                    }
                    Button {
                        onDecision(false)
                    } label: {
                        Text(isLastSession ? "Done" : "Not yet — cancel")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDecision(false) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct StagePreviewCard: View {
    let stage: CBITSessionStage
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(isCurrent ? "Now" : "Next")
                .font(.caption.bold())
                .foregroundColor(isCurrent ? .secondary : Color(hex: "FA709A"))
            Text("Session \(stage.rawValue)")
                .font(.headline.bold())
            Text(stage.title.replacingOccurrences(of: "Session \(stage.rawValue): ", with: ""))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(isCurrent ? Color(.systemGray6) : Color(hex: "FA709A").opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrent ? Color.clear : Color(hex: "FA709A").opacity(0.4), lineWidth: 1.5)
        )
    }
}

// MARK: - CBIT Resources Sheet (tb-mvp2-006)
//
// Links to reputable CBIT / Tourette education sources for caregivers.
// When hasTherapist=true, shows therapist-prep checklist instead.

struct CBITResourcesSheet: View {
    let hasTherapist: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if hasTherapist {
                    therapistPrepSection
                }
                cbResources
                tournetteResources
                medicationNoteSection
            }
            .navigationTitle(hasTherapist ? "Therapist Prep" : "CBIT Resources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    // Pre-session checklist for families working with a therapist
    private var therapistPrepSection: some View {
        Section("Before Your Session") {
            ResourceRow(
                emoji: "📋",
                title: "Review this week's practice calendar",
                subtitle: "Note which days had full / partial / hard-day entries"
            )
            ResourceRow(
                emoji: "📝",
                title: "Note any new tics or changes",
                subtitle: "Did any tics get better, worse, or shift to a new body part?"
            )
            ResourceRow(
                emoji: "💬",
                title: "Ask your child what felt hardest",
                subtitle: "Teens especially benefit from sharing their own perspective"
            )
            ResourceRow(
                emoji: "🎯",
                title: "Identify one win to share",
                subtitle: "Any moment the CR worked — even partially — is worth celebrating"
            )
        }
    }

    private var cbResources: some View {
        Section("CBIT & Habit Reversal") {
            LinkRow(
                emoji: "📗",
                title: "What is CBIT?",
                subtitle: "Tourette Association of America",
                url: "https://tourette.org/research-medical/cbit/"
            )
            LinkRow(
                emoji: "🎓",
                title: "CBIT Parent Guide",
                subtitle: "Rutgers CBIT training program overview",
                url: "https://tourette.org/resource/cbit-patient-workbook/"
            )
            LinkRow(
                emoji: "🧠",
                title: "How habit reversal works",
                subtitle: "Child Mind Institute explainer",
                url: "https://childmind.org/article/what-is-habit-reversal-training/"
            )
        }
    }

    private var tournetteResources: some View {
        Section("Tourette Syndrome") {
            LinkRow(
                emoji: "🏥",
                title: "Tourette Association of America",
                subtitle: "tourette.org — comprehensive parent hub",
                url: "https://tourette.org"
            )
            LinkRow(
                emoji: "👶",
                title: "TS in Children",
                subtitle: "CDC overview for families",
                url: "https://www.cdc.gov/tourette/about/index.html"
            )
            LinkRow(
                emoji: "🏫",
                title: "School accommodations guide",
                subtitle: "Tourette Association — IEP / 504 resources",
                url: "https://tourette.org/living-with-ts/education/"
            )
        }
    }

    private var medicationNoteSection: some View {
        Section {
            HStack(spacing: 12) {
                Text("⚕️")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Medication questions?")
                        .font(.subheadline.bold())
                    Text("Always ask your prescribing doctor or neurologist — not an app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Medical Note")
        }
    }
}

private struct ResourceRow: View {
    let emoji: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(emoji).font(.title3)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct LinkRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(alignment: .top, spacing: 12) {
                Text(emoji).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Evening Check-In Banner (tb-mvp2-018)
//
// Soft in-app prompt shown after reminder hour when today's practice is unlogged.
// Less intrusive than a notification — a quiet nudge within the app itself.

private struct EveningCheckInBanner: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text("🌙")
                    .font(.system(size: 28))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Evening check-in")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("No practice logged yet today. Tap to mark it.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.systemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Color.orange.opacity(0.1), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Nightly Debrief Card (tb-mvp2-018)
// Shown when child has submitted their evening check-in.

private struct NightlyRitualCard: View {
    let checkIn: EveningCheckInSummary
    let childName: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(checkIn.moodEmoji)
                    .font(.system(size: 36))

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(childName) checked in 🌙")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Tap to start tonight's 5-min ritual")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [Color(hex: "1A1F36"), Color(hex: "2D3561")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(18)
            .shadow(color: Color(hex: "1A1F36").opacity(0.4), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// Shown after reminder hour when practice hasn't been logged and no check-in yet.
private struct EveningPracticePromptCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text("🌙").font(.system(size: 32))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Evening ritual ready")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Log practice + brief debrief with your child")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(18)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Evening Reminder Settings View (tb-mvp2-018)
//
// Embedded in SettingsView / FamilyManagementView for caregivers to configure
// the daily reminder time or disable it entirely.

struct EveningReminderSettingsView: View {
    @ObservedObject private var service = EveningCheckInService.shared

    // Local time picker state — synced to service on commit
    @State private var pickerDate: Date = EveningReminderSettingsView.defaultReminderDate()

    var body: some View {
        Form {
            Section {
                Toggle("Daily practice reminder", isOn: $service.isEnabled)
                    .tint(Color(hex: "667EEA"))

                if service.isEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: $pickerDate,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: pickerDate) { newDate in
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                        service.reminderHour   = comps.hour ?? 19
                        service.reminderMinute = comps.minute ?? 0
                    }
                }
            } header: {
                Text("Evening Check-In")
            } footer: {
                if service.permissionDenied {
                    Text("⚠️ Notification permission denied. Go to Settings → TicBuddy → Notifications to enable.")
                        .foregroundColor(.orange)
                } else if service.isEnabled {
                    Text("You'll receive a reminder at \(service.formattedTime) on days when practice hasn't been logged.")
                } else {
                    Text("Get a gentle reminder each evening to log today's CBIT practice session.")
                }
            }
        }
        .navigationTitle("Practice Reminder")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { pickerDate = Self.defaultReminderDate(hour: service.reminderHour, minute: service.reminderMinute) }
    }

    private static func defaultReminderDate(hour: Int = 19, minute: Int = 0) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - Lesson 1 Replay Card (tb-mvp2-066)

private struct Lesson1ReplayCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Lesson 1: CBIT Foundations")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("11 slides · Read by Ziggy · Tap to replay")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Read Ahead Card (tb-mvp2-026)
// Caregiver-facing card showing what's coming in the next CBIT session.
// Content comes from WeeklySessionService.caregiverReadAhead(currentStage:).
// No Ziggy voice here — plain text so caregivers can skim before the session.

private struct CaregiverReadAheadCard: View {
    let content: CaregiverReadAheadContent

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header row ──────────────────────────────────────────
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(hex: "667EEA").opacity(0.12))
                            .frame(width: 40, height: 40)
                        Text("📖")
                            .font(.system(size: 20))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read Ahead")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text(content.headline)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            // ── Expanded detail ─────────────────────────────────────
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 14) {
                    // Summary
                    Text(content.summary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // Bullet points
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(content.bulletPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(Color(hex: "667EEA"))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text(point)
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    // Therapist note (optional)
                    if let note = content.therapistNote {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "stethoscope")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "764BA2"))
                                .padding(.top, 1)
                            Text(note)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(Color(hex: "764BA2"))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background(Color(hex: "764BA2").opacity(0.07))
                        .cornerRadius(10)
                    }
                }
                .padding(16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Preview

#Preview {
    // Create a dedicated preview service — never touches the singleton
    let previewService = TicDataService()

    var family = FamilyUnit()

    var caregiver = CaregiverProfile()
    caregiver.displayName = "Mom"
    family.caregivers = [caregiver]

    var tic = TicHierarchyEntry(
        ticName: "Eye Blink",
        category: .motor,
        distressRating: 7,
        frequencyPerDay: 40,
        hasPremonitoryUrge: true,
        urgeDescription: "like a pressure behind my eye",
        competingResponse: "Slowly lower eyelids for 1–2 seconds, then open normally",
        sessionIntroduced: .session2,
        hierarchyOrder: 0
    )
    tic.baselineDistress = 7
    tic.currentDistress = 4

    var child = ChildProfile()
    child.nickname = "Alex"
    child.ageGroup = .olderChild
    child.sessionStage = .session3
    child.ticHierarchy = [tic]
    family.children = [child]
    family.sharedData.rewardPoints = 23

    previewService.familyUnit = family

    return CaregiverHomeView()
        .environmentObject(previewService)
}
