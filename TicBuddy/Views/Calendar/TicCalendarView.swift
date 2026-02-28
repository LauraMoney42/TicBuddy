// TicBuddy — TicCalendarView.swift
// Monthly calendar showing tic logs with day detail and quick-add.

import SwiftUI

struct TicCalendarView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var selectedDate = Date()
    @State private var showAddTicSheet = false
    @State private var currentMonth = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month header + navigation
                    MonthNavigationView(currentMonth: $currentMonth)

                    // Calendar grid
                    CalendarGridView(
                        currentMonth: currentMonth,
                        selectedDate: $selectedDate,
                        dataService: dataService
                    )
                    .padding(.horizontal, 16)

                    // Selected day summary
                    DaySummaryView(date: selectedDate, dataService: dataService)
                        .padding(.horizontal, 16)

                    // Day's tic entries
                    DayEntriesView(date: selectedDate, dataService: dataService)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Tic Calendar 📅")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTicSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .leading, endPoint: .trailing))
                    }
                }
            }
            .sheet(isPresented: $showAddTicSheet) {
                AddTicView(date: selectedDate)
                    .environmentObject(dataService)
            }
        }
    }
}

// MARK: - Month Navigation

struct MonthNavigationView: View {
    @Binding var currentMonth: Date

    var monthString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        return fmt.string(from: currentMonth)
    }

    var body: some View {
        HStack {
            Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth)! }) {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundColor(Color(hex: "667EEA"))
            }

            Spacer()

            Text(monthString)
                .font(.title2.bold())

            Spacer()

            Button(action: { currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth)! }) {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundColor(Color(hex: "667EEA"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

// MARK: - Calendar Grid

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let dataService: TicDataService

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth)) else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }
        return days
    }

    var body: some View {
        VStack(spacing: 8) {
            // Day name headers
            HStack(spacing: 0) {
                ForEach(dayNames, id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day cells
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<daysInMonth.count, id: \.self) { i in
                    if let date = daysInMonth[i] {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            ticCount: dataService.entries(for: date).count,
                            hasRedirection: dataService.entries(for: date).contains { $0.outcome == .redirected }
                        ) {
                            selectedDate = date
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

// MARK: - Day Cell

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let ticCount: Int
    let hasRedirection: Bool
    let action: () -> Void

    var dayNumber: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "d"
        return fmt.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 15, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? Color(hex: "667EEA") : .primary))

                // Tic indicator dots
                if ticCount > 0 {
                    HStack(spacing: 2) {
                        Circle()
                            .fill(hasRedirection ? Color.green : Color.orange)
                            .frame(width: 5, height: 5)
                        if ticCount > 1 {
                            Text("+\(ticCount - 1)")
                                .font(.system(size: 7))
                                .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        }
                    }
                } else {
                    Color.clear.frame(height: 7)
                }
            }
            .frame(width: 44, height: 44)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    } else if isToday {
                        Color(hex: "667EEA").opacity(0.1)
                    } else {
                        Color.clear
                    }
                }
            )
            .cornerRadius(12)
        }
    }
}

// MARK: - Day Summary

struct DaySummaryView: View {
    let date: Date
    let dataService: TicDataService

    var entries: [TicEntry] { dataService.entries(for: date) }
    var redirected: Int { entries.filter { $0.outcome == .redirected }.count }
    var caught: Int { entries.filter { $0.outcome == .caught }.count }

    var displayDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        return fmt.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayDate)
                .font(.headline.bold())

            if entries.isEmpty {
                HStack {
                    Text("💙")
                    Text("No tics logged this day")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    StatPill(value: entries.count, label: "Total", color: .orange)
                    StatPill(value: caught, label: "Caught ⚡️", color: .yellow)
                    StatPill(value: redirected, label: "Redirected 🌟", color: .green)
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

struct StatPill: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Day Entries List

struct DayEntriesView: View {
    let date: Date
    @ObservedObject var dataService: TicDataService

    var entries: [TicEntry] { dataService.entries(for: date).sorted { $0.date > $1.date } }

    var body: some View {
        if !entries.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tic Log")
                    .font(.headline.bold())

                ForEach(entries) { entry in
                    TicEntryRowView(entry: entry) {
                        dataService.deleteTicEntry(entry)
                    }
                }
            }
        }
    }
}

struct TicEntryRowView: View {
    let entry: TicEntry
    let onDelete: () -> Void

    var timeString: String {
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        return fmt.string(from: entry.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(Color(hex: "667EEA").opacity(0.1))
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.displayName)
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    Text(entry.outcome.emoji)
                    Text(entry.outcome.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red.opacity(0.6))
                    .font(.caption)
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }
}

// MARK: - Add Tic Sheet

struct AddTicView: View {
    let date: Date
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) var dismiss

    @State private var category: TicCategory = .motor
    @State private var motorType: TicMotorType = .eyeBlink
    @State private var vocalType: TicVocalType = .throatClearing
    @State private var outcome: TicOutcome = .noticed
    @State private var urgeStrength: Double = 2
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Tic Type") {
                    Picker("Category", selection: $category) {
                        Text("Motor 💪").tag(TicCategory.motor)
                        Text("Vocal 🔊").tag(TicCategory.vocal)
                    }
                    .pickerStyle(.segmented)

                    if category == .motor {
                        Picker("Type", selection: $motorType) {
                            ForEach(TicMotorType.allCases) { t in
                                Text("\(t.emoji) \(t.rawValue)").tag(t)
                            }
                        }
                    } else {
                        Picker("Type", selection: $vocalType) {
                            ForEach(TicVocalType.allCases) { t in
                                Text("\(t.emoji) \(t.rawValue)").tag(t)
                            }
                        }
                    }
                }

                Section("What happened?") {
                    ForEach(TicOutcome.allCases, id: \.self) { o in
                        Button(action: { outcome = o }) {
                            HStack {
                                Text("\(o.emoji) \(o.rawValue)")
                                    .foregroundColor(.primary)
                                Spacer()
                                if outcome == o {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "667EEA"))
                                }
                            }
                        }
                    }
                }

                Section("Urge strength (1=low, 5=strong)") {
                    HStack {
                        Text("1").foregroundColor(.secondary)
                        Slider(value: $urgeStrength, in: 1...5, step: 1)
                            .tint(Color(hex: "667EEA"))
                        Text("5").foregroundColor(.secondary)
                        Text("  \(Int(urgeStrength))⭐️")
                            .bold()
                    }
                }

                Section("Note (optional)") {
                    TextField("What was going on?", text: $note)
                }
            }
            .navigationTitle("Log a Tic")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = TicEntry(
                            date: date,
                            category: category,
                            motorType: category == .motor ? motorType : nil,
                            vocalType: category == .vocal ? vocalType : nil,
                            outcome: outcome,
                            urgeStrength: Int(urgeStrength),
                            note: note.isEmpty ? nil : note
                        )
                        dataService.addTicEntry(entry)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}
