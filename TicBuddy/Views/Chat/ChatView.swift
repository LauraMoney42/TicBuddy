// TicBuddy — ChatView.swift
// Main chat interface with TicBuddy AI.

import SwiftUI

struct ChatView: View {
    // Voice profile is determined automatically by ChatViewModel.activeVoiceProfile:
    //   - child active → profile based on their AgeGroup
    //   - no child (caregiver mode) → .caregiver
    // No param needed — ViewModel reads from familyUnit state directly.

    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject var dataService: TicDataService
    @State private var showTicLoggedBanner = false

    var body: some View {
        VStack(spacing: 0) {
            // Header — voice profile-aware name/avatar + countdown (tb-mvp2-012)
            ChatHeaderView(
                profile: dataService.userProfile,
                voiceProfile: viewModel.activeVoiceProfile,
                countdownMessage: viewModel.countdownMessage
            )

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }

                        if viewModel.isLoading {
                            TypingIndicatorView()
                                .id("typing")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        if let lastID = viewModel.messages.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        } else {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.isLoading) { _ in
                    if viewModel.isLoading {
                        withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                    }
                }
            }

            // Tic logged banner
            if showTicLoggedBanner, let entry = viewModel.lastLoggedEntry {
                TicLoggedBannerView(entry: entry)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Daily limit reached — swap input area for "come back tomorrow" banner
            if viewModel.isLimitReached {
                DailyLimitReachedView()
            } else {
                // Quick action chips
                QuickActionChipsView(viewModel: viewModel, dataService: dataService)

                // Input bar
                ChatInputView(viewModel: viewModel)
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: viewModel.lastLoggedEntry?.id) { _ in
            if viewModel.lastLoggedEntry != nil {
                withAnimation { showTicLoggedBanner = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { showTicLoggedBanner = false }
                }
            }
        }
        .onAppear {
            // Re-inject updated profile context on return to tab (no-op if session is mid-flight)
        }
        .onDisappear {
            // Session ends when user leaves the chat tab — extract memories in background.
            // CBITSessionStore silently swallows extraction failures, so this is safe.
            Task { await viewModel.endSession() }
        }
    }
}

// MARK: - Chat Header

struct ChatHeaderView: View {
    let profile: UserProfile
    var voiceProfile: ZiggyVoiceProfile = .olderChild  // tb-mvp2-012: profile-aware header
    var countdownMessage: String? = nil
    // Observe TTS service so speaker icon stays in sync with live state (tb-mvp2-011)
    @ObservedObject var ttsService: ZiggyTTSService = .shared

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: voiceProfile.avatarGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                Text(voiceProfile.avatarEmoji)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(voiceProfile.chatTitle)
                    .font(.headline.bold())

                // Show countdown when ≤5 exchanges remain; otherwise show profile subtitle.
                // Same text for both caregiver and child views (tb-mvp2-021).
                if let countdown = countdownMessage {
                    HStack(spacing: 4) {
                        Text(countdown)
                            .font(.caption.bold())
                            .foregroundColor(Color.orange)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 7, height: 7)
                        Text(voiceProfile.chatSubtitle(phase: profile.recommendedPhase))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: countdownMessage)

            Spacer()

            // TTS speaker toggle (tb-mvp2-011).
            // speaker.wave.2.fill = TTS on; speaker.slash.fill = TTS off.
            // Soft pulsing circle behind icon while Ziggy is actively speaking.
            Button {
                ttsService.isEnabled.toggle()
                if !ttsService.isEnabled { ttsService.stopSpeaking() }
            } label: {
                ZStack {
                    if ttsService.isSpeaking {
                        Circle()
                            .fill(Color(hex: "667EEA").opacity(0.15))
                            .frame(width: 36, height: 36)
                            .scaleEffect(ttsService.isSpeaking ? 1.2 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                                value: ttsService.isSpeaking
                            )
                    }
                    Image(systemName: ttsService.isEnabled
                          ? "speaker.wave.2.fill"
                          : "speaker.slash.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(ttsService.isEnabled ? Color(hex: "667EEA") : .secondary)
                }
                .frame(width: 40, height: 40)
            }
            .accessibilityLabel(ttsService.isEnabled ? "Mute Ziggy voice" : "Enable Ziggy voice")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Chat Bubble

struct ChatBubbleView: View {
    let message: ChatMessage

    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 50) }

            if !isUser {
                Text("⚡")
                    .font(.title3)
                    .padding(.bottom, 2)
            }

            Text(message.content)
                .font(.body)
                .foregroundColor(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                    ? LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color(.secondarySystemBackground), Color(.secondarySystemBackground)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(18, corners: isUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
                .shadow(color: .black.opacity(0.07), radius: 3, y: 1)

            if !isUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("⚡").font(.title3)

            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.2 : 0.8)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])

            Spacer(minLength: 50)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Tic Logged Banner

struct TicLoggedBannerView: View {
    let entry: TicEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Tic Logged! \(entry.outcome.emoji)")
                    .font(.headline.bold())
                Text("\(entry.displayName) — \(entry.outcome.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.15))
        .overlay(Rectangle().fill(Color.green).frame(width: 4), alignment: .leading)
    }
}

// MARK: - Daily Limit Reached Banner

struct DailyLimitReachedView: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Text("🌙")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("You're done for today!")
                        .font(.headline.bold())
                    Text("Come back tomorrow — Ziggy will be here! 💙")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "667EEA").opacity(0.12), Color(hex: "764BA2").opacity(0.12)],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .overlay(
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(height: 3),
                alignment: .top
            )
        }
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }
}

// MARK: - Quick Action Chips

struct QuickActionChipsView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var dataService: TicDataService

    // tb-mvp2-012: chips adapt to the active Ziggy voice profile
    private var quickMessages: [String] {
        viewModel.activeVoiceProfile.quickActionChips
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickMessages, id: \.self) { msg in
                    Button(action: {
                        viewModel.inputText = msg
                        viewModel.sendMessage()
                    }) {
                        Text(msg)
                            .font(.caption.bold())
                            .foregroundColor(Color(hex: "667EEA"))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(hex: "667EEA").opacity(0.1))
                            .cornerRadius(20)
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color(hex: "667EEA").opacity(0.3), lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Chat Input

struct ChatInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            TextField(viewModel.activeVoiceProfile.inputPlaceholder, text: $viewModel.inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(22)
                .focused($focused)
                .onSubmit { viewModel.sendMessage() }

            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(
                        viewModel.inputText.isEmpty || viewModel.isLoading
                        ? AnyShapeStyle(Color.gray)
                        : AnyShapeStyle(LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, y: -2)
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
