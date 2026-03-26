// TicBuddy — SessionSchedulerView.swift
// tb-mvp2-096: Day-of-week + time picker for weekly CBIT session reminder.
//
// Two usage modes:
//   1. First-run linear flow (tb-mvp2-098): pass onContinue callback.
//      Button reads "Schedule & Continue →" — calls onContinue() instead of dismiss.
//      User cannot skip: it's a required step between Lesson and Tic Assessment.
//   2. Settings / standalone: pass nil for onContinue.
//      Button reads "Set Weekly Reminder" — dismisses sheet when done.
//
// Notification scheduling handled by SessionSchedulerService (tb-mvp2-097).

import SwiftUI

struct SessionSchedulerView: View {
    @StateObject private var service = SessionSchedulerService.shared
    @Environment(\.dismiss) private var dismiss

    /// When set, button advances the linear post-Session-1 flow instead of dismissing.
    var onContinue: (() -> Void)?

    // Local picker state — init from service (or default: Sunday 10:00 AM)
    @State private var selectedWeekday: Int
    @State private var selectedTime: Date

    private let weekdayNames = Calendar.current.weekdaySymbols  // ["Sunday", "Monday", …]

    init(onContinue: (() -> Void)? = nil) {
        self.onContinue = onContinue
        let svc = SessionSchedulerService.shared
        let weekday = svc.scheduledWeekday > 0 ? svc.scheduledWeekday : 1  // default Sunday
        _selectedWeekday = State(initialValue: weekday)
        var comps = DateComponents()
        comps.hour   = svc.hasSchedule ? svc.scheduledHour   : 10
        comps.minute = svc.hasSchedule ? svc.scheduledMinute : 0
        let date = Calendar.current.date(from: comps) ?? Date()
        _selectedTime = State(initialValue: date)
    }

    // CTA label depends on usage mode
    private var ctaLabel: String {
        onContinue != nil ? "Schedule & Continue →" : "Set Weekly Reminder"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {

                    // ── Header ────────────────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("📅")
                            .font(.system(size: 52))
                        Text("Schedule Your\nWeekly Session")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)
                        Text("One session per week keeps the progress going.\nWe'll remind you so you never miss it.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 24)

                    // ── Pickers ────────────────────────────────────────────────
                    VStack(spacing: 2) {
                        // Day of week
                        HStack {
                            Label("Day", systemImage: "calendar")
                                .font(.body.weight(.medium))
                            Spacer()
                            Picker("Day", selection: $selectedWeekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(weekdayNames[weekday - 1]).tag(weekday)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Time
                        HStack {
                            Label("Time", systemImage: "clock")
                                .font(.body.weight(.medium))
                            Spacer()
                            DatePicker(
                                "",
                                selection: $selectedTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 16)

                    // ── Permission denied warning ──────────────────────────────
                    if service.permissionDenied {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.slash")
                                .foregroundColor(.orange)
                            Text("Notifications are off. Enable them in **Settings** → Notifications → TicBuddy to receive reminders.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 8)

                    // ── CTA ────────────────────────────────────────────────────
                    Button {
                        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
                        Task {
                            await service.saveSchedule(
                                weekday: selectedWeekday,
                                hour: comps.hour ?? 10,
                                minute: comps.minute ?? 0
                            )
                            if let onContinue {
                                onContinue()
                            } else {
                                dismiss()
                            }
                        }
                    } label: {
                        Text(ctaLabel)
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // "Not Now" only visible in standalone settings mode — first-run flow is required
                if onContinue == nil {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Not Now") { dismiss() }
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Next Session Card

/// Compact card shown on CaregiverHomeView when a weekly schedule is set.
/// Tapping opens SessionSchedulerView (standalone mode) to change the schedule.
struct NextSessionCard: View {
    @StateObject private var service = SessionSchedulerService.shared
    @State private var showScheduler = false

    var body: some View {
        if service.hasSchedule {
            Button {
                showScheduler = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(service.formattedSchedule)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showScheduler) {
                // Standalone mode — no onContinue, shows "Not Now" cancel
                SessionSchedulerView()
            }
        }
    }
}
