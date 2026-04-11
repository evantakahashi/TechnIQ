# Stadium Night UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Revamp the TechnIQ visual design from generic dark-mode gamification to a premium "Stadium Night" athletic-catalog aesthetic. All features, navigation, and business logic unchanged.

**Architecture:** Changes are centralized in `DesignSystem.swift` and `ModernComponents.swift` so most views inherit the redesign automatically. Hero surfaces and state views get targeted per-screen updates. Work is split into 5 sequential phases, each a separate commit with a user-visual-verification checkpoint before proceeding.

**Tech Stack:** SwiftUI, iOS 17+, SF Pro system font (compressed/black variants), Core Data (untouched).

**Spec:** `docs/superpowers/specs/2026-04-11-stadium-night-ui-redesign-design.md`

---

## Ground Rules

- **TDD does not apply here.** This is a pure visual redesign. Verification is: "build succeeds + user visually confirms on simulator."
- **Dark mode only.** Remove all light-mode branches from adaptive colors in Phase 1. Do not add new light-mode code paths.
- **Preserve public APIs.** `ModernCard`, `ModernButton`, `StatCard`, `GlowBadge`, etc. keep the same initializer signatures so existing call sites continue to compile.
- **Preserve token names where possible.** Keep `primaryGreen`, `accentGold`, etc. as aliases that now resolve to the new palette. This lets existing views compile without sweeping changes. Dead aliases get removed in Phase 5.
- **Every phase is its own commit.** Each `Commit` step marks a user-verification checkpoint.
- **Build after every non-trivial change.** Use `/build` or run the Bash command from `CLAUDE.md`.
- **Never commit secrets.** Follow `.claude/rules/no-commit.md`.
- **Style rules:** Follow `.claude/rules/swift-style.md` — use `DesignSystem` tokens, no hardcoded values.

---

## File Structure

**Files modified:**
- `TechnIQ/Components/DesignSystem.swift` — Phase 1 (palette, typography, radii, shadows, gradients)
- `TechnIQ/Components/ModernComponents.swift` — Phase 2 (restyle + add `PitchDivider`, `CornerBracketShape`, `TurfBackground`, `.heroCard()`)
- `TechnIQ/App/ContentView.swift` — Phase 3 (apply `TurfBackground` at root)
- `TechnIQ/Components/EmptyStateView.swift` — Phase 3 (rebuild without mascot)
- `TechnIQ/Views/Dashboard/DashboardView.swift` — Phase 3 + 4
- `TechnIQ/Views/Training/TrainHubView.swift` — Phase 3 + 4
- `TechnIQ/Views/Training/ActiveTrainingView.swift` — Phase 3 + 4
- `TechnIQ/Views/Dashboard/PlayerProgressView.swift` — Phase 3 + 4
- `TechnIQ/Views/Training/SessionCompleteView.swift` — Phase 3 (remove mascot usage)
- `TechnIQ/Views/Auth/UnifiedOnboardingView.swift` — Phase 3 (remove mascot usage)
- `TechnIQ/Views/Auth/Onboarding/FeatureHighlightView.swift` — Phase 3 (remove mascot usage)
- `TechnIQ/Views/Training/SessionHistoryView.swift` — Phase 4
- `TechnIQ/Views/Dashboard/EnhancedProfileView.swift` — Phase 4
- `TechnIQ/Views/Training/TrainingPlansListView.swift` — Phase 4
- `TechnIQ/Components/ConfettiView.swift` — Phase 5 (palette swap only)

**Files deleted (Phase 5):**
- `TechnIQ/Components/MascotView.swift`
- `TechnIQ/Models/MascotState.swift`
- Matching references in `TechnIQ.xcodeproj/project.pbxproj`

**Files NOT touched:**
- Any file under `TechnIQ/Services/` — business logic is untouched
- Core Data models (`TechnIQ/Models/*.xcdatamodeld`)
- Firebase functions (`functions/`)

---

## Chunk 1: Phase 1 — Foundation (DesignSystem.swift)

Rewrite `DesignSystem.swift` to the Stadium Night palette, compressed typography, sharper radii, and flattened shadows. Keep legacy token names as aliases that point at new values so existing call sites compile unchanged.

### Task 1.1: Rewrite color palette

**Files:**
- Modify: `TechnIQ/Components/DesignSystem.swift:8-173` (the entire `Colors` struct)

- [ ] **Step 1: Replace the `Colors` struct body**

Replace `struct Colors { ... }` (lines 8–173) with:

```swift
struct Colors {
    // MARK: - Stadium Night Palette

    // Surfaces (dark-only)
    static let surfaceBase = Color(red: 0.051, green: 0.059, blue: 0.055)      // #0D0F0E
    static let surfaceRaised = Color(red: 0.082, green: 0.098, blue: 0.090)    // #151917
    static let surfaceOverlay = Color(red: 0.118, green: 0.137, blue: 0.125)   // #1E2320
    static let surfaceHighlight = Color(red: 0.165, green: 0.184, blue: 0.173) // #2A2F2C

    // Accents
    static let accentLime = Color(red: 0.800, green: 1.000, blue: 0.000)       // #CCFF00
    static let accentLimeDim = Color(red: 0.561, green: 0.702, blue: 0.000)    // #8FB300
    static let bloodOrange = Color(red: 1.000, green: 0.294, blue: 0.122)      // #FF4B1F

    // Text (chalk tones)
    static let chalkWhite = Color(red: 0.949, green: 0.941, blue: 0.902)       // #F2F0E6
    static let mutedIvory = Color(red: 0.659, green: 0.647, blue: 0.604)       // #A8A59A
    static let dimIvory = Color(red: 0.420, green: 0.412, blue: 0.384)         // #6B6962

    // MARK: - Semantic aliases (map legacy token names → Stadium Night)

    // Primary brand (was emerald green)
    static let primaryGreen = accentLime
    static let primaryGreenLight = accentLime
    static let primaryGreenDark = accentLimeDim

    // Gold/secondary (collapsed to lime)
    static let secondaryBlue = accentLime
    static let secondaryBlueLight = accentLime
    static let accentGold = accentLime
    static let accentOrange = bloodOrange
    static let accentYellow = accentLime

    // Gamification
    static let successGreen = accentLime
    static let streakOrange = bloodOrange
    static let xpGold = accentLime
    static let levelPurple = accentLime
    static let coinGold = accentLime

    // Semantic
    static let success = accentLime
    static let warning = bloodOrange
    static let error = bloodOrange
    static let info = accentLime

    // Text aliases
    static let textPrimary = chalkWhite
    static let textSecondary = mutedIvory
    static let textTertiary = dimIvory
    static let textOnAccent = surfaceBase
    static let primaryDark = surfaceBase

    // Background aliases
    static let background = surfaceBase
    static let backgroundSecondary = surfaceRaised
    static let backgroundTertiary = surfaceOverlay
    static let cardBackground = surfaceRaised
    static let cardBorder = chalkWhite.opacity(0.08)
    static let darkModeBackground = surfaceBase
    static let cellBackground = surfaceRaised

    // MARK: - Preserved: rarity system (players recognize these)
    static let rarityCommon = Color(red: 0.62, green: 0.62, blue: 0.62)
    static let rarityUncommon = Color(red: 0.3, green: 0.69, blue: 0.31)
    static let rarityRare = Color(red: 0.13, green: 0.59, blue: 0.95)
    static let rarityEpic = Color(red: 0.61, green: 0.15, blue: 0.69)
    static let rarityLegendary = Color(red: 1.0, green: 0.76, blue: 0.03)

    // MARK: - Legacy neutrals (kept as aliases to chalk tones)
    static let neutral100 = chalkWhite
    static let neutral200 = chalkWhite.opacity(0.12)
    static let neutral300 = chalkWhite.opacity(0.08)
    static let neutral400 = mutedIvory
    static let neutral500 = mutedIvory
    static let neutral600 = dimIvory
    static let neutral700 = dimIvory
    static let neutral800 = surfaceHighlight
    static let neutral900 = surfaceBase

    // MARK: - Confetti palette (Phase 5 also recolors ConfettiView)
    static let confettiColors: [Color] = [
        accentLime,
        bloodOrange,
        chalkWhite,
        accentLimeDim
    ]

    // MARK: - Gradients
    static let primaryGradient = LinearGradient(
        colors: [accentLime, accentLimeDim],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let secondaryGradient = primaryGradient
    static let athleticGradient = primaryGradient
    static let xpGradient = primaryGradient
    static let levelUpGradient = primaryGradient
    static let streakGradient = LinearGradient(
        colors: [bloodOrange, bloodOrange.opacity(0.7)],
        startPoint: .bottom,
        endPoint: .top
    )
    static let celebrationGradient = primaryGradient
    static let backgroundGradient = LinearGradient(
        colors: [surfaceBase, surfaceRaised],
        startPoint: .top,
        endPoint: .bottom
    )
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED. If any call site fails, note the error — it means a legacy alias is missing from the map above. Add the alias rather than changing the call site.

### Task 1.2: Rewrite typography

**Files:**
- Modify: `TechnIQ/Components/DesignSystem.swift:175-206` (the `Typography` struct)

- [ ] **Step 1: Replace the `Typography` struct body**

Replace `struct Typography { ... }` with:

```swift
struct Typography {
    // Display (compressed, black-weight SF Pro — the "Nike Training" hero typography)
    static let heroDisplay = Font.system(size: 72, weight: .black).width(.compressed)
    static let displayLarge = Font.system(size: 56, weight: .black).width(.compressed)
    static let displayMedium = Font.system(size: 42, weight: .heavy).width(.compressed)
    static let displaySmall = Font.system(size: 32, weight: .heavy).width(.compressed)

    // Headlines (restrained, readable)
    static let headlineLarge = Font.system(size: 24, weight: .bold)
    static let headlineMedium = Font.system(size: 20, weight: .semibold)
    static let headlineSmall = Font.system(size: 17, weight: .semibold)

    // Titles
    static let titleLarge = Font.system(size: 22, weight: .semibold)
    static let titleMedium = Font.system(size: 16, weight: .semibold)
    static let titleSmall = Font.system(size: 14, weight: .medium)

    // Labels (buttons, tags, uppercase metadata)
    static let labelLarge = Font.system(size: 15, weight: .heavy).width(.compressed)
    static let labelMedium = Font.system(size: 13, weight: .heavy).width(.compressed)
    static let labelSmall = Font.system(size: 11, weight: .heavy).width(.compressed)

    // Body (stays clean and readable)
    static let bodyLarge = Font.system(size: 17, weight: .regular)
    static let bodyMedium = Font.system(size: 15, weight: .regular)
    static let bodySmall = Font.system(size: 13, weight: .regular)

    // Numbers (monospaced for stat alignment)
    static let numberLarge = Font.system(size: 36, weight: .black, design: .monospaced)
    static let numberMedium = Font.system(size: 24, weight: .black, design: .monospaced)
    static let numberSmall = Font.system(size: 17, weight: .semibold, design: .monospaced)
}
```

- [ ] **Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED.

### Task 1.3: Tighten radii and flatten shadows

**Files:**
- Modify: `TechnIQ/Components/DesignSystem.swift:225-254` (`CornerRadius` and `Shadow` structs)

- [ ] **Step 1: Replace `CornerRadius` struct**

Replace with:

```swift
struct CornerRadius {
    static let xs: CGFloat = 2
    static let sm: CGFloat = 4
    static let md: CGFloat = 6
    static let lg: CGFloat = 8
    static let xl: CGFloat = 12
    static let xxl: CGFloat = 16

    // Specific use cases
    static let button: CGFloat = sm
    static let card: CGFloat = lg
    static let textField: CGFloat = sm
    static let image: CGFloat = sm
    static let pill: CGFloat = 999
}
```

- [ ] **Step 2: Replace `Shadow` struct**

Replace with:

```swift
struct Shadow {
    static let small = (color: Color.black.opacity(0.3), radius: CGFloat(2), x: CGFloat(0), y: CGFloat(1))
    static let medium = (color: Color.black.opacity(0.4), radius: CGFloat(4), x: CGFloat(0), y: CGFloat(2))
    static let large = (color: Color.black.opacity(0.5), radius: CGFloat(8), x: CGFloat(0), y: CGFloat(4))
    static let xl = (color: Color.black.opacity(0.6), radius: CGFloat(16), x: CGFloat(0), y: CGFloat(8))

    // Legacy glow aliases — flattened to plain shadows (glow is gone from Stadium Night)
    static let glowSmall = small
    static let glowMedium = medium
    static let glowLarge = large
    static let glowGold = medium
}
```

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED.

### Task 1.4: Force dark mode at the root

**Files:**
- Modify: `TechnIQ/App/TechnIQApp.swift` (add `.preferredColorScheme(.dark)` to the root `WindowGroup`)

- [ ] **Step 1: Read the file to find the `WindowGroup` / `body`**

Run Read on `TechnIQ/App/TechnIQApp.swift`.

- [ ] **Step 2: Add `.preferredColorScheme(.dark)` to the root view**

Find the `ContentView()` instantiation inside `WindowGroup { ... }` and append `.preferredColorScheme(.dark)` as a modifier on it. If `ContentView` is already wrapped in other modifiers, add it at the end of the chain.

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED.

### Task 1.5: Commit Phase 1 and request visual verification

- [ ] **Step 1: Stage and commit**

```bash
git add TechnIQ/Components/DesignSystem.swift TechnIQ/App/TechnIQApp.swift
git commit -m "feat(ui): Stadium Night palette, compressed typography, sharp radii"
```

- [ ] **Step 2: Checkpoint — ask user to verify visually**

Prompt: "Phase 1 committed. Please launch the app and send me a screenshot of any screen (Dashboard is fine). I want to confirm the palette, typography, and radii feel right before moving to Phase 2."

Wait for user confirmation before proceeding to Chunk 2.

---

## Chunk 2: Phase 2 — Core Components (ModernComponents.swift)

Update component styling and add three new primitives (`PitchDivider`, `CornerBracketShape`, `TurfBackground`) plus the `.heroCard()` modifier. Component public APIs stay the same.

### Task 2.1: Restyle `ModernButton`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:3-117`

- [ ] **Step 1: Update the `body` of `ModernButton`**

Replace the `HStack(spacing: ...) { ... }` body block (lines 37–60) with:

```swift
HStack(spacing: DesignSystem.Spacing.sm) {
    if let icon = icon {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .heavy))
    }
    Text(title)
        .font(DesignSystem.Typography.labelLarge)
        .textCase(.uppercase)
        .tracking(0.8)
}
.padding(DesignSystem.Spacing.buttonPadding)
.frame(maxWidth: .infinity)
.background(backgroundForStyle)
.foregroundColor(foregroundColorForStyle)
.cornerRadius(DesignSystem.CornerRadius.button)
.overlay(borderForStyle)
.customShadow(shadowForStyle)
.scaleEffect(isPressed ? 0.97 : 1.0)
.animation(DesignSystem.Animation.quick, value: isPressed)
```

Note: the gradient-sheen `.overlay` is removed. Everything else in the file stays.

- [ ] **Step 2: Update `borderForStyle` to use chalk white for secondary**

Find `private var borderForStyle: some View { ... }` and change the `.secondary` case's stroke color from `DesignSystem.Colors.primaryGreen` to `DesignSystem.Colors.chalkWhite` and `lineWidth` from `1.5` to `1`.

- [ ] **Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED.

### Task 2.2: Restyle `ModernCard`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:119-199`

- [ ] **Step 1: Update the `cardContent` background and overlay**

In `ModernCard.body`, change the `.overlay(RoundedRectangle(...).stroke(Color.white.opacity(0.06), lineWidth: 1))` to:

```swift
.overlay(
    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
        .stroke(DesignSystem.Colors.chalkWhite.opacity(0.08), lineWidth: 1)
)
```

- [ ] **Step 2: Replace adaptive glow shadow with plain shadow**

Change `.customShadow(colorScheme == .dark ? DesignSystem.Shadow.glowMedium : DesignSystem.Shadow.medium)` to:

```swift
.customShadow(DesignSystem.Shadow.medium)
```

Remove the `@Environment(\.colorScheme) private var colorScheme` property since it's no longer used.

- [ ] **Step 3: Build**

Expected: BUILD SUCCEEDED.

### Task 2.3: Restyle `ModernTextField`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:241-305`

- [ ] **Step 1: Update the label and border to use lime accent**

In `ModernTextField.body`:
- Change `Text(title).font(DesignSystem.Typography.labelMedium)` to also add `.textCase(.uppercase)` and `.tracking(0.8)` modifiers.
- The existing code already swaps to `primaryGreen` (now an alias for `accentLime`) on focus, so the behavior is correct — no change needed there.

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.4: Restyle `ProgressRing`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:307-346`

- [ ] **Step 1: Replace the angular gradient with solid lime**

Replace the second `Circle()` block (the progress trim) with:

```swift
Circle()
    .trim(from: 0, to: CGFloat(progress))
    .stroke(
        DesignSystem.Colors.accentLime,
        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    )
    .rotationEffect(.degrees(-90))
    .animation(DesignSystem.Animation.smooth, value: progress)
```

Remove the `.shadow(color: color.opacity(0.4), radius: 4)` glow.

Change the track `Circle().stroke(Color.white.opacity(0.08), lineWidth: lineWidth)` to:

```swift
Circle()
    .stroke(DesignSystem.Colors.chalkWhite.opacity(0.12), lineWidth: lineWidth)
```

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.5: Restyle `GlowBadge` (keep API, remove the glow)

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:820-860`

- [ ] **Step 1: Replace body**

Replace the `body` of `GlowBadge` with:

```swift
var body: some View {
    HStack(spacing: DesignSystem.Spacing.xs) {
        if let icon {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
        }
        Text(text)
            .font(DesignSystem.Typography.labelSmall)
            .textCase(.uppercase)
            .tracking(0.8)
    }
    .foregroundColor(DesignSystem.Colors.surfaceBase)
    .padding(.horizontal, DesignSystem.Spacing.sm)
    .padding(.vertical, DesignSystem.Spacing.xs)
    .background(color)
    .clipShape(Capsule())
}
```

Also remove the unused `@State private var appeared` and the `.onAppear` animation block.

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.6: Restyle `AnimatedTabBar`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift:767-818`

- [ ] **Step 1: Replace tab bar visuals**

In the inner `VStack` / `ZStack`:
- Change the selected `Capsule().fill(DesignSystem.Colors.primaryGreen.opacity(0.15))` to `Capsule().fill(DesignSystem.Colors.accentLime)`.
- Remove the `.shadow(color: DesignSystem.Colors.primaryGreen.opacity(0.3), radius: 8)` glow.
- Change the `Text` font to `DesignSystem.Typography.labelSmall` with `.textCase(.uppercase)` added.
- Change `.foregroundColor(...)` to `selectedTab == index ? DesignSystem.Colors.surfaceBase : DesignSystem.Colors.mutedIvory` so the selected tab's icon/label sits on lime with dark text.
- Change the outer background from `DesignSystem.Colors.surfaceRaised` to:
  ```swift
  .background(
      DesignSystem.Colors.surfaceRaised
          .overlay(Rectangle().fill(DesignSystem.Colors.chalkWhite.opacity(0.08)).frame(height: 1), alignment: .top)
  )
  ```
  (This adds a chalk-line divider above the tab bar.)

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.7: Restyle `ModernSegmentControl`, `PillSelector`, `MultiSelectPillSelector`, `ActionChip`

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift` (ranges for each component)

- [ ] **Step 1: Segment control**

In `ModernSegmentControl.body`, find the selected-state `Capsule().fill(DesignSystem.Colors.primaryGreen)` and change its text `.foregroundColor(...)` from `.white` to `DesignSystem.Colors.surfaceBase`. (`primaryGreen` now aliases to lime, so the fill is correct.) Also add `.textCase(.uppercase)` to the option `Text`.

- [ ] **Step 2: Pill selectors**

In both `PillSelector` and `MultiSelectPillSelector`, change the selected-state `.foregroundColor(... ? .white : ...)` to `.foregroundColor(... ? DesignSystem.Colors.surfaceBase : ...)` so text reads dark on the lime pill.

- [ ] **Step 3: ActionChip**

In `ActionChip.body`, change `.background(color.opacity(isPressed ? 0.2 : 0.1))` to `.background(DesignSystem.Colors.surfaceHighlight)`. Change the icon color binding from `color` to `DesignSystem.Colors.accentLime`.

- [ ] **Step 4: Build**

Expected: BUILD SUCCEEDED.

### Task 2.8: Add `PitchDivider` primitive

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift` (append new struct at the bottom, before the Preview provider)

- [ ] **Step 1: Append `PitchDivider`**

Add just above `// MARK: - Preview Provider`:

```swift
// MARK: - Pitch Line Divider

/// A chalk-white horizontal line used to separate sections, evoking a pitch line.
struct PitchDivider: View {
    var opacity: Double = 0.4
    var horizontalPadding: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(DesignSystem.Colors.chalkWhite.opacity(opacity))
            .frame(height: 1)
            .padding(.horizontal, horizontalPadding)
    }
}
```

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.9: Add `CornerBracketShape` and `.heroCard()` modifier

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift` (append)

- [ ] **Step 1: Append shape + modifier**

Add just above `// MARK: - Preview Provider`:

```swift
// MARK: - Corner Bracket (pitch corner arc stylized as an L)

/// An L-shaped bracket drawn in one corner, evoking a pitch corner arc.
struct CornerBracketShape: Shape {
    var length: CGFloat = 20
    var thickness: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Top-left L: horizontal arm then vertical arm
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: length, height: thickness))
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: thickness, height: length))
        return path
    }
}

// MARK: - Hero Card Modifier

private struct HeroCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(DesignSystem.Spacing.cardPadding)
            .background(DesignSystem.Colors.surfaceRaised)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(DesignSystem.Colors.chalkWhite.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                CornerBracketShape(length: 20, thickness: 2)
                    .fill(DesignSystem.Colors.chalkWhite.opacity(0.7))
                    .frame(width: 20, height: 20)
                    .padding(10),
                alignment: .topLeading
            )
            .customShadow(DesignSystem.Shadow.medium)
    }
}

extension View {
    /// Wraps content in a Stadium Night hero card with a chalk corner bracket.
    func heroCard() -> some View {
        self.modifier(HeroCardModifier())
    }
}
```

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.10: Add `TurfBackground` primitive

**Files:**
- Modify: `TechnIQ/Components/ModernComponents.swift` (append)

- [ ] **Step 1: Append `TurfBackground`**

Add just above `// MARK: - Preview Provider`:

```swift
// MARK: - Turf Background

/// Root-level background: surfaceBase with a very subtle procedural grain overlay.
/// Used once at the app root so every screen inherits the texture.
struct TurfBackground: View {
    var body: some View {
        ZStack {
            DesignSystem.Colors.surfaceBase
            TurfGrainCanvas()
                .opacity(0.05)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

private struct TurfGrainCanvas: View {
    var body: some View {
        Canvas { context, size in
            // Deterministic grain using a fixed seed so it doesn't flicker on redraw.
            var generator = SeededRandomNumberGenerator(seed: 0xA11CE)
            for _ in 0..<1800 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.fill(Path(rect), with: .color(DesignSystem.Colors.chalkWhite))
            }
        }
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0xdead_beef : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
```

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 2.11: Commit Phase 2 and request visual verification

- [ ] **Step 1: Stage and commit**

```bash
git add TechnIQ/Components/ModernComponents.swift
git commit -m "feat(ui): Stadium Night core components, pitch divider, hero card, turf background"
```

- [ ] **Step 2: Checkpoint — ask user to verify visually**

Prompt: "Phase 2 committed. Components are restyled and the new primitives are ready. Please launch the app and send screenshots of: (1) Dashboard, (2) Train Hub, (3) Profile. Most of the redesign should already be visible from the component updates alone. I'll wait for your go-ahead before Phase 3."

Wait for user confirmation before proceeding to Chunk 3.

---

## Chunk 3: Phase 3 — Hero Surfaces & State View Rebuild

Apply `TurfBackground` at the root. Add `.heroCard()` + `PitchDivider` to the four hero screens. Rebuild `EmptyStateView` / `LoadingStateView` / `ErrorStateView` / `WelcomeBackView` without the mascot. Remove mascot call sites in non-state views.

### Task 3.1: Apply `TurfBackground` at app root

**Files:**
- Modify: `TechnIQ/App/ContentView.swift:290-317` (`MainTabView.body`)

- [ ] **Step 1: Wrap `MainTabView.body` contents in a `ZStack` with `TurfBackground`**

Change the outer `VStack(spacing: 0) { ... }` to:

```swift
ZStack {
    TurfBackground()
    VStack(spacing: 0) {
        AnimatedTabContent(selectedTab: $selectedTab) { tab in
            // ... existing content ...
        }
        AnimatedTabBar(selectedTab: $selectedTab)
    }
}
.ignoresSafeArea(.keyboard)
```

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 3.2: Rebuild `EmptyStateView` without mascot

**Files:**
- Modify: `TechnIQ/Components/EmptyStateView.swift` (entire file)

- [ ] **Step 1: Replace the `EmptyStateView.body`**

Replace the `body` with:

```swift
var body: some View {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Image(systemName: symbolName)
            .font(.system(size: 96, weight: .regular))
            .foregroundColor(DesignSystem.Colors.chalkWhite.opacity(0.85))

        PitchDivider(horizontalPadding: 48)

        Text(title)
            .font(DesignSystem.Typography.displayMedium)
            .textCase(.uppercase)
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .multilineTextAlignment(.center)

        Text(description)
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.mutedIvory)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)

        if let title = actionTitle, let action = action {
            ModernButton(title, icon: actionIcon, style: .primary, action: action)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }
    .padding(DesignSystem.Spacing.xl)
}

private var symbolName: String {
    switch context {
    case .noSessions: return "soccerball"
    case .noFavorites: return "heart"
    case .noAchievements: return "trophy"
    case .noProgress: return "chart.line.uptrend.xyaxis"
    case .noPlans: return "calendar"
    case .noPosts: return "bubble.left.and.bubble.right"
    }
}
```

Delete the `speechBubbleText` computed property (no longer used).

- [ ] **Step 2: Replace `CompactEmptyStateView.body`**

```swift
var body: some View {
    HStack(spacing: DesignSystem.Spacing.md) {
        Image(systemName: symbolName)
            .font(.system(size: 32, weight: .regular))
            .foregroundColor(DesignSystem.Colors.chalkWhite.opacity(0.7))
            .frame(width: 40)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(DesignSystem.Typography.labelLarge)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)

            Text(subtitle)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
        }

        Spacer()
    }
    .padding(DesignSystem.Spacing.md)
}

private var symbolName: String {
    switch context {
    case .noSessions: return "soccerball"
    case .noFavorites: return "heart"
    case .noAchievements: return "trophy"
    case .noProgress: return "chart.line.uptrend.xyaxis"
    case .noPlans: return "calendar"
    case .noPosts: return "bubble.left.and.bubble.right"
    }
}
```

Also remove the `showMascot` parameter from `init` — replace with just `init(context: EmptyStateContext) { self.context = context }`. Delete the `showMascot` stored property.

- [ ] **Step 3: Replace `LoadingStateView.body`**

```swift
var body: some View {
    VStack(spacing: DesignSystem.Spacing.lg) {
        SoccerBallSpinner()
            .scaleEffect(2.0)

        Text(message)
            .font(DesignSystem.Typography.displaySmall)
            .textCase(.uppercase)
            .foregroundColor(DesignSystem.Colors.chalkWhite)
    }
    .padding(DesignSystem.Spacing.xl)
}
```

(`SoccerBallSpinner` already exists in `ModernComponents.swift` — it's a rotating soccerball SF Symbol.)

- [ ] **Step 4: Replace `ErrorStateView.body`**

```swift
var body: some View {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 96, weight: .regular))
            .foregroundColor(DesignSystem.Colors.bloodOrange)

        PitchDivider(horizontalPadding: 48)

        Text(title)
            .font(DesignSystem.Typography.displayMedium)
            .textCase(.uppercase)
            .foregroundColor(DesignSystem.Colors.chalkWhite)
            .multilineTextAlignment(.center)

        Text(message)
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.mutedIvory)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)

        if let retry = retryAction {
            ModernButton("Try Again", icon: "arrow.clockwise", style: .primary, action: retry)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }
    .padding(DesignSystem.Spacing.xl)
}
```

- [ ] **Step 5: Replace `WelcomeBackView.body`**

```swift
var body: some View {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Image(systemName: "figure.soccer")
            .font(.system(size: 120, weight: .regular))
            .foregroundColor(DesignSystem.Colors.chalkWhite)

        PitchDivider(horizontalPadding: 48)

        Text("WELCOME BACK")
            .font(DesignSystem.Typography.displayLarge)
            .foregroundColor(DesignSystem.Colors.chalkWhite)

        Text(motivationalMessage)
            .font(DesignSystem.Typography.bodyMedium)
            .foregroundColor(DesignSystem.Colors.mutedIvory)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DesignSystem.Spacing.lg)

        ModernButton("Start Training", icon: "play.fill", style: .primary, action: onStartTraining)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.horizontal, DesignSystem.Spacing.xl)
    }
    .padding(DesignSystem.Spacing.xl)
}
```

Delete the `welcomeMessage` computed property (no longer used).

- [ ] **Step 6: Build**

Expected: BUILD SUCCEEDED. If `CompactEmptyStateView(..., showMascot: ...)` call sites break, update them to drop the argument (grep for `CompactEmptyStateView(` to find them).

### Task 3.3: Remove mascot usage from non-state views

**Files:**
- Modify: `TechnIQ/Views/Training/SessionCompleteView.swift`
- Modify: `TechnIQ/Views/Auth/UnifiedOnboardingView.swift`
- Modify: `TechnIQ/Views/Auth/Onboarding/FeatureHighlightView.swift`

- [ ] **Step 1: Find each `MascotView(...)` usage**

For each file: grep for `MascotView(` to find the line(s). For each site, replace with one of:
- A large SF Symbol: `Image(systemName: "soccerball").font(.system(size: 96)).foregroundColor(DesignSystem.Colors.chalkWhite)`
- A large Text title in `displayLarge` + uppercase
- Whichever fits the surrounding layout best (use judgment; keep spacing the same)

If the mascot was wrapped in a speech bubble with text, keep the text and drop the bubble/mascot chrome.

- [ ] **Step 2: Build after each file**

Expected: BUILD SUCCEEDED.

### Task 3.4: Apply `.heroCard()` to the four hero screens

**Files:**
- Modify: `TechnIQ/Views/Dashboard/DashboardView.swift` (hero stats section)
- Modify: `TechnIQ/Views/Training/TrainHubView.swift` (top card)
- Modify: `TechnIQ/Views/Training/ActiveTrainingView.swift` (session header)
- Modify: `TechnIQ/Views/Dashboard/PlayerProgressView.swift` (XP/level hero)

For each file:

- [ ] **Step 1: Read the file and locate the current hero section**

The hero is usually the first `ModernCard { ... }` or top `VStack` of the screen.

- [ ] **Step 2: Replace the wrapping `ModernCard` (or add one) with `.heroCard()`**

Replace:
```swift
ModernCard { ... content ... }
```
with:
```swift
VStack { ... content ... }
    .heroCard()
```

If the section is currently a bare `VStack` without a card, just append `.heroCard()`.

- [ ] **Step 3: Insert `PitchDivider()` above each hero section header**

Between any existing screen greeting and the hero card, insert `PitchDivider(horizontalPadding: DesignSystem.Spacing.lg)` for visual separation.

- [ ] **Step 4: Build after each file**

Expected: BUILD SUCCEEDED.

### Task 3.5: Commit Phase 3 and request visual verification

- [ ] **Step 1: Stage and commit**

```bash
git add TechnIQ/App/ContentView.swift TechnIQ/Components/EmptyStateView.swift \
        TechnIQ/Views/Training/SessionCompleteView.swift \
        TechnIQ/Views/Auth/UnifiedOnboardingView.swift \
        TechnIQ/Views/Auth/Onboarding/FeatureHighlightView.swift \
        TechnIQ/Views/Dashboard/DashboardView.swift \
        TechnIQ/Views/Training/TrainHubView.swift \
        TechnIQ/Views/Training/ActiveTrainingView.swift \
        TechnIQ/Views/Dashboard/PlayerProgressView.swift
git commit -m "feat(ui): turf background, hero cards, state view rebuild without mascot"
```

- [ ] **Step 2: Checkpoint — ask user to verify**

Prompt: "Phase 3 committed. Please launch the app and check: (1) Dashboard hero, (2) Train Hub top card, (3) an empty state (Training Plans with no plans is a good test), (4) a loading state. I need your go-ahead before Phase 4."

Wait for user confirmation before proceeding to Chunk 4.

---

## Chunk 4: Phase 4 — Typography Pass on Hero Screens

Upgrade high-visibility screen headers to the new display typography. Scoped to hero screens only — body text and list items stay readable in current sizes.

### Task 4.1: Dashboard greeting + current level

**Files:**
- Modify: `TechnIQ/Views/Dashboard/DashboardView.swift`

- [ ] **Step 1: Find the greeting Text**

Grep inside the file for the user greeting (usually "Welcome" or "Hello" or player name). Replace its font with `DesignSystem.Typography.displayLarge` and add `.textCase(.uppercase)` + `.foregroundColor(DesignSystem.Colors.chalkWhite)`.

- [ ] **Step 2: Find the level display**

Find the "Level N" label. Replace its value with `DesignSystem.Typography.heroDisplay` (the 72pt one) and keep the "LEVEL" label in `DesignSystem.Typography.labelMedium` uppercase above it.

- [ ] **Step 3: Build**

Expected: BUILD SUCCEEDED.

### Task 4.2: EnhancedProfileView player name + stats

**Files:**
- Modify: `TechnIQ/Views/Dashboard/EnhancedProfileView.swift`

- [ ] **Step 1: Find the player name header**

Replace its font with `DesignSystem.Typography.displayLarge` + `.textCase(.uppercase)`.

- [ ] **Step 2: Find the primary stats (sessions completed, XP total, streak)**

Replace their value Texts with `DesignSystem.Typography.heroDisplay` and put a `DesignSystem.Typography.labelMedium` uppercase label above each.

- [ ] **Step 3: Build**

Expected: BUILD SUCCEEDED.

### Task 4.3: ActiveTrainingView current drill name

**Files:**
- Modify: `TechnIQ/Views/Training/ActiveTrainingView.swift`

- [ ] **Step 1: Find the current drill name Text**

Replace its font with `DesignSystem.Typography.displayMedium` + `.textCase(.uppercase)`.

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 4.4: SessionHistoryView + TrainingPlansListView headers

**Files:**
- Modify: `TechnIQ/Views/Training/SessionHistoryView.swift`
- Modify: `TechnIQ/Views/Training/TrainingPlansListView.swift`

- [ ] **Step 1: Find the top-level screen title in each**

Replace the header `Text` font with `DesignSystem.Typography.displayMedium` + `.textCase(.uppercase)`.

- [ ] **Step 2: Build after each**

Expected: BUILD SUCCEEDED.

### Task 4.5: Commit Phase 4 and request verification

- [ ] **Step 1: Stage and commit**

```bash
git add TechnIQ/Views/Dashboard/DashboardView.swift \
        TechnIQ/Views/Dashboard/EnhancedProfileView.swift \
        TechnIQ/Views/Training/ActiveTrainingView.swift \
        TechnIQ/Views/Training/SessionHistoryView.swift \
        TechnIQ/Views/Training/TrainingPlansListView.swift
git commit -m "feat(ui): hero typography pass on dashboard, profile, training screens"
```

- [ ] **Step 2: Checkpoint**

Prompt: "Phase 4 committed. Please verify the hero typography on Dashboard, Profile, Active Training, Session History, and Training Plans list. Final phase next (cleanup)."

Wait for confirmation.

---

## Chunk 5: Phase 5 — Polish & Cleanup

Delete dead code, delete the mascot files, palette-swap confetti, run a final full build, and address any deferred issues from earlier phases.

### Task 5.1: Palette-swap ConfettiView

**Files:**
- Modify: `TechnIQ/Components/ConfettiView.swift`

- [ ] **Step 1: Verify default colors source**

The file already defaults to `DesignSystem.Colors.confettiColors`. Since Phase 1 replaced that array with `[accentLime, bloodOrange, chalkWhite, accentLimeDim]`, no code changes are strictly required.

- [ ] **Step 2: (Optional) Reduce particle count**

If the user confirmed tone-down in earlier review: change the default `particleCount: Int = 50` to `particleCount: Int = 30`. Otherwise skip.

- [ ] **Step 3: Build**

Expected: BUILD SUCCEEDED.

### Task 5.2: Delete mascot files

**Files:**
- Delete: `TechnIQ/Components/MascotView.swift`
- Delete: `TechnIQ/Models/MascotState.swift`
- Modify: `TechnIQ.xcodeproj/project.pbxproj` (remove file references)

- [ ] **Step 1: Verify no remaining references**

```bash
grep -rn "MascotView\|MascotState" TechnIQ/ --include='*.swift'
```

Expected: no matches. If any remain, return to Task 3.3 and remove them before proceeding.

- [ ] **Step 2: Delete the Swift files**

```bash
rm TechnIQ/Components/MascotView.swift TechnIQ/Models/MascotState.swift
```

- [ ] **Step 3: Remove the file references from `project.pbxproj`**

Use Grep to find `MascotView.swift` and `MascotState.swift` occurrences in `TechnIQ.xcodeproj/project.pbxproj`. For each match, remove the entire matching line (PBXBuildFile, PBXFileReference, PBXSourcesBuildPhase entry, PBXGroup child entry). There are typically 4 entries per file.

- [ ] **Step 4: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED. If the build fails with "missing file" errors, the `.pbxproj` still has stale references — find and remove them.

### Task 5.3: Remove dead design tokens

**Files:**
- Modify: `TechnIQ/Components/DesignSystem.swift`

- [ ] **Step 1: Audit unused legacy tokens**

Grep the codebase for each legacy token to see if it's still referenced:
```bash
grep -rn "accentOrange\|accentYellow\|levelPurple\|neutral100\|neutral200\|neutral300\|neutral400\|neutral500\|neutral600\|neutral700\|neutral800\|neutral900" TechnIQ/ --include='*.swift'
```

For any token with zero call-site matches, delete its declaration from `DesignSystem.swift`. For tokens still referenced, leave them as aliases.

- [ ] **Step 2: Build**

Expected: BUILD SUCCEEDED.

### Task 5.4: Full-app audit

- [ ] **Step 1: Launch the app**

Have the user walk through every top-level screen and flag any that still look like the old design, have broken layouts, or reference removed assets.

- [ ] **Step 2: Fix anything flagged**

Per fix: make the minimal change, build, confirm.

- [ ] **Step 3: Final build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -40`

Expected: BUILD SUCCEEDED, no warnings introduced by this plan.

### Task 5.5: Commit Phase 5

- [ ] **Step 1: Stage and commit**

```bash
git add -u TechnIQ/ TechnIQ.xcodeproj/project.pbxproj
git commit -m "chore(ui): delete mascot, swap confetti palette, prune dead tokens"
```

- [ ] **Step 2: Final checkpoint**

Prompt: "Stadium Night redesign complete. All 5 phases committed. Want me to push, open a PR, or continue with follow-up polish?"

---

## Rollback Notes

- Each phase is its own commit → `git revert <sha>` rolls back cleanly.
- Legacy token aliases mean a single `git revert` of Phase 1 restores the old palette app-wide even if later phases shipped.
- Files deleted in Phase 5 can be restored with `git checkout HEAD~N -- path` if needed.

## Open Questions (carried over from spec)

- Phase 4 scope: hero screens only (per this plan) vs. every screen. Plan is scoped to hero-only; expand later if needed.
- `ConfettiView.particleCount`: left at 50 unless user says otherwise in Task 5.1 Step 2.
