# Onboarding Overhaul + Pricing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the onboarding flow with "Value Sandwich" pattern (feature highlights → personalization → paywall) and add post-onboarding contextual tooltips.

**Architecture:** Refactor `UnifiedOnboardingView` from 5 steps to 9. Add 4 new feature highlight screens (1-4), refine existing personalization screens (5-7), keep plan gen (8), add new onboarding paywall (9). New `CoachMarkOverlay` view modifier for post-onboarding tooltips. Uses existing `SubscriptionManager` StoreKit 2 code.

**Tech Stack:** SwiftUI, StoreKit 2, Core Data, DesignSystem tokens, existing MascotView

---

### Task 1: Create Feature Highlight Screens (Screens 1-4)

**Files:**
- Create: `TechnIQ/Onboarding/FeatureHighlightView.swift`

**Step 1: Create the reusable FeatureHighlightPage component and 4 pages**

```swift
import SwiftUI

// MARK: - Feature Highlight Data

struct FeatureHighlight: Identifiable {
    let id = UUID()
    let headline: String
    let body: String
    let mascotState: MascotState
    let speechText: String
    let iconContent: FeatureIconContent
}

enum FeatureIconContent {
    case sfSymbol(name: String, color: Color)
    case multiIcon(icons: [(name: String, color: Color)])
}

// MARK: - Feature Highlight Page

struct FeatureHighlightPage: View {
    let highlight: FeatureHighlight

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Mascot
            MascotView(
                state: highlight.mascotState,
                size: .xlarge,
                showSpeechBubble: true,
                speechText: highlight.speechText
            )

            // Icon visual
            featureVisual

            // Text
            VStack(spacing: DesignSystem.Spacing.md) {
                Text(highlight.headline)
                    .font(DesignSystem.Typography.displaySmall)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(highlight.body)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    @ViewBuilder
    private var featureVisual: some View {
        switch highlight.iconContent {
        case .sfSymbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(DesignSystem.Spacing.lg)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 100, height: 100)
                )
        case .multiIcon(let icons):
            HStack(spacing: DesignSystem.Spacing.lg) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                    Image(systemName: icon.name)
                        .font(.system(size: 32))
                        .foregroundColor(icon.color)
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            Circle()
                                .fill(icon.color.opacity(0.12))
                        )
                }
            }
        }
    }
}

// MARK: - Feature Highlights Data

extension FeatureHighlight {
    static let onboardingHighlights: [FeatureHighlight] = [
        // Screen 2: AI Training
        FeatureHighlight(
            headline: "Smart Drills, Built for You",
            body: "AI generates personalized drills based on your position, skill level, and weaknesses",
            mascotState: .coaching,
            speechText: "I'll be your coach!",
            iconContent: .sfSymbol(name: "brain.head.profile", color: DesignSystem.Colors.primaryGreen)
        ),
        // Screen 3: Progress & XP
        FeatureHighlight(
            headline: "Level Up Your Game",
            body: "Earn XP, build streaks, unlock achievements. 50 levels from Grassroots to Living Legend",
            mascotState: .excited,
            speechText: "How far can you go?",
            iconContent: .multiIcon(icons: [
                ("star.fill", DesignSystem.Colors.xpGold),
                ("flame.fill", DesignSystem.Colors.streakOrange),
                ("trophy.fill", DesignSystem.Colors.accentGold)
            ])
        ),
        // Screen 4: Avatar & Rewards
        FeatureHighlight(
            headline: "Make It Yours",
            body: "Customize your player avatar. Earn coins from training to unlock gear",
            mascotState: .happy,
            speechText: "Express yourself!",
            iconContent: .multiIcon(icons: [
                ("person.crop.circle.fill", DesignSystem.Colors.primaryGreen),
                ("tshirt.fill", DesignSystem.Colors.secondaryBlue),
                ("shoe.fill", DesignSystem.Colors.accentOrange)
            ])
        )
    ]
}
```

**Step 2: Build the app and verify no compilation errors**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/Onboarding/FeatureHighlightView.swift
git commit -m "feat: add FeatureHighlightPage reusable component + onboarding highlight data"
```

---

### Task 2: Create Onboarding Paywall Screen (Screen 9)

**Files:**
- Create: `TechnIQ/Onboarding/OnboardingPaywallView.swift`

**Step 1: Create the onboarding paywall view**

```swift
import SwiftUI
import StoreKit

struct OnboardingPaywallView: View {
    let planName: String
    let onContinueFree: () -> Void
    let onPurchaseComplete: () -> Void

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showFreeConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [DesignSystem.Colors.accentGold, DesignSystem.Colors.accentOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Text("Unlock TechnIQ Pro")
                        .font(DesignSystem.Typography.displaySmall)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if !planName.isEmpty {
                        Text("Your \(planName) plan is ready")
                            .font(DesignSystem.Typography.bodyLarge)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
                .padding(.top, DesignSystem.Spacing.xl)

                // Benefits
                ModernCard {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        benefitRow("Unlimited AI-generated drills", icon: "brain.head.profile")
                        benefitRow("Personalized training plans", icon: "calendar.badge.plus")
                        benefitRow("Animated drill walkthroughs", icon: "play.circle.fill")
                        benefitRow("Smart weakness recommendations", icon: "sparkles")
                        benefitRow("Full progress analytics", icon: "chart.line.uptrend.xyaxis")
                        benefitRow("All avatar items & rewards", icon: "person.crop.circle.badge.checkmark")
                    }
                }

                // Trial timeline
                if subscriptionManager.hasTrialOffer {
                    trialTimeline
                }

                // Pricing
                VStack(spacing: DesignSystem.Spacing.sm) {
                    if subscriptionManager.hasTrialOffer {
                        Text("7 days free, then \(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    } else {
                        Text("\(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Text("Cancel anytime")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                // Purchase CTA
                ModernButton(
                    subscriptionManager.hasTrialOffer ? "Start Your 7-Day Free Trial" : "Subscribe Now",
                    icon: "crown.fill",
                    style: .primary
                ) {
                    Task {
                        await subscriptionManager.purchase()
                        if subscriptionManager.isPro {
                            onPurchaseComplete()
                        }
                    }
                }
                .disabled(subscriptionManager.isLoading)
                .overlay {
                    if subscriptionManager.isLoading {
                        ProgressView().tint(.white)
                    }
                }

                // Continue with Free
                Button {
                    showFreeConfirmation = true
                } label: {
                    Text("Continue with Free")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Restore
                Button {
                    Task { await subscriptionManager.restorePurchases() }
                } label: {
                    Text("Restore Purchases")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .disabled(subscriptionManager.isLoading)

                // Legal
                legalText
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .sheet(isPresented: $showFreeConfirmation) {
            freeConfirmationSheet
        }
        .task {
            await subscriptionManager.loadProduct()
        }
        .alert("Error", isPresented: Binding(
            get: { subscriptionManager.errorMessage != nil },
            set: { if !$0 { subscriptionManager.errorMessage = nil } }
        )) {
            Button("OK") { subscriptionManager.errorMessage = nil }
        } message: {
            Text(subscriptionManager.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 20)

            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()
        }
    }

    private var trialTimeline: some View {
        HStack(spacing: 0) {
            // Today
            VStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen)
                    .frame(width: 12, height: 12)
                Text("Today")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("Trial Starts")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }

            // Line
            Rectangle()
                .fill(DesignSystem.Colors.primaryGreen.opacity(0.3))
                .frame(height: 2)

            // Day 7
            VStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(DesignSystem.Colors.accentGold)
                    .frame(width: 12, height: 12)
                Text("Day 7")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("First Charge")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.accentGold)
            }

            // Line
            Rectangle()
                .fill(DesignSystem.Colors.primaryGreen.opacity(0.3))
                .frame(height: 2)

            // Cancel
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                Text("Anytime")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Text("Cancel")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.surfaceRaised)
        )
    }

    private var freeConfirmationSheet: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Free Plan Includes")
                .font(DesignSystem.Typography.headlineMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                freeFeatureRow("1 custom AI drill")
                freeFeatureRow("1 quick AI drill")
                freeFeatureRow("Basic training sessions")
                freeFeatureRow("Progress tracking")
            }
            .padding(DesignSystem.Spacing.md)

            Text("Upgrade anytime in Settings")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            ModernButton("Continue with Free", style: .secondary) {
                showFreeConfirmation = false
                onContinueFree()
            }

            ModernButton(
                subscriptionManager.hasTrialOffer ? "Start Free Trial Instead" : "Subscribe Instead",
                style: .primary
            ) {
                showFreeConfirmation = false
                Task {
                    await subscriptionManager.purchase()
                    if subscriptionManager.isPro {
                        onPurchaseComplete()
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.screenPadding)
        .presentationDetents([.medium])
    }

    private func freeFeatureRow(_ text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }

    private var legalText: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("Payment charged to Apple ID at confirmation. Auto-renews unless cancelled 24 hours before period end.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)

            HStack(spacing: DesignSystem.Spacing.md) {
                Link("Terms of Service", destination: URL(string: "https://techniq.app/terms")!)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)

                Link("Privacy Policy", destination: URL(string: "https://techniq.app/privacy")!)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/Onboarding/OnboardingPaywallView.swift
git commit -m "feat: add onboarding paywall with trial timeline + free tier confirmation"
```

---

### Task 3: Create CoachMark Overlay System (Post-Onboarding Tooltips)

**Files:**
- Create: `TechnIQ/Components/CoachMarkOverlay.swift`

**Step 1: Create the CoachMarkManager and CoachMarkOverlay view modifier**

```swift
import SwiftUI

// MARK: - Coach Mark Manager

class CoachMarkManager {
    static let shared = CoachMarkManager()
    private init() {}

    private func key(for id: String) -> String {
        "hasSeenCoachMark_\(id)"
    }

    func hasSeen(_ id: String) -> Bool {
        UserDefaults.standard.bool(forKey: key(for: id))
    }

    func markSeen(_ id: String) {
        UserDefaults.standard.set(true, forKey: key(for: id))
    }

    func resetAll() {
        let keys = ["dashboard", "train", "plans", "progress", "avatar"]
        for k in keys {
            UserDefaults.standard.removeObject(forKey: key(for: k))
        }
    }
}

// MARK: - Coach Mark Data

struct CoachMarkInfo {
    let id: String
    let text: String
}

// MARK: - Coach Mark Overlay Modifier

struct CoachMarkModifier: ViewModifier {
    let info: CoachMarkInfo
    @State private var showCoachMark = false
    @State private var targetFrame: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            targetFrame = geo.frame(in: .global)
                        }
                }
            )
            .overlay {
                if showCoachMark {
                    coachMarkOverlay
                }
            }
            .onAppear {
                guard !CoachMarkManager.shared.hasSeen(info.id) else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(DesignSystem.Animations.smooth) {
                        showCoachMark = true
                    }
                }
            }
    }

    private var coachMarkOverlay: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            // Tooltip
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(info.text)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                Button("Got it") {
                    dismiss()
                }
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surfaceRaised)
                    .shadow(color: .black.opacity(0.2), radius: 12)
            )
            .padding(.horizontal, DesignSystem.Spacing.xl)
        }
    }

    private func dismiss() {
        withAnimation(DesignSystem.Animations.smooth) {
            showCoachMark = false
        }
        CoachMarkManager.shared.markSeen(info.id)
    }
}

// MARK: - View Extension

extension View {
    func coachMark(_ info: CoachMarkInfo) -> some View {
        modifier(CoachMarkModifier(info: info))
    }
}

// MARK: - Predefined Coach Marks

extension CoachMarkInfo {
    static let dashboard = CoachMarkInfo(id: "dashboard", text: "Start your first session here!")
    static let train = CoachMarkInfo(id: "train", text: "Browse drills or generate a custom AI drill")
    static let plans = CoachMarkInfo(id: "plans", text: "Your AI plan lives here. Complete sessions to progress")
    static let progress = CoachMarkInfo(id: "progress", text: "Track your XP, streaks, and skill growth")
    static let avatar = CoachMarkInfo(id: "avatar", text: "Earn coins from training to unlock gear")
}
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/Components/CoachMarkOverlay.swift
git commit -m "feat: add CoachMarkOverlay system for post-onboarding tooltips"
```

---

### Task 4: Refactor UnifiedOnboardingView — Update Step Count and Progress Bar

**Files:**
- Modify: `TechnIQ/UnifiedOnboardingView.swift`

**Step 1: Update the step constants and progress bar to 9 segments**

In `UnifiedOnboardingView`, change:

```swift
// Old (line 12):
private let totalSteps = 5

// New:
private let totalSteps = 9
```

Update `stepTitle` to handle all 9 steps:

```swift
private var stepTitle: String {
    switch currentStep {
    case 0: return "Welcome"
    case 1, 2, 3: return "TechnIQ"
    case 4: return "Your Goal"
    case 5: return "About You"
    case 6: return "Your Style"
    case 7: return "Your Plan"
    case 8: return "Go Pro"
    default: return ""
    }
}
```

Update the skip button to skip feature highlights (screens 0-3) → jump to screen 4:

```swift
// Old (line 122):
if currentStep < 2 {

// New:
if currentStep < 4 {
```

And the skip target:

```swift
// Old (line 125):
currentStep = 2

// New:
currentStep = 4
```

Update back button to show from step 1 to step 6 (not on welcome, plan gen, or paywall):

```swift
// Old (line 94):
if currentStep > 0 && currentStep < totalSteps - 1 {

// New:
if currentStep > 0 && currentStep < 7 {
```

**Step 2: Update stepContent to route new screens**

Replace the `stepContent` ViewBuilder:

```swift
@ViewBuilder
private var stepContent: some View {
    Group {
        switch currentStep {
        case 0:
            welcomeStep
        case 1, 2, 3:
            FeatureHighlightPage(
                highlight: FeatureHighlight.onboardingHighlights[currentStep - 1]
            )
        case 4:
            goalStep
        case 5:
            basicInfoStep
        case 6:
            positionStyleStep
        case 7:
            planGenerationStep
        case 8:
            OnboardingPaywallView(
                planName: selectedGoal,
                onContinueFree: { isOnboardingComplete = true },
                onPurchaseComplete: { isOnboardingComplete = true }
            )
        default:
            EmptyView()
        }
    }
    .transition(.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    ))
}
```

**Step 3: Update continueButton and its logic**

Update `continueButton` — hide on plan gen (step 7) and paywall (step 8):

```swift
private var continueButton: some View {
    Group {
        if currentStep < 7 {
            Button(action: {
                HapticManager.shared.mediumTap()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if currentStep == 6 {
                        // End of soccer profile — create player, then advance to plan gen
                        createPlayer()
                        currentStep += 1
                        generateInitialPlan()
                    } else {
                        currentStep += 1
                    }
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(buttonTitle)
                        .font(DesignSystem.Typography.labelLarge)
                        .fontWeight(.semibold)
                    if currentStep == 3 {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(canContinue ? DesignSystem.Colors.primaryGreen : Color.gray)
                .cornerRadius(DesignSystem.CornerRadius.button)
            }
            .disabled(!canContinue)
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, 34)
        }
    }
}
```

Update `buttonTitle`:

```swift
private var buttonTitle: String {
    switch currentStep {
    case 0: return "GET STARTED"
    case 3: return "LET'S SET UP YOUR PROFILE"
    case 6: return "GENERATE MY PLAN"
    default: return "CONTINUE"
    }
}
```

Update `canContinue`:

```swift
private var canContinue: Bool {
    switch currentStep {
    case 5:
        return !playerName.isEmpty
    default:
        return true
    }
}
```

**Step 4: Update plan generation completion to navigate to paywall instead of completing onboarding**

In `generateInitialPlan()`, change the success auto-navigate (around line 768):

```swift
// Old:
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    isOnboardingComplete = true
}

// New:
DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        currentStep = 8
    }
}
```

In the "Skip for Now" button in `planGenerationStep` error state, also navigate to paywall:

```swift
// Old:
Button("Skip for Now") {
    isOnboardingComplete = true
}

// New:
Button("Skip for Now") {
    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
        currentStep = 8
    }
}
```

**Step 5: Update MascotState.forOnboarding to handle 9 steps**

In `TechnIQ/MascotState.swift`, update:

```swift
static func forOnboarding(screenIndex: Int) -> MascotState {
    switch screenIndex {
    case 0: return .waving
    case 1...3: return .coaching
    case 4: return .coaching
    case 5: return .encouraging
    case 6: return .coaching
    case 7: return .thinking
    case 8: return .excited
    default: return .happy
    }
}
```

**Step 6: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 7: Commit**

```bash
git add TechnIQ/UnifiedOnboardingView.swift TechnIQ/MascotState.swift
git commit -m "feat: refactor onboarding to 9-step Value Sandwich flow with paywall"
```

---

### Task 5: Refine Personalization Screens (5-7)

**Files:**
- Modify: `TechnIQ/UnifiedOnboardingView.swift`

**Step 1: Add reinforcement text to goalStep (Screen 5)**

After the frequency selector in `goalStep`, add:

```swift
// After the ScrollView(.horizontal) for frequencies, add:
if !selectedGoal.isEmpty {
    Text("We'll tailor your drills to \(selectedGoal.lowercased())")
        .font(DesignSystem.Typography.bodySmall)
        .foregroundColor(DesignSystem.Colors.primaryGreen)
        .transition(.opacity)
        .animation(DesignSystem.Animations.smooth, value: selectedGoal)
}
```

**Step 2: Replace age slider with Picker wheel in basicInfoStep (Screen 6)**

Replace the age slider section with:

```swift
// Age Picker (wheel)
VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
    Text("Age")
        .font(DesignSystem.Typography.labelMedium)
        .foregroundColor(DesignSystem.Colors.textSecondary)

    Picker("Age", selection: $playerAge) {
        ForEach(8...25, id: \.self) { age in
            Text("\(age) years").tag(age)
        }
    }
    .pickerStyle(.wheel)
    .frame(height: 120)
    .clipped()
}
```

**Step 3: Add experience level descriptors**

Replace the experience level grid labels with descriptors:

```swift
private func experienceDescription(_ level: String) -> String {
    switch level {
    case "Beginner": return "Just starting out"
    case "Intermediate": return "Play regularly"
    case "Advanced": return "Club/travel team"
    case "Professional": return "Academy level"
    default: return ""
    }
}
```

Update the experience level buttons to show descriptors — replace the `Text(level)` label inside the `ForEach(experienceLevels)` grid button with:

```swift
VStack(spacing: 2) {
    Text(level)
        .font(DesignSystem.Typography.labelMedium)
        .fontWeight(.medium)
    Text(experienceDescription(level))
        .font(DesignSystem.Typography.labelSmall)
}
.foregroundColor(selectedExperienceLevel == level ? .white : DesignSystem.Colors.textPrimary)
.frame(maxWidth: .infinity)
.padding(.vertical, DesignSystem.Spacing.md)
.background(selectedExperienceLevel == level ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
.cornerRadius(DesignSystem.CornerRadius.sm)
```

**Step 4: Add playing style descriptors to positionStyleStep (Screen 7)**

Add helper:

```swift
private func styleDescriptor(_ style: String) -> String {
    switch style {
    case "Aggressive": return "Press high"
    case "Defensive": return "Stay back"
    case "Balanced": return "All-around"
    case "Creative": return "Flair moves"
    case "Fast": return "Quick counter"
    default: return ""
    }
}
```

Replace the playing style `FrequencyChip` usage with a version showing descriptors:

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: DesignSystem.Spacing.sm) {
        ForEach(playingStyles, id: \.self) { style in
            Button {
                selectedPlayingStyle = style
                HapticManager.shared.selectionChanged()
            } label: {
                VStack(spacing: 2) {
                    Text(style)
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.medium)
                    Text(styleDescriptor(style))
                        .font(DesignSystem.Typography.labelSmall)
                }
                .foregroundColor(selectedPlayingStyle == style ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(selectedPlayingStyle == style ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.pill)
            }
        }
    }
}
```

**Step 5: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 6: Commit**

```bash
git add TechnIQ/UnifiedOnboardingView.swift
git commit -m "feat: refine personalization screens — age wheel, descriptors, reinforcement text"
```

---

### Task 6: Add New Files to Xcode Project

**Files:**
- Modify: `TechnIQ.xcodeproj/project.pbxproj`

**Step 1: Create Onboarding group directory if needed**

```bash
mkdir -p TechnIQ/Onboarding TechnIQ/Components
```

**Step 2: Add file references to Xcode project**

Use a Ruby script to add the new files to the Xcode project:

```bash
ruby -e '
require "xcodeproj"
project = Xcodeproj::Project.open("TechnIQ.xcodeproj")
target = project.targets.find { |t| t.name == "TechnIQ" }
main_group = project.main_group.find_subpath("TechnIQ", true)

# Create Onboarding group
onboarding = main_group.find_subpath("Onboarding", false) || main_group.new_group("Onboarding", "Onboarding")
["FeatureHighlightView.swift", "OnboardingPaywallView.swift"].each do |f|
  ref = onboarding.new_file(f)
  target.source_build_phase.add_file_reference(ref)
end

# Create Components group (or find existing)
components = main_group.find_subpath("Components", false) || main_group.new_group("Components", "Components")
ref = components.new_file("CoachMarkOverlay.swift")
target.source_build_phase.add_file_reference(ref)

project.save
'
```

**Step 3: Build to verify project file is valid**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TechnIQ.xcodeproj/project.pbxproj
git commit -m "chore: add new onboarding + coach mark files to Xcode project"
```

---

### Task 7: Wire Coach Marks to Tab Views

**Files:**
- Modify: `TechnIQ/DashboardView.swift` — add `.coachMark(.dashboard)` to Today's Training CTA
- Modify: `TechnIQ/TrainHubView.swift` — add `.coachMark(.train)` to AI drill hero card
- Modify: `TechnIQ/TrainingPlansListView.swift` — add `.coachMark(.plans)` to active plan card
- Modify: `TechnIQ/EnhancedProfileView.swift` — add `.coachMark(.progress)` to stats section

**Step 1: Read each file to find exact insertion points**

Read the relevant views to locate the specific UI elements that should receive coach marks. Find the "Today's Training" button in DashboardView, the AI drill card in TrainHubView, the active plan in TrainingPlansListView, and the stats in EnhancedProfileView.

**Step 2: Add `.coachMark()` modifier to each target view**

For each file, add the modifier to the outermost container of the target element. Example pattern:

```swift
// In DashboardView, on the "Today's Training" button:
.coachMark(.dashboard)

// In TrainHubView, on the AI drill hero card:
.coachMark(.train)

// In TrainingPlansListView, on the active plan card:
.coachMark(.plans)

// In EnhancedProfileView, on the stats section:
.coachMark(.progress)
```

**Step 3: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add TechnIQ/DashboardView.swift TechnIQ/TrainHubView.swift TechnIQ/TrainingPlansListView.swift TechnIQ/EnhancedProfileView.swift
git commit -m "feat: wire coach mark tooltips to dashboard, train, plans, and profile tabs"
```

---

### Task 8: Add Swipe Gesture to Feature Highlight Screens

**Files:**
- Modify: `TechnIQ/UnifiedOnboardingView.swift`

**Step 1: Add swipe gesture to the stepContent for screens 0-3**

Add a `DragGesture` on the feature highlight screens:

```swift
// Wrap the stepContent in a gesture handler
@State private var dragOffset: CGFloat = 0

// In body, replace stepContent with:
stepContent
    .offset(x: dragOffset)
    .gesture(
        currentStep < 4 ? DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 50
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if value.translation.width < -threshold && currentStep < 3 {
                        currentStep += 1
                    } else if value.translation.width > threshold && currentStep > 0 {
                        currentStep -= 1
                    }
                    dragOffset = 0
                }
            } : nil
    )
```

**Step 2: Build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add TechnIQ/UnifiedOnboardingView.swift
git commit -m "feat: add swipe gesture navigation on feature highlight screens"
```

---

### Task 9: Pass SubscriptionManager as Environment Object

**Files:**
- Modify: `TechnIQ/TechnIQApp.swift` — ensure `.environmentObject(SubscriptionManager.shared)` is passed
- Modify: `TechnIQ/ContentView.swift` — ensure environment propagates to onboarding

**Step 1: Read TechnIQApp.swift to check if SubscriptionManager is already passed**

Read the file and verify. If not present, add `.environmentObject(SubscriptionManager.shared)` to the root ContentView in the app body.

**Step 2: Build and verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 3: Commit (if changes needed)**

```bash
git add TechnIQ/TechnIQApp.swift TechnIQ/ContentView.swift
git commit -m "fix: ensure SubscriptionManager environment object propagates to onboarding"
```

---

### Task 10: Final Build + Manual Test Walkthrough

**Step 1: Full clean build**

Run: `xcodebuild clean build -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: Manual test checklist**

Verify in simulator:
- [ ] Screen 1 (Welcome): mascot waving, "Get Started" button, no skip
- [ ] Screens 2-4 (Features): swipe left/right works, skip link jumps to Screen 5, progress bar fills
- [ ] Screen 5 (Goal): reinforcement text appears after goal selection
- [ ] Screen 6 (About You): age wheel picker, experience level descriptors visible
- [ ] Screen 7 (Style): playing style descriptors, position icons
- [ ] Screen 8 (Plan Gen): loading phases animate, success → auto-advances to paywall
- [ ] Screen 9 (Paywall): benefits list, trial timeline, "Continue with Free" shows sheet, purchase CTA works, restore link present, legal text present
- [ ] Post-onboarding: coach marks appear on first visit to each tab
- [ ] Coach marks don't reappear after dismissal

**Step 3: Commit any fixes**

```bash
git add -A && git commit -m "fix: address build/test issues from onboarding overhaul"
```
