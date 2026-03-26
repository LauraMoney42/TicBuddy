// TicBuddy — ChatViewModel.swift
// Manages chat state, message history, and tic auto-logging from chat.

import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var pendingTicLog: TicLogIntent? = nil
    @Published var lastLoggedEntry: TicEntry? = nil
    @Published var errorMessage: String? = nil

    // tb-mvp2-062: Word-by-word text reveal synced to TTS.
    // streamingMessageId — the assistant message currently being revealed (nil = none).
    // streamingText      — the portion of that message revealed so far.
    // ChatBubbleView shows streamingText (+ cursor) instead of message.content while active.
    @Published var streamingMessageId: UUID? = nil
    @Published var streamingText: String = ""

    private let claudeService = ClaudeService()
    private let dataService: TicDataService
    private let sessionStore = CBITSessionStore.shared
    private let usageLimiter = ChatUsageLimiter.shared
    private let contentFilter = ZiggyContentFilter.shared
    private let piiScrubber = ZiggyPIIScrubber.shared      // tb-rag-002: strip PII before API
    private let outputFilter = ZiggyOutputFilter.shared    // tb-rag-004: scan response before delivery
    private let ragService = ZiggyRAGService.shared        // tb-rag-001: CBIT knowledge retrieval
    /// TTS service — shared singleton so the speaker toggle in ChatView binds live
    let ttsService = ZiggyTTSService.shared

    // Memory injection is loaded once per session start (lazy, on first send).
    // Nil = first-ever session or no memories yet; non-nil = injected into system prompt.
    private var sessionMemoryInjection: String? = nil
    private var memoryLoadedForSession = false

    // MARK: - Usage Limit State

    /// Whether the child has hit their daily message limit.
    @Published var isLimitReached: Bool = false

    init(dataService: TicDataService = .shared) {
        self.dataService = dataService
        loadHistory()
        if messages.isEmpty {
            addWelcomeMessage()
        }
    }

    // MARK: - Active Child Helpers

    /// UUID key for the child currently in session.
    /// Uses active family unit child if available; falls back to legacy userProfile.id.
    private var activeChildID: UUID {
        dataService.familyUnit.activeChildID ?? dataService.userProfile.id
    }

    private var activeChildAge: Int {
        dataService.familyUnit.activeChild?.userProfile.age ?? dataService.userProfile.age
    }

    /// True when the active child is under 13 — triggers COPPA mode on API calls (tb-mvp2-014).
    private var activeChildIsCOPPA: Bool {
        dataService.familyUnit.activeChild?.ageGroup.isCOPPAApplicable ?? false
    }

    private var activeChildName: String {
        dataService.familyUnit.activeChild?.nickname ?? dataService.userProfile.name
    }

    /// Selects the correct Ziggy voice profile for the current session context.
    /// Child active → profile based on their AgeGroup. No child → caregiver mode.
    /// tb-mvp2-117: selfUser has no child profiles by design — route to .adolescent,
    /// not .caregiver, so chips/prompt address the teen as "you" not as a parent.
    /// Exposed publicly so ChatView can adapt its header and quick-action chips (tb-mvp2-012).
    var activeVoiceProfile: ZiggyVoiceProfile {
        if dataService.familyUnit.accountType == .selfUser { return .adolescent }
        guard let child = dataService.familyUnit.activeChild else { return .caregiver }
        return ZiggyVoiceProfileService.shared.profile(for: child.ageGroup)
    }

    /// Daily limit for the active child (0 = unlimited for caregiver/therapist mode).
    private var activeDailyLimit: Int {
        dataService.familyUnit.activeChild?.effectiveDailyLimit
            ?? ChatUsageLimiter.defaultDailyLimit
    }

    /// Countdown message shown in chat header when ≤ countdownThreshold exchanges remain.
    /// Returns nil when plenty remain or limit is unlimited.
    /// Same text shown to both caregiver and child views per tb-mvp2-021 spec.
    var countdownMessage: String? {
        usageLimiter.countdownMessage(for: activeChildID, limit: activeDailyLimit)
    }

    // MARK: - Welcome Message

    private func addWelcomeMessage() {
        let profile = dataService.userProfile
        let phase = profile.recommendedPhase
        let welcome = ChatMessage(
            role: .assistant,
            content: """
            Hi \(profile.name.isEmpty ? "there" : profile.name)! 👋 I'm Ziggy, your tic-fighting sidekick! 🦸

            \(phase.goalText)

            You can tell me about any tics you notice, and I'll help you log them. Or just chat — I'm here! 😊

            What's going on today?
            """
        )
        messages.append(welcome)
    }

    // MARK: - Contextual Seed (tb-mvp2-102)

    /// Pre-populates the input and auto-sends when Ziggy is opened from a contextual
    /// lesson CTA (e.g. "Ask Ziggy →" on the What's Next slide).
    /// No-ops if the chat already has a real exchange — prevents double-sending on re-appear.
    func seedAndSend(_ prompt: String) {
        guard messages.count <= 1 else { return }   // ≤ 1 = only the welcome message
        inputText = prompt
        sendMessage()
    }

    // MARK: - Send Message

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // CLIENT-SIDE SAFETY FILTER (tb-mvp2-020):
        // Run BEFORE anything else — if the message is out-of-scope (medication question
        // or mental health counseling), show Ziggy's warm redirect and stop here.
        // The message never reaches Claude; no API call is made.
        let filterResult = contentFilter.check(text)
        if case .redirect(let redirectMsg) = filterResult {
            inputText = ""
            let redirectMessage = ChatMessage(role: .assistant, content: redirectMsg)
            messages.append(redirectMessage)
            saveHistory()
            return
        }

        // Hard stop: child has hit their daily limit — no more messages today.
        let childID = activeChildID
        let limit = activeDailyLimit
        if usageLimiter.isLimitReached(for: childID, limit: limit) {
            isLimitReached = true
            // Only show the wrap-up message once (not on every blocked tap)
            if messages.last?.content.contains("See you then") == false {
                let usedToday = usageLimiter.messagesUsedToday(for: childID)
                let wrapUp = ChatMessage(
                    role: .assistant,
                    content: ChatUsageLimiter.limitReachedMessage(
                        childName: activeChildName,
                        messagesUsed: usedToday
                    )
                )
                messages.append(wrapUp)
                saveHistory()
            }
            return
        }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)

        // Count this message toward the daily limit
        usageLimiter.incrementCount(for: childID)

        isLoading = true

        Task {
            do {
                // Load memory injection once at the start of each session (first message only).
                // Subsequent messages in the same session reuse the same injection block so it
                // doesn't change mid-conversation or inflate the prompt on every turn.
                if !memoryLoadedForSession {
                    sessionMemoryInjection = sessionStore.buildMemoryInjection(for: activeChildID)
                    memoryLoadedForSession = true
                }

                // Build usage-aware memory addendum (soft warning near limit, hard close at limit)
                let usageAddendum = usageLimiter.systemPromptAddendum(for: childID, limit: limit)
                let combinedInjection: String? = {
                    switch (sessionMemoryInjection, usageAddendum) {
                    case let (mem?, usage?): return mem + "\n\n" + usage
                    case let (mem?, nil):    return mem
                    case let (nil, usage?):  return usage
                    case (nil, nil):         return nil
                    }
                }()

                // tb-rag-002: Scrub PII from user message before sending to Claude proxy.
                // The user sees their original text in the bubble; only the API receives scrubbed text.
                let scrubbed = piiScrubber.scrub(text)
                let apiUserMessage = scrubbed.scrubbed

                // tb-rag-001: Fetch relevant CBIT knowledge chunks (best-effort, non-blocking).
                // Uses the PII-scrubbed message + voice profile/phase filters for precision retrieval.
                // Returns nil if RAG is unavailable; Claude responds from base knowledge only.
                let ragBlock = await ragService.fetchContext(
                    for: apiUserMessage,
                    voiceProfile: activeVoiceProfile,
                    phase: dataService.activeUserProfile.recommendedPhase,
                    ticCategories: dataService.activeUserProfile.primaryTicCategories
                )

                // Merge RAG context into the combined injection block
                let finalInjection: String? = {
                    switch (combinedInjection, ragBlock) {
                    case let (base?, rag?): return base + "\n\n" + rag
                    case let (base?, nil):  return base
                    case let (nil, rag?):   return rag
                    case (nil, nil):        return nil
                    }
                }()

                let response = try await claudeService.sendMessage(
                    userMessage: apiUserMessage,
                    conversationHistory: Array(messages.dropLast()),
                    profile: dataService.activeUserProfile,
                    voiceProfile: activeVoiceProfile,
                    memoryInjection: finalInjection,
                    isCOPPA: activeChildIsCOPPA
                )

                // If we just hit the limit after this message, mark it
                if usageLimiter.isLimitReached(for: childID, limit: limit) {
                    isLimitReached = true
                }

                // Check for auto-log intent
                if let intent = claudeService.parseTicLogIntent(from: response) {
                    pendingTicLog = intent
                    let logged = dataService.quickLog(intent: intent)
                    lastLoggedEntry = logged
                }

                let cleanedResponse = claudeService.cleanResponse(response)

                // tb-rag-004: Scan Claude's response before showing it to the user.
                // If it contains prohibited content (medication, diagnosis, identity denial, etc.)
                // replace it with a warm safe fallback — never show the blocked response.
                let outputResult = outputFilter.filter(cleanedResponse)
                let safeResponse = outputResult.displayMessage

                let assistantMessage = ChatMessage(role: .assistant, content: safeResponse)
                messages.append(assistantMessage)

                // TTS: speak Ziggy's response if user has TTS enabled (tb-mvp2-011).
                // Fire-and-forget — TTS failure never blocks the chat UI.
                // Use safeResponse (post-output-filter) so we never speak a blocked response.
                let voiceForTTS = activeVoiceProfile
                ttsService.speak(text: safeResponse, voiceProfile: voiceForTTS)

                // tb-mvp2-062: Reveal words in sync with TTS playback (TTS-enabled only).
                startWordReveal(text: safeResponse, messageId: assistantMessage.id)

                saveHistory()
                dataService.checkAndAdvancePhase()

            } catch {
                errorMessage = error.localizedDescription
                let errorMsg = ChatMessage(
                    role: .assistant,
                    content: "Oops! I had a little glitch. 🤖 Try again? \(error.localizedDescription)"
                )
                messages.append(errorMsg)
            }

            isLoading = false
        }
    }

    // MARK: - Word-by-Word Reveal (tb-mvp2-062)

    /// Reveals `text` word-by-word for `messageId`'s bubble, timed to match TTS playback.
    ///
    /// Rate: 160 WPM — calibrated to OpenAI nova at speed 1.05. Words appear in sync with
    /// what the user hears. Only active when TTS is enabled; otherwise the full message is
    /// already visible and no animation is needed.
    ///
    /// Each reveal block checks `streamingMessageId == messageId` before writing, so a new
    /// message that interrupts mid-reveal cleanly takes over without stale writes.
    private func startWordReveal(text: String, messageId: UUID) {
        guard ttsService.isEnabled else { return }

        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard !words.isEmpty else { return }

        // Show the first word immediately so the bubble never flashes empty.
        streamingMessageId = messageId
        streamingText = words[0]

        // 160 WPM → 0.375 s per word. Matches OpenAI nova at speed 1.05 closely enough
        // that words appear on screen around the time TTS speaks them.
        let interval: TimeInterval = 60.0 / 160.0

        for i in 1 ..< words.count {
            let delay = interval * Double(i)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.streamingMessageId == messageId else { return }
                self.streamingText = words[0 ... i].joined(separator: " ")
            }
        }

        // Clear streaming state after the last word + a short linger so the cursor
        // doesn't vanish exactly when the final word is spoken.
        let totalDuration = interval * Double(words.count) + 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration) { [weak self] in
            guard let self, self.streamingMessageId == messageId else { return }
            self.streamingMessageId = nil
            self.streamingText = ""
        }
    }

    // MARK: - Quick Tic Log (manual from calendar quick-add)

    func logTicManually(category: TicCategory, typeName: String, outcome: TicOutcome) {
        let intent = TicLogIntent(category: category, typeName: typeName, outcome: outcome, count: 1)
        let entry = dataService.quickLog(intent: intent)
        lastLoggedEntry = entry

        // Add a confirmation chat message
        let confirmMsg = ChatMessage(
            role: .assistant,
            content: "Logged a \(typeName) tic! \(outcome.emoji) \(outcome.encouragement)"
        )
        messages.append(confirmMsg)
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        // Keep last 100 messages
        let recent = Array(messages.suffix(100))
        if let data = try? JSONEncoder().encode(recent) {
            UserDefaults.standard.set(data, forKey: "ticbuddy_chat_history")
        }
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "ticbuddy_chat_history"),
           let history = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = history
        }
    }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: "ticbuddy_chat_history")
        // Reset memory state so the next session picks up fresh injection
        memoryLoadedForSession = false
        sessionMemoryInjection = nil
        addWelcomeMessage()
    }

    // MARK: - Session Lifecycle

    /// Called when the chat session ends (tab disappear or explicit clear).
    /// Sends the session transcript to Claude for memory extraction and saves results locally.
    /// Fire-and-forget — failures are swallowed silently inside CBITSessionStore.
    func endSession() async {
        // Only extract if there was real conversation (not just the welcome message)
        guard messages.count > 2 else { return }
        await sessionStore.extractAndSaveMemories(
            from: messages,
            childID: activeChildID,
            childAge: activeChildAge,
            using: claudeService
        )
        // Reset session state so the NEXT session reloads memories fresh
        memoryLoadedForSession = false
        sessionMemoryInjection = nil
    }
}
