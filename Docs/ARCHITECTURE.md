# TicBuddy Architecture

**Document:** Technical Architecture Overview
**Date:** 2026-02-28
**Version:** 1.0

---

## Overview

TicBuddy is a native iOS app built with SwiftUI. It follows the MVVM pattern with a service layer for persistence and API calls. The app is fully client-side for MVP1 — no custom backend. Claude AI is accessed via a proxy server (TicBuddyProxy) to keep the API key off the device.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        iOS App (SwiftUI)                         │
│                                                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌──────────────────────────┐ │
│  │  Onboarding │  │  Main App   │  │       Settings           │ │
│  │   Flow      │  │  (TabView)  │  │  SettingsView            │ │
│  │             │  │             │  │  CaregiversView           │ │
│  │ WelcomeKind │  │ HomeView    │  └──────────────────────────┘ │
│  │ OnboardingV │  │ ProgressV   │                               │
│  └─────────────┘  │ ChatView    │                               │
│                   │ TicCalendarV│                               │
│                   └──────┬──────┘                               │
│                          │                                      │
│            ┌─────────────┴──────────────┐                       │
│            │         ViewModels          │                       │
│            │  ChatViewModel              │                       │
│            └─────────────┬──────────────┘                       │
│                          │                                      │
│            ┌─────────────┴──────────────┐                       │
│            │          Services           │                       │
│            │  TicDataService (local)     │                       │
│            │  ClaudeService (API)        │                       │
│            │  KeychainHelper             │                       │
│            └─────────────┬──────────────┘                       │
│                          │                                      │
│            ┌─────────────┴──────────────┐                       │
│            │          Models             │                       │
│            │  TicEntry                   │                       │
│            │  UserProfile                │                       │
│            │  CompetingResponses         │                       │
│            └─────────────────────────────                       │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TicBuddyProxy Server                          │
│                  (Railway / Cloud-hosted)                        │
│                                                                  │
│  Express.js proxy — receives requests from app,                  │
│  attaches Anthropic API key, forwards to Claude API              │
│                                                                  │
└─────────────────────────────┬───────────────────────────────────┘
                              │ HTTPS
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Anthropic Claude API                          │
│                  (claude-3-5-sonnet or haiku)                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Layer Breakdown

### Views (SwiftUI)

| View | Location | Purpose |
|------|----------|---------|
| `TicBuddyApp` | `TicBuddyApp.swift` | App entry, tab bar, onboarding gating |
| `HomeView` | `Views/Home/HomeView.swift` | Dashboard — today's summary, quick log |
| `ProgressView` | `Views/Home/ProgressView.swift` | Charts, stats, competing responses |
| `TicCalendarView` | `Views/Calendar/TicCalendarView.swift` | Monthly calendar with tic dots |
| `ChatView` | `Views/Chat/ChatView.swift` | AI chat interface |
| `OnboardingView` | `Views/Onboarding/OnboardingView.swift` | Multi-screen onboarding flow |
| `WelcomeKindnessView` | `Views/Onboarding/WelcomeKindnessView.swift` | First welcome screen |
| `SettingsView` | `Views/Settings/SettingsView.swift` | Profile, feedback, nav |
| `CaregiversView` | `Views/Settings/CaregiversView.swift` | Adult/caregiver resources |

### ViewModels

| ViewModel | Purpose |
|-----------|---------|
| `ChatViewModel` | Manages chat state, message history, Claude API calls |

### Services

| Service | Purpose |
|---------|---------|
| `TicDataService` | Local persistence of tic entries (UserDefaults / Core Data) |
| `ClaudeService` | HTTP client for TicBuddyProxy → Claude API |
| `KeychainHelper` | Secure storage for any sensitive values |

### Models

| Model | Purpose |
|-------|---------|
| `TicEntry` | Single tic log entry: date, type, severity, notes |
| `UserProfile` | Child's name, age, primary tic types |
| `CompetingResponses` | CBIT competing response definitions per tic type |

---

## Data Flow

### Tic Logging Flow
```
User taps "Log Tic"
  → HomeView captures: tic type + severity
  → TicDataService.save(TicEntry)
  → Persisted to local storage
  → ProgressView / Calendar re-renders via @Published / ObservableObject
```

### AI Chat Flow
```
User types message
  → ChatViewModel.send(message)
  → ClaudeService.complete(prompt)
  → HTTPS POST to TicBuddyProxy
  → Proxy adds API key + forwards to Anthropic
  → Response streams back
  → ChatViewModel updates messages array
  → ChatView re-renders
```

### Onboarding Flow
```
App launch → check UserDefaults "hasCompletedOnboarding"
  → false: show OnboardingView (fullscreen)
    → User completes flow → UserProfile saved → flag set
  → true: show MainTabView directly
  → "View Onboarding Again" in Settings resets flag + presents fullScreenCover
```

---

## API: TicBuddyProxy

The app never holds the Anthropic API key. All Claude requests go through a lightweight Express proxy.

**Endpoint:** `POST /api/chat`

**Request:**
```json
{
  "messages": [
    { "role": "user", "content": "Why do I tic more at school?" }
  ],
  "system": "You are TicBuddy, a friendly CBIT assistant for children with Tourette Syndrome..."
}
```

**Response:** Claude API response (streamed or complete)

**Security:**
- API key lives only on the server (Railway env var)
- CORS restricted to TicBuddy app bundle ID (future)
- Rate limiting to prevent abuse

---

## Local Data Storage

For MVP1, tic data is stored locally on device:

| Data | Storage | Notes |
|------|---------|-------|
| Tic entries | UserDefaults / JSON | Encoded `[TicEntry]` array |
| User profile | UserDefaults | Encoded `UserProfile` |
| Onboarding completed | UserDefaults | Bool flag |
| API config | App bundle / env | Proxy URL only |

**Future:** iCloud sync via CloudKit (post-MVP1)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Minimum iOS | iOS 17.0 |
| Target Devices | iPhone (iPad future) |
| AI | Anthropic Claude (via proxy) |
| Proxy | Express.js on Railway |
| Charts | SwiftUI Charts (native) |
| Persistence | UserDefaults (MVP1) → CloudKit (future) |
| Project Config | XcodeGen (`project.yml`) |

---

## File Structure

```
TicBuddy/
├── Docs/                           ← Project documentation
│   ├── ARCHITECTURE.md             ← This file
│   ├── MVP1_PLAN.md
│   ├── STYLE_GUIDE.md
│   └── USER_STORY.md
├── TicBuddy.xcodeproj/
├── TicBuddy/
│   ├── TicBuddyApp.swift           ← App entry + tab bar
│   ├── Info.plist
│   ├── Extensions.swift            ← Color(hex:) and utilities
│   ├── Assets.xcassets/
│   │   ├── AppIcon.appiconset/
│   │   └── AccentColor.colorset/
│   ├── Models/
│   │   ├── TicEntry.swift
│   │   ├── UserProfile.swift
│   │   └── CompetingResponses.swift
│   ├── Services/
│   │   ├── TicDataService.swift
│   │   ├── ClaudeService.swift
│   │   └── KeychainHelper.swift
│   ├── ViewModels/
│   │   └── ChatViewModel.swift
│   └── Views/
│       ├── Home/
│       │   ├── HomeView.swift
│       │   └── ProgressView.swift
│       ├── Calendar/
│       │   └── TicCalendarView.swift
│       ├── Chat/
│       │   └── ChatView.swift
│       ├── Onboarding/
│       │   ├── OnboardingView.swift
│       │   └── WelcomeKindnessView.swift
│       └── Settings/
│           ├── SettingsView.swift
│           └── CaregiversView.swift
├── project.yml                     ← XcodeGen config
└── ticbuddy-icon.svg               ← Source icon
```

---

*Architecture document — 2026-02-28. Update as the system evolves.*
