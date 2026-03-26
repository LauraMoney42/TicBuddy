// TicBuddy — TicIntakeAssessmentView.swift
// tb-mvp2-039: CBIT Session 1 tic inventory — builds ChildProfile.ticHierarchy.
//
// CBIT requires a tic inventory before treatment begins. This 3-step sheet
// collects: which tics the child has, distress level, daily frequency, and
// premonitory urge presence — enough to populate TicHierarchyEntry records
// and sort them by distress (most → least) per the CBIT hierarchy protocol.
//
// Entry point: EmptyTicHierarchyCard button in CaregiverHomeView.
// Saves via: dataService.updateChild(_:)

import SwiftUI

// MARK: - Main View

struct TicIntakeAssessmentView: View {
    @EnvironmentObject var dataService: TicDataService
    let child: ChildProfile
    let onComplete: () -> Void

    // MARK: Step Machine

    enum Step { case selectTics, rateEach, confirm }
    @State private var step: Step = .selectTics

    // Selections from Step 1
    @State private var selectedMotor: Set<TicMotorType> = []
    // tb-mvp2-082: wordOrPhrase removed from this set — handled separately so
    // users can add multiple named word/phrase tics (e.g. "The Blurt", "The Whisper").
    @State private var selectedVocal: Set<TicVocalType> = []
    @State private var customTicName: String = ""
    @State private var showCustomField: Bool = false
    /// tb-mvp2-082: Each entry is a user-supplied name for one Word or Phrase tic.
    @State private var wordPhraseEntries: [String] = []
    /// tb-mvp2-108: Each entry is a user description of one complex (motor+vocal) tic sequence.
    @State private var complexTicEntries: [String] = []

    // Per-tic ratings — keyed by stable item UUID (not display name)
    @State private var ratings: [UUID: TicRating] = [:]
    @State private var currentRatingIndex: Int = 0

    // tb-mvp2-082: Mutable items list — display names can be edited in RateEachStep.
    // Built once when user taps Continue in Step 1, then mutated during Step 2.
    @State private var ratingItems: [TicSelectionItem] = []

    // MARK: Helpers

    /// Snapshot of selected items — rebuilt fresh for Step 1 validation only.
    private var allSelectedNames: [TicSelectionItem] {
        var items: [TicSelectionItem] = []
        items += selectedMotor.sorted(by: { $0.rawValue < $1.rawValue })
            .map { TicSelectionItem(canonicalName: $0.rawValue, displayName: $0.rawValue, emoji: $0.emoji, category: .motor) }
        items += selectedVocal.filter { $0 != .wordOrPhrase }
            .sorted(by: { $0.rawValue < $1.rawValue })
            .map { TicSelectionItem(canonicalName: $0.rawValue, displayName: $0.rawValue, emoji: $0.emoji, category: .vocal) }
        // Each word/phrase entry becomes its own TicSelectionItem
        items += wordPhraseEntries.map {
            TicSelectionItem(canonicalName: TicVocalType.wordOrPhrase.rawValue, displayName: $0, emoji: "💬", category: .vocal)
        }
        // tb-mvp2-108: Complex tics — each entry is a free-text description of a
        // combined motor+vocal sequence (e.g. "hands to face + scream").
        items += complexTicEntries.map {
            TicSelectionItem(canonicalName: $0, displayName: $0, emoji: "🔀", category: .complex)
        }
        if !customTicName.trimmingCharacters(in: .whitespaces).isEmpty {
            items.append(TicSelectionItem(canonicalName: customTicName.trimmingCharacters(in: .whitespaces),
                                          displayName: customTicName.trimmingCharacters(in: .whitespaces),
                                          emoji: "⚡️", category: .motor))
        }
        return items
    }

    private var currentItem: TicSelectionItem? {
        guard currentRatingIndex < ratingItems.count else { return nil }
        return ratingItems[currentRatingIndex]
    }

    private var builtHierarchy: [TicHierarchyEntry] {
        ratingItems
            .compactMap { item -> TicHierarchyEntry? in
                guard let r = ratings[item.id] else { return nil }
                return TicHierarchyEntry(
                    ticName: item.canonicalName,
                    nickname: item.hasNickname ? item.displayName : "",
                    category: item.category,
                    distressRating: r.distress,
                    frequencyPerDay: r.frequency.dailyCount,
                    hasPremonitoryUrge: r.hasUrge,
                    urgeDescription: r.urgeDescription,
                    hierarchyOrder: 0   // re-ordered below
                )
            }
            .sorted { $0.distressRating > $1.distressRating }
            .enumerated()
            .map { pair in var e = pair.element; e.hierarchyOrder = pair.offset; return e }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                switch step {
                case .selectTics:
                    SelectTicsStep(
                        selectedMotor: $selectedMotor,
                        selectedVocal: $selectedVocal,
                        customTicName: $customTicName,
                        showCustomField: $showCustomField,
                        wordPhraseEntries: $wordPhraseEntries,
                        complexTicEntries: $complexTicEntries,
                        childName: child.displayName
                    ) {
                        let snapshot = allSelectedNames
                        guard !snapshot.isEmpty else { return }
                        // tb-mvp2-082: Snapshot into mutable ratingItems so Step 2
                        // can update displayName without rebuilding the list.
                        ratingItems = snapshot
                        currentRatingIndex = 0
                        step = .rateEach
                    }

                case .rateEach:
                    if let item = currentItem {
                        RateEachStep(
                            item: Binding(
                                get: { ratingItems[currentRatingIndex] },
                                set: { ratingItems[currentRatingIndex] = $0 }
                            ),
                            rating: Binding(
                                get: { ratings[item.id] ?? TicRating() },
                                set: { ratings[item.id] = $0 }
                            ),
                            progress: currentRatingIndex + 1,
                            total: ratingItems.count,
                            childName: child.displayName,
                            onBack: {
                                if currentRatingIndex == 0 { step = .selectTics }
                                else { currentRatingIndex -= 1 }
                            },
                            onNext: {
                                if currentRatingIndex < ratingItems.count - 1 {
                                    currentRatingIndex += 1
                                } else {
                                    step = .confirm
                                }
                            }
                        )
                    }

                case .confirm:
                    ConfirmStep(
                        hierarchy: builtHierarchy,
                        childName: child.displayName,
                        onBack: {
                            // Use ratingItems (the mutable snapshot) not allSelectedNames
                            currentRatingIndex = max(0, ratingItems.count - 1)
                            step = .rateEach
                        },
                        onSave: saveAndClose
                    )
                }
            }
            .navigationTitle("Tic Assessment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onComplete() }
                }
            }
        }
    }

    // MARK: Save

    private func saveAndClose() {
        var updated = child
        updated.ticHierarchy = builtHierarchy
        dataService.updateChild(updated)
        onComplete()
    }
}

// MARK: - Tic Selection Item (internal helper)
// tb-mvp2-082: id is stable across renames so ratings dict never loses its entry.
// displayName is mutable — user can rename in the RateEachStep header card.

private struct TicSelectionItem: Identifiable {
    let id: UUID = UUID()
    let canonicalName: String    // Original type name — stored as ticName
    var displayName: String      // User-editable; becomes nickname if changed
    let emoji: String
    let category: TicCategory

    /// True when the user has given this tic a custom nickname.
    var hasNickname: Bool { displayName != canonicalName }
}

// MARK: - Tic Rating (per-tic data collected in Step 2)

private struct TicRating {
    var distress: Int = 5                           // 1–10
    var frequency: FrequencyBucket = .sometimes
    var hasUrge: Bool = false
    var urgeDescription: String = ""
}

private enum FrequencyBucket: String, CaseIterable, Identifiable {
    case rarely     = "Rarely"
    case sometimes  = "Sometimes"
    case often      = "Often"
    case veryOften  = "Very Often"

    var id: String { rawValue }

    var dailyCount: Int {
        switch self {
        case .rarely:    return 2
        case .sometimes: return 8
        case .often:     return 20
        case .veryOften: return 40
        }
    }

    var description: String {
        switch self {
        case .rarely:    return "1–3×/day"
        case .sometimes: return "4–12×/day"
        case .often:     return "13–30×/day"
        case .veryOften: return "30+/day"
        }
    }
}

// MARK: - Step 1: Select Tics

private struct SelectTicsStep: View {
    @Binding var selectedMotor: Set<TicMotorType>
    @Binding var selectedVocal: Set<TicVocalType>
    @Binding var customTicName: String
    @Binding var showCustomField: Bool
    /// tb-mvp2-082: Each string is one named Word-or-Phrase tic entry.
    @Binding var wordPhraseEntries: [String]
    /// tb-mvp2-108: Each string describes one complex (motor+vocal) tic sequence.
    @Binding var complexTicEntries: [String]
    let childName: String
    let onNext: () -> Void

    @State private var newWordPhraseName: String = ""
    @FocusState private var wordPhraseFieldFocused: Bool
    @State private var newComplexTicName: String = ""
    @FocusState private var complexTicFieldFocused: Bool

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var hasSelection: Bool {
        !selectedMotor.isEmpty ||
        !selectedVocal.filter({ $0 != .wordOrPhrase }).isEmpty ||
        !wordPhraseEntries.isEmpty ||
        !complexTicEntries.isEmpty ||
        !customTicName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Which tics does \(childName.isEmpty ? "your child" : childName) have?")
                        .font(.title2.bold())
                    Text("Select all that apply. You can always add more later.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Motor tics
                VStack(alignment: .leading, spacing: 10) {
                    Label("Motor Tics", systemImage: "figure.walk")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(TicMotorType.allCases.filter { $0 != .other }) { type in
                            TicTypeToggle(
                                emoji: type.emoji,
                                name: type.rawValue,
                                isSelected: selectedMotor.contains(type)
                            ) {
                                if selectedMotor.contains(type) { selectedMotor.remove(type) }
                                else { selectedMotor.insert(type) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }

                // Vocal tics (all types except wordOrPhrase — handled separately below)
                VStack(alignment: .leading, spacing: 10) {
                    Label("Vocal Tics", systemImage: "waveform")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(TicVocalType.allCases.filter { $0 != .other && $0 != .wordOrPhrase }) { type in
                            TicTypeToggle(
                                emoji: type.emoji,
                                name: type.rawValue,
                                isSelected: selectedVocal.contains(type)
                            ) {
                                if selectedVocal.contains(type) { selectedVocal.remove(type) }
                                else { selectedVocal.insert(type) }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // tb-mvp2-082: Word or Phrase — multi-entry section.
                    // Each entry gets its own name (e.g. "The Blurt", "The Whisper")
                    // so they appear as separate hierarchy items.
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Word or Phrase tics", systemImage: "bubble.left.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)

                        ForEach(wordPhraseEntries.indices, id: \.self) { i in
                            HStack(spacing: 8) {
                                Text("💬")
                                    .font(.system(size: 20))
                                Text(wordPhraseEntries[i])
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                Spacer()
                                Button {
                                    wordPhraseEntries.remove(at: i)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .background(Color(hex: "667EEA").opacity(0.07))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                        }

                        HStack(spacing: 8) {
                            TextField("e.g. \"The Blurt\", \"That word\"", text: $newWordPhraseName)
                                .textFieldStyle(.roundedBorder)
                                .focused($wordPhraseFieldFocused)
                                .submitLabel(.done)
                                .onSubmit { addWordPhrase() }
                            Button(action: addWordPhrase) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(newWordPhraseName.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.gray.opacity(0.4)
                                        : Color(hex: "667EEA"))
                            }
                            .disabled(newWordPhraseName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // tb-mvp2-108: Complex tics (motor + vocal combined sequence)
                // e.g. "hands to face + scream" — logged as one hierarchy entry.
                VStack(alignment: .leading, spacing: 10) {
                    Label("Complex Tics (motor + vocal)", systemImage: "arrow.triangle.merge")
                        .font(.headline)
                        .padding(.horizontal, 20)

                    Text("A single movement and sound that always happen together, like squishing hands to face while screaming.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 20)

                    ForEach(complexTicEntries.indices, id: \.self) { i in
                        HStack(spacing: 8) {
                            Text("🔀")
                                .font(.system(size: 20))
                            Text(complexTicEntries[i])
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Spacer()
                            Button {
                                complexTicEntries.remove(at: i)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.07))
                        .cornerRadius(10)
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 8) {
                        TextField("Describe the sequence (e.g. \"hands to face + scream\")", text: $newComplexTicName)
                            .textFieldStyle(.roundedBorder)
                            .focused($complexTicFieldFocused)
                            .submitLabel(.done)
                            .onSubmit { addComplexTic() }
                        Button(action: addComplexTic) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(newComplexTicName.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color.gray.opacity(0.4)
                                    : Color.purple)
                        }
                        .disabled(newComplexTicName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, 16)
                }

                // Custom tic
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation { showCustomField.toggle() }
                    } label: {
                        Label(showCustomField ? "Remove custom tic" : "+ Add a different tic",
                              systemImage: showCustomField ? "minus.circle" : "plus.circle")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 20)

                    if showCustomField {
                        TextField("Custom tic name (e.g. \"finger tapping\")", text: $customTicName)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // Next button
                Button(action: { wordPhraseFieldFocused = false; onNext() }) {
                    Text("Continue →")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(hasSelection
                            ? LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                             startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.5)],
                                             startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(16)
                }
                .disabled(!hasSelection)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func addWordPhrase() {
        let name = newWordPhraseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        wordPhraseEntries.append(name)
        newWordPhraseName = ""
    }

    // tb-mvp2-108
    private func addComplexTic() {
        let name = newComplexTicName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        complexTicEntries.append(name)
        newComplexTicName = ""
    }
}

// MARK: - Tic Type Toggle

private struct TicTypeToggle: View {
    let emoji: String
    let name: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(emoji).font(.system(size: 22))
                Text(name)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "667EEA"))
                }
            }
            .padding(12)
            .background(isSelected
                ? Color(hex: "667EEA").opacity(0.12)
                : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "667EEA") : Color.clear, lineWidth: 1.5)
            )
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Step 2: Rate Each Tic

private struct RateEachStep: View {
    /// tb-mvp2-082: Binding so inline rename writes back to ratingItems array.
    @Binding var item: TicSelectionItem
    @Binding var rating: TicRating
    let progress: Int
    let total: Int
    let childName: String
    let onBack: () -> Void
    let onNext: () -> Void

    @State private var isEditingName: Bool = false
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Progress header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tic \(progress) of \(total)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    ProgressView(value: Double(progress), total: Double(total))
                        .tint(Color(hex: "667EEA"))
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // tb-mvp2-082: Tic name card — tappable to rename inline.
                // Shows canonical type name by default; becomes the nickname once edited.
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        Text(item.emoji)
                            .font(.system(size: 40))
                        VStack(alignment: .leading, spacing: 2) {
                            if isEditingName {
                                TextField("Give this tic a name", text: $item.displayName)
                                    .font(.title3.bold())
                                    .focused($nameFieldFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        isEditingName = false
                                        if item.displayName.trimmingCharacters(in: .whitespaces).isEmpty {
                                            item.displayName = item.canonicalName
                                        }
                                    }
                            } else {
                                Text(item.displayName)
                                    .font(.title3.bold())
                            }
                            // tb-mvp2-108: three-way label for motor / vocal / complex
                            Text(item.category == .motor ? "Motor tic" : item.category == .vocal ? "Vocal tic" : "Complex tic (motor + vocal)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            isEditingName.toggle()
                            if isEditingName { nameFieldFocused = true }
                        } label: {
                            Image(systemName: isEditingName ? "checkmark.circle.fill" : "pencil.circle")
                                .font(.system(size: 22))
                                .foregroundColor(Color(hex: "667EEA"))
                        }
                    }

                    // Nickname hint — only shown before the user edits
                    if !isEditingName && !item.hasNickname {
                        Text("Does this tic have a special name? Tap ✏️ to rename it.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if item.hasNickname {
                        Text("aka \"\(item.canonicalName)\"")
                            .font(.caption)
                            .foregroundColor(Color(hex: "667EEA").opacity(0.8))
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(.horizontal, 20)

                // Distress rating
                VStack(alignment: .leading, spacing: 12) {
                    Text("How much does it bother \(childName.isEmpty ? "them" : childName)?")
                        .font(.headline)

                    HStack {
                        Text("Not much")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("A lot")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Custom number slider display
                    HStack(spacing: 6) {
                        ForEach(1...10, id: \.self) { val in
                            Button {
                                rating.distress = val
                            } label: {
                                Text("\(val)")
                                    .font(.system(size: 13, weight: rating.distress == val ? .bold : .regular, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(rating.distress == val
                                        ? distressColor(val)
                                        : Color(.systemFill))
                                    .foregroundColor(rating.distress == val ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    Text(distressLabel(rating.distress))
                        .font(.caption)
                        .foregroundColor(distressColor(rating.distress))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .animation(.easeInOut, value: rating.distress)
                }
                .padding(.horizontal, 20)

                // Frequency
                VStack(alignment: .leading, spacing: 12) {
                    Text("How often does it happen?")
                        .font(.headline)

                    VStack(spacing: 8) {
                        ForEach(FrequencyBucket.allCases) { bucket in
                            Button {
                                rating.frequency = bucket
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bucket.rawValue)
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        Text(bucket.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if rating.frequency == bucket {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(Color(hex: "667EEA"))
                                    }
                                }
                                .padding(14)
                                .background(rating.frequency == bucket
                                    ? Color(hex: "667EEA").opacity(0.10)
                                    : Color(.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(rating.frequency == bucket
                                            ? Color(hex: "667EEA") : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Premonitory urge
                VStack(alignment: .leading, spacing: 12) {
                    Text("Does \(childName.isEmpty ? "the child" : childName) feel a warning sensation?")
                        .font(.headline)
                    Text("A tingly, itchy, or \"buildup\" feeling right before the tic — called a premonitory urge.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Yes, they feel an urge before the tic", isOn: $rating.hasUrge)
                        .toggleStyle(SwitchToggleStyle(tint: Color(hex: "667EEA")))

                    if rating.hasUrge {
                        TextField("Describe the feeling (optional)", text: $rating.urgeDescription)
                            .textFieldStyle(.roundedBorder)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .animation(.easeInOut(duration: 0.2), value: rating.hasUrge)

                // Navigation buttons
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundColor(Color(hex: "667EEA"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "667EEA").opacity(0.10))
                        .cornerRadius(16)
                    }

                    Button(action: onNext) {
                        HStack(spacing: 6) {
                            Text(progress < total ? "Next" : "Review")
                            Image(systemName: progress < total ? "chevron.right" : "checkmark")
                        }
                        .font(.headline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                           startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func distressColor(_ val: Int) -> Color {
        switch val {
        case 1...3: return Color(hex: "38F9D7")
        case 4...6: return Color(hex: "FFA500")
        default:    return Color(hex: "FF4757")
        }
    }

    private func distressLabel(_ val: Int) -> String {
        switch val {
        case 1...2: return "Barely noticeable"
        case 3...4: return "A little bothersome"
        case 5...6: return "Moderately distressing"
        case 7...8: return "Very distressing"
        default:    return "Extremely distressing"
        }
    }
}

// MARK: - Step 3: Confirm & Save

private struct ConfirmStep: View {
    let hierarchy: [TicHierarchyEntry]
    let childName: String
    let onBack: () -> Void
    let onSave: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tic Hierarchy")
                        .font(.title2.bold())
                    Text("Sorted from most to least distressing — this is the CBIT treatment order.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Hierarchy list
                VStack(spacing: 8) {
                    ForEach(hierarchy) { entry in
                        HStack(spacing: 14) {
                            // Rank bubble
                            ZStack {
                                Circle()
                                    .fill(rankColor(entry.hierarchyOrder))
                                    .frame(width: 36, height: 36)
                                Text("\(entry.hierarchyOrder + 1)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                HStack(spacing: 8) {
                                    Label("Distress \(entry.distressRating)/10", systemImage: "chart.bar.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("·")
                                        .foregroundColor(.secondary)
                                    Text("\(entry.frequencyPerDay)×/day")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if entry.hasPremonitoryUrge {
                                    Label("Has premonitory urge", systemImage: "bolt.fill")
                                        .font(.caption)
                                        .foregroundColor(Color(hex: "667EEA"))
                                }
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(Color(.systemBackground))
                        .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20)

                // CBIT note
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Color(hex: "667EEA"))
                        .padding(.top, 1)
                    Text("CBIT starts with the top tic. Once that's manageable, you'll move to the next one. You can update this hierarchy any time.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(14)
                .background(Color(hex: "667EEA").opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                // Navigation
                HStack(spacing: 12) {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .foregroundColor(Color(hex: "667EEA"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "667EEA").opacity(0.10))
                        .cornerRadius(16)
                    }

                    Button(action: onSave) {
                        Text("Begin CBIT 🎯")
                            .font(.headline.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func rankColor(_ order: Int) -> Color {
        switch order {
        case 0: return Color(hex: "FF4757")
        case 1: return Color(hex: "FFA500")
        case 2: return Color(hex: "FFC312")
        default: return Color(hex: "667EEA")
        }
    }
}

// MARK: - TicVocalType extension (mirror emoji access for SelectTicsStep)
// TicVocalType.allCases is enumerated alongside an arbitrary second element
// in SelectTicsStep; this ensures .emoji is available on the type directly.
// (Already defined on TicVocalType in TicEntry.swift — no extra code needed.)
