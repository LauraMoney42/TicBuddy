# TicBuddy — CBIT Tic Management App

## What It Is
A friendly, child-accessible iOS app helping people with Tourette Syndrome manage tics using CBIT (Comprehensive Behavioral Intervention for Tics). Designed to be understood by a 3rd grader.

## Core MVP1 Features
1. **Onboarding** — Simple questions about the user and their tics. Explains Tourette's, CBIT, and neuroplasticity in kid-friendly language.
2. **Chat Buddy** — Claude-powered chatbot that guides users through their CBIT journey, logs tics via conversation.
3. **Tic Calendar** — Daily/weekly calendar to log tics: type, count, "caught it?" / "redirected it?"
4. **Weekly Program** — Week 1: just notice. Week 2+: start competing responses. Clinically-guided progression.

## Tech Stack
- **iOS**: SwiftUI (iPhone first)
- **AI**: Anthropic Claude API (claude-3-5-haiku for chat — fast + affordable)
- **Storage**: UserDefaults + Core Data for tic logs
- **Architecture**: MVVM

## CBIT Protocol (Research-Based)
- **Week 1**: Awareness only — notice the premonitory urge, log the tic, no redirection yet
- **Week 2-3**: Introduce competing responses — isometric muscle tension opposing the tic
- **Week 4+**: Function-based interventions, relaxation training

## Tic Types Tracked
- Motor: Simple (eye blink, head jerk) / Complex (touching, jumping)
- Vocal: Simple (throat clearing, sniffing) / Complex (words, phrases)

## Key Metrics
- Tic frequency per day
- Tic types
- "Caught it" (noticed premonitory urge)
- "Redirected it" (successful competing response)
- Streak tracking

## Architecture
```
TicBuddy/
├── TicBuddyApp.swift          — @main entry, tab routing, onboarding gate
├── Extensions.swift           — Color(hex:), View.if(), Date helpers
├── Models/
│   ├── TicEntry.swift         — TicMotorType, TicVocalType, TicOutcome, TicEntry, DayLog
│   ├── UserProfile.swift      — CBITPhase enum, UserProfile, auto-phase-advance logic
│   └── CompetingResponses.swift — Full CBIT competing response library (Woods et al.)
├── Services/
│   ├── ClaudeService.swift    — Anthropic API, phase-aware system prompt, [LOG_TIC:] parsing
│   └── TicDataService.swift   — UserDefaults persistence, CRUD, streak tracking
├── ViewModels/
│   └── ChatViewModel.swift    — Chat state, auto-log from Claude responses
└── Views/
    ├── Onboarding/OnboardingView.swift — 6-step flow (welcome→name→TS explainer→CBIT→neuro→tic setup)
    ├── Chat/ChatView.swift     — Chat bubbles, typing indicator, quick-reply chips
    ├── Calendar/TicCalendarView.swift — Monthly grid, day detail, add-tic sheet
    └── Home/
        ├── HomeView.swift      — Dashboard: greeting, CBIT phase card, today stats, quick log, streak
        └── ProgressView.swift  — 7-day stacked bar chart, insights, competing response guide
```

## Security (per Security bot review)
- **Local-first**: All data in UserDefaults (no cloud, no third-party analytics)
- **Anonymized AI calls**: System prompt uses tic types only, never PII
- **API key**: Loaded from environment variable `ANTHROPIC_API_KEY` (not hardcoded)
- **No tracking SDKs**: Firebase/Mixpanel explicitly excluded
- **COPPA-aware**: No behavioral tracking, no ads

## MVP2 (Future)
- Voice chat (speech-to-text + TTS)
- Android

## MVP3
- Web version
- Android
