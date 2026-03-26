// TicBuddy — EveningCheckInSheet.swift
// tb-mvp2-018: Child-facing evening check-in, shown after 5pm (or on demand).
//
// PRIVACY CONTRACT:
//   - Mood emoji + energy + practice done → SharedFamilyData.eveningCheckIns (caregiver sees)
//   - Free-text notes (optional) → AdolescentJournalStore only (teens), NEVER shared
//   - CaregiverHomeView reads only EveningCheckInSummary (no text crosses)

import SwiftUI

// MARK: - Evening Check-In Sheet

struct EveningCheckInSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let childAgeGroup: AgeGroup

    @State private var selectedMood: MoodOption? = nil
    @State private var energyLevel: Int = 2                 // 1–3
    @State private var practiceDone: Bool? = nil
    @State private var didSubmit = false

    private var isTeen: Bool {
        childAgeGroup == .youngTeen || childAgeGroup == .teen
    }

    private var isYoung: Bool {
        childAgeGroup == .veryYoung || childAgeGroup == .young
    }

    private var canSubmit: Bool {
        selectedMood != nil && practiceDone != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                if didSubmit {
                    CheckInConfirmationView(ageGroup: childAgeGroup) {
                        dismiss()
                    }
                } else {
                    checkInForm
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(isTeen ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                        .foregroundColor(isTeen ? Color(hex: "8899AA") : .secondary)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Check-In Form

    private var checkInForm: some View {
        ScrollView {
            VStack(spacing: 28) {

                // Header
                VStack(spacing: 8) {
                    Text(isYoung ? "🌙" : "🌙")
                        .font(.system(size: 52))
                        .padding(.top, 24)

                    Text(isYoung ? "Time to check in!" : "Quick evening check-in")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)

                    Text(isYoung
                         ? "How are you feeling right now?"
                         : "Takes 30 seconds. Your caregiver will see your mood and if you practiced.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                }

                // Mood selector
                VStack(spacing: 12) {
                    Text(isYoung ? "How do you feel? 👇" : "How are you feeling?")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    HStack(spacing: isYoung ? 20 : 14) {
                        ForEach(MoodOption.allCases, id: \.self) { mood in
                            MoodButton(
                                mood: mood,
                                isSelected: selectedMood == mood,
                                isYoung: isYoung
                            ) {
                                withAnimation(.spring(response: 0.3)) { selectedMood = mood }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Energy level (older children + teens only)
                if !isYoung {
                    VStack(spacing: 12) {
                        Text("Energy level today")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(primaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)

                        HStack(spacing: 12) {
                            ForEach(1...3, id: \.self) { level in
                                EnergyButton(
                                    level: level,
                                    isSelected: energyLevel == level,
                                    isTeen: isTeen
                                ) {
                                    withAnimation(.spring(response: 0.3)) { energyLevel = level }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Practice done?
                VStack(spacing: 12) {
                    Text(isYoung ? "Did you try your superpower move today? 💪" : "Did you do your competing response practice?")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(primaryTextColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        PracticeAnswerButton(
                            label: isYoung ? "Yes! ✅" : "Yes",
                            isSelected: practiceDone == true,
                            isAffirmative: true,
                            isTeen: isTeen
                        ) {
                            withAnimation(.spring(response: 0.3)) { practiceDone = true }
                        }
                        PracticeAnswerButton(
                            label: isYoung ? "Not today 💙" : "Not today",
                            isSelected: practiceDone == false,
                            isAffirmative: false,
                            isTeen: isTeen
                        ) {
                            withAnimation(.spring(response: 0.3)) { practiceDone = false }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Privacy note (teens only)
                if isTeen {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "8899AA"))
                        Text("Your caregiver sees mood + practice only — no notes or details.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color(hex: "8899AA"))
                    }
                    .padding(.horizontal, 24)
                }

                // Submit button
                Button {
                    submitCheckIn()
                } label: {
                    Text(isYoung ? "Done! 🌟" : "Submit check-in")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(isTeen ? Color(hex: "0D1117") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSubmit ? submitButtonColor : Color.gray.opacity(0.3))
                        .cornerRadius(16)
                }
                .disabled(!canSubmit)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Submit

    private func submitCheckIn() {
        guard let mood = selectedMood, let practiced = practiceDone else { return }
        let summary = EveningCheckInSummary(
            moodEmoji: mood.emoji,
            energyLevel: energyLevel,
            practiceDoneToday: practiced
        )
        dataService.submitEveningCheckIn(summary)
        withAnimation(.spring(response: 0.4)) { didSubmit = true }
    }

    // MARK: - Style helpers

    private var backgroundGradient: LinearGradient {
        if isTeen {
            return LinearGradient(colors: [Color(hex: "0D1117"), Color(hex: "1A1F36")],
                                  startPoint: .top, endPoint: .bottom)
        }
        if isYoung {
            return LinearGradient(colors: [Color(hex: "1A1A2E"), Color(hex: "16213E")],
                                  startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(hex: "0F3460"), Color(hex: "1A1A2E")],
                              startPoint: .top, endPoint: .bottom)
    }

    private var primaryTextColor: Color { .white }
    private var secondaryTextColor: Color { Color(hex: "AABBCC") }
    private var submitButtonColor: Color {
        isTeen ? Color(hex: "5B9BF0") : Color(hex: "667EEA")
    }
}

// MARK: - Mood Options

enum MoodOption: CaseIterable {
    case great, okay, hard

    var emoji: String {
        switch self {
        case .great: return "😊"
        case .okay:  return "😐"
        case .hard:  return "😣"
        }
    }

    var label: String {
        switch self {
        case .great: return "Great"
        case .okay:  return "Okay"
        case .hard:  return "Hard"
        }
    }
}

// MARK: - Sub-components

private struct MoodButton: View {
    let mood: MoodOption
    let isSelected: Bool
    let isYoung: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: isYoung ? 6 : 4) {
                Text(mood.emoji)
                    .font(.system(size: isYoung ? 48 : 36))
                if !isYoung {
                    Text(mood.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(isSelected ? .white : Color(hex: "8899AA"))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, isYoung ? 16 : 12)
            .background(isSelected
                        ? Color.white.opacity(0.15)
                        : Color.white.opacity(0.05))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.white.opacity(0.5) : Color.clear, lineWidth: 1.5)
            )
            .scaleEffect(isSelected ? 1.06 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct EnergyButton: View {
    let level: Int
    let isSelected: Bool
    let isTeen: Bool
    let action: () -> Void

    private var label: String {
        switch level {
        case 1: return "🔋 Low"
        case 2: return "⚡️ Medium"
        default: return "🚀 High"
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(isSelected ? .white : Color(hex: "8899AA"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? Color(hex: "667EEA").opacity(0.35) : Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "667EEA") : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct PracticeAnswerButton: View {
    let label: String
    let isSelected: Bool
    let isAffirmative: Bool
    let isTeen: Bool
    let action: () -> Void

    private var activeColor: Color {
        isAffirmative ? Color(hex: "43E97B") : Color(hex: "667EEA")
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : Color(hex: "8899AA"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? activeColor.opacity(0.3) : Color.white.opacity(0.05))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? activeColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Post-submit confirmation

private struct CheckInConfirmationView: View {
    let ageGroup: AgeGroup
    let onDone: () -> Void

    private var isYoung: Bool { ageGroup == .veryYoung || ageGroup == .young }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(isYoung ? "🌟" : "✓")
                .font(.system(size: isYoung ? 80 : 56))
            Text(isYoung ? "Yay! All done!" : "Check-in complete")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(isYoung
                 ? "Your grown-up will see how you're doing. Good night! 🌙"
                 : "Your caregiver can see your mood and practice update. Good night.")
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(Color(hex: "AABBCC"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button(action: onDone) {
                Text("Done")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "0D1117"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "5B9BF0"))
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}
