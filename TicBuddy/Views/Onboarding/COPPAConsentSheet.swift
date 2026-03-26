// TicBuddy — COPPAConsentSheet.swift
// Parental consent disclosure for children under 13 (tb-mvp2-014).
//
// Shown as a required sheet when a caregiver creates a child profile for an
// under-13 child (AgeGroups: veryYoung, young, olderChild).
//
// The caregiver must:
//   1. Review what data TicBuddy collects and why
//   2. Enter their email address (stored locally only — never transmitted)
//   3. Check two acknowledgment boxes
//   4. Tap "I Agree — Continue"
//
// Tapping "Cancel" returns to onboarding without saving the child profile.
//
// COPPA §312.3: Operators must obtain verifiable parental consent before collecting,
// using, or disclosing personal information from children under 13.
//
// Design note: warm, clear language — parents should feel confident, not alarmed.
// Legal language is accurate but written at a 10th-grade reading level.

import SwiftUI

struct COPPAConsentSheet: View {
    let childNickname: String
    let childAgeGroup: AgeGroup
    let onAccept: (String) -> Void   // passes caregiverEmail
    let onCancel: () -> Void

    @State private var caregiverEmail = ""
    @State private var acknowledgedData = false
    @State private var acknowledgedPrivacy = false
    @State private var showEmailError = false
    @FocusState private var emailFocused: Bool

    // Design decision (tb-mvp2-014): checkbox-only consent — email is optional but not required
    private var canProceed: Bool {
        acknowledgedData && acknowledgedPrivacy
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Header ────────────────────────────────────────────────
                    VStack(spacing: 10) {
                        Text("🔐")
                            .font(.system(size: 56))
                            .padding(.top, 24)

                        Text("Parent Consent Required")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)

                        Text("Because \(childNickname) is under 13, we're required by law (COPPA) to get your permission before saving any information about them.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 8)
                    }

                    // ── What We Collect ───────────────────────────────────────
                    ConsentSection(icon: "list.clipboard", title: "What TicBuddy stores") {
                        ConsentRow(emoji: "✅", text: "**Nickname** — '\(childNickname)' (not their full name)")
                        ConsentRow(emoji: "✅", text: "**Tic types** — e.g. 'Eye Blink', 'Throat Clearing'")
                        ConsentRow(emoji: "✅", text: "**Daily logs** — tic counts, urge strength, outcomes")
                        ConsentRow(emoji: "✅", text: "**CBIT coaching notes** — Ziggy conversations (on-device only)")
                        ConsentRow(emoji: "🚫", text: "**No full name, date of birth, or location**")
                        ConsentRow(emoji: "🚫", text: "**No advertising or behavioral tracking**")
                        ConsentRow(emoji: "🚫", text: "**No data shared with third parties**")
                    }

                    // ── How Data Is Used ──────────────────────────────────────
                    ConsentSection(icon: "brain.head.profile", title: "How it's used") {
                        ConsentRow(emoji: "💡", text: "AI coaching: tic types (not names) are sent to our AI server to personalize Ziggy's coaching. No names or dates are included.")
                        ConsentRow(emoji: "🔒", text: "Everything else stays on this device only — no cloud backup until you enable it.")
                        ConsentRow(emoji: "🗑️", text: "You can delete all of \(childNickname)'s data at any time in Settings → Family.")
                    }

                    // ── Your Rights ───────────────────────────────────────────
                    ConsentSection(icon: "hand.raised", title: "Your rights (COPPA §312.6)") {
                        ConsentRow(emoji: "👁️", text: "**Review** — you can view all data stored for \(childNickname) at any time")
                        ConsentRow(emoji: "🗑️", text: "**Delete** — request deletion of all data via Settings → Family")
                        ConsentRow(emoji: "🚫", text: "**Refuse further collection** — you can stop data collection by deleting \(childNickname)'s profile")
                    }

                    // ── Email ─────────────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Your email address", systemImage: "envelope")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("parent@example.com", text: $caregiverEmail)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .focused($emailFocused)
                            .onChange(of: caregiverEmail) { _ in showEmailError = false }

                        if showEmailError {
                            Text("Please enter a valid email address.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        Text("Optional — stored on this device only, never transmitted. Helps you keep a record of consent.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // ── Acknowledgments ───────────────────────────────────────
                    VStack(spacing: 14) {
                        ConsentCheckbox(
                            isChecked: $acknowledgedData,
                            text: "I am the parent or legal guardian of \(childNickname) and I consent to TicBuddy collecting the data described above to provide CBIT coaching support."
                        )

                        ConsentCheckbox(
                            isChecked: $acknowledgedPrivacy,
                            text: "I understand that \(childNickname)'s data will not be shared with advertisers or third parties, and I can request deletion at any time."
                        )
                    }
                    .padding(.horizontal, 4)

                    // ── Action Buttons ────────────────────────────────────────
                    VStack(spacing: 12) {
                        Button {
                            emailFocused = false
                            // Email is optional — proceed regardless of whether it was entered
                            onAccept(caregiverEmail.trimmingCharacters(in: .whitespaces))
                        } label: {
                            Text("I Agree — Continue")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    canProceed
                                    ? LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                                     startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.4)],
                                                     startPoint: .leading, endPoint: .trailing)
                                )
                                .cornerRadius(16)
                        }
                        .disabled(!canProceed)

                        Button("Not right now — go back", action: onCancel)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Privacy Consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        // Basic format check — caregiver enters their own email
        return trimmed.contains("@") && trimmed.contains(".") && trimmed.count > 5
    }
}

// MARK: - Supporting Views

private struct ConsentSection<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
    }
}

private struct ConsentRow: View {
    let emoji: String
    let text: LocalizedStringKey

    init(emoji: String, text: String) {
        self.emoji = emoji
        // Support **bold** markdown in text
        self.text = LocalizedStringKey(text)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji)
                .font(.system(size: 14))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ConsentCheckbox: View {
    @Binding var isChecked: Bool
    let text: String

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.2)) { isChecked.toggle() }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(isChecked ? Color(hex: "667EEA") : .secondary)
                    .frame(width: 24, height: 24)

                Text(text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isChecked
                ? Color(hex: "667EEA").opacity(0.08)
                : Color(.secondarySystemBackground)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isChecked ? Color(hex: "667EEA").opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    COPPAConsentSheet(
        childNickname: "Sam",
        childAgeGroup: .young,
        onAccept: { _ in },
        onCancel: {}
    )
}
