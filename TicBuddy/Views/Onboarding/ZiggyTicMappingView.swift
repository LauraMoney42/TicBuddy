// TicBuddy — ZiggyTicMappingView.swift
// tb-tic-ziggy-001: Ziggy-first tic mapping conversation.
//
// Shown once (AppStorage gated) before TicIntakeAssessmentView during first-time
// onboarding. Ziggy discovers the user's top-3 most distressing tics via friendly
// conversation, then outputs a structured [TIC_MAPPING_COMPLETE: {...}] tag that
// pre-populates the manual tic grid.
//
// Session is exempt from daily message limits (one-time onboarding event).
// User can skip at any time → proceeds to empty manual grid.

import SwiftUI
import Speech

// MARK: - Tic Mapping Result (parsed from Ziggy structured output)

struct TicMappingResult: Codable {
    struct TicEntry: Codable {
        let name: String
        let category: String        // "motor" | "vocal" | "complex"
        let distress: Int           // 1–10
        let description: String
        let hasUrge: Bool
        let urgeDescription: String
    }
    let tics: [TicEntry]
}

// MARK: - View

struct ZiggyTicMappingView: View {
    @EnvironmentObject var dataService: TicDataService
    let child: ChildProfile

    /// Called with parsed tic entries when Ziggy finishes the mapping conversation.
    let onComplete: ([TicHierarchyEntry]) -> Void
    /// Called when the user taps "Skip — add tics manually".
    let onSkip: () -> Void

    @StateObject private var service = ClaudeService()
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @FocusState private var inputFocused: Bool

    // tb-ziggy-voice-001: TTS for Ziggy messages in tic mapping session.
    // @ObservedObject so speaker/mute toggle UI reacts to isEnabled/isSpeaking changes.
    @ObservedObject private var ttsService = ZiggyTTSService.shared
    // tb-ziggy-ui-001: Mic input — same SpeechRecognizer.shared pattern as CaregiverOnboardingZiggyView.
    @ObservedObject private var speechRecognizer = SpeechRecognizer.shared
    // tb-tic-map-continue-001: Hold parsed hierarchy until user taps "See My Tic Map →".
    // Replaces the 1.5s auto-transition so the user can read Ziggy's closing message first.
    @State private var pendingHierarchy: [TicHierarchyEntry]? = nil

    // MARK: System Prompt

    private var ticMappingSystemPrompt: String {
        let name = child.displayName.isEmpty ? "there" : child.displayName
        return """
        TIC MAPPING CONVERSATION — SPECIAL ONE-TIME ONBOARDING SESSION:

        You are helping \(name) identify and document their most distressing tics for the \
        very first time. This is NOT a regular CBIT session — it is a brief, friendly intake \
        conversation to build their tic list.

        YOUR GOAL: Discover the top 3 most distressing tics through natural conversation. \
        Stop at 3 — do not collect more, even if the user mentions others.

        HOW TO PROCEED:
        1. Your opening message (already sent) has welcomed \(name) and asked what tics bother \
        them most.
        2. For EACH tic mentioned, ask 1–2 short clarifying questions ONLY:
           - "What does it look or sound like?" (brief description)
           - "On a scale of 1 to 10, how much does it bother you — where 1 is not bothersome at all and 10 is the most bothersome?" (distress rating)
           - If unclear: "Is it more of a movement or a sound?" (category)
        3. Once you have 3 tics (or when the user signals they're done with fewer), confirm:
           "Okay, so your top 3 are: [list]. Does that sound right?"
        4. Once confirmed, close with this message and then output the structured tag:
           "We'll focus on these 3 for now — that's exactly how CBIT works. Once you've made \
           progress, the same approach works for any other tics you want to tackle later. 💪"
           Then on the same message as the very last content, output:
           [TIC_MAPPING_COMPLETE: {"tics":[{"name":"Eye Blink","category":"motor","distress":8,"description":"rapid blinking","hasUrge":false,"urgeDescription":""},{"name":"Throat Clear","category":"vocal","distress":6,"description":"loud clearing","hasUrge":true,"urgeDescription":"tickle in throat"}]}]

        RULES:
        - Keep every reply to 2–4 sentences maximum — short and conversational
        - Never rush — let \(name) describe in their own words
        - STOP collecting tics after 3 — if they mention a 4th, acknowledge it warmly and \
          say "We'll save that for after you've worked through these three first."
        - Category values: "motor" (any movement), "vocal" (sounds/words/phrases), \
          "complex" (coordinated movement sequences)
        - Distress must be an integer 1–10; suggest "how much does it interrupt your day?" \
          if they are unsure
        - Descriptions: brief phrase, under 20 words
        - NEVER output [TIC_MAPPING_COMPLETE] until you have confirmed the list with \(name)
        - The tag must be the very last content in your message
        - If \(name) has fewer than 3 tics, that is perfectly fine — never push for more

        TONE: warm, curious, casual — like a knowledgeable friend who genuinely cares.
        """
    }

    // MARK: Opening Ziggy Message

    private func openingMessage() -> String {
        let name = child.displayName.isEmpty ? "there" : child.displayName
        return "Hey \(name)! I'm going to help you build your tic list — it only takes a few minutes and there are no wrong answers. 😊\n\nWhat are the tics that bother you the most right now — the ones you'd most want to work on?"
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                VStack(spacing: 0) {
                    messageList
                    // tb-tic-map-continue-001: "See My Tic Map →" appears once Ziggy
                    // outputs [TIC_MAPPING_COMPLETE]. User taps when ready — no auto-transition.
                    if let hierarchy = pendingHierarchy {
                        Button {
                            onComplete(hierarchy)
                        } label: {
                            Text("See My Tic Map →")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(hex: "667EEA"))
                        }
                    }
                    Divider()
                    inputBar
                }
            }
            .navigationTitle("Map Your Tics with Ziggy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onSkip) {
                        VStack(spacing: 0) {
                            Text("Skip").font(.subheadline.bold())
                            Text("add tics manually").font(.caption)
                        }
                    }
                    .foregroundColor(.secondary)
                }
                // tb-ziggy-ui-001: Speaker/mute toggle — matches ChatView lines 157–183.
                ToolbarItem(placement: .navigationBarTrailing) {
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
            }
        }
        .onAppear {
            // Exempt this session from daily limits — one-time onboarding event
            ChatUsageLimiter.isOnboardingTicMappingActive = true
            // Seed the opening Ziggy message
            if messages.isEmpty {
                let opener = openingMessage()
                messages = [ChatMessage(role: .assistant, content: opener)]
                // tb-ziggy-voice-001: Speak the opening message via AI voice
                ttsService.speak(text: opener, voiceProfile: .olderChild)
            }
            // tb-ziggy-ui-001: Wire mic transcript callback + request permissions.
            // Same pattern as CaregiverOnboardingViewModel.setup().
            speechRecognizer.onFinalTranscript = { text in
                guard !text.isEmpty else { return }
                inputText = text
                sendMessage()
            }
            Task { await speechRecognizer.requestPermissions() }
        }
        .onDisappear {
            ChatUsageLimiter.isOnboardingTicMappingActive = false
            ttsService.stopSpeaking()
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording(fireCallback: false)
            }
        }
    }

    // MARK: Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        TicMappingBubble(message: msg)
                            .id(msg.id)
                    }
                    if isLoading {
                        TicMappingTypingIndicator()
                            .id("typing")
                    }
                    if let err = errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 20)
                            .id("error")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    if let lastID = messages.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isLoading) { loading in
                if loading {
                    withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            // tb-ziggy-ui-001: Mic button — same pattern as CaregiverOnboardingZiggyView MicButton.
            Button {
                #if targetEnvironment(simulator)
                // mic unavailable on simulator
                #else
                if speechRecognizer.isMicLocked {
                    speechRecognizer.toggleMicLock()
                } else if speechRecognizer.isRecording {
                    speechRecognizer.stopRecording(fireCallback: true)
                } else {
                    speechRecognizer.startRecording()
                }
                #endif
            } label: {
                ZStack {
                    if speechRecognizer.isRecording {
                        Circle()
                            .stroke(
                                speechRecognizer.isMicLocked ? Color.green : Color(hex: "667EEA"),
                                lineWidth: 2
                            )
                            .frame(width: 42, height: 42)
                            .scaleEffect(1.15)
                            .opacity(0.6)
                            .animation(
                                .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                                value: speechRecognizer.isRecording
                            )
                    }
                    Circle()
                        .fill(speechRecognizer.isRecording
                              ? (speechRecognizer.isMicLocked ? Color.green : Color(hex: "667EEA"))
                              : Color(.tertiaryLabel))
                        .frame(width: 36, height: 36)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 42, height: 42)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    #if targetEnvironment(simulator)
                    #else
                    if !speechRecognizer.isMicLocked { speechRecognizer.toggleMicLock() }
                    #endif
                }
            )

            TextField("Type your reply…", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .lineLimit(1...4)
                .focused($inputFocused)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading
                        ? Color(.tertiaryLabel) : Color(hex: "667EEA"))
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    // MARK: Send

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isLoading else { return }

        let userMsg = ChatMessage(role: .user, content: text)
        messages.append(userMsg)
        inputText = ""
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let reply = try await service.sendMessageWithCustomPrompt(
                    userMessage: text,
                    conversationHistory: Array(messages.dropLast()),
                    systemPrompt: ticMappingSystemPrompt,
                    voiceProfile: .olderChild
                )

                await MainActor.run {
                    isLoading = false
                    messages.append(ChatMessage(role: .assistant, content: reply))
                    // tb-ziggy-voice-001: Speak Ziggy's reply via AI voice.
                    // Strip [TIC_MAPPING_COMPLETE: ...] tag before TTS — same logic as TicMappingBubble.displayContent.
                    let speakableReply: String = {
                        let marker = "[TIC_MAPPING_COMPLETE:"
                        if let range = reply.range(of: marker) {
                            return String(reply[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        return reply
                    }()
                    ttsService.speak(text: speakableReply, voiceProfile: .olderChild)
                    // tb-tic-map-continue-001: Store result — no auto-transition.
                    // "See My Tic Map →" button appears and user taps when ready.
                    if let hierarchy = parseTicMappingComplete(from: reply) {
                        pendingHierarchy = hierarchy
                        // tb-mvp2-159: Warm closing message naming the target tic + homework framing.
                        // Target tic = hierarchy[0] (sorted highest distress first in parseTicMappingComplete).
                        let targetName = hierarchy.first?.ticName ?? "your most bothersome tic"
                        let closing = "It sounds like your most bothersome tic is \(targetName). 🌟 That's your focus this week — not to stop it, just to notice it. When you feel that urge coming on, that's a win! Pop it in your tic counter so we can track your catches together. You've got this! 💪"
                        messages.append(ChatMessage(role: .assistant, content: closing))
                        ttsService.speak(text: closing, voiceProfile: .olderChild)
                    }
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Couldn't reach Ziggy — check your connection and try again."
                }
            }
        }
    }

    // MARK: Parse [TIC_MAPPING_COMPLETE: {...}]

    private func parseTicMappingComplete(from text: String) -> [TicHierarchyEntry]? {
        let marker = "[TIC_MAPPING_COMPLETE: "
        guard let markerRange = text.range(of: marker) else { return nil }

        // Everything after the marker — find the closing ] after the JSON object
        let afterMarker = text[markerRange.upperBound...]
        guard let closingBracket = afterMarker.lastIndex(of: "]") else { return nil }
        let jsonString = String(afterMarker[..<closingBracket])

        guard let data = jsonString.data(using: .utf8),
              let result = try? JSONDecoder().decode(TicMappingResult.self, from: data)
        else { return nil }

        // Map to TicHierarchyEntry, capped at top 3, sorted by distress desc
        let entries = result.tics
            .prefix(3)
            .sorted { $0.distress > $1.distress }
            .enumerated()
            .map { index, tic -> TicHierarchyEntry in
                let category: TicCategory = {
                    switch tic.category.lowercased() {
                    case "vocal":   return .vocal
                    case "complex": return .complex
                    default:        return .motor
                    }
                }()
                return TicHierarchyEntry(
                    ticName: tic.name,
                    nickname: "",
                    category: category,
                    distressRating: max(1, min(10, tic.distress)),
                    frequencyPerDay: 8,    // default: "sometimes" — user can adjust in grid
                    hasPremonitoryUrge: tic.hasUrge,
                    urgeDescription: tic.urgeDescription,
                    userDescription: tic.description,
                    hierarchyOrder: index
                )
            }

        return entries.isEmpty ? nil : entries
    }
}

// MARK: - Chat Bubble

private struct TicMappingBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    // Strip the [TIC_MAPPING_COMPLETE: ...] tag from display
    private var displayContent: String {
        let marker = "[TIC_MAPPING_COMPLETE:"
        if let range = message.content.range(of: marker) {
            return String(message.content[..<range.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return message.content
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 40) }

            if !isUser {
                Text("😉")
                    .font(.system(size: 24))
                    .alignmentGuide(.bottom) { d in d[.bottom] }
            }

            Text(displayContent)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(isUser ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isUser ? Color(hex: "667EEA") : Color(.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .cornerRadius(isUser ? 4 : 18, corners: isUser ? .bottomRight : .bottomLeft)

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Typing Indicator

private struct TicMappingTypingIndicator: View {
    @State private var dotOpacity: [Double] = [0.3, 0.3, 0.3]

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("😉")
                .font(.system(size: 24))
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 7, height: 7)
                        .opacity(dotOpacity[i])
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(18)
            .cornerRadius(4, corners: .bottomLeft)
            .onAppear { animateDots() }
            Spacer(minLength: 40)
        }
    }

    private func animateDots() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                    dotOpacity[i] = 1.0
                }
            }
        }
    }
}

// Note: cornerRadius(_:corners:) and RoundedCorner are defined in ChatView.swift (module-wide).
