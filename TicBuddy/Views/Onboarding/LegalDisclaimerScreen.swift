// TicBuddy — LegalDisclaimerScreen.swift
// Full-screen "Before You Get Started" legal disclaimer (tb-mvp2-029).
//
// Shown once — before any Program content — when:
//   UserDefaults "ticbuddy_legal_accepted" == false (first install / reset)
//
// "I Understand and Agree" sets the flag and dismisses.
// Tap on [Terms of Use] / [Privacy Policy] → in-app SafariView (future V2).
//
// Text sourced from ticbuddy_legal.md Document 3.

import SwiftUI

// MARK: - Store

/// Persists the caregiver's one-time legal acceptance.
@MainActor
final class LegalConsentService: ObservableObject {
    static let shared = LegalConsentService()
    private init() {}

    private let key = "ticbuddy_legal_accepted"

    /// True once the user has tapped "I Understand and Agree".
    var hasAcknowledgedDisclaimer: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            objectWillChange.send()
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    func reset() {
        UserDefaults.standard.removeObject(forKey: key)
        objectWillChange.send()
    }
}

// MARK: - Screen

/// Matches the name expected by TicBuddyApp.swift wiring.
typealias LegalDisclaimerView = LegalDisclaimerScreen

struct LegalDisclaimerScreen: View {

    /// Called when the user taps "I Understand and Agree".
    let onAccept: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {

            // ── Background ──────────────────────────────────────────────────
            LinearGradient(
                colors: [Color(hex: "0D1117"), Color(hex: "1A1F36")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ── Scrollable content ──────────────────────────────────────────
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text("🛡️")
                            .font(.system(size: 48))
                        Text("Before You Get Started")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("TicBuddy is an educational and practice support tool — not a medical or therapy app.")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "43E97B"))
                    }

                    // What TicBuddy IS
                    DisclaimerSection(
                        title: "What TicBuddy IS",
                        emoji: "✅",
                        color: Color(hex: "43E97B"),
                        items: [
                            "A guide to help your family learn about and practice CBIT concepts",
                            "A tool for tracking tic management progress",
                            "An educational resource about Tourette Syndrome",
                            "A supportive companion for families navigating tic disorders"
                        ]
                    )

                    // What TicBuddy is NOT
                    DisclaimerSection(
                        title: "What TicBuddy is NOT",
                        emoji: "🚫",
                        color: Color(hex: "FF6B6B"),
                        items: [
                            "A replacement for a doctor, psychologist, or licensed CBIT therapist",
                            "A diagnostic tool",
                            "A medical treatment or clinical therapy program",
                            "A crisis service"
                        ]
                    )

                    // About Ziggy
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Text("🧠")
                            Text("About Ziggy, our AI companion")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        Text("Ziggy uses artificial intelligence to guide you through the CBIT framework. Ziggy is not a licensed professional. AI can make mistakes. Always consult a qualified healthcare provider for medical questions or concerns about your child's diagnosis or treatment.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(16)

                    // CBIT therapist nudge
                    HStack(spacing: 12) {
                        Image(systemName: "person.badge.shield.checkmark.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "667EEA"))
                        Text("We strongly encourage you to work with a certified CBIT therapist. Find one at **tourette.org**.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color(hex: "667EEA").opacity(0.12))
                    .cornerRadius(14)

                    // Crisis banner
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "FEE140"))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("In a crisis?")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "FEE140"))
                            Text("Call 911 or go to your nearest emergency room. You can also call or text 988 — the US Suicide & Crisis Lifeline. Do not rely on an app in an emergency.")
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(14)
                    .background(Color(hex: "FEE140").opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "FEE140").opacity(0.3), lineWidth: 1)
                    )
                    .cornerRadius(14)

                    // Bottom spacer for the fixed button
                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
            }

            // ── Fixed bottom: accept button + legal links ───────────────────
            VStack(spacing: 0) {
                // Gradient fade behind button
                LinearGradient(
                    colors: [Color.clear, Color(hex: "0D1117")],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 40)
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                    // Agreement text
                    Group {
                        Text("By tapping below, you confirm you have read this notice, understand the nature and limitations of this App, and agree to our ")
                        + Text("Terms of Use")
                            .underline()
                            .foregroundColor(Color(hex: "667EEA"))
                        + Text(" and ")
                        + Text("Privacy Policy")
                            .underline()
                            .foregroundColor(Color(hex: "667EEA"))
                        + Text(".")
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                    // Accept button
                    Button(action: onAccept) {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                            Text("I Understand and Agree")
                                .fontWeight(.bold)
                        }
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(18)
                        .shadow(color: Color(hex: "667EEA").opacity(0.4), radius: 10, y: 4)
                    }
                    .padding(.horizontal, 24)

                    Text("If you do not agree, please exit the App.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.bottom, 8)
                }
                .padding(.vertical, 12)
                .background(Color(hex: "0D1117"))
            }
        }
    }
}

// MARK: - Section Component

private struct DisclaimerSection: View {
    let title: String
    let emoji: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(emoji)
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            VStack(alignment: .leading, spacing: 7) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(color.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        Text(item)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(color.opacity(0.07))
        .cornerRadius(16)
    }
}
