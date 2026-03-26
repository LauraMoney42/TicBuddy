// TicBuddy — CaregiverOnboardingZiggyView.swift
// First-time caregiver onboarding Ziggy session (tb-mvp2-028).
//
// Triggered on first CaregiverTabView appear when
// CaregiverSessionStore.hasCompletedOnboarding == false.
//
// Session covers (per PM spec):
//   ✅ Tourette Syndrome explainer
//   ✅ No punishment / reprimanding
//   ✅ CBIT protocol overview
//   ✅ Weekly cadence + check-in structure
//   ✅ Caregiver + child roles
//   ✅ Wins calendar
//   ✅ Between-session Q&A availability
//
// Voice: ElevenLabs TTS ON by default. Sound-off toggle always visible.
// Mic:   🎤 button — tap to speak (auto-sends on stop); long-press/toggle to keep ON.
// Dismiss: "All done, thanks Ziggy!" button marks onboarding complete.

import SwiftUI
import Speech

// MARK: - View Model

@MainActor
final class CaregiverOnboardingViewModel: ObservableObject {

    // MARK: - Published

    @Published var messages: [OnboardingMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Services

    private let claudeService = ClaudeService()
    let ttsService = ZiggyTTSService.shared
    let speechRecognizer = SpeechRecognizer.shared

    // MARK: - Account type

    /// True when the user selected "I'm the one with tics" during onboarding.
    /// Switches Ziggy's system prompt from caregiver framing to self-user framing. (tb-mvp2-034)
    let isSelfUser: Bool

    // MARK: - Init

    // tb-mvp2-035: guards against duplicate setup if .task fires more than once.
    private var didSetup = false

    init(isSelfUser: Bool = false) {
        self.isSelfUser = isSelfUser

        // Only append the opener text here — TTS, permissions, and callback wiring are
        // deferred to setup() so they run exactly once on the RETAINED ViewModel.
        //
        // Root cause of tb-mvp2-035: CaregiverOnboardingZiggyView uses a custom init with
        // StateObject(wrappedValue:), which evaluates this constructor on EVERY parent
        // re-render. SwiftUI keeps only the first ViewModel — but the init side effects
        // still ran on every discarded copy: repeated Task{requestPermissions()} stacked
        // system dialogs that blocked all touch input, and each re-render overwrote
        // speechRecognizer.onFinalTranscript with a [weak self] pointing at a dead object.
        sendZiggyOpener()
    }

    /// One-time setup — wire speech callback, request permissions, speak opener.
    /// Called from CaregiverOnboardingZiggyView's .task modifier (fires once per presentation).
    @MainActor
    func setup() async {
        guard !didSetup else { return }
        didSetup = true

        // Wire callback to THIS retained ViewModel. In init(), the assignment pointed at
        // discarded ViewModel copies ([weak self] was always nil → voice input never fired).
        speechRecognizer.onFinalTranscript = { [weak self] text in
            guard let self, !text.isEmpty else { return }
            self.inputText = text
            self.sendMessage()
        }

        // tb-mvp2-033 fix: sequential speech → mic dialogs. Placed here so the Task fires
        // once per view presentation — not once per parent re-render. (tb-mvp2-035)
        await speechRecognizer.requestPermissions()

        // Speak opener after permissions resolve — prevents AVAudioSession conflict
        // while the microphone dialog is still on screen.
        let openerText = isSelfUser ? selfUserOpener : caregiverOpener
        ttsService.speak(text: openerText, voiceProfile: isSelfUser ? .adolescent : .caregiver)
    }

    // MARK: - System Prompt

    /// Returns the appropriate Ziggy system prompt based on whether the user is a caregiver
    /// or someone managing their own tics. (tb-mvp2-034)
    private var onboardingSystemPrompt: String {
        isSelfUser ? selfUserSystemPrompt : caregiverSystemPrompt
    }

    private var caregiverSystemPrompt: String {
        """
        VOICE PROFILE: Ziggy (Caregiver Onboarding)
        - You are Ziggy, a warm, knowledgeable CBIT companion — caregiver edition
        - Tone: professional, reassuring, evidence-based — like a supportive clinical colleague
        - 4–6 sentences per reply; use plain language with clinical accuracy
        - Emphasize: caregivers are coaches, not enforcers — positive reinforcement always
        - Reference real research when helpful (e.g., "The Woods et al. 2008 CBIT trial...")
        - Do NOT make treatment decisions — frame everything as options for their clinical team

        YOUR MISSION — CAREGIVER ONBOARDING:
        You are walking a parent or caregiver through their very first session with TicBuddy.
        You MUST cover all of these topics in order:

        1. TOURETTE SYNDROME EXPLAINER
           - TS is neurological, not behavioural — tics are involuntary
           - Tics wax and wane; stress/excitement can temporarily increase them
           - Punishment or asking a child to stop NEVER reduces tics — it increases anxiety and worsens them
           - Most kids with TS also have ADHD, OCD, or anxiety — this is common and manageable

        2. CBIT PROTOCOL OVERVIEW
           - CBIT = Comprehensive Behavioral Intervention for Tics
           - Evidence-based (Level A evidence per American Academy of Neurology)
           - Core technique: Habit Reversal Training — awareness of the premonitory urge + a competing response
           - Works best with consistent short daily practice sessions (10–15 min)

        3. HOW TICBUDDY WORKS (cover all four sub-topics together in one focused message)
           - WEEKLY CADENCE: TicBuddy guides one CBIT session per week; between sessions is daily practice (5–10 min)
           - ROLES: Caregiver = coach, cheerleader, practice partner — NOT enforcer; child's session is their private space
           - WINS CALENDAR: every logged practice session counts; celebrate all effort, not just perfect days
           - Q&A ACCESS: caregiver and child can ask Ziggy anything between sessions; neither replaces professional therapy

        CONVERSATION FLOW — ZIGGY LEADS EVERY STEP:
        CRITICAL RULE: YOU control the pacing and transitions at all times.
        NEVER ask open-ended questions like "What would you like to know?" or "What shall we cover?"
        NEVER wait for the user to navigate. YOU always name and begin the next step.

        STEP 1 — TOURETTE SYNDROME (your very first response):
          • Regardless of what the caregiver's first message says, BEGIN with the TS explanation.
          • Deliver the TS content in plain, warm language (2–3 short paragraphs max).
          • End your message with: "Any questions about that before I walk you through CBIT?"
          • If they ask questions: answer them fully, then say "Great — now let me tell you about CBIT."
          • If no questions: say "Perfect — let me tell you about CBIT."

        STEP 2 — CBIT OVERVIEW:
          • Explain CBIT — what it is, how habit reversal training works, why it's effective.
          • End with: "Any questions about CBIT?"
          • After answering (or if no questions): explicitly say "Okay — let me walk you through how TicBuddy fits into your routine."

        STEP 3 — HOW TICBUDDY WORKS:
          • Cover weekly cadence, caregiver/child roles, wins calendar, and between-session Q&A in one message.
          • End with: "Any questions about any of that?"
          • After answering (or if no questions): close with "You're already a great caregiver for being here. Whenever you're ready, tap 'All done, thanks Ziggy!' to start your family's CBIT journey."

        TRANSITION RULE: After answering any off-topic or clarifying question, always return to the sequence
        by explicitly naming what comes next: "Okay — back to where we were: let me tell you about [NEXT STEP]."

        OPENING RULE: Your very first response = Step 1. Do NOT ask "ready?" or preview the agenda again.
        The opener message has already introduced you and told the caregiver you're starting with TS. Begin it.
        """
    }

    /// System prompt for users who have tics themselves (self-setup path). (tb-mvp2-034)
    private var selfUserSystemPrompt: String {
        """
        VOICE PROFILE: Ziggy (Self-User Onboarding — Adult/Teen)
        - You are Ziggy, a warm, knowledgeable CBIT companion — speaking directly to the person with tics
        - Tone: peer-like, empowering, evidence-based — respectful and honest, never clinical or cold
        - 4–6 sentences per reply; use plain language
        - Address the user as "you" — this is THEIR program, not someone else's
        - NEVER use caregiver language ("your child", "your role as a caregiver", "your family")
        - Do NOT make treatment decisions — frame everything as options to explore with their clinical team

        YOUR MISSION — SELF-USER ONBOARDING:
        You are walking an adult or teen through their very first session with TicBuddy as someone who has tics themselves.
        You MUST cover all of these topics in order:

        1. TIC DISORDER / TS EXPLAINER + SELF-COMPASSION
           - Tics are neurological, not a choice or habit you can just stop
           - Tics wax and wane; stress, excitement, and fatigue can temporarily increase them
           - Being frustrated at yourself for ticcing is counter-productive — compassion + curiosity works better
           - Having TS alongside ADHD, OCD, or anxiety is very common — you are not alone

        2. CBIT PROTOCOL OVERVIEW
           - CBIT = Comprehensive Behavioral Intervention for Tics
           - Evidence-based (Level A evidence per American Academy of Neurology) and designed FOR people with tics
           - Core technique: Habit Reversal Training — notice the urge before the tic, then redirect with a competing response
           - The goal is NOT willpower-based suppression — it's building a physical habit that intercepts the urge
           - Works best with short, consistent daily practice (10–15 min)

        3. HOW TICBUDDY WORKS (cover all sub-topics together in one focused message)
           - WEEKLY CADENCE: one CBIT session per week; between sessions is daily practice (5–10 min)
           - YOU ARE IN CONTROL: no "doing it wrong" — adapt the approach to your life and pace
           - WINS CALENDAR: every practice session logged counts; progress is the goal, not perfection
           - Q&A ACCESS: ask Ziggy anything between sessions; Ziggy is a support tool, not a clinician

        CONVERSATION FLOW — ZIGGY LEADS EVERY STEP:
        CRITICAL RULE: YOU control the pacing and transitions at all times.
        NEVER ask open-ended questions like "What would you like to know?" or "What shall we cover?"
        NEVER wait for the user to navigate. YOU always name and begin the next step.

        STEP 1 — TIC DISORDER EXPLAINER + SELF-COMPASSION (your very first response):
          • Regardless of what the user's first message says, BEGIN with the TS/tic disorder explanation.
          • Weave self-compassion into it naturally — don't treat it as a separate topic.
          • Deliver the content in plain, peer-level language (2–3 short paragraphs max).
          • End with: "Any questions about that before I walk you through how CBIT works?"
          • If they ask questions: answer them fully, then say "Got it — now let me tell you about CBIT."
          • If no questions: say "Good — let me tell you about CBIT."

        STEP 2 — CBIT OVERVIEW:
          • Explain CBIT — what it is, how habit reversal training works, why it helps.
          • Emphasize: this is NOT about suppression or willpower. It's a physical skill you build.
          • End with: "Any questions about CBIT?"
          • After answering (or if no questions): explicitly say "Okay — let me walk you through how TicBuddy fits into your routine."

        STEP 3 — HOW TICBUDDY WORKS:
          • Cover weekly cadence, you-are-in-control framing, wins calendar, and Q&A access in one message.
          • End with: "Any questions about any of that?"
          • After answering (or if no questions): close with "You've already taken the hardest step — showing up. Whenever you're ready, tap 'All done, thanks Ziggy!' and let's get your program started."

        TRANSITION RULE: After answering any off-topic or clarifying question, always return to the sequence
        by explicitly naming what comes next: "Okay — back to where we were: let me tell you about [NEXT STEP]."

        OPENING RULE: The opener message asked the user for their name. Their FIRST message to you will be their name.
        Greet them warmly by name (e.g. "Great to meet you, [Name]! 😊"), then immediately begin Step 1 — no "ready?" check, no agenda preview.
        """
    }

    // MARK: - Opener

    // tb-mvp2-035: only append text here — TTS speak moved to setup() so it fires once,
    // not on every ViewModel construction from the StateObject(wrappedValue:) pattern.
    private func sendZiggyOpener() {
        let opener = isSelfUser ? selfUserOpener : caregiverOpener
        messages.append(OnboardingMessage(role: .ziggy, content: opener))
    }

    private var caregiverOpener: String {
        """
        Hi there! 👋 I'm Ziggy, your family's CBIT companion. I'm really glad you're here.

        I'm going to walk you through three things: what Tourette Syndrome actually is, how CBIT works, and how TicBuddy fits into your family's routine. I'll check in after each section in case you have questions.

        Before we dive in — what's your name? 😊
        """
    }

    private var selfUserOpener: String {
        """
        Hey! 👋 I'm Ziggy — I'll be your CBIT practice companion. Really glad you're here.

        I'm going to walk you through three things: what tics actually are (and why the standard advice to "just stop" doesn't work), how CBIT works, and how TicBuddy will support you week to week. I'll pause after each section in case you have questions.

        First though — what's your name? 😊
        """
    }

    // MARK: - Send

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""

        let userMsg = OnboardingMessage(role: .caregiver, content: text)
        messages.append(userMsg)
        isLoading = true

        Task {
            do {
                // Build conversation history for Claude (system + turns)
                let history: [ChatMessage] = messages.dropLast().map {
                    ChatMessage(role: $0.role == .ziggy ? .assistant : .user, content: $0.content)
                }

                // tb-mvp2-034: use adolescent voice for self-users (teen/adult) vs caregiver for parent/guardian
                let voiceProfile: ZiggyVoiceProfile = isSelfUser ? .adolescent : .caregiver
                let response = try await claudeService.sendMessageWithCustomPrompt(
                    userMessage: text,
                    conversationHistory: history,
                    systemPrompt: onboardingSystemPrompt,
                    voiceProfile: voiceProfile
                )

                let cleaned = claudeService.cleanResponse(response)
                let ziggyMsg = OnboardingMessage(role: .ziggy, content: cleaned)
                messages.append(ziggyMsg)

                ttsService.speak(text: cleaned, voiceProfile: voiceProfile)
            } catch {
                errorMessage = error.localizedDescription
                let errMsg = OnboardingMessage(
                    role: .ziggy,
                    content: "Hmm, I had a little glitch. 🤖 Try again? \(error.localizedDescription)"
                )
                messages.append(errMsg)
            }
            isLoading = false
        }
    }
}

// MARK: - Message Model

struct OnboardingMessage: Identifiable {
    let id = UUID()
    enum Role { case ziggy, caregiver }
    let role: Role
    let content: String
}

// MARK: - Main View

struct CaregiverOnboardingZiggyView: View {

    // tb-mvp2-034: pass isSelfUser so ViewModel uses correct system prompt + opener
    private let isSelfUser: Bool
    @StateObject private var viewModel: CaregiverOnboardingViewModel
    @ObservedObject private var ttsService = ZiggyTTSService.shared
    @ObservedObject private var speechRecognizer = SpeechRecognizer.shared

    /// Fired when user taps "All done" — sets hasCompletedOnboarding = true
    let onComplete: () -> Void

    init(isSelfUser: Bool = false, onComplete: @escaping () -> Void) {
        self.isSelfUser = isSelfUser
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: CaregiverOnboardingViewModel(isSelfUser: isSelfUser))
    }

    // tb-mvp2-028: restore prior TTS preference when this view leaves
    @State private var ttsWasEnabled: Bool = false
    // tb-mvp2-043: gates the pre-launch screen. False = show "Start chatting?" prompt.
    // True = show full chat. setup() and TTS only fire once hasStarted = true.
    @State private var hasStarted: Bool = false

    var body: some View {
        Group {
            if hasStarted {
                chatBody
                    // tb-mvp2-035: .task fires once when chatBody appears (hasStarted = true).
                    // Wires voice callback, requests permissions, speaks opener automatically.
                    .task { await viewModel.setup() }
            } else {
                preLaunchBody
            }
        }
        .onAppear {
            // Save TTS state for restore on dismiss.
            // Do NOT force isEnabled = true here — wait until user taps "Start" so TTS
            // is only activated after explicit user intent (tb-mvp2-043).
            ttsWasEnabled = ttsService.isEnabled
        }
        .onDisappear {
            ttsService.isEnabled = ttsWasEnabled
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording(fireCallback: false)
            }
        }
    }

    // MARK: - Pre-launch Screen (tb-mvp2-043)

    /// "Start chatting with your TicBuddy?" gate shown before the chat.
    /// Tapping enables TTS and transitions to chatBody — voice auto-plays on arrival.
    private var preLaunchBody: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A1F36"), Color(hex: "2D2555")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()

                // TicBuddy app icon — tb-mvp2-043: use real app icon, not emoji
                Image("TicBuddyIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .shadow(color: Color(hex: "667EEA").opacity(0.4), radius: 16, y: 6)
                    .padding(.bottom, 28)

                Text("Start chatting with your TicBuddy?")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 10)

                Text("Ziggy will walk you through everything —\njust tap below when you're ready.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Start button — enables TTS and transitions to chat
                Button {
                    // tb-mvp2-043: force TTS on just before entering chat so voice
                    // auto-plays on arrival without any additional tap.
                    ttsService.isEnabled = true
                    withAnimation(.easeInOut(duration: 0.25)) {
                        hasStarted = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("Let's go")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(18)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 52)
            }
        }
    }

    // MARK: - Chat Body

    private var chatBody: some View {
        // tb-mvp2-035 fix: bottom bar placed BELOW ScrollView in VStack (no ZStack overlap).
        // UIScrollView aggressively captures touches through ZStack layers.
        // Gradient fade is a non-interactive overlay on the scroll view.
        ZStack {
            // ── Background ──────────────────────────────────────────────────────
            LinearGradient(
                colors: [Color(hex: "1A1F36"), Color(hex: "2D2555")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {

                // ── Header ──────────────────────────────────────────────────────
                onboardingHeader

                // ── Messages ────────────────────────────────────────────────────
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.messages) { msg in
                                OnboardingBubble(message: msg)
                                    .id(msg.id)
                            }
                            if viewModel.isLoading {
                                OnboardingTypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation {
                            if viewModel.isLoading {
                                proxy.scrollTo("typing")
                            } else {
                                proxy.scrollTo(viewModel.messages.last?.id)
                            }
                        }
                    }
                    .onChange(of: viewModel.isLoading) { loading in
                        if loading {
                            withAnimation { proxy.scrollTo("typing") }
                        }
                    }
                }
                // Gradient fade — cosmetic, never intercepts touches
                .overlay(
                    LinearGradient(
                        colors: [Color.clear, Color(hex: "1A1F36")],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 32)
                    .allowsHitTesting(false),
                    alignment: .bottom
                )

                // ── Bottom: input + done button ──────────────────────────────────
                VStack(spacing: 0) {
                    Button {
                        onComplete()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("All done, thanks Ziggy!")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "43E97B"), Color(hex: "38F9D7")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    OnboardingInputBar(viewModel: viewModel, speechRecognizer: speechRecognizer)
                }
                .background(Color(hex: "1A1F36").opacity(0.97))
            }
        }
    }

    // MARK: - Header

    private var onboardingHeader: some View {
        HStack(spacing: 14) {
            // Ziggy avatar — tb-mvp2-058: replaced green circle/lightning with TicBuddy app icon
            Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text("Ziggy")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                // tb-mvp2-034: show correct subtitle based on account type
                Text(isSelfUser ? "Your onboarding session" : "Caregiver onboarding session")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            // Sound toggle — always visible (spec requirement)
            Button {
                ttsService.isEnabled.toggle()
                if !ttsService.isEnabled { ttsService.stopSpeaking() }
            } label: {
                ZStack {
                    if ttsService.isSpeaking {
                        Circle()
                            .fill(Color(hex: "667EEA").opacity(0.25))
                            .frame(width: 36, height: 36)
                            .scaleEffect(ttsService.isSpeaking ? 1.15 : 1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                       value: ttsService.isSpeaking)
                    }
                    Image(systemName: ttsService.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 18))
                        .foregroundColor(ttsService.isEnabled ? Color(hex: "43E97B") : .white.opacity(0.4))
                }
            }
            .frame(width: 40, height: 40)
            .accessibilityLabel(ttsService.isEnabled ? "Mute Ziggy" : "Unmute Ziggy")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.white.opacity(0.05)
                .background(.ultraThinMaterial.opacity(0.3))
        )
    }
}

// MARK: - Input Bar

private struct OnboardingInputBar: View {
    @ObservedObject var viewModel: CaregiverOnboardingViewModel
    @ObservedObject var speechRecognizer: SpeechRecognizer
    @FocusState private var textFocused: Bool

    var body: some View {
        HStack(spacing: 10) {

            // ── Mic Button ─────────────────────────────────────────────
            // Tap: start recording / stop and send
            // Long-press toggles "mic locked ON" mode
            MicButton(speechRecognizer: speechRecognizer)

            // ── Text input ──────────────────────────────────────────────
            ZStack(alignment: .leading) {
                if viewModel.inputText.isEmpty && !speechRecognizer.isRecording {
                    Text("Ask Ziggy anything...")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }
                TextField("", text: $viewModel.inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .focused($textFocused)
                    .onSubmit { viewModel.sendMessage() }
                    // Mirror live speech transcript into the text field
                    .onChange(of: speechRecognizer.transcript) { transcript in
                        if speechRecognizer.isRecording {
                            viewModel.inputText = transcript
                        }
                    }
            }
            .background(Color.white.opacity(0.1))
            .cornerRadius(20)

            // ── Send Button ──────────────────────────────────────────────
            Button(action: viewModel.sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.inputText.isEmpty || viewModel.isLoading
                        ? AnyShapeStyle(Color.white.opacity(0.25))
                        : AnyShapeStyle(LinearGradient(
                            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                          ))
                    )
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Mic Button

private struct MicButton: View {
    @ObservedObject var speechRecognizer: SpeechRecognizer

    // tb-mvp2-046: simulator guard — SFSpeechRecognizer live mic is not available in the
    // iOS Simulator (Apple restriction). Show a friendly notice instead of attempting to
    // start recording, which would crash or silently fail.
    #if targetEnvironment(simulator)
    @State private var showSimulatorNotice = false
    #endif

    var body: some View {
        Button {
            #if targetEnvironment(simulator)
            showSimulatorNotice = true
            #else
            if speechRecognizer.isMicLocked {
                // Already locked: single tap stops and sends
                speechRecognizer.toggleMicLock()
            } else if speechRecognizer.isRecording {
                // Tap while recording (not locked): stop + send
                speechRecognizer.stopRecording(fireCallback: true)
            } else {
                // Not recording: start (tap mode — stops on next tap)
                speechRecognizer.startRecording()
            }
            #endif
        } label: {
            ZStack {
                // Pulsing ring while recording
                if speechRecognizer.isRecording {
                    Circle()
                        .stroke(
                            speechRecognizer.isMicLocked ? Color.green : Color(hex: "667EEA"),
                            lineWidth: 2
                        )
                        .frame(width: 42, height: 42)
                        .scaleEffect(speechRecognizer.isRecording ? 1.15 : 1.0)
                        .opacity(speechRecognizer.isRecording ? 0.6 : 0)
                        .animation(
                            .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                            value: speechRecognizer.isRecording
                        )
                }

                Circle()
                    .fill(micBgColor)
                    .frame(width: 36, height: 36)

                Image(systemName: micIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityLabel(micAccessibilityLabel)
        .simultaneousGesture(
            // Long-press toggles mic-lock ON
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    #if targetEnvironment(simulator)
                    showSimulatorNotice = true
                    #else
                    if !speechRecognizer.isMicLocked {
                        speechRecognizer.toggleMicLock()
                    }
                    #endif
                }
        )
        #if targetEnvironment(simulator)
        .alert("Physical Device Required", isPresented: $showSimulatorNotice) {
            Button("Got it", role: .cancel) { }
        } message: {
            Text("Microphone input requires a physical device. The iOS Simulator does not support live mic recording.")
        }
        #endif
    }

    private var micBgColor: Color {
        if speechRecognizer.isMicLocked { return .green }
        if speechRecognizer.isRecording  { return Color(hex: "667EEA") }
        return Color.white.opacity(0.15)
    }

    private var micIcon: String {
        speechRecognizer.isRecording ? "mic.fill" : "mic"
    }

    private var micAccessibilityLabel: String {
        if speechRecognizer.isMicLocked { return "Mic locked on — tap to stop and send" }
        if speechRecognizer.isRecording  { return "Recording — tap to stop and send" }
        return "Tap to speak, hold to keep mic on"
    }
}

// MARK: - Chat Bubble

private struct OnboardingBubble: View {
    let message: OnboardingMessage

    private var isZiggy: Bool { message.role == .ziggy }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isZiggy {
                // Ziggy avatar chip
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Text("⚡")
                        .font(.system(size: 14))
                }
                .padding(.bottom, 2)
            }

            Text(message.content)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(isZiggy ? .white : .white.opacity(0.9))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isZiggy
                    ? AnyShapeStyle(Color.white.opacity(0.12))
                    : AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(hex: "667EEA").opacity(0.8), Color(hex: "764BA2").opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                      )
                )
                .cornerRadius(18, corners: isZiggy
                    ? [.topLeft, .topRight, .bottomRight]
                    : [.topLeft, .topRight, .bottomLeft]
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: isZiggy ? .leading : .trailing)

            if !isZiggy {
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: isZiggy ? .leading : .trailing)
        .padding(.leading, isZiggy ? 0 : 40)
        .padding(.trailing, isZiggy ? 40 : 0)
    }
}

// MARK: - Typing Indicator

private struct OnboardingTypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 28, height: 28)
                Text("⚡")
                    .font(.system(size: 14))
            }
            .padding(.bottom, 2)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.white.opacity(phase == i ? 0.9 : 0.3))
                        .frame(width: 7, height: 7)
                        .animation(.easeInOut(duration: 0.4).delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.12))
            .cornerRadius(18, corners: [.topLeft, .topRight, .bottomRight])

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}
