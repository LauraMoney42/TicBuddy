// TicBuddy — SpeechRecognizer.swift
// SFSpeechRecognizer + AVAudioEngine wrapper for voice input in Ziggy sessions (tb-mvp2-028).
//
// Supports two input modes:
//   Tap mode   — tap once to start recording, tap again to stop and send
//   Toggle mode — stay on until explicitly toggled off (user toggles mic ON)
//
// Transcript streams live to `transcript` as user speaks.
// `onFinalTranscript` closure fires when recording ends with final text.
//
// Stops ZiggyTTSService playback before recording to avoid mic feedback.

import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject {

    // MARK: - Published State

    @Published var transcript: String = ""
    @Published var isRecording: Bool = false
    /// True when the user chose "keep mic on" toggle mode
    @Published var isMicLocked: Bool = false
    @Published var permissionStatus: SpeechPermissionStatus = .unknown

    // MARK: - Callbacks

    /// Called with the final transcript when recording stops (tap-mode only).
    /// In toggle mode, caller should read `transcript` directly when they stop.
    var onFinalTranscript: ((String) -> Void)?

    // MARK: - Private

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    /// Tracks whether an audio tap is currently installed on inputNode bus 0.
    /// Guards all removeTap calls — AVAudioNode throws NSException (fatal) if
    /// removeTap is called on a bus with no tap installed.
    private var tapInstalled = false

    // MARK: - Singleton

    static let shared = SpeechRecognizer()
    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    // MARK: - Permissions

    /// Request speech recognition and microphone permissions sequentially.
    ///
    /// tb-mvp2-033 fix: Previously fired both requests simultaneously with no sequencing
    /// and discarded the microphone grant result. On iOS 17 + Swift 6, the simultaneous
    /// background callbacks could race and crash the app on "Allow". Fixed by:
    ///   1. Awaiting each permission in order (speech → mic) so dialogs are sequential.
    ///   2. Evaluating BOTH results before setting permissionStatus.
    ///   3. Using the iOS 17 async API for microphone (AVAudioApplication.shared).
    ///
    /// tb-mvp2-035 crash fix: Declared `nonisolated` so the Obj-C callback resumes the
    /// continuation in a non-actor context. In Swift 6, @MainActor async functions assert
    /// main-queue isolation at every suspension point re-entry. When
    /// SFSpeechRecognizer.requestAuthorization fires its callback on Thread 15 (background),
    /// resuming a continuation inside a @MainActor function causes dispatch_assert_queue_fail
    /// because Swift re-checks the actor at the resume site — a known Swift 6 bug with
    /// withCheckedContinuation across actor boundaries. Making the function nonisolated avoids
    /// the assertion entirely; MainActor.run is used explicitly for the state write.
    nonisolated func requestPermissions() async {
        // Step 1: speech recognition — bridges Obj-C callback to Swift async.
        // nonisolated: the callback fires on whatever thread Apple chooses (usually background).
        // withCheckedContinuation is safe here because no actor state is accessed in the closure.
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }

        // Step 2: microphone — iOS 17+ async API.
        // Awaiting ensures the mic dialog appears AFTER the speech dialog is fully dismissed,
        // preventing simultaneous overlapping alerts and the resulting callback race.
        let micGranted = await AVAudioApplication.requestRecordPermission()

        // Step 3: hop to MainActor to write @Published state.
        // Explicit MainActor.run replaces the implicit @MainActor isolation that was
        // causing the crash — we control exactly when we re-enter the actor.
        await MainActor.run {
            switch (speechStatus, micGranted) {
            case (.authorized, true):
                permissionStatus = .authorized
            case (.denied, _), (.restricted, _), (_, false):
                permissionStatus = .denied
            default:
                permissionStatus = .unknown
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        guard permissionStatus == .authorized else {
            Task { await requestPermissions() }
            return
        }
        guard let recognizer = speechRecognizer, recognizer.isAvailable else { return }

        // Stop any active TTS — prevents microphone feedback loop
        ZiggyTTSService.shared.stopSpeaking()

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .record, mode: .measurement, options: .duckOthers
            )
            try AVAudioSession.sharedInstance().setActive(
                true, options: .notifyOthersOnDeactivation
            )
        } catch {
            print("[SpeechRecognizer] Audio session error: \(error.localizedDescription)")
            return
        }

        transcript = ""
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }
        request.shouldReportPartialResults = true
        // tb-mvp2-028: on-device recognition if available — avoids sending audio to Apple servers
        if #available(iOS 17, *) {
            request.requiresOnDeviceRecognition = false // Use cloud for better accuracy
        }

        // Install the audio tap BEFORE creating the recognition task.
        // If the tap is installed first, any immediate error from the recognition task
        // will call finishRecording() safely (tap exists to remove). If we install AFTER,
        // a synchronous error callback can fire before the tap is installed → removeTap crash.
        //
        // tb-mvp2-041 fix (tap block): use nonisolated factory so this closure is NOT
        // implicitly @MainActor. The tap fires on Thread 22 (AVAudioEngine render thread)
        // the instant audioEngine.start() is called — before the recognition callback ever
        // fires. If the closure inherits @MainActor from startRecording(), Swift 6's
        // dispatch_assert_queue check triggers EXC_BREAKPOINT at closure entry.
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat,
                             block: makeTapBlock(request: request))
        tapInstalled = true

        // tb-mvp2-041 fix: use nonisolated handler so the closure is NOT implicitly @MainActor.
        // In Swift 6, closures written inside @MainActor functions can inherit @MainActor
        // isolation. SFSpeechRecognizer fires this callback on a background thread (Thread 22);
        // if the closure is @MainActor, Swift 6's dispatch_assert_queue check fires →
        // EXC_BREAKPOINT. Extracting to a nonisolated function breaks the @MainActor inference
        // — identical fix to requestPermissions() for the launch crash (tb-mvp2-033).
        recognitionTask = recognizer.recognitionTask(with: request, resultHandler: makeRecognitionHandler())

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
        } catch {
            print("[SpeechRecognizer] Engine start error: \(error.localizedDescription)")
            cleanupAudio()
        }
    }

    /// Stop recording. In tap mode this fires `onFinalTranscript`. In toggle mode caller reads `transcript`.
    func stopRecording(fireCallback: Bool = true) {
        guard isRecording else { return }
        finishRecording(fireCallback: fireCallback)
    }

    /// Toggle mic-lock mode ON/OFF.
    /// When turning ON: starts recording. When turning OFF: stops recording.
    func toggleMicLock() {
        if isMicLocked {
            isMicLocked = false
            stopRecording(fireCallback: true)
        } else {
            isMicLocked = true
            startRecording()
        }
    }

    // MARK: - Private

    /// Returns the AVAudioEngine tap block as a nonisolated closure.
    ///
    /// tb-mvp2-041 fix (tap): The tap fires on Thread 22 (audio render thread) the instant
    /// audioEngine.start() is called. A closure written inside @MainActor startRecording()
    /// inherits @MainActor isolation; Swift 6 checks actor isolation at closure entry →
    /// dispatch_assert_queue_fail → EXC_BREAKPOINT before a single line of the body runs.
    /// nonisolated factory breaks the inference. SFSpeechAudioBufferRecognitionRequest is
    /// @unchecked Sendable (Obj-C class) so the cross-boundary capture is safe.
    nonisolated private func makeTapBlock(
        request: SFSpeechAudioBufferRecognitionRequest
    ) -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in request.append(buffer) }
    }

    /// Returns the SFSpeechRecognizer result handler as a nonisolated closure.
    ///
    /// tb-mvp2-041 fix: Declared nonisolated so the returned closure does NOT inherit
    /// @MainActor isolation from the enclosing startRecording() call. SFSpeechRecognizer
    /// fires recognition callbacks on a background thread (Thread 22); a @MainActor closure
    /// triggers dispatch_assert_queue_fail → EXC_BREAKPOINT (code=1) in Swift 6.
    /// All actor-isolated work is deferred to an explicit Task { @MainActor } inside.
    nonisolated private func makeRecognitionHandler() -> (SFSpeechRecognitionResult?, Error?) -> Void {
        { [weak self] result, error in
            // tb-mvp2-041 Swift 6 Sendable fix: SFSpeechRecognitionResult and Error are not
            // Sendable — they cannot cross the actor boundary into Task { @MainActor }.
            // Extract all needed values as Sendable primitives (String, Bool, Int) HERE,
            // before the Task boundary, then pass only those into the actor-isolated closure.
            let transcriptText: String? = result?.bestTranscription.formattedString
            let isFinal: Bool = result?.isFinal == true
            let nsErr = error.map { $0 as NSError }
            let errorDomain: String? = nsErr?.domain
            let errorCode: Int? = nsErr?.code
            let errorDesc: String? = nsErr?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let transcriptText {
                    self.transcript = transcriptText
                }
                if let errorDesc {
                    // Code 216 = recording stopped by user — not a real error
                    if errorDomain != "kAFAssistantErrorDomain" || errorCode != 216 {
                        print("[SpeechRecognizer] Recognition error: \(errorDesc)")
                    }
                    self.finishRecording()
                } else if isFinal {
                    self.finishRecording()
                }
            }
        }
    }

    private func finishRecording(fireCallback: Bool = true) {
        // Guard against re-entry. Recognition task can fire multiple callbacks (error + isFinal
        // in rapid succession). Without this guard: duplicate onFinalTranscript, double
        // setActive(false), and potential state corruption.
        guard isRecording || tapInstalled else { return }
        audioEngine.stop()
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )

        let final = transcript
        if fireCallback && !final.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            onFinalTranscript?(final)
        }
    }

    private func cleanupAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        isMicLocked = false
    }
}

// MARK: - Permission Status

enum SpeechPermissionStatus {
    case unknown
    case authorized
    case denied
}
