// TicBuddy — TicDetailEditSheet.swift
// tb-mvp2-161: Lightweight edit sheet for enriching a logged tic entry.
//
// Opened from:
//   • HomeView "Add detail →" button (most recent today's entry)
//   • TicCalendarView — tapping any entry row
//
// Fields: tic name (customLabel override), context (where/what), notes (note).
// Saves via dataService.updateTicEntry() — no new entries created.

import SwiftUI

struct TicDetailEditSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let entry: TicEntry

    @State private var ticName: String
    @State private var context: String
    @State private var notes: String

    init(entry: TicEntry) {
        self.entry = entry
        // Pre-populate with existing values if present
        _ticName = State(initialValue: entry.customLabel ?? "")
        _context = State(initialValue: entry.context ?? "")
        _notes   = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── Tic name ─────────────────────────────────────────────
                Section {
                    TextField("e.g. eye blink, head jerk", text: $ticName)
                        .autocorrectionDisabled()
                } header: {
                    Text("Tic Name")
                } footer: {
                    Text("Overrides the logged tic type label if filled in.")
                        .font(.caption)
                }

                // ── Context ───────────────────────────────────────────────
                Section {
                    TextField("e.g. watching TV, at school, stressed", text: $context)
                } header: {
                    Text("Context")
                } footer: {
                    Text("Where were you or what were you doing when this happened?")
                        .font(.caption)
                }

                // ── Notes ─────────────────────────────────────────────────
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Anything else worth remembering about this tic.")
                        .font(.caption)
                }

                // ── Entry meta (read-only) ────────────────────────────────
                Section {
                    HStack {
                        Text("Type").foregroundColor(.secondary)
                        Spacer()
                        Text(entry.displayName).bold()
                    }
                    HStack {
                        Text("Outcome").foregroundColor(.secondary)
                        Spacer()
                        Text("\(entry.outcome.emoji) \(entry.outcome.rawValue)")
                    }
                    HStack {
                        Text("Logged").foregroundColor(.secondary)
                        Spacer()
                        Text(entry.date, style: .time)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Logged Entry")
                }
            }
            .navigationTitle("Add Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
        }
    }

    // MARK: Save

    private func save() {
        var updated = entry

        let trimmedName = ticName.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.customLabel = trimmedName.isEmpty ? nil : trimmedName

        let trimmedContext = context.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.context = trimmedContext.isEmpty ? nil : trimmedContext

        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmedNotes.isEmpty ? nil : trimmedNotes

        dataService.updateTicEntry(updated)
        dismiss()
    }
}
