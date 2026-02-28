// TicBuddy — CaregiversView.swift
// "For Adults/Caregivers" — educational resource hub for parents, teachers,
// and family members supporting a child with Tourette Syndrome.
//
// All links point to credible medical/advocacy sources only.
// Medical disclaimer is prominently displayed at top of view.

import SwiftUI

struct CaregiversView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // MARK: ⚕️ Medical Disclaimer (always first)
                DisclaimerCard()

                // MARK: 📖 What is Tourette Syndrome
                InfoSection(
                    emoji: "📖",
                    title: "What is Tourette Syndrome?",
                    bodyText: """
Tourette Syndrome (TS) is a neurodevelopmental disorder characterized by repetitive, involuntary movements and vocalizations called tics. TS affects approximately 1 in 100 school-age children and is 3–4× more common in males.

Key facts:
• Tics typically begin between ages 5–7 and peak around age 10–12
• Tics often improve significantly in late adolescence
• TS commonly co-occurs with ADHD (50–60%) and OCD (20–60%)
• Tics are not voluntary — children cannot simply "stop" them
• Stress, excitement, fatigue, and illness can temporarily worsen tics
""",
                    links: [
                        ResourceLink(label: "CDC — About Tourette Syndrome", url: "https://www.cdc.gov/tourette-syndrome/about/index.html"),
                        ResourceLink(label: "Mayo Clinic — Tourette Syndrome", url: "https://www.mayoclinic.org/diseases-conditions/tourette-syndrome/symptoms-causes/syc-20350465"),
                        ResourceLink(label: "NIMH — Tourette Syndrome", url: "https://www.nimh.nih.gov/health/topics/tourette-syndrome"),
                    ]
                )

                // MARK: 🧠 How CBIT Works
                InfoSection(
                    emoji: "🧠",
                    title: "How CBIT Works",
                    bodyText: """
Comprehensive Behavioral Intervention for Tics (CBIT) is the gold-standard, evidence-based behavioral treatment for Tourette Syndrome — with Level 1 clinical evidence.

How it works:
1. Awareness Training — learn to recognize tics and the "urge" feeling before each tic
2. Competing Response Training — practice a subtle movement that physically prevents the tic
3. Relaxation Training — breathing and muscle relaxation to reduce tic-triggering stress
4. Function-Based Intervention — identify and modify situations where tics are worse

A landmark 2010 JAMA study found 52.5% of children showed meaningful improvement with CBIT (vs. 18.5% control). Effects were maintained at 6-month follow-up.

TicBuddy guides children through a 12-week digital CBIT program designed in line with published protocols.
""",
                    links: [
                        ResourceLink(label: "TAA — CBIT Overview", url: "https://tourette.org/research-medical/cbit-overview/"),
                        ResourceLink(label: "JAMA 2010 CBIT Study (Piacentini et al.)", url: "https://pubmed.ncbi.nlm.nih.gov/20483968/"),
                    ]
                )

                // MARK: 🔍 Find a CBIT Therapist
                InfoSection(
                    emoji: "🔍",
                    title: "Find a CBIT Therapist",
                    bodyText: """
TicBuddy is a self-guided tool — not a replacement for professional CBIT therapy. For moderate-to-severe tics, or when your child is struggling significantly, a trained CBIT therapist is the most effective option.

The Tourette Association of America maintains a searchable directory of CBIT-trained clinicians across the US.
""",
                    links: [
                        ResourceLink(label: "TAA — Find a Healthcare Provider", url: "https://tourette.org/find-a-healthcare-provider/"),
                        ResourceLink(label: "TAA — CBIT for Patients", url: "https://tourette.org/research-medical/cbit-overview/"),
                    ]
                )

                // MARK: 🏫 School Accommodations
                InfoSection(
                    emoji: "🏫",
                    title: "School Accommodations",
                    bodyText: """
Children with Tourette Syndrome may qualify for formal school accommodations under a 504 Plan or Individualized Education Program (IEP).

Common helpful accommodations:
• Extended time on tests
• Private space for tic release breaks
• Permission to leave class briefly
• Reduced writing load (if motor tics affect handwriting)
• Preferential seating (away from distractions)
• Exemption from oral reading aloud (if vocal tics are present)

Guidance for teachers:
In most cases, teachers are directed to ignore a child's tics and to instruct classmates to do the same. Drawing attention to tics — even with good intentions — can increase their frequency and cause shame. The exception is when a tic poses a risk of harm to the child or to other students, in which case staff should respond calmly and privately.

A 504 Plan covers accommodations only. An IEP additionally provides specialized instruction and services. Talk to your child's school counselor or special education coordinator to begin the process.
""",
                    links: [
                        ResourceLink(label: "TAA — School & TS Resource Guide", url: "https://tourette.org/about-tourette/overview/school-accommodations/"),
                        ResourceLink(label: "CDC — 504 Plans for Students", url: "https://www.cdc.gov/ncbddd/adhd/school-success.html"),
                    ]
                )

                // MARK: 💬 Talking to Teachers & Coaches
                InfoSection(
                    emoji: "💬",
                    title: "Talking to Teachers & Coaches",
                    bodyText: """
Educators and coaches who understand TS can make an enormous difference. Here's how to approach those conversations:

DO:
• Share a brief, factual explanation: "My child has Tourette Syndrome — it causes involuntary movements and sounds they can't control."
• Provide the TAA's educator resources (link below)
• Ask for a private meeting — not a hallway conversation
• Request that tics not be addressed in front of classmates

DO NOT:
• Ask teachers to remind your child to "stop" the tic
• Expect your child to suppress tics all day (exhausting and counterproductive)
• Wait until a crisis — proactive conversations work best

The TAA has a free educator toolkit specifically designed for this.
""",
                    links: [
                        ResourceLink(label: "TAA — Educator's Guide to TS", url: "https://tourette.org/about-tourette/overview/educators/"),
                    ]
                )

                // MARK: 👨‍👩‍👧 Family & Sibling Support
                InfoSection(
                    emoji: "👨‍👩‍👧",
                    title: "Family & Sibling Support",
                    bodyText: """
Tourette Syndrome affects the whole family. Siblings may feel confused, embarrassed, or overlooked. Parents often feel helpless, guilty, or exhausted.

Tips for families:
• Talk openly — silence creates shame; matter-of-fact conversations create safety
• Educate siblings at their level: "It's like a sneeze you can't stop"
• Avoid drawing attention to tics — tic-watching increases tic frequency
• Celebrate effort and awareness, not tic reduction
• Seek caregiver support — parent stress affects children's tic levels

The TAA offers support groups, online communities, and family resources.
""",
                    links: [
                        ResourceLink(label: "TAA — Family Support Resources", url: "https://tourette.org/life-with-tourette/newly-diagnosed/"),
                        ResourceLink(label: "TAA — Online Support Community", url: "https://tourette.org/life-with-tourette/support-groups/"),
                    ]
                )

                // MARK: 📞 TAA Helpline & Support
                InfoSection(
                    emoji: "📞",
                    title: "TAA Helpline & Contact",
                    bodyText: """
The Tourette Association of America offers direct support to families navigating a new diagnosis or ongoing challenges.

TAA Helpline: 1-888-4-TOURET (1-888-486-8738)
Available Monday–Friday, 9am–5pm ET

The helpline can help with:
• Finding local support groups
• Navigating the school system
• Understanding treatment options
• Connecting with other families
""",
                    links: [
                        ResourceLink(label: "Tourette Association of America", url: "https://tourette.org/"),
                        ResourceLink(label: "TAA — Newly Diagnosed", url: "https://tourette.org/life-with-tourette/newly-diagnosed/"),
                    ]
                )

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
        .navigationTitle("For Adults & Caregivers")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Subviews

/// Prominent medical disclaimer card — always shown at top.
private struct DisclaimerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "cross.circle.fill")
                    .foregroundColor(.orange)
                Text("Medical Disclaimer")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            Text("TicBuddy is an educational tool, not a medical device. The information and activities in this app are not a substitute for professional medical advice, diagnosis, or treatment. Always consult a qualified healthcare provider or licensed CBIT therapist for your child's specific needs.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }
}

/// A single content section with title, body text, and optional resource links.
private struct InfoSection: View {
    let emoji: String
    let title: String
    let bodyText: String
    let links: [ResourceLink]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title2)
                Text(title)
                    .font(.headline)
            }

            // Body text
            Text(bodyText)
                .font(.subheadline)
                .foregroundColor(.primary.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            // Resource links
            if !links.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(links) { link in
                        if let url = URL(string: link.url) {
                            Link(destination: url) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                    Text(link.label)
                                        .font(.caption)
                                        .underline()
                                }
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }

            Divider()
                .padding(.top, 4)
        }
    }
}

/// Simple model for a labeled URL resource link.
private struct ResourceLink: Identifiable {
    let id = UUID()
    let label: String
    let url: String
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaregiversView()
    }
}
