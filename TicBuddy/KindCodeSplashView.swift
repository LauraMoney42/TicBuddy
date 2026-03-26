import SwiftUI

/// KindCode branded launch splash — shown for ~2s on cold start, then fades out.
/// Matches iOS dark mode system color for consistency across all KindCode apps.
struct KindCodeSplashView: View {
    @Binding var isShowing: Bool
    @State private var opacity: Double = 1.0
    @State private var logoScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            // Dark background — matches iOS dark mode system color
            Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // KindCode logo — uses asset image when available, falls back to
                // programmatic vector mark so the splash always renders correctly.
                KindCodeLogoView()
                    .frame(width: 180, height: 180)
                    .scaleEffect(logoScale)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7).delay(0.1),
                        value: logoScale
                    )

                Button {
                    if let url = URL(string: "https://kindcode.us") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Created by KindCode")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.655, green: 0.953, blue: 0.816),
                                    Color(red: 0.204, green: 0.831, blue: 0.600)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .tracking(0.6)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(opacity)
        .onAppear {
            // Pop logo in
            logoScale = 1.0

            // Fade out after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.5)) {
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isShowing = false
                }
            }
        }
    }
}

// MARK: - KindCode Logo Mark

/// Renders the KindCode logo.
/// If the "KindCodeLogo" image asset is present in Assets.xcassets, it is shown.
/// Otherwise falls back to the programmatic vector mark — a rounded square with
/// a stylised "KC" monogram using the KindCode green gradient, ensuring the splash
/// screen always renders correctly even before the asset is added.
struct KindCodeLogoView: View {
    // Brand gradient — matches "Created by KindCode" text colour below
    private let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.655, green: 0.953, blue: 0.816), // #A7F3D0 mint
            Color(red: 0.204, green: 0.831, blue: 0.600)  // #34D499 green
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        Group {
            // Prefer the real asset if supplied
            if UIImage(named: "KindCodeLogo") != nil {
                Image("KindCodeLogo")
                    .resizable()
                    .scaledToFit()
            } else {
                programmaticMark
            }
        }
    }

    /// Programmatic fallback: rounded square + "KC" monogram.
    private var programmaticMark: some View {
        ZStack {
            // Background tile
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.13, green: 0.18, blue: 0.16),
                            Color(red: 0.10, green: 0.14, blue: 0.13)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Subtle border
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(brandGradient, lineWidth: 2)
                .opacity(0.6)

            // "KC" monogram
            Text("KC")
                .font(.system(size: 68, weight: .bold, design: .rounded))
                .foregroundStyle(brandGradient)
                .tracking(2)
        }
    }
}

#Preview {
    KindCodeSplashView(isShowing: .constant(true))
}
