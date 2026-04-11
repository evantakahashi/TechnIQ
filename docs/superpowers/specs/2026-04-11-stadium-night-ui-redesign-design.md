# Stadium Night UI Redesign — Design Spec

**Date:** 2026-04-11
**Status:** Draft
**Scope:** Visual redesign of TechnIQ iOS app. Features, navigation, and business logic unchanged.

## Problem

The current TechnIQ UI is polished but visually generic — emerald green + gold + glow effects + glass morphism read as "fintech gamification" rather than a soccer training app. It does not feel distinctly athletic or sport-specific.

## Goals

- Make the app unmistakably feel like a soccer training app at first glance.
- Evoke a premium athletic catalog aesthetic (Nike Training Club / Adidas Running direction) rather than generic dark-mode gamification.
- Preserve every existing feature, screen, and navigation structure.
- Centralize changes in `DesignSystem.swift` and `ModernComponents.swift` so most of the 55+ views pick up the redesign automatically.

## Non-Goals

- No feature additions or removals.
- No changes to Core Data, services, Firebase, or any business logic.
- No custom fonts that require licensing — use SF Pro variants only.
- No light mode. Dark-only.
- No complex custom illustrations (jersey numbers as backgrounds, tactical arrow shapes, etc.).
- No mascot. The existing Kicko mascot system is removed entirely in this redesign.

## Direction: "Stadium Night"

A premium, floodlit-training-facility aesthetic. Hard edges, chalk lines, massive condensed typography, one high-energy accent color. Reads as athletic catalog, not gamification dashboard.

### Palette

| Token | Hex | Use |
|---|---|---|
| `surfaceBase` | `#0D0F0E` | App background (near-black with green undertone) |
| `surfaceRaised` | `#151917` | Cards |
| `surfaceOverlay` | `#1E2320` | Modals, raised sheets |
| `surfaceHighlight` | `#2A2F2C` | Hover/pressed states, divider fills |
| `accentLime` | `#CCFF00` | Primary CTA, hero highlights, progress fills |
| `accentLimeDim` | `#8FB300` | Pressed state for lime |
| `bloodOrange` | `#FF4B1F` | Streaks, alerts, error, fire moments |
| `chalkWhite` | `#F2F0E6` | Primary text, pitch-line dividers |
| `mutedIvory` | `#A8A59A` | Secondary text |
| `dimIvory` | `#6B6962` | Tertiary text, disabled |

**Removed from the palette entirely:** emerald green (`primaryGreen`), gold (`accentGold`), purple (`levelPurple`), pink/red alerts — consolidated into blood orange.

**Rarity colors** (for shop items) stay as-is since they're a game convention players recognize.

### Typography

Use SF Pro with condensed/compressed widths and heavy weights to get a Nike-catalog feel without custom font licensing.

| Token | Size | Weight | Width | Case | Use |
|---|---|---|---|---|---|
| `heroDisplay` | 72pt | `.black` | `.compressed` | UPPERCASE | Hero numbers (XP, level, stats) |
| `displayLarge` | 56pt | `.black` | `.compressed` | UPPERCASE | Screen titles on hero surfaces |
| `displayMedium` | 42pt | `.heavy` | `.compressed` | UPPERCASE | Section headers |
| `displaySmall` | 32pt | `.heavy` | `.compressed` | UPPERCASE | Card titles on hero cards |
| `headlineLarge` | 24pt | `.bold` | default | Sentence | Subheads |
| `headlineMedium` | 20pt | `.semibold` | default | Sentence | Card titles |
| `titleMedium` | 16pt | `.semibold` | default | Sentence | Inline titles |
| `bodyLarge` | 17pt | `.regular` | default | Sentence | Body copy |
| `bodyMedium` | 15pt | `.regular` | default | Sentence | Secondary copy |
| `label` | 12pt | `.heavy` | `.compressed` | UPPERCASE | Button labels, tags, metadata |
| `numberMono` | 36pt | `.black` | monospaced | — | Stat values where alignment matters |

Italic variants (`.italic()`) are allowed on display sizes for high-energy moments (streak counts, celebration screens).

### Motifs (kept deliberately simple)

1. **Pitch-line dividers** — 1pt `chalkWhite` lines at 40% opacity replace the current subtle border separators. Used between sections, between card rows, and under screen titles.
2. **Turf grain** — a very subtle monochrome noise overlay on `surfaceBase` at 4–6% opacity. Implemented once as a `ZStack` background layer at the root.
3. **Corner bracket** — an optional thin chalk-white L-bracket in one corner of hero cards, reminiscent of a pitch corner arc. Implemented as a `Shape` in `ModernComponents.swift` and applied via a new `.heroCard()` modifier.

No tactical arrows, no jersey numbers, no kit stripes. If the above three don't carry the aesthetic, we add more later — we do not start with more.

### Component Changes

**`DesignSystem.swift`** — rewrite palette, typography, radii, shadows.
- Radii: drop all values. New scale: `sm: 6`, `md: 8`, `lg: 12`, `pill: 999`. (Sharper than current 12/16/24.)
- Shadows: flatten. Drop all glow variants. Keep only a subtle dark shadow for elevation.
- Gradients: remove `athleticGradient`, `celebrationGradient`, `levelUpGradient`, `streakGradient`. Keep a single `primaryGradient` (lime → dim-lime).

**`ModernComponents.swift`** — update styles without changing component APIs:
- `ModernButton`: uppercase label via `label` typography, squarer corners, remove gradient sheen, remove glow. Primary = solid lime with `surfaceBase` text. Secondary = chalk-white outline, transparent fill.
- `ModernCard`: sharper corners, flatter shadow, chalk-white border at 8% opacity instead of current 6% white.
- `ModernTextField`: focused state border = lime (was green), animated label uses `label` typography uppercase.
- `StatCard`: hero number uses `numberMono` or `heroDisplay` depending on context. Label above the number is `label`-styled.
- `ProgressRing`: single lime color with no angular gradient; chalk-white track.
- `GlowBadge`: rename internally but keep public API — remove glow, use solid lime/blood-orange background with black text, uppercase label.
- `AnimatedTabBar`: selected state = chalk-white label + lime capsule; unselected = dim ivory. Drop glow shadow.

**New in `ModernComponents.swift`:**
- `PitchDivider` — 1pt `chalkWhite @ 0.4` line with optional horizontal padding.
- `CornerBracketShape` + `.heroCard()` view modifier — wraps content in a `ModernCard` with one chalk-white L-bracket.
- `TurfBackground` — root-level `ZStack` background with subtle noise. Applied once in `ContentView`.

### Mascot Removal

The Kicko mascot system (`MascotView`) is removed. It clashes with the new aesthetic and is not worth the effort of redrawing. State views that currently depend on it get a new treatment:

- `EmptyStateView`, `CompactEmptyStateView`, `LoadingStateView`, `ErrorStateView`, `WelcomeBackView` — rebuilt around a large chalk-white SF Symbol (80–120pt) plus massive compressed uppercase typography.
- Suggested SF Symbol mapping:
  - Empty: `soccerball` or `figure.soccer`
  - Loading: `soccerball` in a rotation animation
  - Error: `exclamationmark.triangle` or `sportscourt`
  - Welcome back: `figure.soccer`
- All `MascotView` call sites are replaced. `MascotView.swift` is deleted in Phase 5 cleanup.

### What explicitly stays the same

- All 55+ views, their navigation, and their content structure.
- `AnimatedTabBar` structure (5 tabs: Home, Train, Plans, Community, Profile).
- Particle effects (confetti, sparkle, coin burst) — palette-swap to new accent colors, behavior unchanged.
- Haptic feedback patterns.
- Accessibility reduce-motion behavior.
- Rarity color system for shop items.

## Execution Plan

Five sequential phases. Each phase is its own commit. After each phase, I build, report any errors, and wait for the user to visually verify before proceeding to the next phase.

### Phase 1 — Foundation
Rewrite `DesignSystem.swift`:
- Replace palette tokens with Stadium Night palette.
- Replace typography tokens with compressed/heavy SF Pro variants.
- Replace radii and shadow tokens.
- Remove dead gradients and glow variants.
- Keep old token names where possible so existing views still compile (e.g., `.primaryGreen` → now resolves to lime).

**Verification:** Build succeeds. User opens app, confirms palette shift is visible on any screen.

### Phase 2 — Core Components
Update `ModernComponents.swift`:
- Restyle `ModernButton`, `ModernCard`, `ModernTextField`, `ModernSegmentControl`, `StatCard`, `ProgressRing`, `GlowBadge`, `ActionChip`, `PillSelector`.
- Update `AnimatedTabBar` styling.
- Add `PitchDivider`, `CornerBracketShape`, `.heroCard()` modifier.

**Verification:** Build succeeds. User checks Dashboard, Training Hub, Profile — most screens should now feel redesigned from component updates alone.

### Phase 3 — Hero Surfaces & State Views
Apply `TurfBackground` to `ContentView`. Apply `.heroCard()` and `PitchDivider` where they have the most impact:
- `DashboardView` hero stats section
- `TrainHubView` top card
- `ActiveTrainingView` session header
- `PlayerProgressView` XP/level hero

Rebuild state views without the mascot:
- `EmptyStateView` / `CompactEmptyStateView` — SF Symbol + uppercase compressed display text + CTA button
- `LoadingStateView` — rotating `soccerball` symbol + "LOADING" label
- `ErrorStateView` — triangle warning symbol + "SOMETHING BROKE" + retry button
- `WelcomeBackView` — `figure.soccer` symbol + personalized greeting in display typography

**Verification:** User checks the four hero screens + at least one empty state, one loading state, one error state.

### Phase 4 — Typography Pass
Go through high-visibility screens and upgrade headers to the new display typography:
- Dashboard: greeting + current level
- Profile: player name + stats
- Active Training: current drill name
- Session History: "YOUR SESSIONS" style headers
- Training Plans list: plan names

This is a targeted pass — not every screen, just the ones where the massive typography adds the most value.

**Verification:** User checks each updated screen.

### Phase 5 — Polish & Cleanup
- Remove dead token definitions from `DesignSystem.swift`.
- Delete `MascotView.swift` and any mascot-related assets.
- Audit for any views still referencing removed tokens or `MascotView`.
- Palette-swap particle effects in `ConfettiView` to new colors.
- Run a final build.
- Fix anything the user flagged during earlier phases that we deferred.

**Verification:** Clean build, no warnings introduced, user sign-off on full app walkthrough.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Compressed SF Pro may not render well at very small sizes | Use compressed only on display/label tokens, not on body |
| 55 views → too much visual churn to verify | Phase 3 & 4 narrow focus to hero screens; rest inherit from components |
| Removing `primaryGreen` breaks views that reference it directly | Phase 1 keeps old names as aliases pointing to new values; dead-name cleanup in Phase 5 |
| Turf noise texture hurts readability | Keep opacity ≤ 6%, only on base background, never behind text |
| Uppercase labels hurt long strings | Only apply `.label` typography to short strings (buttons, tags). Titles stay sentence case except on display tokens |
| User doesn't like direction mid-phase | Each phase is a separate commit; revert is cheap |

## Open Questions

- Phase 4 typography — apply to every screen or only hero screens?
- Keep `ConfettiView` as-is (just recolored) or tone down particle count?
