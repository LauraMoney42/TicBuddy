// TicBuddy — FamilyManagementView.swift
// V2 family profile management (tb-mvp2-017).
//
// Reachable from SettingsView → "Family Profiles" for family unit users.
// Allows caregivers to:
//   - View and edit caregiver display name
//   - View all child profiles (nickname, age group, session stage)
//   - Add a new child profile
//   - Edit a child (nickname, age group)
//   - Set or change a child's PIN
//   - Remove a child profile (with confirmation + data warning)
//
// Privacy design:
//   - Caregiver PINs managed here (set / change)
//   - Child PINs for ages 13+ are marked "Private" — caregiver cannot view the PIN itself
//   - All data stays on-device (COPPA compliant)

import SwiftUI

// MARK: - Family Management View

struct FamilyManagementView: View {
    @EnvironmentObject var dataService: TicDataService
    @State private var showAddChild = false
    @State private var editingChild: ChildProfile? = nil
    @State private var removingChild: ChildProfile? = nil
    @State private var showCaregiverEdit = false

    private var family: FamilyUnit { dataService.familyUnit }

    var body: some View {
        List {

            // ── Caregivers Section ─────────────────────────────────────────
            Section {
                ForEach(family.caregivers) { caregiver in
                    CaregiverRow(caregiver: caregiver)
                        .contentShape(Rectangle())
                }
            } header: {
                Text("Caregivers")
            } footer: {
                Text("Caregiver accounts can view all child data and manage the family unit.")
            }

            // ── Children Section ──────────────────────────────────────────
            Section {
                ForEach(family.children) { child in
                    ChildManagementRow(child: child) {
                        editingChild = child
                    }
                }
                .onDelete { indexSet in
                    // Capture the child to remove; show confirmation before deleting
                    if let first = indexSet.first {
                        removingChild = family.children[first]
                    }
                }

                // Add child button
                Button {
                    showAddChild = true
                } label: {
                    Label("Add Another Child", systemImage: "person.badge.plus")
                        .foregroundColor(Color(hex: "667EEA"))
                }
            } header: {
                Text("Children (\(family.children.count))")
            } footer: {
                Text("Each child has their own profile, tic logs, and optional PIN. Adolescents (13+) have private chat logs.")
            }

            // ── Device Config Summary ─────────────────────────────────────
            if let firstChild = family.children.first {
                Section("Device Setup") {
                    HStack {
                        Label(firstChild.deviceConfig.rawValue, systemImage: deviceConfigIcon(firstChild.deviceConfig))
                        Spacer()
                        Text(firstChild.deviceConfig.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }

            // ── Privacy & Data ────────────────────────────────────────────
            Section {
                Label("All data stored on this device only", systemImage: "lock.shield.fill")
                Label("Child names/ages never sent to AI", systemImage: "person.fill.checkmark")
                Label("Chat messages use anonymous child ID only", systemImage: "bubble.left.fill")
            } header: {
                Text("Privacy")
            } footer: {
                Text("TicBuddy is designed for COPPA compliance. No child PII leaves the device.")
            }
        }
        .navigationTitle("Family Profiles")
        .navigationBarTitleDisplayMode(.large)
        // Edit child sheet
        .sheet(item: $editingChild) { child in
            EditChildSheet(child: child)
                .environmentObject(dataService)
        }
        // Add child sheet
        .sheet(isPresented: $showAddChild) {
            AddChildSheet()
                .environmentObject(dataService)
        }
        // Remove child confirmation
        .confirmationDialog(
            "Remove \(removingChild?.displayName ?? "this child")?",
            isPresented: .init(
                get: { removingChild != nil },
                set: { if !$0 { removingChild = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove and Delete Data", role: .destructive) {
                if let child = removingChild {
                    removeChild(child)
                }
                removingChild = nil
            }
            Button("Cancel", role: .cancel) { removingChild = nil }
        } message: {
            Text("This will permanently delete \(removingChild?.displayName ?? "this child")'s tic logs, session data, and profile. This cannot be undone.")
        }
    }

    private func removeChild(_ child: ChildProfile) {
        // Use COPPAComplianceService.purgeChildData — covers tic entries, journal,
        // consent keys, Keychain PIN, and FamilyUnit removal in one call.
        COPPAComplianceService.shared.purgeChildData(child.id, dataService: dataService)
        dataService.saveFamilyUnit()
    }

    private func deviceConfigIcon(_ config: DeviceConfig) -> String {
        switch config {
        case .separateDevices: return "iphone.gen3"
        case .singleDevice:    return "iphone.gen3.badge.play"
        case .caregiverOnly:   return "person.crop.circle.badge.checkmark"
        }
    }
}

// MARK: - Caregiver Row

private struct CaregiverRow: View {
    let caregiver: CaregiverProfile

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(Color(hex: "667EEA"))

            VStack(alignment: .leading, spacing: 3) {
                Text(caregiver.displayName.isEmpty ? "Caregiver" : caregiver.displayName)
                    .font(.headline)
                Text(caregiver.relationship.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // First caregiver in the array is the primary

        }
        .padding(.vertical, 4)
    }
}

// MARK: - Child Management Row

private struct ChildManagementRow: View {
    let child: ChildProfile
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                // Age group avatar
                Text(child.ageGroup.subModeName == "Adolescent" ? "🧑" : "🧒")
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(child.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Text(child.ageGroup.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("·")
                            .foregroundColor(.secondary)
                            .font(.caption)

                        Text(child.sessionStage.shortLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // PIN indicator
                Image(systemName: child.hasPIN ? "lock.fill" : "lock.open")
                    .font(.caption)
                    .foregroundColor(child.hasPIN ? Color(hex: "43E97B") : .secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Edit Child Sheet

struct EditChildSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let child: ChildProfile

    @State private var nickname: String = ""
    @State private var selectedAgeGroup: AgeGroup = .young
    @State private var showPINSetup = false
    @State private var showPINChange = false
    /// COPPA §312.6 right-to-be-forgotten confirmation
    @State private var showDeleteDataConfirm = false

    private let pinService = FamilyPINService.shared
    private let coppa = COPPAComplianceService.shared

    var body: some View {
        NavigationStack {
            Form {

                // ── Identity ───────────────────────────────────────────────
                Section("Profile") {
                    HStack {
                        Text("Nickname")
                        Spacer()
                        TextField("e.g. Sam, Alex", text: $nickname)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    // Age group picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Age Group")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 100))],
                            spacing: 8
                        ) {
                            ForEach(AgeGroup.allCases, id: \.self) { group in
                                Button {
                                    selectedAgeGroup = group
                                } label: {
                                    VStack(spacing: 2) {
                                        Text(group.displayName)
                                            .font(.caption.bold())
                                            .multilineTextAlignment(.center)
                                        Text(group.subModeName)
                                            .font(.system(size: 10))
                                            .foregroundColor(selectedAgeGroup == group ? .white : .secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedAgeGroup == group
                                        ? Color(hex: "667EEA") : Color(.systemGray6))
                                    .foregroundColor(selectedAgeGroup == group ? .white : .primary)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── PIN Management ─────────────────────────────────────────
                Section {
                    if child.hasPIN {
                        // Change PIN
                        Button {
                            showPINChange = true
                        } label: {
                            Label("Change PIN", systemImage: "lock.rotation")
                        }

                        // Remove PIN (caregiver can always remove — even private teen PINs,
                        // since the device belongs to the family)
                        Button(role: .destructive) {
                            removePIN()
                        } label: {
                            Label("Remove PIN", systemImage: "lock.open")
                        }
                    } else {
                        Button {
                            showPINSetup = true
                        } label: {
                            Label("Set a PIN for \(child.displayName)", systemImage: "lock.fill")
                        }
                    }
                } header: {
                    Text("PIN")
                } footer: {
                    if child.ageGroup.childPINIsPrivate {
                        Text("⚠️ For ages 13+, PINs are private by design. Only \(child.displayName) should know their PIN.")
                    } else {
                        Text("A PIN prevents accidental profile switching. Optional for younger children.")
                    }
                }

                // ── COPPA §312.6 — Right to Be Forgotten ──────────────────
                // Only shown for under-13 profiles. Gives the caregiver a clear,
                // prominent path to erase all of the child's data as required by law.
                if child.ageGroup.isCOPPAApplicable {
                    Section {
                        Button(role: .destructive) {
                            showDeleteDataConfirm = true
                        } label: {
                            Label("Delete \(child.displayName)'s Data", systemImage: "trash.fill")
                        }
                    } header: {
                        Text("Privacy (COPPA §312.6)")
                    } footer: {
                        Text("As the parent or guardian, you have the right to request deletion of all data collected about \(child.displayName). This removes tic logs, session notes, practice history, and all app data. This cannot be undone.")
                    }
                }
            }
            .navigationTitle("Edit \(child.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showPINSetup) {
                SetChildPINSheet(child: child)
                    .environmentObject(dataService)
            }
            .sheet(isPresented: $showPINChange) {
                SetChildPINSheet(child: child)
                    .environmentObject(dataService)
            }
            // COPPA §312.6 right-to-be-forgotten confirmation
            .confirmationDialog(
                "Delete all data for \(child.displayName)?",
                isPresented: $showDeleteDataConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All Data", role: .destructive) {
                    deleteChildDataAndDismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes \(child.displayName)'s tic logs, session notes, practice history, and their profile. Required by COPPA §312.6 (right to erasure). This cannot be undone.")
            }
        }
        .onAppear {
            nickname = child.nickname
            selectedAgeGroup = child.ageGroup
        }
    }

    private func saveAndDismiss() {
        var updated = child
        updated.nickname = nickname.trimmingCharacters(in: .whitespaces)
        updated.ageGroup = selectedAgeGroup
        dataService.updateChild(updated)
        dismiss()
    }

    private func removePIN() {
        _ = pinService.deleteChildPIN(profileID: child.id)
        var updated = child
        updated.hasPIN = false
        dataService.updateChild(updated)
    }

    /// COPPA §312.6 — Right to Erasure.
    /// Purges all on-device data for this child, removes their profile, and dismisses.
    private func deleteChildDataAndDismiss() {
        coppa.purgeChildData(child.id, dataService: dataService)
        dataService.saveFamilyUnit()
        dismiss()
    }
}

// MARK: - Set Child PIN Sheet

private struct SetChildPINSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    let child: ChildProfile

    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var step: PINStep = .enter
    @State private var mismatch = false

    private let pinService = FamilyPINService.shared

    enum PINStep { case enter, confirm }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 10) {
                    Text("🔒")
                        .font(.system(size: 56))
                    Text(step == .enter ? "Set a PIN for \(child.displayName)" : "Confirm PIN")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(step == .enter
                         ? "Choose a 4-digit PIN"
                         : "Enter the PIN again to confirm")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 4-dot indicator
                HStack(spacing: 16) {
                    let currentPIN = step == .enter ? pin : confirmPin
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i < currentPIN.count
                                  ? Color(hex: "43E97B")
                                  : Color.secondary.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                }

                if mismatch {
                    Text("PINs don't match. Try again.")
                        .font(.caption.bold())
                        .foregroundColor(.red)
                }

                PINPad(
                    pin: step == .enter ? $pin : $confirmPin,
                    maxLength: 4
                ) {
                    handlePINComplete()
                }
                .padding(.horizontal, 60)

                Spacer()
            }
            .navigationTitle("Set PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func handlePINComplete() {
        switch step {
        case .enter:
            step = .confirm
            mismatch = false
        case .confirm:
            if confirmPin == pin {
                _ = pinService.saveChildPIN(pin, profileID: child.id)
                var updated = child
                updated.hasPIN = true
                dataService.updateChild(updated)
                dismiss()
            } else {
                mismatch = true
                confirmPin = ""
                // Return to enter step so user starts fresh
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    step = .enter
                    pin = ""
                    mismatch = false
                }
            }
        }
    }
}

// MARK: - Add Child Sheet

struct AddChildSheet: View {
    @EnvironmentObject var dataService: TicDataService
    @Environment(\.dismiss) private var dismiss

    @State private var nickname = ""
    @State private var selectedAgeGroup: AgeGroup = .young
    /// COPPA: caregiver must check this box for under-13 profiles (tb-mvp2-014)
    @State private var parentalConsentChecked = false

    private let coppa = COPPAComplianceService.shared

    /// True when selected age group is under 13 and requires COPPA consent.
    private var requiresCOPPAConsent: Bool {
        [AgeGroup.veryYoung, .young, .olderChild].contains(selectedAgeGroup)
    }

    private var canAdd: Bool {
        let hasName = !nickname.trimmingCharacters(in: .whitespaces).isEmpty
        let hasConsent = !requiresCOPPAConsent || parentalConsentChecked
        return hasName && hasConsent
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Sam, Alex, Jordan", text: $nickname)
                        .autocorrectionDisabled()
                } header: {
                    Text("Child's Nickname")
                } footer: {
                    Text("This is how TicBuddy will address them. No last names needed.")
                }

                Section {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 120))],
                        spacing: 10
                    ) {
                        ForEach(AgeGroup.allCases, id: \.self) { group in
                            Button {
                                selectedAgeGroup = group
                                // Reset consent when age group changes
                                parentalConsentChecked = false
                            } label: {
                                VStack(spacing: 4) {
                                    Text(group.displayName)
                                        .font(.subheadline.bold())
                                    Text(group.subModeName)
                                        .font(.caption)
                                        .foregroundColor(selectedAgeGroup == group ? .white : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(selectedAgeGroup == group
                                    ? Color(hex: "667EEA") : Color(.systemGray6))
                                .foregroundColor(selectedAgeGroup == group ? .white : .primary)
                                .cornerRadius(12)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Age Group")
                }

                Section {
                    // Privacy notes
                    Label("Nickname only — no last name stored", systemImage: "person.fill.checkmark")
                    Label("Tic logs stored locally on this device", systemImage: "iphone.gen3")
                    if selectedAgeGroup.childPINIsPrivate {
                        Label("Ages 13+: chat logs are private by default", systemImage: "lock.fill")
                    }
                    if requiresCOPPAConsent {
                        Label("Data auto-deleted after 30 days if inactive", systemImage: "trash.fill")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Privacy")
                }

                // MARK: COPPA Consent (under-13 only, tb-mvp2-014)
                if requiresCOPPAConsent {
                    Section {
                        Toggle(isOn: $parentalConsentChecked) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Parental Consent")
                                    .font(.subheadline.bold())
                                Text("I confirm I am the parent or legal guardian of this child and consent to their use of TicBuddy.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tint(Color(hex: "43E97B"))
                    } header: {
                        Text("Required for Under-13 (COPPA)")
                    } footer: {
                        Text("U.S. law (COPPA) requires verifiable parental consent before collecting data from children under 13. TicBuddy stores all data on-device only — no information is shared with third parties.")
                    }
                }
            }
            .navigationTitle("Add Child")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { addChildAndDismiss() }
                        .disabled(!canAdd)
                }
            }
        }
    }

    private func addChildAndDismiss() {
        let trimmed = nickname.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !requiresCOPPAConsent || parentalConsentChecked else { return }

        var newChild = ChildProfile()
        newChild.nickname = trimmed
        newChild.ageGroup = selectedAgeGroup
        newChild.hasPIN = false
        newChild.sessionStage = .session1
        var profile = UserProfile()
        profile.name = trimmed
        newChild.userProfile = profile

        dataService.addChild(newChild)

        // Record parental consent + initial activity timestamp (tb-mvp2-014)
        // Design decision: checkbox-only consent — both flags true when checkbox is checked
        if requiresCOPPAConsent {
            coppa.recordConsent(
                childID: newChild.id,
                caregiverEmail: "",
                acknowledgedDataCollection: true,
                acknowledgedNoThirdPartySharing: true
            )
        }
        coppa.recordActivity(for: newChild.id)

        // Set up caregiver notifications on first under-13 child added
        if requiresCOPPAConsent {
            Task { await coppa.setupCaregiverNotifications() }
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let service = TicDataService()
    var family = FamilyUnit()
    var caregiver = CaregiverProfile()
    caregiver.displayName = "Mom"
    family.caregivers = [caregiver]
    var child = ChildProfile()
    child.nickname = "Sam"
    child.ageGroup = .olderChild
    child.hasPIN = true
    family.children = [child]
    service.familyUnit = family
    return NavigationStack {
        FamilyManagementView()
            .environmentObject(service)
    }
}
