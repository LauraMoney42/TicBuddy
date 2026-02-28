# TicBuddy MVP1 Plan

**Document:** MVP1 Feature Scope & Task Breakdown
**Date:** 2026-02-28
**Timeline:** 1 month
**Version:** 1.0

---

## MVP1 Goal

Ship a functional, polished iOS app that helps children with Tourette Syndrome track tics, learn CBIT basics via AI chat, and gives caregivers trusted resources — all within a warm, kid-friendly experience.

**Launch criteria:** App builds on device, all 5 feature areas functional, no crashes on core flows.

---

## Feature Areas

### 1. Tic Tracking + Calendar
**Status:** In Progress (core model exists)

| Task | Owner | Status |
|------|-------|--------|
| TicEntry model with date, type, severity | Dev | ✅ Done |
| TicDataService (local persistence) | Dev | ✅ Done |
| Log tic UI (quick entry: tic type + severity) | Dev | 🔄 In Progress |
| Calendar view (monthly, color-coded by severity) | Dev | 🔄 In Progress |
| Tic detail / history list view | Dev | 🔲 Pending |
| Tic type management (add/remove custom tics) | Dev | 🔲 Pending |

**Acceptance criteria:**
- Child can log a tic in under 10 seconds
- Calendar shows color-coded severity dots by day
- History shows last 30 days of entries

---

### 2. AI Chat (CBIT Support)
**Status:** In Progress (ClaudeService exists)

| Task | Owner | Status |
|------|-------|--------|
| ClaudeService integration (API calls) | Dev | ✅ Done |
| ChatView UI (message bubbles, input) | Dev | ✅ Done |
| CBIT-aware system prompt for Claude | Dev | 🔲 Pending |
| Age-appropriate response filtering | Dev | 🔲 Pending |
| Competing response suggestions | Dev | 🔲 Pending |
| "Not medical advice" disclaimer on first open | Dev | 🔲 Pending |
| Offline graceful degradation message | Dev | 🔲 Pending |

**Acceptance criteria:**
- Child can ask "why do I tic?" and get a clear, age-appropriate response
- Claude suggests at least one competing response per tic type discussed
- Medical disclaimer shown on first chat open

---

### 3. Onboarding Flow
**Status:** In Progress (views exist)

| Task | Owner | Status |
|------|-------|--------|
| Welcome screens (WelcomeKindnessView + flow) | Dev | ✅ Done |
| User profile setup (name, age, primary tic) | Dev | ✅ Done |
| CBIT explainer screen | Dev | 🔲 Pending |
| Tic type selection on first launch | Dev | 🔲 Pending |
| "View Onboarding Again" in Settings | Dev | ✅ Done |
| Skip onboarding option | Dev | 🔲 Pending |

**Acceptance criteria:**
- New user completes onboarding in under 3 minutes
- Onboarding can be re-viewed from Settings
- Profile data persists across app launches

---

### 4. For Adults/Caregivers
**Status:** In Progress (CaregiversView exists)

| Task | Owner | Status |
|------|-------|--------|
| CaregiversView base structure | Dev | ✅ Done |
| What is Tourette Syndrome section | Dev | 🔲 Pending |
| How CBIT Works section | Dev | 🔲 Pending |
| Medical disclaimer | Dev | 🔲 Pending |
| Find a CBIT Therapist link (TAA directory) | Dev | 🔲 Pending |
| School accommodations section (504/IEP) | Dev | 🔲 Pending |
| Talking to teachers & coaches section | Dev | 🔲 Pending |
| Family & sibling support resources | Dev | 🔲 Pending |
| TAA helpline link | Dev | 🔲 Pending |
| Credible external links (CDC, NIMH, Mayo) | Dev | 🔲 Pending |

**Acceptance criteria:**
- All sections render with real content
- All external links open in Safari
- Medical disclaimer visible on section entry

---

### 5. Settings
**Status:** In Progress (SettingsView exists)

| Task | Owner | Status |
|------|-------|--------|
| Profile editing (name, age) | Dev | ✅ Done |
| Report a bug / feature request (mailto) | Dev | ✅ Done |
| View Onboarding Again | Dev | ✅ Done |
| Remove API key input (server-side key) | Dev | 🔲 Pending |
| Notification preferences (future) | Dev | 🔲 Stretch |

**Acceptance criteria:**
- Bug report opens Mail with pre-filled recipient
- Onboarding re-launches correctly from Settings
- No API key input visible to user

---

## App Icon & Assets
| Task | Status |
|------|--------|
| App icon (TicBuddy ribbon design) | ✅ Done |
| Welcome screen hero icon | 🔲 Pending |
| Tic type icons | 🔲 Pending |

---

## Timeline (1 Month)

| Week | Focus |
|------|-------|
| **Week 1** | Polish existing views, complete onboarding flow, CBIT system prompt |
| **Week 2** | CaregiversView full content, school accommodations, all links |
| **Week 3** | Tic tracking polish, calendar view, history list |
| **Week 4** | QA, bug fixes, App Store prep, TestFlight build |

---

## Out of Scope for MVP1
- Push notifications / reminders
- iCloud sync
- Multiple user profiles
- Android / web versions
- Social features
- In-app purchases

---

## Definition of Done
- [ ] Builds without warnings on Xcode latest
- [ ] Runs on iPhone 14+ (iOS 17+)
- [ ] All 5 feature areas functional
- [ ] No crashes on core flows (onboarding, logging, chat)
- [ ] App Store screenshots ready
- [ ] Privacy Policy URL ready
- [ ] TestFlight build submitted
