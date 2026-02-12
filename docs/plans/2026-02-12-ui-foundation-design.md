# UI Foundation Overhaul — Design Document

**Date:** 2026-02-12
**Approach:** Evolutionary Upgrade (extend existing DesignSystem + ModernComponents)
**Direction:** Dark-first, bold athletic aesthetic
**Accent:** Emerald (#00E676) + Gold (#FFD740)

---

## 1. Color System — Dark-First Athletic Palette

### Background Layers

| Token | Dark | Light |
|-------|------|-------|
| `surfaceBase` | #0A0A0C | #F5F5F7 |
| `surfaceRaised` | #161618 | #FFFFFF |
| `surfaceOverlay` | #1E1E22 | #F0F0F2 |
| `surfaceHighlight` | #2A2A30 | #E8E8EC |

### Accent Palette — Emerald + Gold

- Primary: #00E676 (bright emerald)
- Secondary: #FFD740 (gold)
- Text on accent: #0A0A0C (dark text on bright fills)

### Semantic Colors

- Success: Primary accent (emerald)
- Error: #FF3B5C
- Warning: #FFAB40
- Info: Secondary accent (gold)

### Gradients

- Athletic gradient: emerald → gold at 135deg
- Glow gradient: emerald at 20% opacity radial behind key elements
- Surface gradient: surfaceBase → surfaceRaised subtle vertical

### Text Colors (Dark)

| Token | Value |
|-------|-------|
| `textPrimary` | #FFFFFF at 95% opacity |
| `textSecondary` | #FFFFFF at 60% opacity |
| `textTertiary` | #FFFFFF at 38% opacity |
| `textOnAccent` | #0A0A0C |

---

## 2. Typography System

Rounded design for headlines (athletic feel). `@ScaledMetric` Dynamic Type on all tokens.

| Token | Size | Weight | Design | Use |
|-------|------|--------|--------|-----|
| `displayLarge` | 48 | .black | .rounded | Hero numbers |
| `displayMedium` | 36 | .bold | .rounded | Section heroes |
| `displaySmall` | 28 | .bold | .rounded | Card headlines |
| `headlineLarge` | 24 | .bold | .rounded | Screen titles |
| `headlineMedium` | 20 | .semibold | .rounded | Section headers |
| `headlineSmall` | 17 | .semibold | .default | Subsection headers |
| `bodyLarge` | 17 | .regular | .default | Primary body |
| `bodyMedium` | 15 | .regular | .default | Secondary body |
| `bodySmall` | 13 | .regular | .default | Captions |
| `labelLarge` | 15 | .semibold | .default | Button text |
| `labelMedium` | 13 | .medium | .default | Tags, chips |
| `labelSmall` | 11 | .medium | .default | Tab labels |
| `numberLarge` | 36 | .bold | .monospaced | Stat numbers |
| `numberMedium` | 24 | .bold | .monospaced | Card stats |
| `numberSmall` | 17 | .semibold | .monospaced | Inline numbers |

---

## 3. Component Library Upgrades

### ModernCard
- Background: `surfaceRaised` + 1pt border (white 6% opacity)
- Optional accent edge (3pt left/top border in emerald/gold)
- Shadow replaced with inner glow on dark (emerald 0.06 opacity, 16pt blur)
- Press: scale 0.97 + surfaceHighlight + light haptic

### ModernButton
- Primary: solid emerald → dark text. Press: desaturated + scale 0.95 + medium haptic
- Secondary: transparent + 1.5pt emerald border. Press: emerald 12% fill + light haptic
- Ghost: no border. Press: surfaceHighlight + light haptic
- Danger: #FF3B5C → white text
- New "Accent": gold fill → dark text (rewards, special actions)
- All: subtle gradient sheen (5% white top-to-bottom)
- Corner radius: 12pt standard, pill variant optional

### ModernTextField
- Background: surfaceHighlight
- Border: 1pt white 10%, 2pt emerald on focus
- Floating label on focus with spring animation

### StatCard
- Number: displaySmall .rounded
- Icon: circle with emerald/gold glow (8% opacity)
- Optional sparkline slot
- Accent edge on left border

### ProgressRing
- Track: white 8% opacity
- Fill: animated emerald→gold gradient
- Glow behind fill endpoint
- Counting animation on center number

### New: GlowBadge
- Pill shape, color fill + outer glow
- Subtle pulse on first appearance
- For achievements, level indicators, rarity tags

### New: ActionChip
- Replaces CompactActionButton
- Rounded rect, icon + label, tinted 10% background
- Press: 20% fill + scale + haptic

### AnimatedTabBar
- Selected: emerald capsule glow
- Icon: .fill variant with symbolEffect transition
- Haptic on every tab change
- Badge: pulsing gold dot

### ModernSegmentControl
- Selected: emerald fill + matchedGeometry (keep)
- Unselected: surfaceHighlight
- Haptic (selection) on change

---

## 4. Transition System

7 signature transitions as ViewModifiers with auto-haptics and reduceMotion support.

### 4.1 Hero Transition
- matchedGeometryEffect: position, size, corner radius
- Spring: response 0.5, damping 0.82
- Haptic: medium launch, soft settle
- Use: card → detail view

### 4.2 Stagger Reveal
- Items: slide up 20pt + fade in, 0.04s delay per item
- Spring: response 0.45, damping 0.85
- Haptic: none
- Use: lists, grids, dashboard sections

### 4.3 Sheet Rise
- Slide up + scale 0.95→1.0, background dims
- surfaceOverlay background, 24pt top corners
- Drag-to-dismiss with velocity detection
- Haptic: soft present, light dismiss

### 4.4 Pulse Expand
- Scale 0.8→1.0 + glow ring ripple outward
- Haptic: rigid impact
- Use: achievement unlock, XP gain, level up

### 4.5 Tab Morph
- Directional slide (left/right by tab delta)
- Outgoing: fade 60% + slide 30pt
- Incoming: from 30pt + fade in
- Haptic: light impact

### 4.6 Card Flip
- 3D Y-axis rotation 0→180deg
- Front/back separate views
- Haptic: medium at 90deg midpoint
- Use: achievement cards, stat comparisons

### 4.7 Countdown Burst
- Number: scale 1.0→1.3 + fade, next scales in from 0.7
- Ring constricts, final "GO" gets pulse expand
- Haptic: tick per number, heavy on GO

### Implementation

```
TransitionSystem.swift
├── .staggerReveal(index:)
├── .heroSource(id:namespace:)
├── .heroDestination(id:namespace:)
├── .pulseExpand(trigger:)
├── .sheetRise()
├── .cardFlip(isFlipped:)
├── .countdownBurst(value:)
├── Environment: \.heroNamespace
└── HapticTransition: auto-fires paired haptics
```

All transitions check `@Environment(\.accessibilityReduceMotion)` and degrade to simple fades.

---

## 5. Accessibility Infrastructure

### VoiceOver — `.a11y()` Modifier

```swift
.a11y(label: "Start training session", hint: "Begins your workout", trait: .isButton)
```

Bundles `accessibilityLabel`, `accessibilityHint`, `accessibilityAddTraits`.

**Label conventions:**
- Buttons: verb + object
- Stats: value + context
- Cards: summary
- Progress: current + total

### Dynamic Type

All typography tokens use `@ScaledMetric`:
- Display/headline: anchored to `.title` (capped scaling)
- Body: anchored to `.body` (full scaling)
- Labels: anchored to `.caption` (full scaling)
- `minimumScaleFactor(0.7)` on tight layouts

### Reduce Motion

Every transition checks `accessibilityReduceMotion`:
- Stagger → instant fade
- Hero → crossfade
- Pulse → opacity only
- Tab morph → instant swap
- Haptics still fire

---

## 6. Haptic Integration

### Component Auto-Haptics

| Component | Haptic |
|-----------|--------|
| ModernButton (primary) | Medium impact |
| ModernButton (secondary/ghost) | Selection feedback |
| ModernCard (tappable) | Light impact |
| AnimatedTabBar | Light impact + prepare() |
| ModernSegmentControl | Selection feedback |
| PillSelector | Selection feedback |
| ProgressRing (100%) | Success notification |

### Transition Auto-Haptics

| Transition | Haptic | Timing |
|------------|--------|--------|
| Hero | Medium + soft | 0ms, ~400ms |
| Stagger | None | — |
| Sheet Rise | Soft + light | present, dismiss |
| Pulse Expand | Rigid | 0ms |
| Tab Morph | Light | 0ms |
| Card Flip | Medium | ~250ms |
| Countdown | Tick + heavy | per-number, final |

### Haptic Budget

- Always: buttons, tabs, completions, achievements, errors
- Sometimes: card taps, segments, sheets
- Never: scrolling, passive state, stagger, loading

---

## 7. File Architecture

| File | Action | Contents |
|------|--------|----------|
| `DesignSystem.swift` | Modify | Dark-first colors, rounded typography, @ScaledMetric, new gradients/glows |
| `ModernComponents.swift` | Modify | Upgraded aesthetics, accent edges, glow effects, auto-haptics |
| `TransitionSystem.swift` | New | 7 transition ViewModifiers, haptic timing, reduceMotion |
| `AccessibilityModifiers.swift` | New | .a11y() modifier, Dynamic Type helpers |
| `HapticManager.swift` | Minor modify | prepareForTransition() method |

### Rollout After Foundation

1. **Phase A — Core loop:** Dashboard, TrainHub, ActiveTraining, ExerciseLibrary, ActivePlan (~12 views)
2. **Phase B — First impressions:** Auth, Onboarding, Profile, Avatar (~8 views)
3. **Phase C — Everything else:** Matches, Settings, Community, all detail views (~35 views)

Each phase independently shippable.
