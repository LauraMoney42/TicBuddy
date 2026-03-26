## 2026-03-24 — tb-mvp2-018 Evening Check-In Sync (Dev1)
- VERIFIED complete — all components fully implemented and wired end-to-end
- Services/EveningCheckInService.swift — daily local notification scheduler (7 PM default, caregiver-configurable), shouldShowEveningPrompt(), permission handling
- Views/Evening/EveningCheckInSheet.swift — child-facing check-in UI (mood emoji, energy 1-3, practice done?); age-appropriate copy for very young / older / teen; privacy note for teens; didSubmit → CheckInConfirmationView
- Views/ChildMode/ChildModeYoungView, OlderView, AdolescentView — all wired with showEveningCheckIn state + sheet (after 5pm / on demand)
- Views/Home/CaregiverHomeView.swift — EveningCheckInBanner (in-app soft nudge), NightlyRitualCard (post-submit summary), EveningReminderSettingsView (time picker)
- Services/TicDataService.swift — submitEveningCheckIn(), todayEveningCheckIn() implemented
- Files affected: all verified, no code changes needed

## 2026-03-24 — tb-mvp2-014 COPPA Compliance (Dev1)
- ADD: Services/COPPAConsentService.swift — consent recording, 30-day inactivity auto-delete, purgeChildData(), caregiver notifications (local only, no email)
- ADD: Views/Onboarding/COPPAConsentSheet.swift — COPPA gate shown before under-13 profile creation; email field + dual checkboxes; blocks "Continue" until both checked + valid email
- UPDATED: Views/Onboarding/FamilyOnboardingView.swift — intercepts last onboarding step for COPPA children; shows COPPAConsentSheet; proceeds only on accept
- UPDATED: Services/ClaudeService.swift — isCOPPA param; sets X-Coppa-Mode: true header for under-13 API calls
- UPDATED: ViewModels/ChatViewModel.swift — activeChildIsCOPPA; passes isCOPPA to sendMessage()
- UPDATED: TicBuddyProxy/server.js — reads X-Coppa-Mode header; suppresses content logging for under-13 per COPPA §312 data minimization
- UPDATED: Views/Settings/FamilyManagementView.swift — removeChild() now calls purgeChildData() (covers tic entries, journal, consent keys, Keychain PIN); EditChildSheet gains COPPA §312.6 "Delete [child]'s Data" section (under-13 only) with confirmation dialog and deleteChildDataAndDismiss()
- Files affected: Services/COPPAConsentService.swift (new), Views/Onboarding/COPPAConsentSheet.swift (new), Views/Onboarding/FamilyOnboardingView.swift, Services/ClaudeService.swift, ViewModels/ChatViewModel.swift, TicBuddyProxy/server.js, Views/Settings/FamilyManagementView.swift

## 2026-03-24 — tb-mvp2-009 Adolescent Mode (Dev1)
- VERIFIED complete — ChildModeAdolescentView.swift (1290 lines) fully implemented and wired into FamilyModeRouter
- Dark slate/navy theme; peer tone; no excessive celebration popups
- AdolHeader (understated greeting + streak), PrivacyPill ("Caregiver sees summary only")
- AdolTodayCard (noticed/caught/redirected + redirect rate %), AdolWeekStrip (7-day stacked bars)
- AdolCRCard expandable with real neuroscience copy; AdolAwarenessCard for Week 1
- AdolTicLogSheet: trigger tag picker (8 tags), private note field, urge 1–5, outcomes redirected-first
- AdolJournalView: fully private journal keyed per child UUID; TeenCrisisDetector runs on save
- TeenCrisisDetector: 27-phrase keyword scan on all teen-authored content
- AdolCrisisFlagSheet: 988 Lifeline + Crisis Text Line + trusted adult; parent never notified
- AdolescentJournalStore: UserDefaults per child UUID, max 200 entries, never read by caregiver
- FamilyModeRouter: .youngTeen/.teen → ChildModeAdolescentView (already wired at line 148)
- Files affected: Views/ChildMode/ChildModeAdolescentView.swift (verified, no changes needed)

## 2026-03-24 — tb-mvp2-011 ElevenLabs TTS — Ziggy Voice (Dev1)
- ADD: Services/ZiggyTTSService.swift — ElevenLabs TTS client + AVAudioPlayer playback
  - Routes through proxy /api/tts (API key stays off-device)
  - Per-voice-profile EL voice IDs + voice settings (stability/similarity/style)
  - speak(text:voiceProfile:) cancels previous playback, cleans markdown before sending
  - isEnabled toggle persisted in UserDefaults; isSpeaking published for pulsing UI indicator
  - TTS failures non-fatal (chat works fine without audio)
- ADD: TicBuddyProxy/server.js — POST /api/tts endpoint
  - Accepts { text, voiceProfile? }; validates text ≤500 chars
  - Maps voiceProfile string to ElevenLabs voice ID (configurable via EL_VOICE_* env vars)
  - Returns { audio: base64mp3, format: "mp3" }; uses eleven_turbo_v2 model (low latency)
  - ELEVENLABS_API_KEY env var required; returns 503 gracefully if not set
- UPDATED: ViewModels/ChatViewModel.swift — inject ZiggyTTSService; call speak() after each Ziggy response
- UPDATED: Views/Chat/ChatView.swift — speaker toggle button in ChatHeaderView; pulsing circle when Ziggy speaking
- Files affected: Services/ZiggyTTSService.swift (new), TicBuddyProxy/server.js, ViewModels/ChatViewModel.swift, Views/Chat/ChatView.swift

## 2026-03-24 — tb-mvp2-006 Caregiver Ziggy Session Wiring (Dev1)
- FIXED: CaregiverHomeView "Talk to Ziggy" tile — was a TODO stub; now opens ChatView sheet
- ChatViewModel.activeVoiceProfile returns .caregiver automatically when no child profile is active (no param needed)
- Files affected: Views/Home/CaregiverHomeView.swift, Views/Chat/ChatView.swift (comment clarification)

## 2026-03-24 — tb-mvp2-010 AI Model Upgrade + Voice Profiles (Dev1)
- UPGRADE: TicBuddyProxy/server.js — model claude-opus-4-6 → claude-sonnet-4-6 (default); accepts optional `model` field in request body; allowlist: ["claude-sonnet-4-6", "claude-haiku-4-6"]
- ADD: Services/ZiggyVoiceProfileService.swift — ZiggyVoiceProfile enum (4 profiles: youngChild/olderChild/adolescent/caregiver); each profile defines persona prompt block + preferred model; ZiggyVoiceProfileService.activeProfile(familyUnit:) auto-selects from AgeGroup
- UPDATED: Services/ClaudeService.swift — buildSystemPrompt(for:voiceProfile:memoryInjection:), sendMessage() accepts voiceProfile param, persona block injected at top of system prompt, extraction call uses claude-haiku-4-6, TicTalkRequest includes model field
- Files affected: TicBuddyProxy/server.js, Services/ZiggyVoiceProfileService.swift (new), Services/ClaudeService.swift

## 2026-03-24 — tb-mvp2-008 Older Child Mode (Dev1)
- ADD: Views/ChildMode/ChildModeOlderView.swift — ages 9–12 child-facing home screen
  - Free-text chat available (ZiggyContentFilter guards it); Ziggy button launches ChatView sheet
  - OlderTicLogSheet: tic picker + outcome selector (noticed/caught/redirected/ticHappened) + urge strength 1–5 flame picker
  - OlderProgressRing: animated ring showing redirections vs. total noticed today
  - OlderCRCard: competing response with expandable "Why this works" explanation
  - OlderCelebrationBanner: top-of-screen banner (auto-dismisses 3s) with outcome-specific message
  - Privacy note for ages 10+: "Your PIN is yours — your caregiver can't see what you type to Ziggy"
  - Floating "Log a tic" FAB (spring press animation)
- Files affected: Views/ChildMode/ChildModeOlderView.swift (new)

## 2026-03-24 — tb-mvp2-007 Young Child Mode (Dev1)
- ADD: Views/ChildMode/ChildModeYoungView.swift — ages 4–8 child-facing home screen
  - NO free-text input (tap-only: prevents abuse surface, age-appropriate)
  - BigTicButton: 2-tap logging flow — "I had a tic!" → YoungTicPickerSheet (grid of tic types)
  - Week 1: YoungDetectiveCard ("be a tic detective!"), Week 2+: YoungCRCard (competing response)
  - YoungCelebrationOverlay: spring-animated celebration on every log, auto-dismiss 2.5s
  - YoungTicPickerSheet: uses child's ticHierarchy if set, else common tic buttons; 2-column grid, 100pt min targets
  - YoungCRDetailSheet: full-screen competing response instructions, "I tried it!" logs .redirected entry
  - YoungStarRow: today's noticed + redirected count at bottom
- Files affected: Views/ChildMode/ChildModeYoungView.swift (new)

## 2026-03-24 — tb-mvp2-021 Usage Limits Fix (Dev1)
- FIXED: ChatUsageLimiter.defaultDailyLimit 20 → 15 (per product spec: hardcoded, not caregiver-adjustable)
- ADD: ChatUsageLimiter.countdownThreshold = 5 constant
- ADD: countdownMessage(for:limit:) → "5 questions left today 🌟" (shown to caregiver + child when ≤5 remain)
- UPDATED: Header comment clarifies limit is intentionally not caregiver-adjustable
- REMOVED: Services/SafetyFilter.swift (duplicate — ZiggyContentFilter.swift is the canonical filter)
- Files affected: Services/ChatUsageLimiter.swift

## 2026-03-24 — tb-mvp2-020 Medicine + OOS Hard Rails (Dev2)
- ADD: Services/ZiggyContentFilter.swift — client-side safety filter runs BEFORE Claude API call; two categories: (1) medication — always block, covers 40+ medication names + dosage phrases; (2) mental health counseling — block unless tic-context whitelist terms present (prevents false positives on "anxious about my tic", "OCD vs tic difference"); warm Ziggy redirect messages for both categories including 988 crisis line for severe distress
- UPDATED: ViewModels/ChatViewModel.swift — ZiggyContentFilter.check() called as first gate in sendMessage(); blocked messages show warm redirect in chat, never reach Claude
- UPDATED: Services/ClaudeService.swift — strengthened SAFETY RULES section with explicit MEDICATION HARD RAIL, MENTAL HEALTH HARD RAIL, CRISIS RESPONSE, and tic-context exception for OCD/anxiety educational topics
- Files affected: Services/ZiggyContentFilter.swift (new), ViewModels/ChatViewModel.swift, Services/ClaudeService.swift

## 2026-03-24 — tb-mvp2-019 Wired End-to-End (Dev2)
- UPDATED: ViewModels/ChatViewModel.swift — lazy memory injection on first send via CBITSessionStore.buildMemoryInjection(), passes memoryInjection to ClaudeService.sendMessage(); endSession() async method calls extractAndSaveMemories() on session close; memoryLoadedForSession flag prevents mid-session prompt drift; activeChildID/activeChildAge helpers bridge family unit + legacy single-user modes
- UPDATED: Views/Chat/ChatView.swift — .onDisappear calls Task { await viewModel.endSession() } to trigger extraction when user leaves chat tab
- Files affected: ViewModels/ChatViewModel.swift, Views/Chat/ChatView.swift

## 2026-03-24 — Claude Dream Memory System (tb-mvp2-019)
- ADD: Models/SessionMemory.swift — SessionMemoryItem, SessionMemoryStore, SessionMemoryType enum (8 types: painReport, emotionalFlag, breakthrough, goalSet, ticObservation, caregiverNote, progressNote, contextNote)
- ADD: Services/CBITSessionStore.swift — per-child memory persistence (UserDefaults keyed by UUID), dedup, buildMemoryInjection() for system prompt, extractAndSaveMemories() async
- UPDATED: Services/ClaudeService.swift — buildSystemPrompt(for:memoryInjection:), sendMessage() accepts memoryInjection param, new extractSessionMemories() extraction call → JSON parse → SessionMemoryItems
- Files affected: Models/SessionMemory.swift (new), Services/CBITSessionStore.swift (new), Services/ClaudeService.swift

## 2026-03-24 — Expanded Family Onboarding (tb-mvp2-003, Dev2)
- ADD: Views/Onboarding/FamilyOnboardingView.swift — 6-step family onboarding, two paths (caregiver + self-setup), creates FamilyUnit on completion
  - Step 0: role selection, Step 1: about you, Step 2: about child/age, Step 3: device config, Step 4: treatment stage, Step 5: summary + create
- UPDATE: TicBuddyApp.swift — routes new installs to FamilyOnboardingView; V1 legacy users bypass via hasCompletedOnboarding flag
- Files affected: Views/Onboarding/FamilyOnboardingView.swift (new), TicBuddyApp.swift

## 2026-03-24 — Family Unit Model Extensions (tb-mvp2-001, Dev2)
- ADD: CBITSessionStage enum (8-session clinical protocol) in FamilyUnit.swift
- ADD: PracticeStatus enum (green/yellow/blank daily practice quality)
- ADD: SharedFamilyData struct (reward points, practice calendar, session stage — syncs across devices)
- ADD: TicHierarchyEntry struct (ordered tic treatment list with CR, urge, distress tracking)
- ADD: ChildProfile.sessionStage + ticHierarchy fields
- ADD: ChildProfile.currentTargetTic computed property
- ADD: FamilyUnit.sharedData (SharedFamilyData) field
- Files affected: TicBuddy/Models/FamilyUnit.swift

## 2026-03-24 — Family Unit Architecture (tb-mvp2-001)
- ADD: Models/FamilyUnit.swift — FamilyUnit, CaregiverProfile, ChildProfile, AgeGroup, DeviceConfig, CaregiverRelationship models
- ADD: Services/FamilyPINService.swift — PIN storage via Keychain + biometric auth (Face ID/Touch ID) for caregiver mode unlock
- UPDATED: Services/TicDataService.swift — family unit persistence, switchToChild/switchToCaregiverMode, per-child tic entry storage, backward-compatible with existing single-user data
- Files affected: Models/FamilyUnit.swift (new), Services/FamilyPINService.swift (new), Services/TicDataService.swift

## 2026-02-28 — For Adults/Caregivers Section
- ADD: CaregiversView.swift — 8-section caregiver resource hub (TS explainer, CBIT overview, medical disclaimer, therapist finder, school accommodations, teacher/coach tips, family support, TAA helpline)
- ADD: SettingsView — "Parents & Caregivers" section with NavigationLink to CaregiversView
- All links: TAA, CDC, NIMH, Mayo Clinic, JAMA research
- Files affected: TicBuddy/Views/Settings/CaregiversView.swift (new), TicBuddy/Views/Settings/SettingsView.swift

## 2026-02-25 08:30 — Onboarding Full Rebuild (Medusa/Dev3)
- ENHANCED: WelcomeStepView — 96px hero emoji, pulsing animation, larger type (48px title), feature cards in frosted panel
- ENHANCED: NameAgeStepView — 4-column age grid (8–15), manual stepper for edge ages, larger input field
- ENHANCED: Progress bar — pill-style capsule bar replaces dots, step counter label added
- ENHANCED: Dynamic gradient per step (unique color per screen)
- ENHANCED: Next button — shadow, spring animation, disabled state with opacity
- NEW: TicAwarenessScaleView — 1–5 emoji scale ("How often do you notice your tics?"), selection label, spring animation
- NEW: SectionHeader helper component (Motor Tics / Vocal Tics labels with subtitle)
- NEW: UserProfile.ticAwarenessLevel: Int = 3 (persisted, used by Claude for coaching calibration)
- FIXED: Next button disabled when no tics selected on step 5 (was only disabled on step 1)
- Files modified: Views/Onboarding/OnboardingView.swift, Models/UserProfile.swift

## 2026-02-25 08:00 — Onboarding Enrichment from RESEARCH.md (Dev3/Medusa)
- Enriched TourettesExplainView: added "wax and wane" card, improved premonitory urge explanation (normalized that some feel it less)
- Added famous-TS framing: "athletes, artists, musicians, and scientists"
- Enriched CBITExplainView: renamed "Step 1: Notice" → "Week 1: Detective Mode", added JAMA 2010 citation
- Enriched NeuroplasticityExplainView: replaced generic cards with Play-Doh Brain, Build New Trails, 8–12 Weeks to Rewire
- All new copy aligned with RESEARCH.md clinical language guidelines
- Files modified: Views/Onboarding/OnboardingView.swift

## 2026-02-25 07:30 — Security Hardening + Settings (Medusa/Dev2)
- FIXED: PII removed from Claude system prompt — name and age no longer sent to Anthropic API
- FIXED: Age-based tone adjustment computed locally, only tone description sent to API
- FIXED: Tic descriptions replaced with category-only ("motor and/or vocal") in API payload
- FIXED: Hardcoded "YOUR_API_KEY_HERE" fallback removed from ClaudeService.swift
- NEW: KeychainHelper.swift — secure Keychain read/write/delete for API key storage
- NEW: SettingsView.swift — SecureField for API key entry, saves to Keychain, masked display
- NEW: Settings tab added to MainTabView (5 tabs total)
- NEW: TicDataService.resetProgram() — clears entries + resets CBIT phase (Keychain key preserved)
- NEW: RESEARCH.md — 10KB, 263 lines, full clinical CBIT reference for dev team
- Files modified: ClaudeService.swift, TicDataService.swift, TicBuddyApp.swift, project.pbxproj
- Files created: Services/KeychainHelper.swift, Views/Settings/SettingsView.swift, RESEARCH.md

## 2026-02-25 07:00 — Phase 3: Extensions + Xcode Project File (Dev1)
- Added Extensions.swift: Color(hex:) initializer (required by all views), View.if() modifier, Date helpers
- Registered Extensions.swift in existing TicBuddy.xcodeproj/project.pbxproj
- Updated PROJECT_OVERVIEW.md with accurate file tree and security notes
- Project is now fully buildable in Xcode — open TicBuddy.xcodeproj, add ANTHROPIC_API_KEY to scheme env vars, build
- Files modified:
  - TicBuddy/Extensions.swift (NEW)
  - TicBuddy.xcodeproj/project.pbxproj (Extensions.swift registered)
  - PROJECT_OVERVIEW.md (accurate arch diagram + security section)
  - CHANGELOG.md

## 2026-02-25 06:30 — Phase 2: Competing Responses + Progress View (Dev1)
- Added full CBIT competing response library (8 motor + 6 vocal tic types)
- Added Progress tab: 7-day stacked bar chart, week summary banner, insights, competing response guide
- Wired CompetingResponseLibrary into ClaudeService system prompt (phase-aware)
- ClaudeService: buildCompetingResponseGuidance() pulls tic-specific kid-friendly tips per user's tics
- Security-hardened per Security bot: local-only storage, no analytics SDKs, API key via env var
- Files created/modified:
  - Models/CompetingResponses.swift (NEW — full CBIT library, Woods et al. 2008 protocol)
  - Views/Home/ProgressView.swift (NEW — full progress/insights view)
  - TicBuddyApp.swift (added Progress tab)
  - Services/ClaudeService.swift (competing response guidance wired in)

## 2026-02-25 00:00 — Initial Build (Dev1)
- Created full project scaffold from scratch
- Deep research: CBIT protocol, Tourette's tic types, premonitory urge, neuroplasticity, competing responses (sourced from TAA, NIH, PMC peer-reviewed studies)
- Files created:
  - TicBuddyApp.swift (main entry, routing, tab bar)
  - Models/TicEntry.swift (tic types, outcomes, DayLog)
  - Models/UserProfile.swift (CBIT phases, program progression)
  - Services/ClaudeService.swift (Anthropic API integration, system prompt, tic-log parsing)
  - Services/TicDataService.swift (UserDefaults persistence, CRUD, streak tracking)
  - ViewModels/ChatViewModel.swift (chat state, auto-log from chat)
  - Views/Onboarding/OnboardingView.swift (6-step onboarding with Tourette's/CBIT/neuroplasticity education)
  - Views/Chat/ChatView.swift (full chat UI, typing indicator, quick chips)
  - Views/Calendar/TicCalendarView.swift (monthly calendar, day detail, add tic sheet)
  - Views/Home/HomeView.swift (dashboard, stats, CBIT phase card, streak)
  - PROJECT_OVERVIEW.md

### Key Clinical Findings Incorporated
- Week 1 = awareness ONLY (no competing responses per CBIT protocol)
- Competing responses begin Week 2 only after premonitory urge awareness established
- Premonitory urge reliably detected in children 10+ (app accounts for this)
- Competing responses: isometric tension opposing tic direction (tic-specific)
- Standard CBIT: 8 sessions over 10 weeks + 3 monthly boosters
- Metrics: frequency, urge strength (1-10), redirect success rate
