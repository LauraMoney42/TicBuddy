// TicBuddy — RewardMilestoneSheet.swift
// tb-mvp2-016: Shared milestone celebration sheet shown to child when they cross a reward tier
// (every 10 points). Tone adapts to age group — younger = big celebration, teens = understated.
//
// Privacy: shows the child's own total. Parent dashboard also updates (via @Published familyUnit).
// No caregiver-specific state is modified here.

import SwiftUI

/// Shown in all three child mode views when awardPoints() crosses a tier boundary.
struct RewardMilestoneSheet: View {
    let totalPoints: Int
    let ageGroup: AgeGroup
    @Environment(\.dismiss) private var dismiss

    private var tierNumber: Int { totalPoints / 10 }

    private var isYoung: Bool {
        ageGroup == .veryYoung || ageGroup == .young
    }

    private var isTeen: Bool {
        ageGroup == .youngTeen || ageGroup == .teen
    }

    // MARK: - Age-adaptive copy

    private var headline: String {
        if isYoung { return "You got a new star tier! 🌟🌟🌟" }
        if isTeen  { return "Tier \(tierNumber) reached." }
        return "New reward tier! ⭐️"
    }

    private var subheadline: String {
        if isYoung { return "Wow! You now have \(totalPoints) stars! Tell your grown-up — they're going to be so proud!" }
        if isTeen  { return "\(totalPoints) points total. Your caregiver will see this when they check in." }
        return "You've earned \(totalPoints) points. Your caregiver can see your progress!"
    }

    private var emoji: String {
        if isYoung { return "🎉" }
        if isTeen  { return "📈" }
        return "⭐️"
    }

    private var dismissLabel: String {
        if isYoung { return "Yay! Keep going!" }
        if isTeen  { return "Got it" }
        return "Awesome!"
    }

    private var backgroundColor: Color {
        if isYoung { return Color(hex: "43E97B") }
        if isTeen  { return Color(hex: "0D1117") }
        return Color(.systemBackground)
    }

    private var textColor: Color {
        (isYoung || isTeen) ? .white : .primary
    }

    var body: some View {
        ZStack {
            backgroundColor.ignoresSafeArea()

            VStack(spacing: 28) {

                Spacer()

                // Big emoji
                Text(emoji)
                    .font(.system(size: isYoung ? 80 : 56))

                // Tier badge
                ZStack {
                    Circle()
                        .fill(tierColor.opacity(isYoung ? 0.25 : 0.15))
                        .frame(width: 90, height: 90)
                    VStack(spacing: 2) {
                        Text("TIER")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(tierColor)
                            .tracking(1.5)
                        Text("\(tierNumber)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(tierColor)
                    }
                }

                // Headlines
                VStack(spacing: 10) {
                    Text(headline)
                        .font(.system(size: isYoung ? 26 : 22, weight: .bold, design: .rounded))
                        .foregroundColor(textColor)
                        .multilineTextAlignment(.center)

                    Text(subheadline)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(textColor.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 20)
                }

                // Total points pill
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("\(totalPoints) total points")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(textColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(isYoung ? 0.25 : 0.08))
                .cornerRadius(20)

                Spacer()

                // Dismiss button
                Button {
                    dismiss()
                } label: {
                    Text(dismissLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(isYoung ? Color(hex: "43E97B") : textColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isYoung ? Color.white : tierColor.opacity(0.15))
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    /// Color scales with tier number
    private var tierColor: Color {
        switch tierNumber {
        case 1:  return Color(hex: "43E97B")   // green
        case 2:  return Color(hex: "667EEA")   // blue
        case 3:  return Color(hex: "FA709A")   // pink
        case 4:  return Color(hex: "F6D365")   // gold
        case 5:  return Color(hex: "A18CD1")   // purple
        default: return Color(hex: "FA8231")   // orange (tier 6+)
        }
    }
}
