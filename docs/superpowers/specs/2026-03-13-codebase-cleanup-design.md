# TechnIQ Codebase Cleanup — Design Spec

**Date:** 2026-03-13
**Goal:** Bring AI-generated codebase to production-grade architecture — testable, modular, maintainable.
**Approach:** Risk-layered — ship-blockers first, then structure, then architecture, then polish.
**Milestones:** 7 (M1–M7), each self-contained, app builds after every milestone.

---

## Baseline

- 147 Swift files, 51K LOC, virtually flat in `TechnIQ/`
- 21+ singleton services, 321 `.shared` usages, 0 protocols
- 7 files over 1000 lines (CoreDataManager at 3105)
- 7 test files with in-memory Core Data stack (`TestCoreDataStack`)
- No folder structure (3 files in subfolders)
- Missing from original service inventory: AICoachService (438 lines), CommunityService (804 lines)

---

## Branch Strategy

Each milestone gets its own branch: `cleanup/m1-critical-bugs`, `cleanup/m2-folder-structure`, etc.
Merge to `main` after each milestone passes build + existing tests.
Commit checkpoint before each milestone starts (tag: `pre-m1`, `pre-m2`, etc.) for rollback.

---

## M1: Critical Bugs + Quick Wins

**Goal:** Fix every ship-blocking issue. App safe to submit after this.

**Changes:**

| # | File | Fix |
|---|------|-----|
| 1 | `SubscriptionManager.swift` | Remove `isPro = true; return` bypass — let StoreKit check run |
| 2 | `TrainingPlanService.swift:473` | Replace `plan.player!` with guard-let + early return |
| 3 | `CloudRestoreService.swift:434` | Replace `sqrt(xp/100)` level calc with `XPService().levelForXP()` |
| 4 | `CloudDataService.swift` | Chunk Firestore batch writes into groups of 450 |
| 5 | `XPService`, `AchievementService`, `CoinService` | Make `init()` private. **Note:** XPService and AchievementService have existing tests that call `init()` directly — defer private init for these two to M3 when test init via protocol is available. CoinService tests only test the enum, so private init is safe now. |
| 6 | `AuthenticationManager.swift:296` | Replace `fatalError` in `randomNonceString` — make it `throws`, catch at call site in `startSignInWithAppleFlow()` and surface via `errorMessage` |
| 7 | `CoinService.swift` | Remove unused `context` param from `getBalance` and `getTotalEarned` (param assigned but never used — methods always go through `coreDataManager`). Note: `awardCoins` and `deductCoins` DO use the context param for save/rollback — leave those as-is. |
| 8 | `ActiveSessionManager.swift` | Fix XP double-award: `processSessionCompletion` awards full XP (incl completion bonus), then `finishSession` retroactively zeroes `completionBonus` for partial sessions — but XP was already granted. Fix: pass `isFullCompletion` flag into `processSessionCompletion` so it computes the correct breakdown from the start, then award only `breakdown.total`. Display and actual XP will match. |
| 9 | Codebase-wide | Quick audit for additional force unwraps on optionals (excluding safe calendar arithmetic). Fix any found with guard-let. |

**Scope:** ~20-25 targeted edits across 8-10 files. No structural changes.

---

## M2: Folder Structure + Split God Files

**Goal:** Organize 147 flat files into logical groups, split oversized files.

### Sub-steps (commit between each)

1. **Commit checkpoint** — tag `pre-m2`
2. **Create folders + move files** — use Xcode directly (not xcodeproj gem, per known double-nesting issue in MEMORY.md). This auto-updates pbxproj.
3. **Verify build** — catch any broken references
4. **Split god files** — separate commits per split
5. **Verify build + tests** — ensure test target membership intact

### Folder Structure

```
TechnIQ/
├── App/                  TechnIQApp.swift, ContentView.swift
├── Models/               Core Data +CoreDataClass/Properties, value types (TrainingPlanModels, YouTubeModels, AvatarModels, etc.)
├── Services/             All service singletons
├── Views/
│   ├── Auth/             AuthenticationView, onboarding
│   ├── Dashboard/        DashboardView + sections (decomposed in M6)
│   ├── Training/         Plans, sessions, active training, calendar
│   ├── Exercises/        Library, detail, drill generator, diagrams
│   ├── Matches/          MatchLog, history, seasons
│   ├── Avatar/           Customization, programmatic, shop
│   ├── Analytics/        Progress, calendar heatmap, insights, charts
│   ├── Community/        Feed, posts, leaderboard, marketplace
│   └── Settings/         Settings, edit profile, share
├── Components/           ModernComponents, DesignSystem, CoachMarkOverlay, accessibility, transitions
└── Utilities/            AppLogger, HapticManager, NetworkManager
```

### God File Splits

**CoreDataManager.swift (3105 lines) →**
- `CoreDataManager.swift` (~800) — persistent store setup, context management, CRUD helpers, migrations
- `YouTubeDataService.swift` (~1200) — all YouTube search, transcript, video detail, caching logic
- `CoreDataFetchRequests.swift` (~500) — reusable fetch request builders

**ModernComponents.swift (927 lines) →**
- Evaluate split by component type. If 3+ distinct components, split into separate files. Otherwise leave as-is.

### Xcode Project

Move files via Xcode UI (drag into groups). This auto-updates `project.pbxproj` safely. Verify test target membership after moves.

---

## M3: Protocols + Dependency Injection

**Goal:** Make services testable via protocol-based DI.

### Phased Rollout

**Phase 1 (this milestone):** Protocols for the 8-10 services that tests need to mock:
CoreDataManager, XPService, CoinService, AchievementService, MatchService, TrainingPlanService, ActiveSessionManager, CloudDataService/CloudSyncManager/CloudRestoreService

**Phase 2 (M5 or later):** Remaining services get protocols during consolidation:
AvatarService, AuthenticationManager, CloudMLService, CustomDrillService, YouTubeAPIService, YouTubeDataService, InsightsEngine, SubscriptionManager, WeaknessAnalysisService, AICoachService, CommunityService

### Pattern

```swift
protocol XPServiceProtocol {
    func xpRequiredForLevel(_ level: Int) -> Int64
    func levelForXP(_ xp: Int64) -> Int
    func calculateSessionXP(...) -> XPBreakdown
    func awardXP(to player: Player, amount: Int64) -> Int16?
    func updateStreak(for player: Player)
    func purchaseStreakFreeze(for player: Player, context: NSManagedObjectContext) -> Bool
}
```

### DI Approach

Lightweight init injection with defaults — no DI container framework:

```swift
final class CoinService: CoinServiceProtocol {
    static let shared = CoinService()
    private let coreDataManager: CoreDataManagerProtocol

    private init(coreDataManager: CoreDataManagerProtocol = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }

    // Internal init for testing
    init(testCoreDataManager: CoreDataManagerProtocol) {
        self.coreDataManager = testCoreDataManager
    }
}
```

### Protocol File Location

`TechnIQ/Services/Protocols/` — one file per protocol, named `<ServiceName>Protocol.swift`.

### Test Infrastructure

- `TestCoreDataStack` conforms to `CoreDataManagerProtocol`
- Add initial mocks in `TechnIQTests/Mocks/` for Phase 1 services
- Views untouched — still use `.shared`. View-level DI deferred to M6.

---

## M4: Core Data Thread Safety + @MainActor Consistency

**Goal:** Eliminate thread safety violations for `viewContext` access.

### Strategy

Mark all services that touch Core Data as `@MainActor`:

**Adding `@MainActor`:**
- XPService, CoinService, AchievementService, MatchService, TrainingPlanService, ActiveSessionManager, AvatarService, InsightsEngine, WeaknessAnalysisService

**Already `@MainActor` (no change):**
- CloudMLService, CloudDataService, CloudSyncManager, CustomDrillService, SubscriptionManager

**Stays non-`@MainActor`:**
- AuthenticationManager (Firebase callbacks, manually dispatches)
- AppLogger, HapticManager, NetworkManager, YouTubeAPIService

### Blast Radius Mitigation

Adding `@MainActor` will cause compiler errors at every non-`@MainActor` call site (requires `await`). Strategy:
1. Start with one service (CoinService) to gauge blast radius
2. Fix all callers before proceeding to next service
3. Most callers are SwiftUI views (already implicitly `@MainActor`) — minimal changes expected there
4. Background `Task {}` blocks and async functions will need `await` added

### Specific Fixes

1. **CloudSyncManager `@objc` handler** — migrate `handleCoreDataChange` to `NotificationCenter.notifications(named:)` async sequence. After migration, evaluate if `NSObject` inheritance can be dropped.
2. **AuthenticationManager `@Published` mutations** — audit all paths modifying `errorMessage`, `isAuthenticated`, etc. Ensure all go through `MainActor.run {}`
3. **CoinService.awardSessionCoins** — batch 4 `context.save()` calls into single save at end of method

### Protocol Updates

Protocols from M3 gain `@MainActor` annotation where needed:

```swift
@MainActor
protocol XPServiceProtocol { ... }
```

---

## M5: Service Consolidation

**Goal:** Reduce service count from ~21 to ~16 with cleaner boundaries.

### Merges

**CloudDataService + CloudSyncManager + CloudRestoreService → `CloudService`**
- Single service owning all Firestore sync
- Organized via extension files in `TechnIQ/Services/Cloud/`: `CloudService.swift` (core + published state), `CloudService+Upload.swift`, `CloudService+Download.swift`, `CloudService+Restore.swift`, `CloudService+ConflictResolution.swift`
- Target: no individual extension file over 500 lines
- Single `CloudServiceProtocol` replacing 3 protocols

**YouTubeAPIService + YouTubeDataService → `YouTubeService`**
- Single service for API calls + caching/search
- Extensions if needed: `YouTubeService+API.swift`, `YouTubeService+Cache.swift`

### Renames

- `CloudMLService` → `AIRecommendationService`

### Phase 2 Protocols

Services not protocoled in M3 get protocols during consolidation:
AvatarService, AuthenticationManager, AIRecommendationService, CustomDrillService, YouTubeService, InsightsEngine, SubscriptionManager, WeaknessAnalysisService, AICoachService, CommunityService

### Reference Update Checklist

For each renamed/merged service, grep for old name and verify expected match count:
- `CloudDataService.shared` → 4 references expected
- `CloudSyncManager.shared` → 2 references expected
- `CloudRestoreService.shared` → 3 references expected
- `CloudMLService.shared` → 9 references expected
- `YouTubeAPIService.shared` → 1 reference expected

Zero remaining references after update = verified.

### Result

| Before | After |
|--------|-------|
| CloudDataService | CloudService |
| CloudSyncManager | (merged) |
| CloudRestoreService | (merged) |
| YouTubeAPIService | YouTubeService |
| YouTubeDataService | (merged) |
| CloudMLService | AIRecommendationService |
| ~21 services | ~16 services |

---

## M6: View Decomposition

**Goal:** Break monolithic views into composable, previewable structs.

### Targets

| View | Lines | Split Into |
|------|-------|-----------|
| DashboardView (1565) | Shell | DashboardStatsSection, DashboardQuickActions, DashboardRecentActivity, DashboardMatchesSection, DashboardAIDrillBanner |
| ExerciseLibraryView (1390) | Shell | ExerciseFilterBar, ExerciseGridItem, ExerciseSearchResults |
| NewSessionView (1171) | Shell | SessionSetupStep, ExerciseSelectionStep, SessionReviewStep |
| SessionCalendarView (1079) | Shell | CalendarGrid, SessionDayDetail |
| UnifiedOnboardingView (1042) | Shell | Individual step views (one per onboarding step) |
| PlayerProgressView (1026) | Shell | ProgressStatsCard, ProgressCharts, ProgressTimeline |

### Pattern

Parent becomes thin composition shell:

```swift
struct DashboardView: View {
    @ObservedObject var coinService = CoinService.shared

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.xl) {
                DashboardStatsSection(player: player)
                DashboardAIDrillBanner()
                DashboardQuickActions(...)
                DashboardRecentActivity(sessions: recentSessions)
                DashboardMatchesSection(matches: recentMatches)
            }
        }
    }
}
```

**Note on `@ObservedObject` with `.shared`:** This works because singletons persist for app lifetime, so the object is never deallocated despite `@ObservedObject` not owning lifecycle. Pragmatic choice — `@EnvironmentObject` deferred.

### @StateObject Cleanup

All `@StateObject private var service = SomeService.shared` → `@ObservedObject`:
- `@StateObject` is for view-owned lifecycle. Singletons are app-owned.
- ~25 usages across ~20 view files.

### SwiftUI Previews

Each extracted view gets a `#Preview` block with mock data for rapid iteration.

---

## M7: Error Handling + Test Coverage

**Goal:** Standardize error propagation, expand test suite.

### Error Handling

**Define shared error type:**

```swift
enum ServiceError: LocalizedError {
    case network(String)
    case coreData(String)
    case validation(String)
    case sync(String)
    case auth(String)

    var errorDescription: String? { ... }
}
```

**Service pattern:**

```swift
@MainActor
protocol CoinServiceProtocol {
    var lastError: ServiceError? { get }
    func awardCoins(...) throws -> Int
}
```

**Changes:**
- All services expose `@Published var lastError: ServiceError?`
- Replace silent `return []` / `return false` with thrown errors or published error state
- Replace `#if DEBUG print("Error: \(error)")` with `AppLogger.shared.error(...)` (logs in all builds)
- Views display error banners/alerts where services publish errors (follow existing CloudMLService pattern)

### Test Coverage

**With protocols from M3/M5, write proper isolated tests:**

- **Priority services:** TrainingPlanService, CloudService, ActiveSessionManager, MatchService, CoinService (integration), AchievementService (integration)
- **Mock pattern:**

```swift
final class MockCoreDataManager: CoreDataManagerProtocol {
    var stubbedPlayer: Player?
    func getCurrentPlayer() -> Player? { stubbedPlayer }
}
```

- **Expand TestCoreDataStack** with factories for TrainingPlan, PlanWeek, PlanDay entities
- **Goal:** Every service public method has at least 1 test. Critical paths (XP, coins, achievements, sync) have edge case coverage.

---

## Resolved Questions

1. **M2 pbxproj** → Use Xcode UI to move files (not xcodeproj gem). Known double-nesting issue with gem.
2. **M3 protocol granularity** → Phased: 8-10 core services in M3, remainder in M5. Pragmatic over consistent.
3. **M5 CloudService structure** → Extension files in `Services/Cloud/` folder. No single file over 500 lines.
4. **M6 environment injection** → Keep `@ObservedObject` with `.shared`. `@EnvironmentObject` deferred.

---

## Milestone Dependencies

```
M1 (bugs) → M2 (structure) → M3 (protocols) → M4 (thread safety)
                                    ↓
                              M5 (consolidation) → M6 (views) → M7 (errors + tests)
```

Each milestone:
- Gets its own branch (`cleanup/m1-critical-bugs`, etc.)
- Produces a buildable, runnable app
- Has a rollback tag (`pre-m1`, `pre-m2`, etc.)
- Merges to `main` after build + tests pass
