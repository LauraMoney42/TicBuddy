// TicBuddy — TTSVoicePreviewView.swift
// tb-mvp2-049 / tb-mvp2-053: Hidden developer screen for auditioning OpenAI TTS voices.
//
// Access: triple-tap the version number in SettingsView.
// Usage:  type sample text, pick a voice, adjust speed, tap Preview.
//         When you find the winner → note the voice + speed and lock them in server.js.
//
// Requires: PROXY_BASE_URL set in Info.plist (device) or Xcode scheme env vars (debug).
// Both regular Ziggy TTS and preview use ZiggyTTSService.shared → APIConfig.ttsURL,
// the same endpoint. Ziggy chat "works" via AVSpeechSynthesizer fallback when the proxy
// is unreachable; preview bypasses that fallback so failures are visible. (tb-mvp2-053)

import SwiftUI

struct TTSVoicePreviewView: View {

    @StateObject private var tts = ZiggyTTSService.shared
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var sampleText: String = "Hi there! I'm Ziggy, your CBIT practice companion. Really glad you're here. I'm going to walk you through how tic management works and how TicBuddy supports you."
    @State private var selectedVoice: String = "nova"
    @State private var speed: Double = 1.05
    @State private var lastPlayed: String = ""

    private let voices = ["nova", "shimmer", "alloy", "echo", "fable", "onyx"]

    /// True when PROXY_BASE_URL is set and not a placeholder. Same check Ziggy chat uses.
    private var proxyConfigured: Bool { APIConfig.isConfigured }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "0D0D1A").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerCard
                        if !proxyConfigured { proxyWarningBanner }
                        voicePickerCard
                        speedCard
                        sampleTextCard
                        previewButton
                        if let err = tts.previewError { errorBanner(err) }
                        if !lastPlayed.isEmpty && tts.previewError == nil { lastPlayedBadge }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Voice Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { tts.stopSpeaking(); dismiss() }
                        .foregroundColor(Color(hex: "667EEA"))
                }
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text("🔊 TTS Voice Preview")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            Text("Audition OpenAI tts-1-hd voices in real time.\nPick the winner → lock it in server.js.")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Proxy Not Configured Warning

    /// tb-mvp2-053: Show before the preview button when PROXY_BASE_URL is not set.
    /// Both preview and Ziggy chat use the same APIConfig.ttsURL endpoint — this is
    /// the same URL that Ziggy chat uses. Ziggy chat "works" only because it silently
    /// falls back to AVSpeechSynthesizer; preview bypasses the fallback intentionally
    /// so you can tell when the proxy is actually reachable.
    private var proxyWarningBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .foregroundColor(Color(hex: "FFB347"))
                Text("Proxy not configured")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "FFB347"))
            }
            Text("PROXY_BASE_URL is not set — preview will fail with \"hostname not found\".")
                .font(.caption)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Text("Fix: open TicBuddy/Info.plist and set PROXY_BASE_URL to your Railway URL.\nOr set it in Xcode: Edit Scheme → Run → Environment Variables.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
            Text("Note: Ziggy chat sounds like it works because it falls back to device TTS — it is not reaching OpenAI either.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.35))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FFB347").opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "FFB347").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Voice Picker

    private var voicePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Voice", systemImage: "waveform")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(voices, id: \.self) { voice in
                    voiceChip(voice)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func voiceChip(_ voice: String) -> some View {
        let isSelected = selectedVoice == voice
        return Button {
            selectedVoice = voice
        } label: {
            Text(voice)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.55))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    isSelected
                        ? LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .topLeading, endPoint: .bottomTrailing)
                        : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Speed Slider

    private var speedCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Speed", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(String(format: "%.2fx", speed))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(Color(hex: "43E97B"))
            }

            Slider(value: $speed, in: 0.8...1.2, step: 0.01)
                .tint(Color(hex: "667EEA"))

            HStack {
                Text("0.80  slower")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                Spacer()
                Text("faster  1.20")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Sample Text

    private var sampleTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Sample Text", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white.opacity(0.7))

            TextEditor(text: $sampleText)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 100)
        }
        .padding(16)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Preview Button

    private var previewButton: some View {
        Button {
            if tts.isSpeaking {
                tts.stopSpeaking()
            } else {
                lastPlayed = "\(selectedVoice) @ \(String(format: "%.2f", speed))x"
                tts.previewSpeak(text: sampleText, voice: selectedVoice, speed: speed)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tts.isSpeaking ? "stop.fill" : "play.fill")
                    .font(.system(size: 16, weight: .bold))
                Text(tts.isSpeaking ? "Stop" : "Preview")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                tts.isSpeaking
                    ? LinearGradient(colors: [Color(hex: "FF6B6B"), Color(hex: "FF8E53")], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")], startPoint: .leading, endPoint: .trailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color(hex: "667EEA").opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: tts.isSpeaking)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(hex: "FF6B6B"))
                Text("Preview failed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color(hex: "FF6B6B"))
            }
            Text(message)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Text(proxyConfigured
                 ? "Proxy URL is set — check OPENAI_API_KEY in Railway env vars."
                 : "Set PROXY_BASE_URL in Info.plist first (see warning above).")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.4))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "FF6B6B").opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: "FF6B6B").opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Last Played Badge

    private var lastPlayedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(Color(hex: "43E97B"))
            Text("Last played: \(lastPlayed)")
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }
}

#Preview {
    TTSVoicePreviewView()
}
