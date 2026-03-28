# TicBuddy — Pre-Recorded Audio Spec
**Status:** Research / Planning
**Author:** Dev4
**Date:** 2026-03-27
**Scope:** Replace live ElevenLabs TTS (lesson slides + onboarding openers) with bundled pre-recorded `.m4a` files

---

## 1. Where TTS Is Currently Triggered

### 1.1 Architecture Overview

All TTS is routed through **`ZiggyTTSService.swift`** (singleton). It has two paths:
- **Primary:** ElevenLabs via Railway proxy → MP3 → AVAudioPlayer
- **Fallback:** AVSpeechSynthesizer (on-device, fires if network fails)

### 1.2 TTS Call Sites

| # | Context | File | Line | Method | Notes |
|---|---------|------|------|--------|-------|
| 1 | **Lesson slides** | `Views/Lessons/LessonSlideView.swift` | 90, 331 | `speakLesson(text:voiceProfile:slideIndex:)` | Fires on `.onAppear` + forward nav. Pre-fetches next slide in background. |
| 2 | **Lesson prefetch** | `Views/Onboarding/AppWalkthroughView.swift` | 116–139 | `prefetchLessonSlide(...)` | Pre-warms all 11 lesson slides during the app walkthrough (before user reaches Lesson 1). |
| 3 | **Caregiver onboarding opener** | `Views/Home/CaregiverOnboardingZiggyView.swift` | 92 | `speak(text:voiceProfile:)` | Fires after permission requests resolve. Two variants: caregiver vs. self-user. |
| 4 | **Chat responses** | `ViewModels/ChatViewModel.swift` | 261 | `speak(text:voiceProfile:)` | Fires after every Claude API response. Text is dynamic — **not pre-recordable.** |
| 5 | **Dev voice preview** | `Views/Settings/TTSVoicePreviewView.swift` | 222 | `previewSpeak(text:voice:speed:)` | Dev-only (triple-tap version). Not user-facing. |

> **Pre-recording scope:** Items 1, 2, and 3 use static, known text — ideal candidates.
> Item 4 (chat) is dynamic and must remain live TTS. Item 5 is a dev tool — skip.

---

## 2. What Text Is Spoken

### 2.1 Lesson 1 — All 11 Slides
**Source file:** `Services/CBITLessonService.swift`
**Voice profile used:** `.caregiver` (during current demo/onboarding flow)

| Slide # | Slide ID | Title | approx. Words | Key audioHint |
|---------|----------|-------|---------------|---------------|
| 1 | 0 | Welcome to TicBuddy! | ~358 | "Warm, upbeat, welcoming. Smile through the voice." |
| 2 | 1 | Your TicBuddy Toolkit | ~180 | "Upbeat and quick — features highlight." |
| 3 | 2 | LESSON 1 — What is Tourette's | ~120 | "Gentle, warm, reassuring." |
| 4 | 3 | What Are Tics? | ~130 | "Clear and steady. Slight pause before bullet points." |
| 5 | 4 | Tics Change Over Time | ~110 | "Reassuring tone. Emphasize 'right now, not just someday'." |
| 6 | 5 | The Premonitory Urge | ~130 | "Measured pace. Last line — slight emphasis." |
| 7 | 6 | What If I Can't Feel It Yet? | ~120 | "Warm and reassuring throughout." |
| 8 | 7 | How CBIT Works | ~130 | "Confident, clear. Slow down for eye-blink example." |
| 9 | 8 | Paving a Better Road | ~140 | "Slow, warm, storytelling. Emotional core." |
| 10 | 9 | Let's Map Your Tics | ~100 | "Warm and forward-looking. Pause before 'Tap below'." |
| 11 | 10 | What's Next (Homework) | ~200 | "Energetic and encouraging. Pause after 'that's it'." |

**Total lesson audio files needed:** 11 (per voice profile variant — see §3)

### 2.2 Onboarding Openers (CaregiverOnboardingZiggyView)
**Source file:** `Views/Home/CaregiverOnboardingZiggyView.swift` (lines 206–230)

| Variant | Line | Voice Profile | approx. Words | First line |
|---------|------|---------------|---------------|------------|
| Caregiver opener | 206–217 | `.caregiver` | ~82 | "Hi there! I'm Ziggy, your family's CBIT companion..." |
| Self-user opener | 219–230 | `.adolescent` | ~81 | "Hey! I'm Ziggy — I'll be your CBIT practice companion..." |

**Total onboarding audio files needed:** 2

---

## 3. Proposed File Structure

```
TicBuddy/Resources/Audio/
├── lesson1/
│   ├── caregiver/
│   │   ├── lesson1_slide_00_caregiver.m4a   # Welcome to TicBuddy!
│   │   ├── lesson1_slide_01_caregiver.m4a   # Your TicBuddy Toolkit
│   │   ├── lesson1_slide_02_caregiver.m4a   # What is Tourette's
│   │   ├── lesson1_slide_03_caregiver.m4a   # What Are Tics?
│   │   ├── lesson1_slide_04_caregiver.m4a   # Tics Change Over Time
│   │   ├── lesson1_slide_05_caregiver.m4a   # The Premonitory Urge
│   │   ├── lesson1_slide_06_caregiver.m4a   # What If I Can't Feel It Yet?
│   │   ├── lesson1_slide_07_caregiver.m4a   # How CBIT Works
│   │   ├── lesson1_slide_08_caregiver.m4a   # Paving a Better Road
│   │   ├── lesson1_slide_09_caregiver.m4a   # Let's Map Your Tics
│   │   └── lesson1_slide_10_caregiver.m4a   # What's Next
│   ├── adolescent/
│   │   └── lesson1_slide_XX_adolescent.m4a  # (if needed for teen self-user path)
│   ├── older_child/
│   │   └── lesson1_slide_XX_older_child.m4a # (if needed)
│   └── young_child/
│       └── lesson1_slide_XX_young_child.m4a # (if needed)
├── onboarding/
│   ├── opener_caregiver.m4a                 # Caregiver first-launch opener
│   └── opener_self_user.m4a                 # Self-user (teen) first-launch opener
└── README.md                                # Naming convention + recording notes
```

> **Naming convention:** `{context}_{identifier}_{voice_profile}.m4a`
> Lowercase, underscores, no spaces. Zero-padded slide numbers (00–10).

**Phase 1 minimum viable set (`.caregiver` only):** 11 lesson files + 2 onboarding = **13 files**
**Full multi-profile set:** Up to 4 voice variants × 11 slides = 44 lesson files + 8 onboarding = **52 files**

---

## 4. Playback Approach

### 4.1 Recommended: AVAudioPlayer (not AVPlayer)

| | AVAudioPlayer | AVPlayer |
|--|---------------|----------|
| Local bundled files | ✅ Ideal | Works but overkill |
| Streaming / remote URLs | ❌ No | ✅ Yes |
| Latency | Near-zero | Small buffer delay |
| Duration property | ✅ Available immediately | Requires async load |
| Delegate callbacks | ✅ `audioPlayerDidFinishPlaying` | Requires KVO/notifications |
| Complexity | Low | Medium |

**Verdict:** Use `AVAudioPlayer` for all pre-recorded local files. Matches existing fallback path already in `ZiggyTTSService.swift`.

### 4.2 How to Trigger on Slide Advance

The existing `speakLesson(text:voiceProfile:slideIndex:)` method in `ZiggyTTSService` already receives a `slideIndex: Int`. The implementation change is internal to that method:

**Current flow:**
```
slideIndex → build ElevenLabs request → fetch MP3 → AVAudioPlayer
```

**Proposed flow:**
```
slideIndex + voiceProfile → resolve bundle path → AVAudioPlayer
                          ↓ (if file missing)
                          → live ElevenLabs fetch (fallback)
```

No changes needed in `LessonSlideView.swift` or `AppWalkthroughView.swift` — the call sites are unchanged. Only `ZiggyTTSService.speakLesson()` and `prefetchLessonSlide()` need updating internally.

### 4.3 Audio Session (No Change Needed)

Current audio session config already correct:
```swift
try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
try AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
```
This respects the silent switch override and routes to speaker. Keep as-is.

### 4.4 Word-Reveal Sync

The existing word-reveal animation uses audio duration (`player.duration`) to calculate per-word timing. Since `AVAudioPlayer` exposes `.duration` on local files instantly (no async load needed), the word-reveal timer will work identically with pre-recorded files.

---

## 5. Fallback Plan

**Recommended: Silent fail → live TTS fallback**

```
1. Attempt to load bundled .m4a for slideIndex + voiceProfile
2. If file exists and loads → play pre-recorded audio ✅
3. If file missing or load fails → fall through to existing ElevenLabs fetch
4. If ElevenLabs also fails → AVSpeechSynthesizer on-device fallback (already implemented)
```

**Why not silent fail only?** A missing audio file in lesson content would mean the user hears nothing during an educational slide — disorienting. Falling back to live TTS ensures audio always plays.

**Error logging:** Log a warning (`print("[TTS] Pre-recorded file missing for slide \(index), falling back to live TTS")`) so developers notice missing files during QA.

---

## 6. Recording Workflow

### Option A: ElevenLabs Export (Recommended for consistency)
1. Identify the `spokenText` field for each slide in `CBITLessonService.swift`
2. Strip emojis + apply phonetic fixes (same as `prepareForSpeech()` in `ZiggyTTSService`)
3. POST to ElevenLabs API (or Railway proxy) with target voice ID + speed 1.05x
4. Download MP3 response
5. Convert MP3 → M4A: `ffmpeg -i input.mp3 -c:a aac -b:a 128k output.m4a`
6. Verify playback + trim silence if needed
7. Drop into `TicBuddy/Resources/Audio/` folder structure

**Pros:** 100% consistent with what users currently hear. No re-recording needed.
**Cons:** Requires ElevenLabs API access + minor scripting.

### Option B: Manual Human Recording
1. Read from `spokenText` fields using the `audioHint` guidance in each slide
2. Record in a quiet environment (Voice Memos or DAW)
3. Export as `.m4a` at 44.1kHz / 128kbps AAC
4. Name files per convention in §3

**Pros:** Authentic human voice.
**Cons:** Inconsistent with dynamic chat TTS voice. Requires re-recording if slide text changes.

### Option C: macOS TTS Export (Budget fallback)
```bash
say -v Samantha -r 200 -o slide_00.aiff "Welcome to TicBuddy!..."
afconvert slide_00.aiff -o slide_00.m4a -f m4af -d aac
```
**Pros:** Zero cost, fully scripted, no external API.
**Cons:** Different voice than ElevenLabs — jarring switch between lesson and chat audio.

> **Recommendation:** Option A for production. Option C for rapid prototyping/QA.

---

## 7. Xcode Integration

### 7.1 Adding Files to Xcode Project

1. In Finder, copy `.m4a` files into `TicBuddy/Resources/Audio/` (maintain folder structure)
2. In Xcode: **File → Add Files to "TicBuddy"**
3. Select the `Audio` folder
4. In the dialog: ✅ **"Create folder references"** (NOT "Create groups") — preserves subdirectory paths
5. Ensure **Target Membership** includes `TicBuddy` ✅
6. Verify in **Build Phases → Copy Bundle Resources** that the Audio folder appears

### 7.2 Accessing Files at Runtime

```swift
// Resolve bundle path for a lesson slide
func bundledAudioURL(lessonId: String, slideIndex: Int, profile: ZiggyVoiceProfile) -> URL? {
    let profileName = profile.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
    let filename = "\(lessonId)_slide_\(String(format: "%02d", slideIndex))_\(profileName)"
    return Bundle.main.url(forResource: filename, withExtension: "m4a",
                           subdirectory: "Audio/\(lessonId)/\(profileName)")
}

// Resolve bundle path for onboarding opener
func bundledOnboardingURL(isSelfUser: Bool) -> URL? {
    let name = isSelfUser ? "opener_self_user" : "opener_caregiver"
    return Bundle.main.url(forResource: name, withExtension: "m4a",
                           subdirectory: "Audio/onboarding")
}
```

### 7.3 App Size Estimate

| Scenario | Files | avg. Duration | avg. Size | Total |
|----------|-------|---------------|-----------|-------|
| Phase 1 (caregiver only) | 13 | ~45 sec | ~720 KB | ~9.4 MB |
| Full (4 profiles) | 52 | ~45 sec | ~720 KB | ~37.4 MB |

> At 128kbps AAC: 1 minute ≈ ~960 KB. Most slides are 30–60 seconds.
> Phase 1 adds ~9–10 MB to the app bundle — acceptable for App Store (under 200 MB OTA limit).

### 7.4 .gitignore Note

Large binary `.m4a` files should ideally be tracked via Git LFS:
```
# .gitattributes
*.m4a filter=lfs diff=lfs merge=lfs -text
```

---

## 8. Implementation Checklist (For Dev Pickup)

- [ ] Generate 13 Phase 1 audio files (11 lesson slides + 2 onboarding openers)
- [ ] Add files to Xcode with "Create folder references"
- [ ] Update `ZiggyTTSService.speakLesson()` to check bundle first, fall back to live TTS
- [ ] Update `ZiggyTTSService.prefetchLessonSlide()` similarly (or skip prefetch if bundled)
- [ ] Update `CaregiverOnboardingZiggyView.setup()` to use bundled opener URL
- [ ] Add warning log for missing bundle files
- [ ] Test: lesson plays audio on slide advance ✅
- [ ] Test: missing file falls back to ElevenLabs → AVSpeech ✅
- [ ] Test: word-reveal animation timing correct with `.duration` from pre-recorded file ✅
- [ ] Test: silent mode still plays audio ✅
- [ ] Test: headphone routing ✅

---

## 9. Out of Scope

- **Chat responses** (`ChatViewModel` line 261) — Dynamic text, cannot pre-record. Keep live TTS.
- **Dev voice preview tool** (`TTSVoicePreviewView`) — Dev tool only, no change needed.
- **Future lessons** (Lesson 2+) — Apply same pattern when content is finalized.

---

*Spec complete. No code changes made — research and documentation only.*
