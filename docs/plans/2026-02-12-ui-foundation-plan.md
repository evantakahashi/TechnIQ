# UI Foundation Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the dark-first athletic design foundation (colors, typography, transitions, accessibility, components) so all 55+ views can adopt with one-liners.

**Architecture:** Evolutionary upgrade — modify DesignSystem.swift + ModernComponents.swift in-place, add TransitionSystem.swift + AccessibilityModifiers.swift as new files. Same token names, new values. Existing views keep compiling without changes.

**Tech Stack:** SwiftUI, UIKit (haptics), iOS 17.0+

**Design doc:** `docs/plans/2026-02-12-ui-foundation-design.md`

**Build command:** `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Critical constraint:** All existing token names (`primaryGreen`, `textPrimary`, `cardBackground`, etc.) must remain. Only values change. This ensures 54 files with 500+ callsites keep compiling.

---

### Task 1: DesignSystem — Dark-First Color System

**Files:**
- Modify: `TechnIQ/DesignSystem.swift` (lines 1-129, Colors struct)

**Step 1: Replace Colors struct with dark-first adaptive colors**

Replace the entire `Colors` struct contents. Key changes:
- `primaryGreen` → emerald #00E676 (was #00C853)
- `primaryGreenLight` → lighter emerald for gradients
- `primaryGreenDark` → darker emerald
- `secondaryBlue` → gold #FFD740 (repurposed as secondary accent)
- `secondaryBlueLight` → lighter gold
- New surface tokens: `surfaceBase`, `surfaceRaised`, `surfaceOverlay`, `surfaceHighlight` using adaptive `Color(uiColor:)` for dark/light
- `xpGold` and `coinGold` stay gold-family (now align with secondary accent)
- `cardBackground` → `surfaceRaised`
- `background` → `surfaceBase`
- `backgroundSecondary` → `surfaceRaised`
- `backgroundTertiary` → `surfaceOverlay`
- `darkModeBackground` → `surfaceBase` dark value
- `cellBackground` → `surfaceRaised` dark value
- `textPrimary` → white 95% in dark, label in light
- `textSecondary` → white 60% in dark, secondaryLabel in light
- `textTertiary` → white 38% in dark, tertiaryLabel in light
- New: `textOnAccent` = #0A0A0C
- `error` → #FF3B5C (softer red)
- `warning` → #FFAB40
- `success` → `primaryGreen`
- `info` → `secondaryBlue` (gold)
- New: `accentGold` alias for secondaryBlue
- Shadows → glow-oriented: `neutral900.opacity` replaced with `primaryGreen.opacity` for elevated cards on dark
- All neutral colors stay (used for light mode and structural elements)
- `confettiColors` updated with new emerald + gold

Gradients:
- `primaryGradient` → emerald to emerald-light (solid brand feel)
- `secondaryGradient` → gold to gold-light
- `backgroundGradient` → surfaceBase to surfaceRaised (light mode only)
- New: `athleticGradient` → emerald to gold at diagonal
- `xpGradient` stays (gold→orange)
- `levelUpGradient` → emerald→gold (was purple→blue)
- `celebrationGradient` → emerald richer

Update `AdaptiveBackground` to use `surfaceBase` in dark (was `darkModeBackground`).

**Step 2: Build to verify compilation**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`
Expected: BUILD SUCCEEDED (all 54 files referencing colors still compile because token names unchanged)

**Step 3: Commit**

```bash
git add TechnIQ/DesignSystem.swift
git commit -m "feat: dark-first emerald+gold color system"
```

---

### Task 2: DesignSystem — Athletic Typography with Dynamic Type

**Files:**
- Modify: `TechnIQ/DesignSystem.swift` (lines 131-162, Typography struct)

**Step 1: Replace Typography struct with rounded + @ScaledMetric system**

Since `@ScaledMetric` is a property wrapper requiring an instance, and `DesignSystem.Typography` uses static properties, we need a function-based approach that returns scaled fonts. Replace static `Font` properties with static functions that use `UIFontMetrics` for Dynamic Type support, and change the design/weight/size values:

| Token | Old Size → New | Old Weight → New | Old Design → New |
|-------|---------------|-----------------|-----------------|
| `displayLarge` | 57→48 | .bold→.black | .default→.rounded |
| `displayMedium` | 45→36 | .bold | .default→.rounded |
| `displaySmall` | 36→28 | .bold | .default→.rounded |
| `headlineLarge` | 32→24 | .bold | .default→.rounded |
| `headlineMedium` | 28→20 | .bold→.semibold | .default→.rounded |
| `headlineSmall` | 24→17 | .semibold | .default (stays) |
| `bodyLarge` | 16→17 | .regular | .default (stays) |
| `bodyMedium` | 14→15 | .regular | .default (stays) |
| `bodySmall` | 12→13 | .regular | .default (stays) |
| `labelLarge` | 14→15 | .medium→.semibold | .default (stays) |
| `labelMedium` | 12→13 | .medium | .default (stays) |
| `labelSmall` | 11 | .medium | .default (stays) |
| `numberLarge` | 32→36 | .bold | .monospaced (stays) |
| `numberMedium` | 24 | .bold | .monospaced (stays) |
| `numberSmall` | 16→17 | .semibold | .monospaced (stays) |

Keep them as static `Font` properties (not functions) for backward compatibility. Dynamic Type via `.dynamicTypeSize()` environment modifier at the app level is the SwiftUI-native approach — individual fonts scale automatically when you use `Font.system(size:weight:design:)` with `.dynamicTypeSize` in the environment.

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/DesignSystem.swift
git commit -m "feat: athletic rounded typography with updated scale"
```

---

### Task 3: DesignSystem — Shadows/Glows + Animation Curves

**Files:**
- Modify: `TechnIQ/DesignSystem.swift` (lines 198-213, Shadow + Animation structs)

**Step 1: Update Shadow struct for dark-mode glows**

Add glow variants alongside existing shadows. Shadows are invisible on dark backgrounds, so we add color-tinted glows:
- Keep existing `small`/`medium`/`large`/`xl` (for light mode and structural use)
- Add: `glowSmall` = primaryGreen at 0.08 opacity, radius 4
- Add: `glowMedium` = primaryGreen at 0.12 opacity, radius 8
- Add: `glowLarge` = primaryGreen at 0.15 opacity, radius 16
- Add: `glowGold` = accentGold at 0.15 opacity, radius 12

**Step 2: Update Animation struct with richer spring curves**

- Keep existing `quick`/`smooth`/`slow`/`spring`/`springBouncy`
- Add: `heroSpring` = spring(response: 0.5, dampingFraction: 0.82) — for hero transitions
- Add: `staggerSpring` = spring(response: 0.45, dampingFraction: 0.85) — for stagger reveals
- Add: `tabMorph` = spring(response: 0.35, dampingFraction: 0.86) — for tab content transitions
- Add: `microBounce` = spring(response: 0.3, dampingFraction: 0.7) — for small interactive elements

**Step 3: Update `cardStyle()` and `AdaptiveBackground` view extensions**

- `cardStyle()` → use `surfaceRaised` background + adaptive shadow (glow in dark, shadow in light)
- `AdaptiveBackground` → use `surfaceBase` (already done in Task 1, verify)

**Step 4: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add TechnIQ/DesignSystem.swift
git commit -m "feat: add glow shadows and athletic animation curves"
```

---

### Task 4: AccessibilityModifiers.swift — New File

**Files:**
- Create: `TechnIQ/AccessibilityModifiers.swift`

**Step 1: Create the `.a11y()` view modifier**

```swift
import SwiftUI

// MARK: - Accessibility Modifier
struct A11yModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let isHidden: Bool

    func body(content: Content) -> some View {
        if isHidden {
            content.accessibilityHidden(true)
        } else {
            content
                .accessibilityLabel(label)
                .accessibilityHint(hint ?? "")
                .accessibilityAddTraits(traits)
        }
    }
}

extension View {
    func a11y(
        label: String,
        hint: String? = nil,
        trait: AccessibilityTraits = .isButton
    ) -> some View {
        modifier(A11yModifier(label: label, hint: hint, traits: trait, isHidden: false))
    }

    func a11yHidden() -> some View {
        modifier(A11yModifier(label: "", hint: nil, traits: [], isHidden: true))
    }

    func a11yValue(_ value: String, label: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityValue(value)
    }
}
```

**Step 2: Add reduce-motion environment helper**

```swift
// MARK: - Reduce Motion Helper
struct ReduceMotionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animated: AnyTransition
    let reduced: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? reduced : animated)
    }
}

extension View {
    func adaptiveTransition(
        animated: AnyTransition,
        reduced: AnyTransition = .opacity
    ) -> some View {
        modifier(ReduceMotionModifier(animated: animated, reduced: reduced))
    }
}
```

**Step 3: Add file to Xcode project**

Use ruby script or manually verify the file is picked up by the build system. Since TechnIQ uses a flat directory structure, new .swift files in the TechnIQ/ folder should be auto-discovered if the project uses folder references or has the directory in the compile sources.

Check: `ls TechnIQ/*.swift | wc -l` to verify file count increased.

**Step 4: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add TechnIQ/AccessibilityModifiers.swift
git commit -m "feat: add a11y modifier and reduce-motion helpers"
```

---

### Task 5: HapticManager — Transition Support

**Files:**
- Modify: `TechnIQ/HapticManager.swift` (add new section after line 168)

**Step 1: Add transition-specific haptic methods**

Add a new `// MARK: - Transition Haptics` section after the Training-Specific section:

```swift
// MARK: - Transition Haptics

/// Prepare generators for imminent transition (call before animation starts)
func prepareForTransition() {
    mediumImpact.prepare()
    softImpact.prepare()
    rigidImpact.prepare()
    lightImpact.prepare()
}

/// Hero transition launch
func heroLaunch() {
    mediumImpact.impactOccurred()
}

/// Hero transition settle
func heroSettle() {
    softImpact.impactOccurred()
}

/// Sheet presented
func sheetPresent() {
    softImpact.impactOccurred()
}

/// Sheet dismissed
func sheetDismiss() {
    lightImpact.impactOccurred()
}

/// Pulse expand (achievement, reveal)
func pulseExpand() {
    rigidImpact.impactOccurred()
}

/// Card flip midpoint
func cardFlipMidpoint() {
    mediumImpact.impactOccurred()
}

/// Tab changed
func tabChanged() {
    lightImpact.impactOccurred()
}
```

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 3: Commit**

```bash
git add TechnIQ/HapticManager.swift
git commit -m "feat: add transition haptic methods"
```

---

### Task 6: TransitionSystem.swift — Stagger Reveal + Tab Morph

**Files:**
- Create: `TechnIQ/TransitionSystem.swift`

**Step 1: Create file with stagger reveal modifier**

```swift
import SwiftUI

// MARK: - Stagger Reveal Transition
struct StaggerRevealModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 20)
            .animation(
                reduceMotion
                    ? .none
                    : DesignSystem.Animation.staggerSpring.delay(Double(index) * 0.04),
                value: isVisible
            )
            .onAppear {
                isVisible = true
            }
    }
}

extension View {
    func staggerReveal(index: Int) -> some View {
        modifier(StaggerRevealModifier(index: index))
    }
}
```

**Step 2: Add tab morph modifier**

```swift
// MARK: - Tab Morph Transition
struct TabMorphModifier: ViewModifier {
    let selectedTab: Int
    @State private var previousTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(selectedTab: Int) {
        self.selectedTab = selectedTab
        self._previousTab = State(initialValue: selectedTab)
    }

    private var direction: CGFloat {
        selectedTab > previousTab ? 1 : -1
    }

    func body(content: Content) -> some View {
        content
            .id(selectedTab)
            .transition(
                reduceMotion
                    ? .opacity
                    : .asymmetric(
                        insertion: .offset(x: 30 * direction).combined(with: .opacity),
                        removal: .offset(x: -30 * direction).combined(with: .opacity)
                    )
            )
            .animation(
                reduceMotion ? .none : DesignSystem.Animation.tabMorph,
                value: selectedTab
            )
            .onChange(of: selectedTab) { oldValue, _ in
                previousTab = oldValue
                if !reduceMotion {
                    HapticManager.shared.tabChanged()
                }
            }
    }
}

extension View {
    func tabMorph(selectedTab: Int) -> some View {
        modifier(TabMorphModifier(selectedTab: selectedTab))
    }
}
```

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/TransitionSystem.swift
git commit -m "feat: add stagger reveal and tab morph transitions"
```

---

### Task 7: TransitionSystem — Hero Transition

**Files:**
- Modify: `TechnIQ/TransitionSystem.swift` (append)

**Step 1: Add hero namespace environment key**

```swift
// MARK: - Hero Transition Namespace
private struct HeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var heroNamespace: Namespace.ID? {
        get { self[HeroNamespaceKey.self] }
        set { self[HeroNamespaceKey.self] = newValue }
    }
}

extension View {
    func heroNamespace(_ namespace: Namespace.ID) -> some View {
        environment(\.heroNamespace, namespace)
    }
}
```

**Step 2: Add hero source and destination modifiers**

```swift
// MARK: - Hero Source Modifier
struct HeroSourceModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: true
            )
    }
}

// MARK: - Hero Destination Modifier
struct HeroDestinationModifier: ViewModifier {
    let id: String
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .matchedGeometryEffect(
                id: id,
                in: namespace,
                isSource: false
            )
    }
}

extension View {
    func heroSource(id: String, namespace: Namespace.ID) -> some View {
        modifier(HeroSourceModifier(id: id, namespace: namespace))
    }

    func heroDestination(id: String, namespace: Namespace.ID) -> some View {
        modifier(HeroDestinationModifier(id: id, namespace: namespace))
    }
}
```

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/TransitionSystem.swift
git commit -m "feat: add hero transition with namespace environment"
```

---

### Task 8: TransitionSystem — Pulse Expand, Card Flip, Countdown Burst, Sheet Rise

**Files:**
- Modify: `TechnIQ/TransitionSystem.swift` (append)

**Step 1: Add pulse expand modifier**

```swift
// MARK: - Pulse Expand Transition
struct PulseExpandModifier: ViewModifier {
    @Binding var trigger: Bool
    @State private var isExpanded = false
    @State private var glowOpacity: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isExpanded ? 1.0 : 0.8)
            .opacity(isExpanded ? 1.0 : 0.0)
            .overlay(
                Circle()
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
                    .scaleEffect(isExpanded ? 1.5 : 0.8)
                    .opacity(glowOpacity)
            )
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    HapticManager.shared.pulseExpand()
                    if reduceMotion {
                        isExpanded = true
                    } else {
                        withAnimation(DesignSystem.Animation.springBouncy) {
                            isExpanded = true
                        }
                        withAnimation(DesignSystem.Animation.smooth) {
                            glowOpacity = 0.6
                        }
                        withAnimation(DesignSystem.Animation.slow.delay(0.2)) {
                            glowOpacity = 0
                        }
                    }
                }
            }
    }
}

extension View {
    func pulseExpand(trigger: Binding<Bool>) -> some View {
        modifier(PulseExpandModifier(trigger: trigger))
    }
}
```

**Step 2: Add card flip modifier**

```swift
// MARK: - Card Flip Transition
struct CardFlipModifier<Back: View>: ViewModifier {
    @Binding var isFlipped: Bool
    let back: Back
    @State private var rotation: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .opacity(rotation < 90 ? 1 : 0)
                .accessibilityHidden(isFlipped)

            back
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(rotation >= 90 ? 1 : 0)
                .accessibilityHidden(!isFlipped)
        }
        .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
        .onChange(of: isFlipped) { _, newValue in
            if reduceMotion {
                rotation = newValue ? 180 : 0
            } else {
                withAnimation(DesignSystem.Animation.smooth) {
                    rotation = newValue ? 180 : 0
                }
                // Haptic at midpoint
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    HapticManager.shared.cardFlipMidpoint()
                }
            }
        }
    }
}

extension View {
    func cardFlip<Back: View>(isFlipped: Binding<Bool>, @ViewBuilder back: () -> Back) -> some View {
        modifier(CardFlipModifier(isFlipped: isFlipped, back: back()))
    }
}
```

**Step 3: Add countdown burst modifier**

```swift
// MARK: - Countdown Burst Transition
struct CountdownBurstModifier: ViewModifier {
    let value: Int
    let isFinal: Bool
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: value) { _, _ in
                if reduceMotion { return }

                // Reset
                scale = 0.7
                opacity = 0
                // Animate in
                withAnimation(DesignSystem.Animation.springBouncy) {
                    scale = 1.0
                    opacity = 1.0
                }

                if isFinal {
                    HapticManager.shared.countdownComplete()
                } else {
                    HapticManager.shared.countdownTick()
                }
            }
    }
}

extension View {
    func countdownBurst(value: Int, isFinal: Bool = false) -> some View {
        modifier(CountdownBurstModifier(value: value, isFinal: isFinal))
    }
}
```

**Step 4: Add sheet rise modifier**

```swift
// MARK: - Sheet Rise Modifier
struct SheetRiseModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(DesignSystem.Colors.surfaceOverlay)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: DesignSystem.CornerRadius.xl,
                    topTrailingRadius: DesignSystem.CornerRadius.xl
                )
            )
            .transition(
                reduceMotion
                    ? .opacity
                    : .move(edge: .bottom).combined(with: .opacity)
            )
            .onAppear {
                HapticManager.shared.sheetPresent()
            }
            .onDisappear {
                HapticManager.shared.sheetDismiss()
            }
    }
}

extension View {
    func sheetRise() -> some View {
        modifier(SheetRiseModifier())
    }
}
```

**Step 5: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 6: Commit**

```bash
git add TechnIQ/TransitionSystem.swift
git commit -m "feat: add pulse expand, card flip, countdown burst, sheet rise transitions"
```

---

### Task 9: ModernComponents — ModernCard + ModernButton Upgrade

**Files:**
- Modify: `TechnIQ/ModernComponents.swift` (lines 4-125)

**Step 1: Upgrade ModernButton**

Changes:
- Add `.accent` case to ButtonStyle enum (gold fill, dark text)
- Primary background: solid `primaryGreen` (not gradient — bolder on dark). Add subtle gradient sheen overlay (5% white→transparent top-to-bottom)
- Primary foreground: `textOnAccent` (dark text on bright green)
- Secondary: transparent + 1.5pt `primaryGreen` border. Press fill: `primaryGreen.opacity(0.12)`
- Ghost: press fill → `surfaceHighlight`
- Danger: `error` (#FF3B5C) fill → white text
- Accent: `accentGold` fill → `textOnAccent`
- Haptics: primary/danger/accent → `HapticManager.shared.mediumTap()`, secondary/ghost → `HapticManager.shared.selectionChanged()`
- All buttons get `.overlay(LinearGradient(colors: [.white.opacity(0.05), .clear], startPoint: .top, endPoint: .bottom))` for sheen

**Step 2: Upgrade ModernCard**

Changes:
- Background: `surfaceRaised` (was `cardBackground` which now maps to same)
- Add 1pt border: `.overlay(RoundedRectangle(...).stroke(Color.white.opacity(0.06), lineWidth: 1))`
- Add optional `accentEdge` parameter (`.leading` or `.top`, Color). When set, draw a 3pt accent border on that edge
- Shadow: use adaptive — `glowMedium` in dark, `Shadow.medium` in light. Use `@Environment(\.colorScheme)` to switch
- Add optional `onTap` closure. When provided, card becomes tappable with scale 0.97 press state + light haptic

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/ModernComponents.swift
git commit -m "feat: upgrade ModernButton with accent style and ModernCard with glow borders"
```

---

### Task 10: ModernComponents — TextField, StatCard, ProgressRing

**Files:**
- Modify: `TechnIQ/ModernComponents.swift`

**Step 1: Upgrade ModernTextField**

Changes:
- Background: `surfaceHighlight` (was `backgroundSecondary`)
- Border: `Color.white.opacity(0.1)` default, `primaryGreen` 2pt on focus (was `neutral300`)
- Icon tint: `primaryGreen` on focus (keep existing)
- Label color: `primaryGreen` on focus (keep existing)
- Text font: `bodyMedium` (keep, now 15pt from Task 2)

**Step 2: Upgrade StatCard**

Changes:
- Value font: `displaySmall` (now 28pt .rounded from Task 2, was `numberMedium`)
- Icon container: circle shape with `color.opacity(0.08)` fill and `color.opacity(0.15)` glow shadow (was square with 0.1 opacity)
- Background comes from ModernCard upgrade (surfaceRaised + border already applied via Task 9)

**Step 3: Upgrade ProgressRing**

Changes:
- Track: `Color.white.opacity(0.08)` (was `neutral200`)
- Fill: `AngularGradient` from `primaryGreen` to `accentGold` instead of flat color
- Add glow: `.shadow(color: color.opacity(0.4), radius: 4)` on the fill stroke
- Add completion haptic: when `progress >= 1.0`, fire `HapticManager.shared.success()`

**Step 4: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 5: Commit**

```bash
git add TechnIQ/ModernComponents.swift
git commit -m "feat: upgrade TextField, StatCard, ProgressRing for dark-first aesthetic"
```

---

### Task 11: ModernComponents — New Components (GlowBadge, ActionChip)

**Files:**
- Modify: `TechnIQ/ModernComponents.swift` (append before Preview section)

**Step 1: Add GlowBadge component**

```swift
// MARK: - Glow Badge Component
struct GlowBadge: View {
    let text: String
    let color: Color
    let icon: String?

    @State private var appeared = false

    init(_ text: String, color: Color = DesignSystem.Colors.primaryGreen, icon: String? = nil) {
        self.text = text
        self.color = color
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
            }
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(.bold)
                .textCase(.uppercase)
        }
        .foregroundColor(color)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        .shadow(color: color.opacity(appeared ? 0.3 : 0), radius: 8)
        .scaleEffect(appeared ? 1.0 : 0.8)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(DesignSystem.Animation.springBouncy) {
                appeared = true
            }
        }
    }
}
```

**Step 2: Add ActionChip component (replaces CompactActionButton pattern)**

```swift
// MARK: - Action Chip Component
struct ActionChip: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    init(_ title: String, icon: String, color: Color = DesignSystem.Colors.primaryGreen, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding(.vertical, DesignSystem.Spacing.sm)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .background(color.opacity(isPressed ? 0.2 : 0.1))
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
```

**Step 3: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 4: Commit**

```bash
git add TechnIQ/ModernComponents.swift
git commit -m "feat: add GlowBadge and ActionChip components"
```

---

### Task 12: ModernComponents — AnimatedTabBar + Segment Control + Pill Selectors

**Files:**
- Modify: `TechnIQ/ModernComponents.swift`

**Step 1: Upgrade AnimatedTabBar**

Changes:
- Selected capsule: `primaryGreen.opacity(0.2)` → `primaryGreen.opacity(0.15)` with `.shadow(color: primaryGreen.opacity(0.3), radius: 8)` for glow effect
- Icon: use `HapticManager.shared.tabChanged()` instead of inline `UIImpactFeedbackGenerator`
- Background: `surfaceRaised` (was `cardBackground`)
- Add `@Environment(\.accessibilityReduceMotion)` — skip matchedGeometry animation when reduce motion enabled

**Step 2: Upgrade ModernSegmentControl**

Changes:
- Background: `surfaceHighlight` (was `backgroundSecondary`)
- Add `HapticManager.shared.selectionChanged()` on segment change
- Keep matchedGeometryEffect (already exists)

**Step 3: Upgrade PillSelector and MultiSelectPillSelector**

Changes:
- Selected background: `primaryGreen` (stays same, now emerald)
- Unselected background: `surfaceHighlight` (was `neutral200`)
- Add `HapticManager.shared.selectionChanged()` on selection change

**Step 4: Upgrade FloatingActionButton**

Changes:
- Use `HapticManager.shared.mediumTap()` instead of inline UIImpactFeedbackGenerator
- Add glow shadow: `.shadow(color: color.opacity(0.4), radius: 12)`
- Background: solid color (stays)

**Step 5: Upgrade SoccerBallSpinner**

Changes:
- Color: `primaryGreen` (stays, now emerald)

**Step 6: Upgrade ModernAlert**

Changes:
- Background: `surfaceOverlay` (was `background`)

**Step 7: Update Preview provider**

Add GlowBadge and ActionChip to preview.

**Step 8: Build to verify**

Run build command. Expected: BUILD SUCCEEDED.

**Step 9: Commit**

```bash
git add TechnIQ/ModernComponents.swift
git commit -m "feat: upgrade tab bar, segments, pills with haptics and dark-first styling"
```

---

### Task 13: Add New Files to Xcode Project

**Files:**
- Modify: `TechnIQ.xcodeproj/project.pbxproj`

**Step 1: Verify new files are in the build**

Run build. If `TransitionSystem.swift` and `AccessibilityModifiers.swift` are NOT picked up automatically (build errors about missing types), add them to the Xcode project using a ruby script:

```ruby
require 'xcodeproj'
project = Xcodeproj::Project.open('TechnIQ.xcodeproj')
target = project.targets.find { |t| t.name == 'TechnIQ' }
group = project.main_group.find_subpath('TechnIQ', true)

['AccessibilityModifiers.swift', 'TransitionSystem.swift'].each do |filename|
  ref = group.new_file(filename)
  target.source_build_phase.add_file_reference(ref)
end

project.save
```

**Step 2: Build to verify**

Run build command. Expected: BUILD SUCCEEDED with all new types accessible.

**Step 3: Commit**

```bash
git add TechnIQ.xcodeproj/project.pbxproj
git commit -m "chore: add new files to Xcode project"
```

---

### Task 14: Final Build Verification + Smoke Test

**Files:** None (verification only)

**Step 1: Clean build**

```bash
xcodebuild clean -scheme TechnIQ -sdk iphonesimulator
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build
```

Expected: BUILD SUCCEEDED with 0 errors.

**Step 2: Verify no regressions in existing views**

Check that the 54 files referencing `DesignSystem.Colors.primaryGreen` (409 occurrences) still compile. The clean build in Step 1 confirms this.

**Step 3: Verify token names preserved**

Spot-check that these still exist and compile:
- `DesignSystem.Colors.primaryGreen`
- `DesignSystem.Colors.textPrimary`
- `DesignSystem.Colors.cardBackground`
- `DesignSystem.Typography.headlineLarge`
- `DesignSystem.Shadow.medium`
- `DesignSystem.Animation.spring`

All should resolve without errors.

**Step 4: Tag the foundation milestone**

```bash
git tag ui-foundation-v1
```

---

## Summary

| Task | File | What |
|------|------|------|
| 1 | DesignSystem.swift | Dark-first emerald+gold colors |
| 2 | DesignSystem.swift | Rounded athletic typography |
| 3 | DesignSystem.swift | Glow shadows + animation curves |
| 4 | AccessibilityModifiers.swift | .a11y() + reduce motion helpers |
| 5 | HapticManager.swift | Transition haptic methods |
| 6 | TransitionSystem.swift | Stagger reveal + tab morph |
| 7 | TransitionSystem.swift | Hero transition |
| 8 | TransitionSystem.swift | Pulse, flip, countdown, sheet |
| 9 | ModernComponents.swift | Button + Card upgrade |
| 10 | ModernComponents.swift | TextField, StatCard, ProgressRing |
| 11 | ModernComponents.swift | GlowBadge + ActionChip |
| 12 | ModernComponents.swift | TabBar, Segment, Pills, FAB, Alert |
| 13 | project.pbxproj | Add new files to Xcode |
| 14 | — | Clean build verification |
