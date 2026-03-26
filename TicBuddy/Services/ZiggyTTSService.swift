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
        isSpeaking = false
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
            print("[ZiggyTTS] Proxy unavailable (\(voiceProfile.rawValue)): \(error.localizedDescription) — using system TTS fallback")
            guard !Task.isCancelled else { return }
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

    /// AVSpeechSynthesizer fallback — fires when the OpenAI TTS proxy is unreachable or
    /// returns an error (e.g. OPENAI_API_KEY not set in Railway). (tb-mvp2-043)
    ///
    /// tb-mvp2-048: Rates pushed above 0.50 (the AVFoundation default). At 0.50,
    /// AVSpeechSynthesizer sounds choppy and word-by-word — each word has an audible
    /// micro-pause before the next. 0.54–0.57 is the sweet spot for natural cadence
    /// without sounding rushed. This is only a fallback — OpenAI tts-1-hd nova is the
    /// primary voice; ensure OPENAI_API_KEY is set in Railway to avoid this path.
    private func speakWithSystemTTS(text: String, voiceProfile: ZiggyVoiceProfile) async {
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
        synthesizer.speak(utterance)

        // Poll until the synthesizer finishes (AVSpeechSynthesizer has no async API).
        while synthesizer.isSpeaking {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            if Task.isCancelled {
                synthesizer.stopSpeaking(at: .immediate)
                break
            }
        }
        isSpeaking = false
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

    private func playAudio(data: Data) async {
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
        // Remove [LOG_TIC: ...] tags Ziggy sometimes appends
        clean = clean.replacingOccurrences(of: #"\[LOG_TIC:[^\]]+\]"#, with: "", options: .regularExpression)
        // Unwrap **bold** and *italic* markers (keep the text, drop the asterisks)
        clean = clean.replacingOccurrences(of: #"\*{1,2}([^*\n]+)\*{1,2}"#, with: "$1", options: .regularExpression)
        // Remove inline `code` backticks
        clean = clean.replacingOccurrences(of: #"`[^`\n]+`"#, with: "", options: .regularExpression)
        // Collapse multiple whitespace/newlines into a single space
        clean = clean.components(separatedBy: .newlines).joined(separator: " ")
        clean = clean.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        // Truncate to 500 chars max (proxy enforces this too; trim here for UX)
        if clean.count > 500 {
            clean = String(clean.prefix(497)) + "..."
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
