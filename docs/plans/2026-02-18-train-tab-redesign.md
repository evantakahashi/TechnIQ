# Train Tab Redesign Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Redesign the Train tab to put exercises and AI drill generation front-and-center, moving session history to a nav bar button.

**Architecture:** Rewrite `TrainHubView` to remove segment control and directly host exercise library content with a hero AI card at top. Refactor `ExerciseLibraryView` to remove its own `NavigationView` wrapper so it composes cleanly inside `TrainHubView`'s nav stack.

**Tech Stack:** SwiftUI, Core Data, DesignSystem tokens, ModernCard/ModernButton components

---

### Task 1: Refactor ExerciseLibraryView — Remove NavigationView Wrapper

`ExerciseLibraryView` currently wraps its body in its own `NavigationView` (line 146). This must be removed so it can be embedded inside `TrainHubView`'s navigation stack. Also remove the `simpleHeader` (title/subtitle) since `TrainHubView` will provide the nav title.

**Files:**
- Modify: `TechnIQ/ExerciseLibraryView.swift:145-296`

**Step 1: Remove NavigationView wrapper and simpleHeader reference**

In `ExerciseLibraryView.swift`, replace the `body` property. The key changes:
- Remove `NavigationView { ... }` wrapper (lines 146, 295)
- Remove `.navigationTitle("Exercises")` and `.navigationBarTitleDisplayMode(.large)` (lines 249-250)
- Remove `simpleHeader` from the ScrollView VStack (line 156)
- Keep the `ZStack` with `AdaptiveBackground`, all ScrollView content, sheets, and `.onAppear`

The body should become:

```swift
var body: some View {
    ZStack {
        AdaptiveBackground()
            .ignoresSafeArea()

        if searchText.isEmpty {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Search Bar
                    searchBar

                    // Action Buttons
                    actionButtons

                    // [... all existing sections unchanged ...]

                    Spacer(minLength: DesignSystem.Spacing.xxl)
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
            }
        } else {
            searchResultsView
        }

        if isLoadingYouTubeContent {
            LoadingOverlay()
        }
    }
    .sheet(isPresented: $showingExerciseDetail) {
        // ... existing sheet content unchanged
    }
    .sheet(isPresented: $showingCustomDrillGenerator) {
        // ... existing sheet content unchanged
    }
    .sheet(isPresented: $showingManualDrillCreator) {
        // ... existing sheet content unchanged
    }
    .sheet(isPresented: $showingDrillPaywall) {
        PaywallView(feature: .customDrill)
    }
    .sheet(isPresented: $showingYouTubePaywall) {
        PaywallView(feature: .youtubeRecs)
    }
    .sheet(isPresented: $showingFilterSheet) {
        // ... existing sheet content unchanged
    }
    .onAppear {
        loadExercises()
        loadRecommendations()
    }
}
```

Note: `simpleHeader` computed property (lines 300-349) can stay in the file — it's just unused now. Or delete it for cleanliness.

**Step 2: Build**

Run: `/build`
Expected: Clean build. No other files reference `ExerciseLibraryView`'s nav title.

**Step 3: Commit**

```
refactor: remove NavigationView wrapper from ExerciseLibraryView
```

---

### Task 2: Rewrite TrainHubView — Exercise Hub with Hero AI Card

Replace the entire `TrainHubView` body. Remove the `TrainHubTab` enum and segment control. Add hero AI card, embed `ExerciseLibraryView`, and add toolbar calendar button for session history.

**Files:**
- Modify: `TechnIQ/TrainHubView.swift` (full rewrite)

**Step 1: Rewrite TrainHubView**

Replace the entire file with:

```swift
import SwiftUI
import CoreData

struct TrainHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @FetchRequest var players: FetchedResults<Player>

    @State private var showingCustomDrillGenerator = false
    @State private var showingDrillPaywall = false

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            if let player = currentPlayer {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Hero AI Drill Card
                        heroAIDrillCard

                        // Exercise Library Content
                        ExerciseLibraryView(player: player)
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SessionHistoryView()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
        .sheet(isPresented: $showingCustomDrillGenerator) {
            if let player = currentPlayer {
                CustomDrillGeneratorView(player: player)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showingDrillPaywall) {
            PaywallView(feature: .customDrill)
        }
        .onAppear {
            updatePlayersFilter()
        }
    }

    // MARK: - Hero AI Drill Card

    private var heroAIDrillCard: some View {
        ModernCard(
            accentEdge: .leading,
            accentColor: DesignSystem.Colors.primaryGreen
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("Create AI Drill")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Text("Get a personalized drill tailored to your weaknesses")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                ModernButton("Generate Drill", icon: "arrow.right.circle.fill", style: .primary) {
                    if subscriptionManager.canUseCustomDrill() {
                        showingCustomDrillGenerator = true
                    } else {
                        showingDrillPaywall = true
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.15),
                    DesignSystem.Colors.primaryGreen.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.md)
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}

#Preview {
    NavigationView {
        TrainHubView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
```

**Key decisions:**
- `ExerciseLibraryView` is now embedded directly inside the `ScrollView`. However, `ExerciseLibraryView` has its own `ScrollView` internally. This creates nested scroll views which won't work.

**IMPORTANT — nested ScrollView fix:** Since `ExerciseLibraryView` contains its own `ScrollView`, we can't wrap it in another one. Instead, `TrainHubView` should NOT wrap content in a ScrollView. Let `ExerciseLibraryView` own the scroll, and inject the hero card as a parameter or place the hero card above the `ExerciseLibraryView` in a `VStack` with no outer scroll.

Revised approach — `TrainHubView` body becomes:

```swift
var body: some View {
    VStack(spacing: 0) {
        if let player = currentPlayer {
            ExerciseLibraryView(player: player, heroCard: { heroAIDrillCard })
        } else {
            ProgressView("Loading...")
        }
    }
    // ... nav title, toolbar, sheets same as above
}
```

This is messy. Cleaner: **add a `heroContent` slot to ExerciseLibraryView** OR just insert the hero card as the first element inside `ExerciseLibraryView`'s ScrollView VStack.

**Cleanest approach:** Add an optional `showHeroCard: Bool` flag (default true) and the hero card directly inside `ExerciseLibraryView`. This avoids nested scrolls entirely. `TrainHubView` becomes a thin shell.

Revised `TrainHubView` body:

```swift
var body: some View {
    Group {
        if let player = currentPlayer {
            ExerciseLibraryView(player: player)
        } else {
            ProgressView("Loading...")
        }
    }
    .navigationTitle("Train")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink {
                SessionHistoryView()
            } label: {
                Image(systemName: "calendar")
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
        }
    }
    .onAppear {
        updatePlayersFilter()
    }
}
```

And the hero card + its sheets live inside `ExerciseLibraryView` (Task 3).

**Step 2: Build**

Run: `/build`
Expected: Clean build.

**Step 3: Commit**

```
feat: rewrite TrainHubView as exercise hub with calendar nav button
```

---

### Task 3: Add Hero AI Card Inside ExerciseLibraryView

Since `ExerciseLibraryView` owns the ScrollView, the hero card must live inside it as the first element.

**Files:**
- Modify: `TechnIQ/ExerciseLibraryView.swift`

**Step 1: Add hero card as first element in ScrollView VStack**

In `ExerciseLibraryView`'s body, inside the `ScrollView > VStack`, add the hero card before `searchBar`:

```swift
ScrollView(.vertical, showsIndicators: false) {
    VStack(spacing: DesignSystem.Spacing.xl) {
        // Hero AI Drill Card
        heroAIDrillCard

        // Search Bar
        searchBar

        // Action Buttons
        actionButtons

        // ... rest unchanged
    }
    .padding(.horizontal, DesignSystem.Spacing.md)
}
```

**Step 2: Add the heroAIDrillCard computed property**

Add after the `actionButtons` computed property (around line 404):

```swift
private var heroAIDrillCard: some View {
    ModernCard(
        accentEdge: .leading,
        accentColor: DesignSystem.Colors.primaryGreen
    ) {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                Text("Create AI Drill")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Text("Get a personalized drill tailored to your weaknesses")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ModernButton("Generate Drill", icon: "arrow.right.circle.fill", style: .primary) {
                if subscriptionManager.canUseCustomDrill() {
                    showingCustomDrillGenerator = true
                } else {
                    showingDrillPaywall = true
                }
            }
        }
    }
    .background(
        LinearGradient(
            colors: [
                DesignSystem.Colors.primaryGreen.opacity(0.15),
                DesignSystem.Colors.primaryGreen.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .cornerRadius(DesignSystem.CornerRadius.card)
    )
}
```

This reuses the existing `showingCustomDrillGenerator` and `showingDrillPaywall` state + sheets already in `ExerciseLibraryView`.

**Step 3: Build**

Run: `/build`
Expected: Clean build. Hero card renders at top of exercise library.

**Step 4: Commit**

```
feat: add hero AI drill card to top of exercise library
```

---

### Task 4: Clean Up Dead Code

Remove `TrainHubTab` enum and `simpleHeader` that are no longer used.

**Files:**
- Modify: `TechnIQ/TrainHubView.swift` — remove `TrainHubTab` enum (lines 4-14 in original)
- Modify: `TechnIQ/ExerciseLibraryView.swift` — remove `simpleHeader` computed property (lines 300-349) and the view-toggle/filter header buttons (these stay in `ExerciseLibraryView` as they still exist in `actionButtons` area)

**Step 1: Remove TrainHubTab enum**

The rewritten `TrainHubView` from Task 2 should not include `TrainHubTab`. If it's still in the file, delete the enum (lines 4-14 of original file).

**Step 2: Remove simpleHeader from ExerciseLibraryView**

Delete the `simpleHeader` computed property (lines 300-349). The filter button and view toggle are already in the `actionButtons`/header area — verify they're still accessible. If `simpleHeader` contained the filter/view-mode buttons, move them into `actionButtons` or a new header row above the search bar.

Looking at the code: `simpleHeader` (lines 300-349) contains:
- "Exercise Library" title + exercise count subtitle
- View toggle button (grid/list)
- Filter button with badge

These should be preserved. Move the view toggle and filter button into a compact row above or beside the search bar.

Add a new `filterToolbar` computed property:

```swift
private var filterToolbar: some View {
    HStack {
        Text("\(allExercises.count) exercises")
            .font(DesignSystem.Typography.bodySmall)
            .foregroundColor(DesignSystem.Colors.textSecondary)

        Spacer()

        HStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewMode = isGridView ? "list" : "grid"
                }
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .font(.title3)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Button {
                showingFilterSheet = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.title2)
                        .foregroundColor(filterState.hasActiveFilters ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)

                    if filterState.activeFilterCount > 0 {
                        Text("\(filterState.activeFilterCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Circle().fill(DesignSystem.Colors.primaryGreen))
                            .offset(x: 6, y: -6)
                    }
                }
            }
        }
    }
}
```

Insert `filterToolbar` in the ScrollView VStack between `heroAIDrillCard` and `searchBar`.

**Step 3: Delete simpleHeader**

Remove lines 300-349 from `ExerciseLibraryView.swift`.

**Step 4: Build**

Run: `/build`
Expected: Clean build. No unused code warnings.

**Step 5: Commit**

```
chore: remove dead code — TrainHubTab enum, simpleHeader
```

---

### Task 5: Visual Polish & Build Verification

Final pass to make sure everything looks right.

**Files:**
- Possibly adjust: `TechnIQ/ExerciseLibraryView.swift` (spacing tweaks)
- Possibly adjust: `TechnIQ/TrainHubView.swift` (spacing tweaks)

**Step 1: Full build**

Run: `/build`
Expected: Clean build, zero errors.

**Step 2: Visual check**

Run in simulator and verify:
- Train tab opens directly to exercise library with hero AI card at top
- Calendar icon in nav bar pushes to SessionHistoryView
- AI drill button on hero card opens CustomDrillGeneratorView (or paywall)
- All exercise sections scroll correctly
- Search works
- Filter/view-mode toggles work
- No double navigation bars or nested scroll issues

**Step 3: Final commit**

```
feat: complete train tab redesign — exercise-first with hero AI card
```
