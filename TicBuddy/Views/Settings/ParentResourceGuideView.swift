import SwiftUI

// MARK: - ParentResourceGuideView
// Self-guided parent resource list accessible from Settings → Parents & Caregivers.
// Mirrors the link set in CBITResourcesSheet (CaregiverHomeView) without the therapist prep section.

struct ParentResourceGuideView: View {
    var body: some View {
        List {
            cbResources
            tournetteResources
            medicationNoteSection
        }
        .navigationTitle("CBIT & TS Resources")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - CBIT & Habit Reversal

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

    // MARK: - Tourette Syndrome

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

    // MARK: - Medical Note

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

// MARK: - LinkRow

struct LinkRow: View {
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

// MARK: - ResourceRow

struct ResourceRow: View {
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
