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
