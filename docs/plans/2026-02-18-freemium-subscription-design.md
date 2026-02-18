# Freemium Subscription Design

## Overview

Add StoreKit 2 freemium subscription to TechnIQ. One tier: Pro ($6.99/mo, 7-day free trial). AI features gated behind Pro; exercise library, session logging, basic stats, onboarding plan, and analytics stay free.

## Tiers

### Free
- Exercise library (45+ drills)
- Manual session logging + ratings/notes
- Basic stats + full analytics dashboard (InsightsEngine)
- 1 AI training plan (auto-generated during onboarding)
- 1 free custom drill (lifetime)
- 1 free quick drill (lifetime)
- Avatar/coin system (unchanged)
- Match logging + seasons

### Pro ($6.99/mo, 7-day free trial)
- Everything in Free
- Unlimited AI training plan generation
- Unlimited custom drill generation
- Unlimited quick drills
- YouTube AI recommendations
- ML drill recommendations on dashboard
- Daily AI coaching
- Weekly plan adaptation / check-in

## Architecture: Centralized Entitlement Service

### SubscriptionManager (new file)
- Singleton `SubscriptionManager.shared`, `@MainActor`, `ObservableObject`
- `@Published var isPro: Bool = false`
- `@Published var currentSubscription: StoreKit.Transaction?`
- On init: listens to `Transaction.updates`, checks `Transaction.currentEntitlements`
- Product ID: `com.techniq.pro.monthly`
- Methods: `purchase()`, `restorePurchases()`, `checkEntitlement()`
- Injected via `.environmentObject(SubscriptionManager.shared)` in `TechnIQApp.swift`
- StoreKit 2 on-device verification only (no server-side receipt validation)

### Free drill tracking
- `UserDefaults` keys: `hasUsedFreeCustomDrill`, `hasUsedFreeQuickDrill` (Bool)
- Checked alongside `isPro` for drill gates

## Gating Points

| Feature | Gate Location | Free User Behavior |
|---|---|---|
| AI Training Plan | TrainingPlansListView "Generate with AI" btn | PaywallView sheet |
| Onboarding Plan | UnifiedOnboardingView | **No gate** (stays free) |
| Custom Drill (full) | ExerciseLibraryView AI button | 1st free, then PaywallView |
| Quick Drill | DashboardView quick drill trigger | 1st free, then PaywallView |
| YouTube AI Recs | ExerciseLibraryView YouTube button | PaywallView sheet |
| ML Drill Recs | DashboardView recs section | ProLockedCardView teaser |
| Daily AI Coaching | DashboardView coach section | ProLockedCardView teaser |
| Weekly Plan Adaptation | SessionCompleteView check-in | PaywallView sheet |

### Lapsed Pro behavior
- Existing AI-generated plans remain accessible (read-only, can still train with them)
- Cannot generate new plans, drills, or access other Pro features
- Passive AI sections revert to teaser cards

## New Components

### PaywallView (new file)
- Presented as `.sheet` from any gated entry point
- Receives `feature: PaywallFeature` enum for contextual header/value prop
- Layout: feature icon, 3-4 Pro benefit bullets, price + trial info, CTA button, restore link
- Uses DesignSystem tokens, ModernButton, ModernCard
- States: idle, loading, success (auto-dismiss), error

### PaywallFeature enum
```
case trainingPlan, customDrill, quickDrill, dailyCoaching,
     mlRecommendations, youtubeRecs, weeklyAdaptation
```

### ProLockedCardView (new file)
- Replaces content sections for passive AI features (coaching, ML recs)
- ModernCard with blur overlay, lock icon, feature name, "Unlock with Pro" button
- Button opens PaywallView

## Settings Integration

In SettingsView, new "Subscription" section:
- If Pro: "TechnIQ Pro" badge, status, manage subscription link (App Store deep link)
- If Free: "Upgrade to Pro" button -> PaywallView
- "Restore Purchases" row always visible

## Files Summary

| Action | File |
|---|---|
| New | SubscriptionManager.swift |
| New | PaywallView.swift |
| New | ProLockedCardView.swift |
| Edit | TechnIQApp.swift (inject environmentObject) |
| Edit | TrainingPlansListView.swift (gate AI plan button) |
| Edit | ExerciseLibraryView.swift (gate custom drill + YouTube) |
| Edit | DashboardView.swift (gate quick drill, swap coach/recs for teasers) |
| Edit | SessionCompleteView.swift (gate weekly check-in) |
| Edit | SettingsView.swift (subscription section) |

## Not Touched
- UnifiedOnboardingView (onboarding plan stays free)
- All service files (gating at view layer only)
- Coin/avatar system (completely separate)
- InsightsEngine/analytics (stays free)

## App Store Connect (manual)
1. Create auto-renewable subscription group "TechnIQ Pro"
2. Create product `com.techniq.pro.monthly`, $6.99/mo
3. Configure 7-day free trial as introductory offer
4. Add localization (display name, description)
5. Test in Sandbox environment
