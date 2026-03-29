// TicBuddy — ZiggyTTSService.swift
// ElevenLabs TTS integration for Ziggy's voice responses (tb-mvp2-011).
//
// Routes through TicBuddyProxy /api/tts — ElevenLabs key stays off-device.
// Each ZiggyVoiceProfile maps to a distinct ElevenLabs voice + tuned voice settings
// so Ziggy literally "sounds different" for a 5-year-old vs. a caregiver.
//
// Auto-speak behaviour:
//   • Default OFF for all profiles (users opt-in via speaker toggle in chat header)
//   • Preference persisted in UserDefaults across launches
//   • ElevenLabs failures fall back to AVSpeechSynthesizer (on-device TTS) — Ziggy
//     always speaks even when the proxy is unreachable or unconfigured. (tb-mvp2-043)
//
// Usage:
//   await ZiggyTTSService.shared.speak(text: cleanedResponse, voiceProfile: activeProfile)

import Foundation
import AVFoundation

@MainActor
final class ZiggyTTSService: ObservableObject {
    static let shared = ZiggyTTSService()

    // MARK: - Published State

    /// Whether Ziggy is currently speaking (used to show audio waveform indicator in UI).
    @Published var isSpeaking: Bool = false

    /// tb-mvp2-049: Last error from the preview path — nil when idle or last call succeeded.
    /// TTSVoicePreviewView observes this to show an inline error banner.
    @Published var previewError: String? = nil

    /// tb-mvp2-062: Words revealed so far in the currently-streaming message.
    /// OnboardingBubble observes this to reveal text word-by-word in sync with audio.
    @Published var revealedWordCount: Int = 0
    /// tb-mvp2-062: Total words in the currently-streaming message.
    @Published var streamingWordCount: Int = 0

    /// Master TTS toggle — persisted across launches.
    /// Changing this immediately affects subsequent Ziggy responses.
    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "ziggy_tts_enabled") }
    }

    // MARK: - Private

    // tb-mvp2-050: URL + token now read from APIConfig (single source of truth).
    private let baseURL   = APIConfig.ttsURL
    private let authToken = APIConfig.authToken

    private var audioPlayer: AVAudioPlayer?
    /// Tracks in-flight speak task so we can cancel if a new message arrives mid-playback.
    private var currentSpeakTask: Task<Void, Never>?
    /// On-device fallback synthesizer — used when ElevenLabs proxy is unreachable. (tb-mvp2-043)
    private let synthesizer = AVSpeechSynthesizer()
    // tb-mvp2-062: Prefetch state for typing-indicator → bubble-reveal flow
    private var prefetchedAudioData: Data?
    private var prefetchedText: String = ""
    private var prefetchedVoiceProfile: ZiggyVoiceProfile = .caregiver
    private var wordRevealTimer: Timer?

    // tb-mvp2-073: Lesson slide audio cache — keyed by slide index.
    // Background-fetched while current slide plays; consumed instantly on Next tap.
    private var lessonAudioCache: [Int: Data] = [:]
    private var lessonPrefetchTasks: [Int: Task<Void, Never>] = [:]

    private init() {
        // Default to stored preference; first-time = false (opt-in)
        self.isEnabled = UserDefaults.standard.object(forKey: "ziggy_tts_enabled") as? Bool ?? false
    }

    // MARK: - Public API

    /// Synthesizes `text` with the given voice profile and plays it via AVAudioPlayer.
    /// Cancels any in-progress playback first so new messages always interrupt old ones.
    /// No-ops if TTS is disabled or the text is empty after cleaning.
    func speak(text: String, voiceProfile: ZiggyVoiceProfile) {
        guard isEnabled else { return }

        let cleanText = prepareForSpeech(text)
        guard !cleanText.isEmpty else { return }

        // Cancel previous playback — new message takes priority
        currentSpeakTask?.cancel()
        stopSpeaking()

        currentSpeakTask = Task {
            await performSpeak(text: cleanText, voiceProfile: voiceProfile)
        }
    }

    /// tb-mvp2-070: Lesson-mode speak — always fires regardless of isEnabled.
    /// tb-mvp2-073: Checks the lesson audio cache first for instant playback.
    /// If the audio for `slideIndex` was pre-fetched, it plays immediately with zero
    /// network latency. Falls through to live fetch / AVSpeech if not cached.
    func speakLesson(text: String, voiceProfile: ZiggyVoiceProfile, slideIndex: Int = -1) {
        let cleanText = prepareForSpeech(text)
        guard !cleanText.isEmpty else { return }
        currentSpeakTask?.cancel()
        stopSpeaking()

        // Check cache first — instant playback if available
        if slideIndex >= 0, let cached = lessonAudioCache[slideIndex] {
            currentSpeakTask = Task { await playAudio(data: cached) }
        } else {
            currentSpeakTask = Task { await performSpeak(text: cleanText, voiceProfile: voiceProfile) }
        }
    }

    /// tb-mvp2-073: Pre-fetches audio for a future lesson slide in the background.
    /// Call immediately after starting playback of the current slide so the next
    /// slide's audio is ready before the user taps Next.
    /// No-ops if already cached or if proxy is not configured (AVSpeech needs no prefetch).
    func prefetchLessonSlide(text: String, voiceProfile: ZiggyVoiceProfile, slideIndex: Int) async {
        guard APIConfig.isConfigured else { return }  // AVSpeech path needs no prefetch
        guard lessonAudioCache[slideIndex] == nil else { return }  // already cached
        guard lessonPrefetchTasks[slideIndex] == nil else { return } // already in-flight

        let cleanText = prepareForSpeech(text)
        guard !cleanText.isEmpty else { return }

        let task = Task {
            if let data = try? await fetchAudio(text: cleanText, voiceProfile: voiceProfile) {
                lessonAudioCache[slideIndex] = data
            }
            lessonPrefetchTasks.removeValue(forKey: slideIndex)
        }
        lessonPrefetchTasks[slideIndex] = task
        await task.value
    }

    /// tb-mvp2-073: Clears the lesson audio cache and cancels in-flight prefetch tasks.
    /// Call from LessonSlideView.onDisappear to free memory when the lesson is dismissed.
    func clearLessonCache() {
        lessonPrefetchTasks.values.forEach { $0.cancel() }
        lessonPrefetchTasks.removeAll()
        lessonAudioCache.removeAll()
    }

    /// tb-mvp2-049: Preview — plays a sample using an explicit voice + speed, bypassing
    /// profile mapping. Used by TTSVoicePreviewView to audition voices in real time.
    /// Always fires regardless of isEnabled — preview is always intentional.
    func previewSpeak(text: String, voice: String, speed: Double) {
        let cleanText = prepareForSpeech(text)
        guard !cleanText.isEmpty else { return }
        currentSpeakTask?.cancel()
        stopSpeaking()
        currentSpeakTask = Task {
            await performPreviewSpeak(text: cleanText, voice: voice, speed: speed)
        }
    }

    /// Stops any active playback immediately (ElevenLabs player + system synthesizer).
    func stopSpeaking() {
        audioPlayer?.stop()
        audioPlayer = nil
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        stopWordRevealTimer()
        isSpeaking = false
    }

    // MARK: - Prefetch + Reveal API (tb-mvp2-062)

    /// Step 1 of the typing-indicator → word-reveal flow.
    /// Pre-fetches TTS audio from the Railway proxy while the typing dots are still showing.
    /// Falls through to nil (AVSpeech) when proxy is not configured or fetch fails.
    func prefetchAudio(text: String, voiceProfile: ZiggyVoiceProfile) async {
        guard isEnabled else { return }
        let cleanText = prepareForSpeech(text)
        guard !cleanText.isEmpty else { return }
        prefetchedText = cleanText
        prefetchedVoiceProfile = voiceProfile
        // Attempt network fetch; nil = fall back to AVSpeech in startPrefetchedPlayback()
        prefetchedAudioData = APIConfig.isConfigured
            ? (try? await fetchAudio(text: cleanText, voiceProfile: voiceProfile))
            : nil
    }

    /// Step 2 of the typing-indicator → word-reveal flow.
    /// Call immediately after appending the Ziggy message to the messages array.
    /// Starts audio and drives revealedWordCount forward one word per spoken interval.
    func startPrefetchedPlayback() {
        guard isEnabled, !prefetchedText.isEmpty else { return }
        let text = prefetchedText
        let voiceProfile = prefetchedVoiceProfile
        let audioData = prefetchedAudioData

        currentSpeakTask?.cancel()
        stopSpeaking()

        let wordCount = max(1, text.split(separator: " ").count)
        streamingWordCount = wordCount
        revealedWordCount = 1   // show first word immediately as bubble appears

        currentSpeakTask = Task {
            if let data = audioData, !Task.isCancelled {
                await playAudio(data: data, wordCount: wordCount)
            } else if !Task.isCancelled {
                await speakWithSystemTTS(text: text, voiceProfile: voiceProfile)
            }
        }
    }

    // MARK: - Private: Network + Playback

    private func performSpeak(text: String, voiceProfile: ZiggyVoiceProfile) async {
        // tb-mvp2-054: skip proxy entirely when Railway is not configured — avoids the
        // 15-second timeout before the AVSpeechSynthesizer fallback fires. Ziggy speaks
        // immediately on-device with zero server dependency.
        guard APIConfig.isConfigured else {
            await speakWithSystemTTS(text: text, voiceProfile: voiceProfile)
            return
        }
        do {
            let audioData = try await fetchAudio(text: text, voiceProfile: voiceProfile)
            guard !Task.isCancelled else { return }
            await playAudio(data: audioData)
        } catch {
            // tb-mvp2-043: proxy failed — fall back to on-device AVSpeechSynthesizer.
            // Common causes: AUTH_TOKEN mismatch (401), OPENAI_API_KEY missing on proxy (503), no network.
            // tb-mvp2-129: capture isCancelled immediately at catch entry — a race between
            // fetchAudio throwing and the guard running could otherwise suppress AVSpeech
            // even when the task was NOT cancelled (e.g. network timeout on a long slide).
            let wasCancelled = Task.isCancelled
            // tb-ziggy-voice-001: speakWithSystemTTS now guards against APIConfig.isConfigured
            // internally, so this call is safe — it will no-op in production (silent fail)
            // and only fire AVSpeech in dev/offline mode (Railway not configured).
            print("[ZiggyTTS] Proxy unavailable (\(voiceProfile.rawValue)): \(error.localizedDescription) — \(APIConfig.isConfigured ? "silent fail (Railway configured)" : "falling back to system TTS")")
            guard !wasCancelled else { return }
            await speakWithSystemTTS(text: text, voiceProfile: voiceProfile)
        }
    }

    /// tb-mvp2-049: Preview path — on proxy error shows inline banner in TTSVoicePreviewView.
    /// tb-mvp2-054: when Railway is not configured, use AVSpeechSynthesizer directly so the
    /// user can audition voice previews with zero server dependency.
    private func performPreviewSpeak(text: String, voice: String, speed: Double) async {
        previewError = nil  // clear stale error before each attempt

        // tb-mvp2-054: proxy not configured → on-device preview immediately (no timeout wait)
        guard APIConfig.isConfigured else {
            // Map the requested voice string to the nearest ZiggyVoiceProfile for rate/pitch
            let profile = ZiggyVoiceProfile.fromPreviewVoice(voice)
            await speakWithSystemTTS(text: text, voiceProfile: profile)
            return
        }

        do {
            let audioData = try await fetchPreviewAudio(text: text, voice: voice, speed: speed)
            guard !Task.isCancelled else { return }
            await playAudio(data: audioData)
        } catch {
            // tb-mvp2-053 fix: suppress cancellation errors — these fire when a new preview
            // request interrupts an in-flight URLSession fetch (expected, not a real failure).
            // Without this guard, the old task's URLError.cancelled overwrites previewError
            // even though the new request succeeded and audio is already playing.
            if Task.isCancelled { return }
            if let urlErr = error as? URLError, urlErr.code == .cancelled { return }
            let msg = (error as? TTSError)?.errorDescription ?? error.localizedDescription
            print("[ZiggyTTS] Preview TTS failed (\(voice) @ \(speed)x): \(msg)")
            // Surface to UI — proxy likely not configured (OPENAI_API_KEY missing in Railway)
            previewError = msg
            // tb-mvp2-054: fall back to system TTS so preview button always produces sound
            let profile = ZiggyVoiceProfile.fromPreviewVoice(voice)
            await speakWithSystemTTS(text: text, voiceProfile: profile)
        }
    }

    /// AVSpeechSynthesizer fallback — fires ONLY when Railway is not configured (dev/offline mode).
    /// tb-ziggy-voice-001: When APIConfig.isConfigured is true, this method returns immediately
    /// so the robot voice is never heard in production. Failure is silent — no playback.
    ///
    /// tb-mvp2-043: Original fallback for proxy-unreachable scenarios.
    /// tb-mvp2-048: Rates pushed above 0.50 (the AVFoundation default). At 0.50,
    /// AVSpeechSynthesizer sounds choppy and word-by-word — each word has an audible
    /// micro-pause before the next. 0.54–0.57 is the sweet spot for natural cadence
    /// without sounding rushed.
    private func speakWithSystemTTS(text: String, voiceProfile: ZiggyVoiceProfile) async {
        // tb-ziggy-voice-001: Suppress AVSpeech entirely when Railway is configured.
        // User always hears the AI voice or silence — never the iOS robot voice in production.
        guard !APIConfig.isConfigured else {
            print("[ZiggyTTS] Railway configured — suppressing AVSpeech fallback (silent fail).")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[ZiggyTTS] AVAudioSession setup failed for system TTS: \(error.localizedDescription)")
        }

        let utterance = AVSpeechUtterance(string: text)
        // Pick a natural English voice; nil falls back to device default.
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Tune rate + pitch per age group so Ziggy still "sounds different" across profiles.
        // tb-mvp2-048: rates increased — 0.50 (AVFoundation default) produces choppy
        // word-by-word pauses; 0.54+ removes the inter-word gap without sounding rushed.
        switch voiceProfile {
        case .youngChild:
            utterance.rate = 0.46
            utterance.pitchMultiplier = 1.20
        case .olderChild:
            utterance.rate = 0.52
            utterance.pitchMultiplier = 1.08
        case .adolescent:
            utterance.rate = 0.55
            utterance.pitchMultiplier = 1.00
        case .caregiver:
            utterance.rate = 0.54
            utterance.pitchMultiplier = 0.92
        }
        utterance.volume = 1.0

        isSpeaking = true

        // tb-mvp2-062: rate-based word reveal. AVSpeechUtteranceDefaultSpeechRate = 0.5
        // maps to ~2.5 words/sec at normal English pace. Scale linearly with utterance.rate.
        if streamingWordCount > 0 {
            let wordsPerSec = max(1.0, Double(utterance.rate) * 5.0)
            let interval = 1.0 / wordsPerSec
            startWordRevealTimer(interval: interval, total: streamingWordCount)
        }

        synthesizer.speak(utterance)

        // Poll until the synthesizer finishes (AVSpeechSynthesizer has no async API).
        while synthesizer.isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if Task.isCancelled {
                synthesizer.stopSpeaking(at: .immediate)
                break
            }
        }
        stopWordRevealTimer()
        if streamingWordCount > 0 { revealedWordCount = streamingWordCount }
        isSpeaking = false
    }

    // MARK: - Word Reveal Timer (tb-mvp2-062)

    private func startWordRevealTimer(interval: TimeInterval, total: Int) {
        stopWordRevealTimer()
        wordRevealTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            // Discard timer param to avoid Swift 6 Sendable data-race warning.
            // Use self.wordRevealTimer for invalidation instead.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.revealedWordCount < total {
                    self.revealedWordCount += 1
                }
                if self.revealedWordCount >= total {
                    self.wordRevealTimer?.invalidate()
                    self.wordRevealTimer = nil
                }
            }
        }
    }

    private func stopWordRevealTimer() {
        wordRevealTimer?.invalidate()
        wordRevealTimer = nil
    }

    // MARK: - Network

    private struct TTSRequest: Encodable {
        let text: String
        let voiceProfile: String
        /// tb-mvp2-049: Optional direct voice override (bypasses profile → voice mapping on proxy).
        let voice: String?
        /// tb-mvp2-049: Optional speed override (0.25–4.0; proxy default is 1.05).
        let speed: Double?
    }

    private struct TTSResponse: Decodable {
        let audio: String   // base64-encoded mp3
        let format: String  // "mp3"
    }

    private func fetchAudio(text: String, voiceProfile: ZiggyVoiceProfile) async throws -> Data {
        try await fetchAudioRaw(text: text, voiceProfile: voiceProfile.rawValue, voice: nil, speed: nil)
    }

    /// Preview variant — sends explicit voice + speed, bypasses profile mapping on proxy. (tb-mvp2-049)
    private func fetchPreviewAudio(text: String, voice: String, speed: Double) async throws -> Data {
        try await fetchAudioRaw(text: text, voiceProfile: "older_child", voice: voice, speed: speed)
    }

    private func fetchAudioRaw(text: String, voiceProfile: String, voice: String?, speed: Double?) async throws -> Data {
        guard let url = URL(string: baseURL) else { throw TTSError.invalidURL }

        let body = TTSRequest(text: text, voiceProfile: voiceProfile, voice: voice, speed: speed)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(body)
        // Give TTS a bit more time than chat — ElevenLabs synthesis can take 2-3s
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw TTSError.invalidResponse }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            throw TTSError.serverError(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(TTSResponse.self, from: data)
        guard let audioData = Data(base64Encoded: decoded.audio) else {
            throw TTSError.invalidAudioData
        }
        return audioData
    }

    // MARK: - Playback

    /// wordCount > 0 enables tb-mvp2-062 word-by-word reveal timer synced to audio duration.
    private func playAudio(data: Data, wordCount: Int = 0) async {
        do {
            // tb-mvp2-043: use .playback, not .ambient.
            // .ambient respects the iOS mute/silent switch — Ziggy's voice was completely
            // silenced on devices in silent mode, which most users leave on. .playback
            // is the correct category for a voice assistant: it ignores the mute switch
            // and uses the main speaker/headphones route as intended.
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            // tb-mvp2-049: Force speaker output — without this the audio can route to the
            // earpiece (receiver) on iPhone, which sounds very quiet and is easily mistaken
            // for silence. overrideOutputAudioPort forces the main speaker regardless of
            // whether headphones are connected (headphones will still be preferred by iOS
            // when physically connected — this only overrides the earpiece vs. speaker choice).
            try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)

            let player = try AVAudioPlayer(data: data)
            player.prepareToPlay()
            audioPlayer = player

            isSpeaking = true

            // tb-mvp2-062: schedule word reveal timer proportional to audio duration.
            // Interval = total_duration / word_count gives one word revealed per spoken word.
            if wordCount > 0 {
                let interval = max(0.08, player.duration / Double(wordCount))
                startWordRevealTimer(interval: interval, total: wordCount)
            }

            player.play()

            // Poll for completion (AVAudioPlayer has no async API).
            // Check every 100ms; bail if task was cancelled.
            while player.isPlaying {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                if Task.isCancelled { player.stop(); break }
            }
        } catch {
            print("[ZiggyTTS] Playback error: \(error.localizedDescription)")
        }
        stopWordRevealTimer()
        if wordCount > 0 { revealedWordCount = wordCount }   // ensure fully revealed on finish
        isSpeaking = false
    }

    // MARK: - Text Preparation

    /// Cleans text before sending to TTS — strips markdown, tags, emojis, and anything
    /// that sounds bizarre when read aloud by a voice engine.
    private func prepareForSpeech(_ text: String) -> String {
        var clean = text
        // tb-mvp2-044: Strip emojis — TTS engines read emoji codepoints as their
        // Unicode name (e.g. 🔥 → "fire", ⚡ → "high voltage sign"). Chat bubbles
        // keep the original text; only the string passed to the voice engine is cleaned.
        // Filter: isEmojiPresentation flags colored emoji scalars; also remove emoji
        // modifiers (skin tones), variation selector U+FE0F, and ZWJ U+200D so that
        // multi-codepoint sequences (e.g. 👨‍👩‍👧) don't leave orphan combining characters.
        // tb-mvp2-048 fix: use String.UnicodeScalarView directly — [Unicode.Scalar] has no
        // String.init overload and would silently use String(describing:), producing garbage.
        var filteredScalars = String.UnicodeScalarView()
        filteredScalars.append(contentsOf: clean.unicodeScalars.filter { scalar in
            !scalar.properties.isEmojiPresentation &&
            !scalar.properties.isEmojiModifier &&
            scalar.value != 0xFE0F &&  // variation selector-16
            scalar.value != 0x200D     // zero-width joiner (emoji sequence combiner)
        })
        clean = String(filteredScalars)
        // tb-mvp2-083: Phonetic substitutions — fix TTS mispronunciations before sending.
        // "CBIT" → "C-BIT": hyphen forces Nova/TTS engines to read each letter separately
        // rather than trying to pronounce it as a word ("suh-bit" or "cee-bit").
        // Applied here so display text in slides/chat is unchanged — only the spoken string differs.
        clean = clean.replacingOccurrences(of: "CBIT", with: "C-BIT")
        // tb-mvp2-131: "pts" / "pt" abbreviations → full words so Nova reads them correctly.
        // Word-boundary regex prevents false matches inside longer words (e.g. "option", "script").
        // Order matters: expand "pts" before "pt" so "pts" isn't partially matched first.
        clean = clean.replacingOccurrences(of: #"\bpts\b"#, with: "points", options: .regularExpression)
        clean = clean.replacingOccurrences(of: #"\bpt\b"#,  with: "point",  options: .regularExpression)
        // Remove [LOG_TIC: ...] tags Ziggy sometimes appends
        clean = clean.replacingOccurrences(of: #"\[LOG_TIC:[^\]]+\]"#, with: "", options: .regularExpression)
        // Unwrap **bold** and *italic* markers (keep the text, drop the asterisks)
        clean = clean.replacingOccurrences(of: #"\*{1,2}([^*\n]+)\*{1,2}"#, with: "$1", options: .regularExpression)
        // Remove inline `code` backticks
        clean = clean.replacingOccurrences(of: #"`[^`\n]+`"#, with: "", options: .regularExpression)
        // Collapse multiple whitespace/newlines into a single space
        clean = clean.components(separatedBy: .newlines).joined(separator: " ")
        clean = clean.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        // tb-mvp2-120: Raised limit to 4000 chars to match backend — 500 was chopping
        // lesson slides mid-sentence (slide 5 body alone exceeds 461 chars pre-truncation).
        if clean.count > 4000 {
            clean = String(clean.prefix(3997)) + "..."
        }
        return clean.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum TTSError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, String)
    case invalidAudioData

    var errorDescription: String? {
        switch self {
        case .invalidURL:                   return "Invalid TTS proxy URL"
        case .invalidResponse:              return "Invalid HTTP response from TTS proxy"
        case .serverError(let code, let b): return "TTS server error \(code): \(b)"
        case .invalidAudioData:             return "Received invalid audio data from TTS proxy"
        }
    }
}
