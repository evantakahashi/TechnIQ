# Freemium Subscription Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add StoreKit 2 freemium subscription (Pro tier, $6.99/mo, 7-day trial) that gates AI features behind a paywall while keeping exercise library, session logging, stats, analytics, and onboarding plan free.

**Architecture:** Centralized `SubscriptionManager` singleton wrapping StoreKit 2, injected as `@EnvironmentObject`. Views check `isPro` before AI actions. Shared `PaywallView` presented as sheet. `ProLockedCardView` replaces passive AI sections for free users.

**Tech Stack:** StoreKit 2 (iOS 17+), SwiftUI, UserDefaults for free drill tracking

**Design doc:** `docs/plans/2026-02-18-freemium-subscription-design.md`

---

### Task 1: Create SubscriptionManager Service

**Files:**
- Create: `TechnIQ/SubscriptionManager.swift`

**Step 1: Create SubscriptionManager.swift**

```swift
import StoreKit
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var isPro: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let productID = "com.techniq.pro.monthly"
    private var product: Product?
    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactions()
        Task { await checkEntitlement() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.checkEntitlement()
                }
            }
        }
    }

    // MARK: - Entitlement Check

    func checkEntitlement() async {
        var hasEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                hasEntitlement = true
                break
            }
        }
        isPro = hasEntitlement
    }

    // MARK: - Load Product

    func loadProduct() async {
        guard product == nil else { return }
        do {
            let products = try await Product.products(for: [productID])
            product = products.first
        } catch {
            #if DEBUG
            print("Failed to load product: \(error)")
            #endif
        }
    }

    // MARK: - Purchase

    func purchase() async {
        isLoading = true
        errorMessage = nil

        await loadProduct()
        guard let product else {
            errorMessage = "Product not available. Please try again later."
            isLoading = false
            return
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await checkEntitlement()
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        try? await AppStore.sync()
        await checkEntitlement()
        if !isPro {
            errorMessage = "No active subscription found."
        }
        isLoading = false
    }

    // MARK: - Product Info

    var displayPrice: String {
        product?.displayPrice ?? "$6.99"
    }

    var subscriptionPeriod: String {
        "month"
    }

    /// Whether user has an introductory offer available (free trial)
    var hasTrialOffer: Bool {
        product?.subscription?.introductoryOffer != nil
    }

    var trialDuration: String {
        guard let offer = product?.subscription?.introductoryOffer else { return "" }
        return "\(offer.period.value) \(offer.period.unit)"
    }

    // MARK: - Free Drill Tracking

    static let hasUsedFreeCustomDrillKey = "hasUsedFreeCustomDrill"
    static let hasUsedFreeQuickDrillKey = "hasUsedFreeQuickDrill"

    var hasUsedFreeCustomDrill: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasUsedFreeCustomDrillKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasUsedFreeCustomDrillKey) }
    }

    var hasUsedFreeQuickDrill: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasUsedFreeQuickDrillKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasUsedFreeQuickDrillKey) }
    }

    /// Returns true if drill should proceed, false if paywall needed
    func canUseCustomDrill() -> Bool {
        isPro || !hasUsedFreeCustomDrill
    }

    func canUseQuickDrill() -> Bool {
        isPro || !hasUsedFreeQuickDrill
    }

    func markCustomDrillUsed() {
        if !isPro { hasUsedFreeCustomDrill = true }
    }

    func markQuickDrillUsed() {
        if !isPro { hasUsedFreeQuickDrill = true }
    }
}
```

**Step 2: Add file to Xcode project**

Run: `ruby add_files.rb` or manually add `SubscriptionManager.swift` to the TechnIQ target in Xcode. (If the project auto-discovers files in the group folder, just placing the file is sufficient.)

**Step 3: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add TechnIQ/SubscriptionManager.swift
git commit -m "feat: add SubscriptionManager with StoreKit 2 subscription handling"
```

---

### Task 2: Inject SubscriptionManager into App

**Files:**
- Modify: `TechnIQ/TechnIQApp.swift:54-62`

**Step 1: Add @StateObject and environmentObject**

In `TechnIQApp.swift`, add a `@StateObject` property and inject it into the view hierarchy:

```swift
// Add after line 19 (@AppStorage line):
@StateObject private var subscriptionManager = SubscriptionManager.shared
```

```swift
// In body, add .environmentObject after line 59:
.environmentObject(subscriptionManager)
```

The body should look like:

```swift
var body: some Scene {
    WindowGroup {
        ContentView()
            .environment(\.managedObjectContext, coreDataManager.context)
            .environmentObject(coreDataManager)
            .environmentObject(authManager)
            .environmentObject(subscriptionManager)
            .preferredColorScheme(appColorScheme.toColorScheme)
    }
}
```

**Step 2: Add StoreKit import**

Add `import StoreKit` at the top of TechnIQApp.swift (not strictly required since SubscriptionManager handles it, but good practice).

**Step 3: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add TechnIQ/TechnIQApp.swift
git commit -m "feat: inject SubscriptionManager as environmentObject"
```

---

### Task 3: Create PaywallView

**Files:**
- Create: `TechnIQ/PaywallView.swift`

**Step 1: Create PaywallView.swift**

```swift
import SwiftUI
import StoreKit

// MARK: - Paywall Feature Context
enum PaywallFeature {
    case trainingPlan
    case customDrill
    case quickDrill
    case dailyCoaching
    case mlRecommendations
    case youtubeRecs
    case weeklyAdaptation

    var title: String {
        switch self {
        case .trainingPlan: return "AI Training Plans"
        case .customDrill: return "Custom AI Drills"
        case .quickDrill: return "Quick AI Drills"
        case .dailyCoaching: return "Daily AI Coaching"
        case .mlRecommendations: return "Smart Recommendations"
        case .youtubeRecs: return "YouTube AI Picks"
        case .weeklyAdaptation: return "Plan Adaptation"
        }
    }

    var icon: String {
        switch self {
        case .trainingPlan: return "calendar.badge.plus"
        case .customDrill: return "brain.head.profile"
        case .quickDrill: return "bolt.fill"
        case .dailyCoaching: return "message.badge.waveform"
        case .mlRecommendations: return "sparkles"
        case .youtubeRecs: return "play.rectangle.fill"
        case .weeklyAdaptation: return "arrow.triangle.2.circlepath"
        }
    }

    var description: String {
        switch self {
        case .trainingPlan: return "Generate unlimited personalized training plans with AI"
        case .customDrill: return "Create custom drills tailored to your skill level"
        case .quickDrill: return "Instantly generate drills from a quick description"
        case .dailyCoaching: return "Get daily AI-powered coaching tips and focus areas"
        case .mlRecommendations: return "Receive smart drill recommendations based on your training"
        case .youtubeRecs: return "Discover curated YouTube drills matched to your needs"
        case .weeklyAdaptation: return "Automatically adapt your plan based on weekly progress"
        }
    }
}

// MARK: - PaywallView
struct PaywallView: View {
    let feature: PaywallFeature
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Feature Header
                    featureHeader

                    // Pro Benefits
                    proBenefits

                    // Pricing
                    pricingSection

                    // CTA
                    purchaseButton

                    // Restore
                    restoreButton

                    // Terms
                    termsText
                }
                .padding(DesignSystem.Spacing.screenPadding)
            }
            .adaptiveBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.title3)
                    }
                }
            }
            .alert("Error", isPresented: .constant(subscriptionManager.errorMessage != nil)) {
                Button("OK") { subscriptionManager.errorMessage = nil }
            } message: {
                Text(subscriptionManager.errorMessage ?? "")
            }
            .onChange(of: subscriptionManager.isPro) { isPro in
                if isPro { dismiss() }
            }
        }
        .task {
            await subscriptionManager.loadProduct()
        }
    }

    // MARK: - Feature Header
    private var featureHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: feature.icon)
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [DesignSystem.Colors.primaryGreen, DesignSystem.Colors.accentGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(DesignSystem.Spacing.lg)
                .background(
                    Circle()
                        .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                )

            Text("Unlock \(feature.title)")
                .font(DesignSystem.Typography.headlineLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(feature.description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DesignSystem.Spacing.lg)
    }

    // MARK: - Pro Benefits
    private var proBenefits: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("TechnIQ Pro includes:")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                benefitRow("Unlimited AI training plans", icon: "calendar.badge.plus")
                benefitRow("Custom & quick drill generator", icon: "brain.head.profile")
                benefitRow("Daily AI coaching", icon: "message.badge.waveform")
                benefitRow("Smart drill recommendations", icon: "sparkles")
                benefitRow("YouTube AI drill picks", icon: "play.rectangle.fill")
                benefitRow("Weekly plan adaptation", icon: "arrow.triangle.2.circlepath")
            }
        }
    }

    private func benefitRow(_ text: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .frame(width: 24)
            Text(text)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Spacer()
        }
    }

    // MARK: - Pricing
    private var pricingSection: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if subscriptionManager.hasTrialOffer {
                Text("7 days free, then \(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            } else {
                Text("\(subscriptionManager.displayPrice)/\(subscriptionManager.subscriptionPeriod)")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Text("Cancel anytime")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Purchase Button
    private var purchaseButton: some View {
        ModernButton(
            subscriptionManager.hasTrialOffer ? "Start Free Trial" : "Subscribe Now",
            icon: "crown.fill",
            style: .primary
        ) {
            Task { await subscriptionManager.purchase() }
        }
        .disabled(subscriptionManager.isLoading)
        .overlay {
            if subscriptionManager.isLoading {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    // MARK: - Restore
    private var restoreButton: some View {
        Button {
            Task { await subscriptionManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .disabled(subscriptionManager.isLoading)
    }

    // MARK: - Terms
    private var termsText: some View {
        Text("Payment will be charged to your Apple ID account at the confirmation of purchase. Subscription automatically renews unless it is cancelled at least 24 hours before the end of the current period.")
            .font(DesignSystem.Typography.bodySmall)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .multilineTextAlignment(.center)
    }
}
```

**Step 2: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 3: Commit**

```bash
git add TechnIQ/PaywallView.swift
git commit -m "feat: add PaywallView with contextual feature upsell"
```

---

### Task 4: Create ProLockedCardView

**Files:**
- Create: `TechnIQ/ProLockedCardView.swift`

**Step 1: Create ProLockedCardView.swift**

This replaces passive AI sections (coaching, ML recs) on the dashboard for free users.

```swift
import SwiftUI

struct ProLockedCardView: View {
    let feature: PaywallFeature
    @State private var showingPaywall = false

    var body: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: feature.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(feature.title)
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(feature.description)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.accentGold)
                }

                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Unlock with Pro")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accentGold.opacity(0.15))
                    .foregroundColor(DesignSystem.Colors.accentGold)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: feature)
        }
    }
}
```

**Step 2: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 3: Commit**

```bash
git add TechnIQ/ProLockedCardView.swift
git commit -m "feat: add ProLockedCardView teaser for locked AI features"
```

---

### Task 5: Gate AI Training Plan Generation

**Files:**
- Modify: `TechnIQ/TrainingPlansListView.swift:175`

**Step 1: Add subscription state and paywall sheet**

At the top of `TrainingPlansListView`, add:

```swift
@EnvironmentObject private var subscriptionManager: SubscriptionManager
@State private var showingPaywall = false
```

**Step 2: Wrap the "Generate with AI" button**

Replace the button at line 175:

```swift
// Old:
ModernButton("Generate with AI", icon: "sparkles", style: .primary) {
    showingAIGenerator = true
}

// New:
ModernButton("Generate with AI", icon: "sparkles", style: .primary) {
    if subscriptionManager.isPro {
        showingAIGenerator = true
    } else {
        showingPaywall = true
    }
}
```

**Step 3: Add paywall sheet**

Add to the view's sheet modifiers:

```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView(feature: .trainingPlan)
}
```

**Step 4: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 5: Commit**

```bash
git add TechnIQ/TrainingPlansListView.swift
git commit -m "feat: gate AI training plan generation behind Pro subscription"
```

---

### Task 6: Gate Custom Drill Generator

**Files:**
- Modify: `TechnIQ/ExerciseLibraryView.swift:360-366`

**Step 1: Add subscription state and paywall sheet**

At the top of `ExerciseLibraryView`, add:

```swift
@EnvironmentObject private var subscriptionManager: SubscriptionManager
@State private var showingDrillPaywall = false
@State private var showingYouTubePaywall = false
```

**Step 2: Gate the AI drill button (line ~364)**

```swift
// Old:
CompactActionButton(
    title: "AI",
    icon: "brain.head.profile",
    color: DesignSystem.Colors.primaryGreen
) {
    showingCustomDrillGenerator = true
}

// New:
CompactActionButton(
    title: "AI",
    icon: "brain.head.profile",
    color: DesignSystem.Colors.primaryGreen
) {
    if subscriptionManager.canUseCustomDrill() {
        showingCustomDrillGenerator = true
    } else {
        showingDrillPaywall = true
    }
}
```

**Step 3: Gate the YouTube button (line ~382)**

```swift
// Old:
CompactActionButton(
    title: "YouTube",
    icon: "play.rectangle.fill",
    color: DesignSystem.Colors.error
) {
    loadYouTubeContent()
}
.disabled(isLoadingYouTubeContent)

// New:
CompactActionButton(
    title: "YouTube",
    icon: "play.rectangle.fill",
    color: DesignSystem.Colors.error
) {
    if subscriptionManager.isPro {
        loadYouTubeContent()
    } else {
        showingYouTubePaywall = true
    }
}
.disabled(isLoadingYouTubeContent)
```

**Step 4: Mark free custom drill as used**

In the `.sheet` for `showingCustomDrillGenerator`, add an `onDismiss` or wrap the drill generation callback. The simplest approach: in `CustomDrillGeneratorView`'s success path, call `SubscriptionManager.shared.markCustomDrillUsed()` after successful generation. Find the success handler in `CustomDrillGeneratorView.swift` near line 355 and add after the drill is saved:

```swift
SubscriptionManager.shared.markCustomDrillUsed()
```

**Step 5: Add paywall sheets**

```swift
.sheet(isPresented: $showingDrillPaywall) {
    PaywallView(feature: .customDrill)
}
.sheet(isPresented: $showingYouTubePaywall) {
    PaywallView(feature: .youtubeRecs)
}
```

**Step 6: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 7: Commit**

```bash
git add TechnIQ/ExerciseLibraryView.swift TechnIQ/CustomDrillGeneratorView.swift
git commit -m "feat: gate custom drill and YouTube recs behind Pro"
```

---

### Task 7: Gate Quick Drill and Dashboard Passive Features

**Files:**
- Modify: `TechnIQ/DashboardView.swift`

**Step 1: Add subscription state and paywall sheets**

At the top of `DashboardView` state properties (around line 36-57), add:

```swift
@EnvironmentObject private var subscriptionManager: SubscriptionManager
@State private var showingQuickDrillPaywall = false
```

**Step 2: Gate the AI Drill Hero Banner (line ~224)**

In `aiDrillHeroBanner()`, replace the button action:

```swift
// Old:
Button {
    showingQuickDrill = true
} label: {

// New:
Button {
    if subscriptionManager.canUseQuickDrill() {
        showingQuickDrill = true
    } else {
        showingQuickDrillPaywall = true
    }
} label: {
```

**Step 3: Gate the "Quick Drill" action card (line ~601-607)**

```swift
// Old:
ModernActionCard(
    title: "Quick Drill",
    icon: "bolt.fill",
    color: DesignSystem.Colors.accentOrange
) {
    showingQuickDrill = true
}

// New:
ModernActionCard(
    title: "Quick Drill",
    icon: "bolt.fill",
    color: DesignSystem.Colors.accentOrange
) {
    if subscriptionManager.canUseQuickDrill() {
        showingQuickDrill = true
    } else {
        showingQuickDrillPaywall = true
    }
}
```

**Step 4: Mark free quick drill as used**

In `QuickDrillSheet.swift`, after the drill is successfully generated (near line 108 where the callback fires), add:

```swift
SubscriptionManager.shared.markQuickDrillUsed()
```

**Step 5: Replace coaching section with teaser for free users**

In `todaysFocusSection(player:)` (line ~341), wrap the existing content:

```swift
@ViewBuilder
private func todaysFocusSection(player: Player) -> some View {
    if subscriptionManager.isPro {
        if aiCoachService.isLoading {
            TodaysFocusCardSkeleton()
        } else if let coaching = aiCoachService.dailyCoaching {
            TodaysFocusCard(
                coaching: coaching,
                isStale: aiCoachService.isCacheStale,
                onStartDrill: {
                    launchAIDrill(coaching.recommendedDrill, for: player)
                },
                onBrowseLibrary: {
                    selectedTab = 2
                }
            )
        }
    } else {
        ProLockedCardView(feature: .dailyCoaching)
    }
}
```

**Step 6: Replace ML recommendations section with teaser for free users**

In `modernRecommendations(player:)` (line ~787), wrap:

```swift
private func modernRecommendations(player: Player) -> some View {
    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
        Text("Recommended for You")
            .font(DesignSystem.Typography.headlineSmall)
            .foregroundColor(DesignSystem.Colors.textPrimary)
            .fontWeight(.bold)

        if subscriptionManager.isPro {
            // Existing ModernCard with recommendations content
            ModernCard {
                // ... existing content unchanged ...
            }
        } else {
            ProLockedCardView(feature: .mlRecommendations)
        }
    }
}
```

**Step 7: Prevent auto-fetching coaching/recs for free users**

In the `.onAppear` block (line ~134), guard the AI calls:

```swift
// Old:
if let player = currentPlayer {
    Task {
        await aiCoachService.fetchDailyCoachingIfNeeded(for: player)
    }
}

// New:
if let player = currentPlayer, subscriptionManager.isPro {
    Task {
        await aiCoachService.fetchDailyCoachingIfNeeded(for: player)
    }
}
```

Similarly guard `loadSmartRecommendations` call behind `subscriptionManager.isPro`.

**Step 8: Add paywall sheet**

```swift
.sheet(isPresented: $showingQuickDrillPaywall) {
    PaywallView(feature: .quickDrill)
}
```

**Step 9: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 10: Commit**

```bash
git add TechnIQ/DashboardView.swift TechnIQ/QuickDrillSheet.swift
git commit -m "feat: gate quick drill, coaching, and ML recs on dashboard"
```

---

### Task 8: Gate Weekly Plan Adaptation

**Files:**
- Modify: `TechnIQ/SessionCompleteView.swift:73-75`

**Step 1: Add subscription state**

Add to `SessionCompleteView`:

```swift
@EnvironmentObject private var subscriptionManager: SubscriptionManager
@State private var showingAdaptationPaywall = false
```

**Step 2: Gate the weekly check-in card**

Replace the weekly check-in conditional (line ~73):

```swift
// Old:
if aiCoachService.weeklyCheckInAvailable {
    weeklyCheckInCard
}

// New:
if aiCoachService.weeklyCheckInAvailable {
    if subscriptionManager.isPro {
        weeklyCheckInCard
    } else {
        ProLockedCardView(feature: .weeklyAdaptation)
            .padding(.horizontal, DesignSystem.Spacing.md)
    }
}
```

**Step 3: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 4: Commit**

```bash
git add TechnIQ/SessionCompleteView.swift
git commit -m "feat: gate weekly plan adaptation behind Pro"
```

---

### Task 9: Add Subscription Section to Settings

**Files:**
- Modify: `TechnIQ/SettingsView.swift`

**Step 1: Add subscription state**

Add to `SettingsView`:

```swift
@EnvironmentObject private var subscriptionManager: SubscriptionManager
@State private var showingPaywall = false
```

**Step 2: Add subscription section**

Insert a new `Section` before the Appearance section (before line 24):

```swift
Section {
    if subscriptionManager.isPro {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(DesignSystem.Colors.accentGold)
            Text("TechnIQ Pro")
                .font(DesignSystem.Typography.labelLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Spacer()
            GlowBadge("Active", color: DesignSystem.Colors.primaryGreen)
        }

        Button {
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack {
                Text("Manage Subscription")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    } else {
        Button {
            showingPaywall = true
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(DesignSystem.Colors.accentGold)
                Text("Upgrade to Pro")
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
    }

    Button {
        Task { await subscriptionManager.restorePurchases() }
    } label: {
        Text("Restore Purchases")
    }
    .disabled(subscriptionManager.isLoading)
} header: {
    Text("Subscription")
}
```

**Step 3: Add paywall sheet**

```swift
.sheet(isPresented: $showingPaywall) {
    PaywallView(feature: .trainingPlan)
}
```

**Step 4: Build**

Run: `/build`
Expected: Compiles with no errors

**Step 5: Commit**

```bash
git add TechnIQ/SettingsView.swift
git commit -m "feat: add subscription management section to Settings"
```

---

### Task 10: Add Files to Xcode Project & Final Build

**Files:**
- Modify: `TechnIQ.xcodeproj/project.pbxproj` (via ruby script or Xcode)

**Step 1: Ensure all new .swift files are in the Xcode target**

The 3 new files need to be added to the TechnIQ target:
- `SubscriptionManager.swift`
- `PaywallView.swift`
- `ProLockedCardView.swift`

If files aren't auto-discovered, run the `add_files.rb` script or add manually via Xcode.

**Step 2: Full build**

Run: `/build`
Expected: Clean build with 0 errors

**Step 3: Final commit**

```bash
git add -A
git commit -m "feat: complete freemium subscription implementation"
```

---

## Post-Implementation Notes

### App Store Connect Setup (Manual)
1. Go to App Store Connect → My Apps → TechnIQ → Subscriptions
2. Create subscription group "TechnIQ Pro"
3. Add product: `com.techniq.pro.monthly`, $6.99, auto-renewable
4. Add 7-day free trial as introductory offer
5. Add localization (English): "TechnIQ Pro" / "Unlock unlimited AI training plans, custom drills, daily coaching, and more."

### Testing
- Use StoreKit Configuration file (`.storekit`) for Xcode testing without App Store Connect
- Test: purchase flow, cancel, restore, lapsed state, free drill counters
- Verify onboarding plan still generates without paywall
- Verify existing plans remain accessible after subscription lapses
