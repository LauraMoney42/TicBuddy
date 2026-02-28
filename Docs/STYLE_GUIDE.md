# TicBuddy Style Guide

**Document:** Visual Design System — Extracted from Source
**Date:** 2026-02-28
**Version:** 1.0
**Source:** Extracted from existing SwiftUI codebase

---

## Brand Identity

TicBuddy is warm, encouraging, and kid-friendly without being childish. The visual language uses vibrant gradients, rounded corners, and soft shadows to feel modern and approachable for ages 8–16 and their caregivers.

**Design principles:**
- **Warm, not clinical** — No sterile whites or medical blues
- **Energetic, not overwhelming** — Gradients add life without being garish
- **Accessible** — High contrast text, large tap targets
- **Inclusive** — Works for the child AND their parents

---

## Color Palette

### Primary Brand Colors

| Name | Hex | Usage |
|------|-----|-------|
| **Periwinkle Blue** | `#667EEA` | Primary accent, buttons, tint, headers |
| **Soft Purple** | `#764BA2` | Gradient end, secondary accent |

**Primary Gradient:**
```swift
LinearGradient(
    colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
```
Used on: CTA buttons, nav headers, selected states, chat bubbles (outgoing)

---

### Onboarding Gradient Sequence

Each onboarding screen uses a unique gradient:

| Screen | Start | End | Mood |
|--------|-------|-----|------|
| Welcome (WelcomeKindness) | `#00D4E8` | `#006E8C` | Teal — calm, welcoming |
| Screen 0 | `#667EEA` | `#764BA2` | Purple — energetic |
| Screen 1 | `#F093FB` | `#764BA2` | Pink/Purple — playful |
| Screen 2 | `#4FACFE` | `#00F2FE` | Sky Blue — light, airy |
| Screen 3 | `#43E97B` | `#38F9D7` | Green/Teal — positive |
| Screen 4 | `#FA709A` | `#FEE140` | Pink/Yellow — warm, fun |
| Screen 5 | `#667EEA` | `#764BA2` | Purple — closing loop |

---

### Semantic Colors

| Name | Value | Usage |
|------|-------|-------|
| **High Tic Day** | `.orange.opacity(0.6)` | Calendar dots, bar chart |
| **Medium Tic Day** | `.yellow` | Calendar dots, bar chart |
| **Low Tic Day** | `.green` | Calendar dots, bar chart |
| **Medical Disclaimer** | `.orange` | Disclaimer borders + icons |
| **Disclaimer Background** | `Color.orange.opacity(0.08)` | Disclaimer card fill |
| **Card Background** | `Color(.systemBackground)` | White cards |
| **Page Background** | `Color(.systemGroupedBackground)` | List/grouped views |
| **External Links** | `.accentColor` → `#667EEA` | Tappable links in Caregivers |

---

### Opacity Scale

| Use | Opacity |
|-----|---------|
| Shadow (primary) | `0.35` |
| Shadow (subtle) | `0.05` |
| Tinted background | `0.08 – 0.10` |
| Border/stroke | `0.20 – 0.30` |
| Muted text | `0.80 – 0.85` |

---

## Typography

All typography uses San Francisco (system font). Design uses `.rounded` design variant for friendly numerics.

| Style | SwiftUI | Use |
|-------|---------|-----|
| **Large Title** | `.largeTitle` | Screen titles |
| **Title 2** | `.title2` | Section headers |
| **Headline** | `.headline` | Card headers, emphasis |
| **Subheadline** | `.subheadline` | Body copy |
| **Body** | `.body` | Default text |
| **Caption** | `.caption` | Labels, metadata |
| **Caption 2** | `.caption2.bold()` | Chart labels |
| **Rounded Numeric** | `.system(size: 24, weight: .bold, design: .rounded)` | Stats, counters |

---

## Spacing & Layout

### Corner Radius

| Component | Radius |
|-----------|--------|
| Cards (large) | `20` |
| Cards (standard) | `18` |
| Buttons (primary) | `16` |
| Chips / tags | `12` |
| Small elements | `4 – 8` |
| Chat bubbles | `20` |

### Padding

| Context | Value |
|---------|-------|
| Horizontal page margin | `16` |
| Card internal padding | `14 – 18` |
| Top spacing | `8 – 16` |

### Shadows

```swift
// Primary card shadow
.shadow(color: Color(hex: "667EEA").opacity(0.35), radius: 10, y: 4)

// Subtle card shadow
.shadow(color: .black.opacity(0.05), radius: 8, y: 2)
```

---

## Component Patterns

### Primary CTA Button
```swift
LinearGradient(colors: [Color(hex: "667EEA"), Color(hex: "764BA2")],
               startPoint: .leading, endPoint: .trailing)
    .cornerRadius(16)
    .shadow(color: Color(hex: "667EEA").opacity(0.4), radius: 8, y: 4)
```

### Card
```swift
.background(Color(.systemBackground))
.cornerRadius(18)
.shadow(color: .black.opacity(0.05), radius: 8, y: 2)
.padding(.horizontal, 16)
```

### Tinted Background Card (accent)
```swift
.background(Color(hex: "667EEA").opacity(0.08))
.cornerRadius(18)
.overlay(RoundedRectangle(cornerRadius: 18)
    .stroke(Color(hex: "667EEA").opacity(0.2), lineWidth: 1))
```

### Medical Disclaimer Card
```swift
.padding(14)
.background(Color.orange.opacity(0.08))
.cornerRadius(12)
.overlay(RoundedRectangle(cornerRadius: 12)
    .stroke(Color.orange.opacity(0.25), lineWidth: 1))
```

---

## App Icon

- **Design:** Tourette syndrome ribbon motif, kid-friendly, emoji-adjacent
- **Colors:** Teal gradient matching WelcomeKindnessView (`#00D4E8` → `#006E8C`)
- **File:** `TicBuddy/Assets.xcassets/AppIcon.appiconset/AppIcon.png`
- **Size:** 1024×1024 source, auto-scaled by Xcode

---

## Voice & Tone

| Context | Tone | Example |
|---------|------|---------|
| Onboarding | Warm, welcoming | "You're not alone. Lots of kids have tics." |
| Tic logging | Casual, low-pressure | "How were your tics today? 🟢 Easy 🟡 Noticed 🔴 Rough" |
| AI Chat | Friendly, age-appropriate | "Stress can make tics happen more — that's totally normal!" |
| Caregivers | Informative, empathetic | "You're doing great by looking for resources." |
| Errors | Gentle, reassuring | "Something went wrong. Try again in a moment!" |

**Avoid:** Medical jargon without explanation, clinical tone, alarming language, anything that feels like a doctor's office.

---

## Accessibility

- Minimum tap target: 44×44pt
- All text meets WCAG AA contrast on their respective backgrounds
- VoiceOver labels on all interactive elements
- Dynamic Type supported (system fonts scale automatically)
- No color-only indicators — always paired with text or icon

---

*Style guide extracted from source code — 2026-02-28. Update when visual design changes.*
