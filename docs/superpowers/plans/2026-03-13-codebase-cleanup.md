# TechnIQ Codebase Cleanup — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform AI-generated codebase into production-grade architecture across 7 milestones.

**Architecture:** Risk-layered cleanup — ship-blocking bugs first, then folder restructuring, protocols/DI, thread safety, service consolidation, view decomposition, and finally error handling + tests. Each milestone produces a buildable app.

**Tech Stack:** Swift 5.9+, SwiftUI, Core Data, Firebase (Auth/Firestore/Functions), StoreKit 2

**Spec:** `docs/superpowers/specs/2026-03-13-codebase-cleanup-design.md`

**Build command:** `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build`

**Test command:** `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test`

---

## Chunk 1: M1 — Critical Bugs + Quick Wins

**Branch:** `cleanup/m1-critical-bugs`

### Task 1: Setup branch + checkpoint

**Files:** None

- [ ] **Step 1: Create branch**

```bash
git checkout main
git tag pre-m1
git checkout -b cleanup/m1-critical-bugs
```

- [ ] **Step 2: Verify build passes before any changes**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

---

### Task 2: Fix subscription bypass

**Files:**
- Modify: `TechnIQ/SubscriptionManager.swift:40-43`

- [ ] **Step 1: Remove the testing bypass**

In `SubscriptionManager.swift`, the `checkEntitlement()` method at line 40-43 has:

```swift
func checkEntitlement() async {
    // TODO: Remove before production — force Pro for testing
    isPro = true
    return
```

Remove lines 41-43 (the comment, `isPro = true`, and `return`). The real StoreKit entitlement check on lines 45-54 will then execute.

Result should be:

```swift
func checkEntitlement() async {
    var hasEntitlement = false
    for await result in Transaction.currentEntitlements {
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TechnIQ/SubscriptionManager.swift
git commit -m "fix: remove isPro testing bypass in SubscriptionManager"
```

---

### Task 3: Fix force unwrap in TrainingPlanService

**Files:**
- Modify: `TechnIQ/TrainingPlanService.swift:473`

- [ ] **Step 1: Replace force unwrap with guard-let**

At line 473, `plan.player!` is force-unwrapped inside the `"add_session"` case of `applyAdaptation`. Replace the block starting at line 466:

```swift
// BEFORE:
case "add_session":
    if let day = days.first(where: { $0.dayNumber == Int16(adaptation.day) }),
       let drill = adaptation.drill {
        let sessionType = SessionType(rawValue: drill.category.capitalized) ?? .technical
        let exercises = matchExercisesFromLibrary(
            suggestedNames: [drill.name],
            sessionType: sessionType,
            for: plan.player!
        )
```

```swift
// AFTER:
case "add_session":
    if let day = days.first(where: { $0.dayNumber == Int16(adaptation.day) }),
       let drill = adaptation.drill,
       let player = plan.player {
        let sessionType = SessionType(rawValue: drill.category.capitalized) ?? .technical
        let exercises = matchExercisesFromLibrary(
            suggestedNames: [drill.name],
            sessionType: sessionType,
            for: player
        )
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TechnIQ/TrainingPlanService.swift
git commit -m "fix: replace force unwrap plan.player! with guard-let"
```

---

### Task 4: Fix level calculation divergence

**Files:**
- Modify: `TechnIQ/CloudRestoreService.swift:434-437`

- [ ] **Step 1: Replace divergent level calc with XPService**

At line 434, `CloudRestoreService.calculateLevel(from:)` uses `sqrt(xp/100) + 1` which disagrees with `XPService.levelForXP()`. Replace:

```swift
// BEFORE:
private func calculateLevel(from xp: Int64) -> Int {
    // Simple level calculation: level = sqrt(xp / 100) + 1
    return max(1, Int(sqrt(Double(xp) / 100.0)) + 1)
}
```

```swift
// AFTER:
private func calculateLevel(from xp: Int64) -> Int {
    return XPService.shared.levelForXP(xp)
}
```

- [ ] **Step 2: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TechnIQ/CloudRestoreService.swift
git commit -m "fix: use XPService.levelForXP for cloud restore level calc"
```

---

### Task 5: Chunk Firestore batch writes

**Files:**
- Modify: `TechnIQ/CloudDataService.swift`

- [ ] **Step 1: Add batch chunking helper**

Add a private helper method at the end of `CloudDataService` (before the closing brace):

```swift
// MARK: - Batch Chunking

/// Commits items in batches of 450 to stay under Firestore's 500-operation limit.
/// - Parameters:
///   - items: Array of items to sync
///   - buildBatch: Closure that adds one item's operations to the batch
private func commitInChunks<T>(
    _ items: [T],
    using buildBatch: (WriteBatch, T) throws -> Void
) async throws {
    let chunkSize = 450
    for startIndex in stride(from: 0, to: items.count, by: chunkSize) {
        let endIndex = min(startIndex + chunkSize, items.count)
        let chunk = Array(items[startIndex..<endIndex])

        let batch = db.batch()
        for item in chunk {
            try buildBatch(batch, item)
        }
        try await batch.commit()
    }
}
```

- [ ] **Step 2: Refactor `syncPlayerGoals` to use chunking**

Replace the batch logic in `syncPlayerGoals` (lines 94-109):

```swift
// BEFORE:
func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws {
    guard let userUID = auth.currentUser?.uid else {
        throw CloudDataError.notAuthenticated
    }

    let batch = db.batch()

    for goal in goals {
        let goalData = try createPlayerGoalDocument(goal: goal)
        let docRef = db.collection("users").document(userUID)
            .collection("playerGoals").document(goal.id?.uuidString ?? UUID().uuidString)
        batch.setData(goalData, forDocument: docRef, merge: true)
    }

    try await batch.commit()
}
```

```swift
// AFTER:
func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws {
    guard let userUID = auth.currentUser?.uid else {
        throw CloudDataError.notAuthenticated
    }

    try await commitInChunks(goals) { batch, goal in
        let goalData = try createPlayerGoalDocument(goal: goal)
        let docRef = db.collection("users").document(userUID)
            .collection("playerGoals").document(goal.id?.uuidString ?? UUID().uuidString)
        batch.setData(goalData, forDocument: docRef, merge: true)
    }
}
```

- [ ] **Step 3: Refactor remaining batch methods**

Apply the same `commitInChunks` pattern to:
- `syncRecommendationFeedback` (lines 131-146) — chunks `feedback` array
- `syncOwnedAvatarItems` (lines 166-181) — chunks `items` array
- `syncCustomExercises` (lines 185-200) — chunks `exercises` array

Each follows the same pattern: extract the `guard userUID` check, then call `commitInChunks` with the array and the per-item batch logic.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/CloudDataService.swift
git commit -m "fix: chunk Firestore batch writes to stay under 500-op limit"
```

---

### Task 6: Private init for singletons

All three services (XPService, AchievementService, CoinService) have public `init()` despite using `.shared` singleton. However, existing tests call `init()` directly:
- `XPServiceTests`: `sut = XPService()`
- `AchievementServiceTests`: `sut = AchievementService()`
- `CoinServiceTests`: `CoinService()` in `test_canAfford_basic`

**Defer all three to M3** where test-specific init via protocol will be available. No changes in M1.

---

### Task 7: Replace fatalError in AuthenticationManager

**Files:**
- Modify: `TechnIQ/AuthenticationManager.swift:291-300, 220`

- [ ] **Step 1: Make randomNonceString throw**

At line 291, change the method signature and error handling:

```swift
// BEFORE:
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}
```

```swift
// AFTER:
private func randomNonceString(length: Int = 32) throws -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    guard errorCode == errSecSuccess else {
        throw AuthError.nonceGenerationFailed
    }
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    return String(randomBytes.map { charset[Int($0) % charset.count] })
}
```

- [ ] **Step 2: Add AuthError enum if not present**

Add near the top of the file (or in an existing error enum):

```swift
enum AuthError: LocalizedError {
    case nonceGenerationFailed

    var errorDescription: String? {
        switch self {
        case .nonceGenerationFailed:
            return "Unable to generate secure nonce. Please try again."
        }
    }
}
```

- [ ] **Step 3: Update call site in startSignInWithAppleFlow**

At line 220, change:

```swift
// BEFORE:
let nonce = randomNonceString()
```

```swift
// AFTER:
let nonce: String
do {
    nonce = try randomNonceString()
} catch {
    await MainActor.run {
        errorMessage = error.localizedDescription
        isLoading = false
    }
    return
}
```

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/AuthenticationManager.swift
git commit -m "fix: replace fatalError with throws in randomNonceString"
```

---

### Task 8: Remove unused context params from CoinService

**Files:**
- Modify: `TechnIQ/CoinService.swift:146-163`

- [ ] **Step 1: Remove context param from getBalance**

At line 146:

```swift
// BEFORE:
func getBalance(context: NSManagedObjectContext? = nil) -> Int {
    let ctx = context ?? coreDataManager.context
    guard let player = coreDataManager.getCurrentPlayer() else {
```

```swift
// AFTER:
func getBalance() -> Int {
    guard let player = coreDataManager.getCurrentPlayer() else {
```

- [ ] **Step 2: Remove context param from getTotalEarned**

At line 157 (adjusted after Step 1 edit):

```swift
// BEFORE:
func getTotalEarned(context: NSManagedObjectContext? = nil) -> Int {
    let ctx = context ?? coreDataManager.context
    guard let player = coreDataManager.getCurrentPlayer() else {
```

```swift
// AFTER:
func getTotalEarned() -> Int {
    guard let player = coreDataManager.getCurrentPlayer() else {
```

- [ ] **Step 3: Find and update any callers passing context**

Run grep to find callers:

```bash
grep -rn "getBalance(context:" TechnIQ/
grep -rn "getTotalEarned(context:" TechnIQ/
```

Remove the `context:` argument from any call sites found. These methods have default params so most callers won't need changes.

- [ ] **Step 4: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add TechnIQ/CoinService.swift
git commit -m "fix: remove unused context param from getBalance/getTotalEarned"
```

---

### Task 9: Fix XP double-award for partial sessions

**Files:**
- Modify: `TechnIQ/XPService.swift:296-336` (processSessionCompletion)
- Modify: `TechnIQ/ActiveSessionManager.swift:132-158` (finishSession)

- [ ] **Step 1: Add `allExercisesCompleted` param to processSessionCompletion**

In `XPService.swift` at line 296, add a parameter:

```swift
// BEFORE:
func processSessionCompletion(
    session: TrainingSession,
    player: Player,
    context: NSManagedObjectContext
) -> (xp: SessionXPBreakdown, levelUp: Int?) {
```

```swift
// AFTER:
func processSessionCompletion(
    session: TrainingSession,
    player: Player,
    context: NSManagedObjectContext,
    allExercisesCompleted: Bool = true
) -> (xp: SessionXPBreakdown, levelUp: Int?) {
```

- [ ] **Step 2: Use the new param instead of hardcoded true**

At line 313 (inside processSessionCompletion), change:

```swift
// BEFORE:
let breakdown = calculateSessionXP(
    intensity: session.intensity,
    exerciseCount: exerciseCount,
    allExercisesCompleted: exerciseCount > 0,
    hasRating: session.overallRating > 0,
```

```swift
// AFTER:
let breakdown = calculateSessionXP(
    intensity: session.intensity,
    exerciseCount: exerciseCount,
    allExercisesCompleted: allExercisesCompleted,
    hasRating: session.overallRating > 0,
```

- [ ] **Step 3: Pass isFullCompletion from ActiveSessionManager**

In `ActiveSessionManager.swift` at line 132, pass the flag:

```swift
// BEFORE:
let (breakdown, levelUp) = XPService.shared.processSessionCompletion(
    session: session,
    player: player,
    context: context
)
```

```swift
// AFTER:
let (breakdown, levelUp) = XPService.shared.processSessionCompletion(
    session: session,
    player: player,
    context: context,
    allExercisesCompleted: isFullCompletion
)
```

- [ ] **Step 4: Remove the retroactive breakdown override**

In `ActiveSessionManager.swift`, delete lines 138-150 (the `var finalBreakdown` block):

```swift
// DELETE THIS BLOCK:
// For partial sessions, create modified breakdown without completion bonus
var finalBreakdown = breakdown
if !isFullCompletion {
    finalBreakdown = XPService.SessionXPBreakdown(
        baseXP: breakdown.baseXP,
        intensityBonus: breakdown.intensityBonus,
        firstSessionBonus: breakdown.firstSessionBonus,
        completionBonus: 0,
        ratingBonus: breakdown.ratingBonus,
        notesBonus: breakdown.notesBonus,
        streakBonus: breakdown.streakBonus
    )
}
```

And change the return at line 158 from `finalBreakdown` to `breakdown`:

```swift
// BEFORE:
return (finalBreakdown, levelUp, achievements)
```

```swift
// AFTER:
return (breakdown, levelUp, achievements)
```

- [ ] **Step 5: Build + test to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test 2>&1 | tail -10`
Expected: All tests pass. XPServiceTests test `calculateSessionXP` which is unchanged. The new default param (`allExercisesCompleted: true`) preserves existing behavior for callers that don't pass it.

- [ ] **Step 6: Commit**

```bash
git add TechnIQ/XPService.swift TechnIQ/ActiveSessionManager.swift
git commit -m "fix: pass isFullCompletion to XP calc so display matches actual award"
```

---

### Task 10: Audit force unwraps

**Files:**
- Various (audit results)

- [ ] **Step 1: Grep for force unwraps on optionals**

```bash
grep -rn '\![^=]' TechnIQ/*.swift | grep -v '// ' | grep -v '#if' | grep -v 'IBOutlet' | grep -v '\.count' | grep -v '\.isEmpty' | head -40
```

Review results. Skip:
- Calendar arithmetic (`Calendar.current.date(byAdding:)!`) — documented as safe
- `!` in boolean negation (`!isValid`)
- Force unwraps on `URL(string: "known-valid-literal")!`

Fix any force unwraps on Core Data optionals or method returns with guard-let.

- [ ] **Step 2: Fix any found, build, commit**

Stage only the specific files you changed:

```bash
git add <specific-files-changed>
git commit -m "fix: replace unsafe force unwraps with guard-let"
```

---

### Task 11: Final M1 verification

- [ ] **Step 1: Full build**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Full test suite**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test 2>&1 | tail -15`
Expected: All tests pass.

- [ ] **Step 3: Merge to main**

```bash
git checkout main
git merge cleanup/m1-critical-bugs
```

---

## Chunk 2: M2 — Folder Structure + Split God Files

**Branch:** `cleanup/m2-folder-structure`

### Task 12: Setup branch

- [ ] **Step 1: Create branch + checkpoint**

```bash
git checkout main
git tag pre-m2
git checkout -b cleanup/m2-folder-structure
```

---

### Task 13: Create folder structure

**Files:**
- Create directories under `TechnIQ/`

- [ ] **Step 1: Create all directories**

```bash
mkdir -p TechnIQ/App
mkdir -p TechnIQ/Models
mkdir -p TechnIQ/Services
mkdir -p TechnIQ/Views/{Auth,Dashboard,Training,Exercises,Matches,Avatar,Analytics,Community,Settings}
mkdir -p TechnIQ/Components
mkdir -p TechnIQ/Utilities
```

- [ ] **Step 2: Commit empty structure**

```bash
# Git doesn't track empty dirs, but the next steps will populate them
```

---

### Task 14: Move files into folders

**IMPORTANT:** This task requires Xcode UI or careful `git mv` + pbxproj updates. The safest approach is `git mv` for the filesystem move, then open Xcode and fix any red (missing) file references by dragging files to their correct groups.

- [ ] **Step 1: Move App files**

```bash
git mv TechnIQ/TechnIQApp.swift TechnIQ/App/
git mv TechnIQ/ContentView.swift TechnIQ/App/
```

- [ ] **Step 2: Move Model files**

Move all `+CoreDataClass.swift`, `+CoreDataProperties.swift`, and value-type model files:

```bash
git mv TechnIQ/*+CoreDataClass.swift TechnIQ/Models/
git mv TechnIQ/*+CoreDataProperties.swift TechnIQ/Models/
git mv TechnIQ/TrainingPlanModels.swift TechnIQ/Models/
git mv TechnIQ/YouTubeModels.swift TechnIQ/Models/
git mv TechnIQ/AvatarModels.swift TechnIQ/Models/
```

- [ ] **Step 3: Move Service files**

```bash
git mv TechnIQ/CoreDataManager.swift TechnIQ/Services/
git mv TechnIQ/AuthenticationManager.swift TechnIQ/Services/
git mv TechnIQ/CloudMLService.swift TechnIQ/Services/
git mv TechnIQ/CloudDataService.swift TechnIQ/Services/
git mv TechnIQ/CloudSyncManager.swift TechnIQ/Services/
git mv TechnIQ/CloudRestoreService.swift TechnIQ/Services/
git mv TechnIQ/TrainingPlanService.swift TechnIQ/Services/
git mv TechnIQ/CustomDrillService.swift TechnIQ/Services/
git mv TechnIQ/YouTubeAPIService.swift TechnIQ/Services/
git mv TechnIQ/XPService.swift TechnIQ/Services/
git mv TechnIQ/CoinService.swift TechnIQ/Services/
git mv TechnIQ/AchievementService.swift TechnIQ/Services/
git mv TechnIQ/AvatarService.swift TechnIQ/Services/
git mv TechnIQ/MatchService.swift TechnIQ/Services/
git mv TechnIQ/ActiveSessionManager.swift TechnIQ/Services/
git mv TechnIQ/InsightsEngine.swift TechnIQ/Services/
git mv TechnIQ/SubscriptionManager.swift TechnIQ/Services/
git mv TechnIQ/WeaknessAnalysisService.swift TechnIQ/Services/
git mv TechnIQ/AICoachService.swift TechnIQ/Services/
git mv TechnIQ/CommunityService.swift TechnIQ/Services/
git mv TechnIQ/NetworkManager.swift TechnIQ/Utilities/
```

- [ ] **Step 4: Move View files**

Move each view to its category subfolder. Full file-to-folder mapping:

```bash
# Auth
git mv TechnIQ/AuthenticationView.swift TechnIQ/Views/Auth/
git mv TechnIQ/Onboarding TechnIQ/Views/Auth/Onboarding
git mv TechnIQ/UnifiedOnboardingView.swift TechnIQ/Views/Auth/

# Dashboard
git mv TechnIQ/DashboardView.swift TechnIQ/Views/Dashboard/

# Training
git mv TechnIQ/TrainHubView.swift TechnIQ/Views/Training/
git mv TechnIQ/TrainingPlansListView.swift TechnIQ/Views/Training/
git mv TechnIQ/TrainingPlanDetailView.swift TechnIQ/Views/Training/
git mv TechnIQ/AITrainingPlanGeneratorView.swift TechnIQ/Views/Training/
git mv TechnIQ/AITrainingPlanPreviewView.swift TechnIQ/Views/Training/
git mv TechnIQ/ActivePlanView.swift TechnIQ/Views/Training/
git mv TechnIQ/PlanEditorView.swift TechnIQ/Views/Training/
git mv TechnIQ/DayEditorView.swift TechnIQ/Views/Training/
git mv TechnIQ/WeekEditorView.swift TechnIQ/Views/Training/
git mv TechnIQ/CustomPlanBuilderView.swift TechnIQ/Views/Training/
git mv TechnIQ/ActiveTrainingView.swift TechnIQ/Views/Training/
git mv TechnIQ/TodaysTrainingView.swift TechnIQ/Views/Training/
git mv TechnIQ/NewSessionView.swift TechnIQ/Views/Training/
git mv TechnIQ/SessionHistoryView.swift TechnIQ/Views/Training/
git mv TechnIQ/SessionCalendarView.swift TechnIQ/Views/Training/
git mv TechnIQ/SessionDetailView.swift TechnIQ/Views/Training/
git mv TechnIQ/SessionEditorView.swift TechnIQ/Views/Training/
git mv TechnIQ/SessionCompleteView.swift TechnIQ/Views/Training/
git mv TechnIQ/WeeklyCheckInView.swift TechnIQ/Views/Training/

# Exercises
git mv TechnIQ/ExerciseLibraryView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/ExerciseDetailView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/ExerciseEditorView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/ExerciseStepView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/CustomDrillGeneratorView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/ManualDrillCreatorView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/DrillDiagramView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/QuickDrillSheet.swift TechnIQ/Views/Exercises/
git mv TechnIQ/SmartDrillRecommendationsView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/SharedDrillDetailView.swift TechnIQ/Views/Exercises/
git mv TechnIQ/RestCountdownView.swift TechnIQ/Views/Exercises/ 2>/dev/null || true
git mv TechnIQ/DrillWalkthroughView.swift TechnIQ/Views/Exercises/ 2>/dev/null || true
git mv TechnIQ/DrillInstructionsView.swift TechnIQ/Views/Exercises/ 2>/dev/null || true
git mv TechnIQ/ExerciseFilterView.swift TechnIQ/Views/Exercises/ 2>/dev/null || true
git mv TechnIQ/TemplateExerciseLibrary.swift TechnIQ/Views/Exercises/

# Matches
git mv TechnIQ/MatchLogView.swift TechnIQ/Views/Matches/
git mv TechnIQ/MatchHistoryView.swift TechnIQ/Views/Matches/
git mv TechnIQ/MatchStatsComparisonView.swift TechnIQ/Views/Matches/
git mv TechnIQ/SeasonManagementView.swift TechnIQ/Views/Matches/
git mv TechnIQ/CreateSeasonView.swift TechnIQ/Views/Matches/

# Avatar
git mv TechnIQ/AvatarCustomizationView.swift TechnIQ/Views/Avatar/
git mv TechnIQ/ProgrammaticAvatarView.swift TechnIQ/Views/Avatar/
git mv TechnIQ/ShopView.swift TechnIQ/Views/Avatar/
git mv TechnIQ/AvatarView.swift TechnIQ/Views/Avatar/ 2>/dev/null || true

# Analytics
git mv TechnIQ/PlayerProgressView.swift TechnIQ/Views/Analytics/
git mv TechnIQ/SkillTrendChartView.swift TechnIQ/Views/Analytics/
git mv TechnIQ/CalendarHeatMapView.swift TechnIQ/Views/Analytics/

# Community
git mv TechnIQ/CommunityView.swift TechnIQ/Views/Community/
git mv TechnIQ/CommunityFeedView.swift TechnIQ/Views/Community/
git mv TechnIQ/CreatePostView.swift TechnIQ/Views/Community/
git mv TechnIQ/PostDetailView.swift TechnIQ/Views/Community/
git mv TechnIQ/LeaderboardView.swift TechnIQ/Views/Community/
git mv TechnIQ/DrillMarketplaceView.swift TechnIQ/Views/Community/
git mv TechnIQ/ShareToCommunitySheet.swift TechnIQ/Views/Community/
git mv TechnIQ/PublicProfileView.swift TechnIQ/Views/Community/

# Settings
git mv TechnIQ/SettingsView.swift TechnIQ/Views/Settings/
git mv TechnIQ/EditProfileView.swift TechnIQ/Views/Settings/
git mv TechnIQ/SharePlanView.swift TechnIQ/Views/Settings/
git mv TechnIQ/PaywallView.swift TechnIQ/Views/Settings/
git mv TechnIQ/EnhancedProfileView.swift TechnIQ/Views/Settings/
git mv TechnIQ/PlayerProfileView.swift TechnIQ/Views/Settings/
git mv TechnIQ/WeaknessSuggestionsCard.swift TechnIQ/Views/Settings/

# Components
git mv TechnIQ/ModernComponents.swift TechnIQ/Components/
git mv TechnIQ/DesignSystem.swift TechnIQ/Components/
git mv TechnIQ/AccessibilityModifiers.swift TechnIQ/Components/
git mv TechnIQ/TransitionSystem.swift TechnIQ/Components/
git mv TechnIQ/MascotView.swift TechnIQ/Components/
git mv TechnIQ/Components/CoachMarkOverlay.swift TechnIQ/Components/CoachMarkOverlay.swift 2>/dev/null || true
git mv TechnIQ/CalendarComponents.swift TechnIQ/Components/ 2>/dev/null || true
git mv TechnIQ/CoinDisplayView.swift TechnIQ/Components/ 2>/dev/null || true
git mv TechnIQ/ConfettiView.swift TechnIQ/Components/ 2>/dev/null || true
git mv TechnIQ/EmptyStateView.swift TechnIQ/Components/ 2>/dev/null || true
git mv TechnIQ/ProLockedCardView.swift TechnIQ/Components/ 2>/dev/null || true
git mv TechnIQ/TodaysFocusCard.swift TechnIQ/Components/ 2>/dev/null || true

# Models (non-CoreData)
git mv TechnIQ/AICoachModels.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/CustomDrillModels.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/FirestoreDataModels.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/MascotState.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/MLProfileModels.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/WeaknessModels.swift TechnIQ/Models/ 2>/dev/null || true
git mv TechnIQ/YouTubeConfig.swift TechnIQ/Models/ 2>/dev/null || true

# Utilities
git mv TechnIQ/AppLogger.swift TechnIQ/Utilities/
git mv TechnIQ/HapticManager.swift TechnIQ/Utilities/

# Remaining views
git mv TechnIQ/WeaknessPickerView.swift TechnIQ/Views/Analytics/ 2>/dev/null || true
```

Note: Some files may not exist or may have different names. The `2>/dev/null || true` handles missing files. After running, check `git status` for any files still in `TechnIQ/` root that should be moved.

- [ ] **Step 5: Update Xcode project**

Open Xcode. The project will show red (missing) file references. For each group:
1. Delete the red references (Remove Reference, NOT Move to Trash)
2. Drag the new folder into the correct Xcode group
3. Ensure Target Membership is checked for `TechnIQ` target

Alternatively, use the xcodeproj gem carefully:

```ruby
# Only if confident — manual Xcode is safer
```

- [ ] **Step 6: Build to verify**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`

Fix any broken references until build succeeds.

- [ ] **Step 7: Run tests**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test 2>&1 | tail -15`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: reorganize 147 files into folder structure"
```

---

### Task 15: Split CoreDataManager

**Files:**
- Modify: `TechnIQ/Services/CoreDataManager.swift`
- Create: `TechnIQ/Services/YouTubeDataService.swift`
- Create: `TechnIQ/Services/CoreDataFetchRequests.swift`

- [ ] **Step 1: Identify YouTube-related code in CoreDataManager**

Read `CoreDataManager.swift` and identify all YouTube/video-related types and methods:
- Types: `EnhancedVideoDetails`, `VideoTranscript`, `EnhancedYouTubeVideo`, `DifficultyAnalysis`
- Methods: YouTube search, transcript fetching, video detail caching, enhanced video processing
- Any properties supporting the above (caches, circuit breakers, etc.)

- [ ] **Step 2: Create YouTubeDataService.swift**

Extract all YouTube-related code into `TechnIQ/Services/YouTubeDataService.swift`:

```swift
import Foundation
import CoreData

// Types
struct EnhancedVideoDetails { ... }  // Move from CoreDataManager
struct VideoTranscript { ... }       // Move from CoreDataManager
// etc.

/// Service for YouTube video data, caching, and search
final class YouTubeDataService {
    static let shared = YouTubeDataService()
    private let coreDataManager = CoreDataManager.shared

    private init() {}

    // MARK: - Video Search
    // Move all search methods here

    // MARK: - Transcript
    // Move all transcript methods here

    // MARK: - Caching
    // Move all video detail caching here
}
```

- [ ] **Step 3: Create CoreDataFetchRequests.swift**

Extract reusable fetch request builder methods:

```swift
import Foundation
import CoreData

/// Reusable Core Data fetch request builders
extension CoreDataManager {
    // MARK: - Player Fetch Requests
    // Move generic fetch helpers here

    // MARK: - Session Fetch Requests
    // Move session query helpers here

    // MARK: - Exercise Fetch Requests
    // Move exercise query helpers here
}
```

- [ ] **Step 4: Update all callers**

Grep for any references to moved methods and update to use `YouTubeDataService.shared`:

```bash
grep -rn "CoreDataManager.shared.*youtube\|CoreDataManager.shared.*video\|CoreDataManager.shared.*transcript" TechnIQ/
```

- [ ] **Step 5: Build + test**

Run build and test commands. Fix any broken references.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: extract YouTubeDataService and CoreDataFetchRequests from CoreDataManager"
```

---

### Task 16: Final M2 verification + merge

- [ ] **Step 1: Full build + tests**

Run build and test commands. All must pass.

- [ ] **Step 2: Merge to main**

```bash
git checkout main
git merge cleanup/m2-folder-structure
```

---

## Chunk 3: M3 — Protocols + Dependency Injection

**Branch:** `cleanup/m3-protocols-di`

### Task 17: Setup branch

- [ ] **Step 1: Create branch + checkpoint**

```bash
git checkout main
git tag pre-m3
git checkout -b cleanup/m3-protocols-di
```

- [ ] **Step 2: Create protocol directory**

```bash
mkdir -p TechnIQ/Services/Protocols
```

---

### Task 18: CoreDataManager protocol

**Files:**
- Create: `TechnIQ/Services/Protocols/CoreDataManagerProtocol.swift`
- Modify: `TechnIQ/Services/CoreDataManager.swift`
- Modify: `TechnIQTests/TestHelpers/TestCoreDataStack.swift`

- [ ] **Step 1: Define protocol**

Read `CoreDataManager.swift` and extract its public interface. Create:

```swift
// TechnIQ/Services/Protocols/CoreDataManagerProtocol.swift
import Foundation
import CoreData

protocol CoreDataManagerProtocol: AnyObject {
    var context: NSManagedObjectContext { get }
    func save()
    func getCurrentPlayer() -> Player?
    // Add other public methods called by other services
    // Read CoreDataManager.swift to get the full list
}
```

- [ ] **Step 2: Conform CoreDataManager**

Add conformance:

```swift
// In CoreDataManager.swift, change:
final class CoreDataManager: CoreDataManagerProtocol {
```

No other changes needed if the protocol matches existing methods.

- [ ] **Step 3: Conform TestCoreDataStack**

In `TechnIQTests/TestHelpers/TestCoreDataStack.swift`:

```swift
class TestCoreDataStack: CoreDataManagerProtocol {
    // Already has `context` and can add `save()` + `getCurrentPlayer()`
    func save() { try? context.save() }
    func getCurrentPlayer() -> Player? {
        let request = Player.fetchRequest()
        return try? context.fetch(request).first
    }
}
```

- [ ] **Step 4: Build + test**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: add CoreDataManagerProtocol + TestCoreDataStack conformance"
```

---

### Task 19: XPService protocol + DI

**Files:**
- Create: `TechnIQ/Services/Protocols/XPServiceProtocol.swift`
- Modify: `TechnIQ/Services/XPService.swift`

- [ ] **Step 1: Define protocol**

```swift
// TechnIQ/Services/Protocols/XPServiceProtocol.swift
import Foundation
import CoreData

// Note: SessionXPBreakdown and LevelTier must be promoted to top-level types
// (moved out of XPService nesting) so the protocol doesn't reference its conforming type.
// Move them to TechnIQ/Models/XPModels.swift before defining this protocol.

protocol XPServiceProtocol: AnyObject {
    func xpRequiredForLevel(_ level: Int) -> Int64
    func levelForXP(_ xp: Int64) -> Int
    func progressToNextLevel(totalXP: Int64, currentLevel: Int) -> Double
    func tierForLevel(_ level: Int) -> LevelTier?
    func calculateSessionXP(intensity: Int16, exerciseCount: Int, allExercisesCompleted: Bool, hasRating: Bool, hasNotes: Bool, isFirstSessionOfDay: Bool, currentStreak: Int16) -> SessionXPBreakdown
    func awardXP(to player: Player, amount: Int32) -> Int?
    func updateStreak(for player: Player, sessionDate: Date)
    func processSessionCompletion(session: TrainingSession, player: Player, context: NSManagedObjectContext, allExercisesCompleted: Bool) -> (xp: SessionXPBreakdown, levelUp: Int?)
    func purchaseStreakFreeze(for player: Player, context: NSManagedObjectContext) -> Bool
}
```

- [ ] **Step 2: Conform XPService + make init private + add test init**

```swift
final class XPService: XPServiceProtocol {
    static let shared = XPService()

    private init() {}

    // Test-only init
    init(forTesting: Bool) {}
```

- [ ] **Step 3: Update XPServiceTests**

Change `sut = XPService()` to `sut = XPService(forTesting: true)`.

- [ ] **Step 4: Build + test, commit**

```bash
git add -A
git commit -m "refactor: add XPServiceProtocol + DI + private init"
```

---

### Task 20: CoinService protocol + DI

**Files:**
- Create: `TechnIQ/Services/Protocols/CoinServiceProtocol.swift`
- Modify: `TechnIQ/Services/CoinService.swift`

- [ ] **Step 1: Define protocol**

Read `CoinService.swift` public methods and create protocol.

- [ ] **Step 2: Add DI for coreDataManager dependency**

```swift
final class CoinService: ObservableObject, CoinServiceProtocol {
    static let shared = CoinService()
    private let coreDataManager: CoreDataManagerProtocol

    // Published properties stay as-is
    @Published private(set) var currentBalance: Int = 0
    @Published private(set) var lastTransaction: CoinTransaction?

    private init(coreDataManager: CoreDataManagerProtocol = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
        loadCurrentBalance()
    }

    // Internal init for testing
    init(testCoreDataManager: CoreDataManagerProtocol) {
        self.coreDataManager = testCoreDataManager
        loadCurrentBalance()
    }
}
```

**Important:** Keep `ObservableObject` conformance — views depend on it via `@ObservedObject`. Change the existing `private let coreDataManager = CoreDataManager.shared` to the init-injected version above. Same pattern applies to ALL services that conform to `ObservableObject` — always keep that conformance alongside the new protocol.

- [ ] **Step 3: Update CoinServiceTests if needed**

- [ ] **Step 4: Build + test, commit**

```bash
git add -A
git commit -m "refactor: add CoinServiceProtocol + DI"
```

---

### Task 21: AchievementService protocol + DI

Same pattern as Task 20. Create `AchievementServiceProtocol.swift`, conform, add test init, update tests.

```bash
git commit -m "refactor: add AchievementServiceProtocol + DI"
```

---

### Task 22: MatchService protocol + DI

Same pattern. Create `MatchServiceProtocol.swift`, conform, add DI.

```bash
git commit -m "refactor: add MatchServiceProtocol + DI"
```

---

### Task 23: TrainingPlanService protocol + DI

Same pattern. Create `TrainingPlanServiceProtocol.swift`, conform, add DI.

```bash
git commit -m "refactor: add TrainingPlanServiceProtocol + DI"
```

---

### Task 24: ActiveSessionManager protocol + DI

Same pattern. Create `ActiveSessionManagerProtocol.swift`, conform, add DI.

```bash
git commit -m "refactor: add ActiveSessionManagerProtocol + DI"
```

---

### Task 25: Cloud services protocols (CloudDataService, CloudSyncManager, CloudRestoreService)

Create protocols for all 3 cloud services. These will be consolidated into a single `CloudServiceProtocol` in M5, but for now create individual protocols to enable testing.

```bash
git commit -m "refactor: add Cloud service protocols"
```

---

### Task 26: Create mock directory + basic mocks

**Files:**
- Create: `TechnIQTests/Mocks/MockCoreDataManager.swift`

- [ ] **Step 1: Create mocks directory**

```bash
mkdir -p TechnIQTests/Mocks
```

- [ ] **Step 2: Create MockCoreDataManager**

```swift
// TechnIQTests/Mocks/MockCoreDataManager.swift
import CoreData
@testable import TechnIQ

final class MockCoreDataManager: CoreDataManagerProtocol {
    let testStack = TestCoreDataStack()

    var context: NSManagedObjectContext { testStack.context }

    func save() { try? context.save() }

    var stubbedPlayer: Player?
    func getCurrentPlayer() -> Player? {
        return stubbedPlayer ?? testStack.makePlayer()
    }
}
```

- [ ] **Step 3: Build + test, commit**

```bash
git add -A
git commit -m "refactor: add MockCoreDataManager + mocks directory"
```

---

### Task 27: Final M3 verification + merge

- [ ] **Step 1: Full build + tests**
- [ ] **Step 2: Merge**

```bash
git checkout main
git merge cleanup/m3-protocols-di
```

---

## Chunk 4: M4 — Core Data Thread Safety

**Branch:** `cleanup/m4-thread-safety`

### Task 28: Setup branch

```bash
git checkout main
git tag pre-m4
git checkout -b cleanup/m4-thread-safety
```

---

### Task 29: Add @MainActor to CoinService (pilot)

**Files:**
- Modify: `TechnIQ/Services/CoinService.swift`
- Modify: `TechnIQ/Services/Protocols/CoinServiceProtocol.swift`

- [ ] **Step 1: Add @MainActor to protocol**

```swift
@MainActor
protocol CoinServiceProtocol: AnyObject { ... }
```

- [ ] **Step 2: Add @MainActor to class**

```swift
@MainActor
final class CoinService: CoinServiceProtocol { ... }
```

- [ ] **Step 3: Build — count errors to gauge blast radius**

Run: `xcodebuild ... build 2>&1 | grep "error:" | wc -l`

Fix each error. Most will be in views (already `@MainActor` implicitly) — those should compile fine. Errors will be in `Task {}` blocks or async functions that need `await`.

- [ ] **Step 4: Fix all callers, build succeeds**
- [ ] **Step 5: Commit**

```bash
git commit -m "refactor: add @MainActor to CoinService + fix callers"
```

---

### Task 30: Add @MainActor to remaining services

Apply the same pattern to each service, one at a time, building after each:

- [ ] **Step 1: XPService** → build → fix callers → commit
- [ ] **Step 2: AchievementService** → build → fix callers → commit
- [ ] **Step 3: MatchService** → build → fix callers → commit
- [ ] **Step 4: TrainingPlanService** → build → fix callers → commit
- [ ] **Step 5: ActiveSessionManager** → build → fix callers → commit
- [ ] **Step 6: AvatarService** → build → fix callers → commit
- [ ] **Step 7: InsightsEngine** → build → fix callers → commit
- [ ] **Step 8: WeaknessAnalysisService** → build → fix callers → commit

Each commit: `refactor: add @MainActor to <ServiceName>`

---

### Task 31: Fix CloudSyncManager @objc handler

**Files:**
- Modify: `TechnIQ/Services/CloudSyncManager.swift`

- [ ] **Step 1: Replace @objc notification handler with async**

Find the `@objc private func handleCoreDataChange` method. Replace with:

```swift
// BEFORE:
@objc private func handleCoreDataChange(_ notification: Notification) {
    Task {
        await performIncrementalSync()
    }
}

// AFTER — in init or setup method:
private var notificationTask: Task<Void, Never>?

private func startListeningForChanges() {
    notificationTask = Task { [weak self] in
        let notifications = NotificationCenter.default.notifications(
            named: .NSManagedObjectContextDidSave
        )
        for await _ in notifications {
            await self?.performIncrementalSync()
        }
    }
}
```

Remove the old `NotificationCenter.addObserver(self, selector:)` call and replace with `startListeningForChanges()`.

- [ ] **Step 2: Build + test, commit**

```bash
git commit -m "refactor: replace @objc notification handler with async in CloudSyncManager"
```

---

### Task 32: Fix AuthenticationManager @Published mutations

**Files:**
- Modify: `TechnIQ/Services/AuthenticationManager.swift`

- [ ] **Step 1: Audit all @Published property mutations**

Grep for all `@Published` properties and ensure mutations are on MainActor:

```bash
grep -n '@Published' TechnIQ/Services/AuthenticationManager.swift
```

Then for each property, grep for mutations outside `MainActor.run {}`:

```bash
grep -n 'errorMessage =' TechnIQ/Services/AuthenticationManager.swift
grep -n 'isAuthenticated =' TechnIQ/Services/AuthenticationManager.swift
grep -n 'isLoading =' TechnIQ/Services/AuthenticationManager.swift
```

- [ ] **Step 2: Wrap any unprotected mutations**

For any mutation not already inside `await MainActor.run { }`, wrap it.

- [ ] **Step 3: Build + test, commit**

```bash
git commit -m "fix: ensure all AuthenticationManager @Published mutations on MainActor"
```

---

### Task 33: Batch CoinService.awardSessionCoins saves

**Files:**
- Modify: `TechnIQ/Services/CoinService.swift`

- [ ] **Step 1: Find awardSessionCoins method**

Read the method. It calls `awardCoins` up to 4 times, each doing `context.save()`.

- [ ] **Step 2: Refactor to batch saves**

Create an internal method that accumulates coin awards without saving, then save once at the end:

```swift
func awardSessionCoins(duration: TimeInterval, isFirstOfDay: Bool, rating: Int, streakDay: Int) {
    guard let player = coreDataManager.getCurrentPlayer() else { return }
    let ctx = coreDataManager.context

    var totalCoins = 0

    // Base session coins
    totalCoins += CoinEarningEvent.sessionCompleted(duration: duration).coins

    // First of day bonus
    if isFirstOfDay {
        totalCoins += CoinEarningEvent.firstSessionOfDay.coins
    }

    // Rating bonus
    if rating == 5 {
        totalCoins += CoinEarningEvent.fiveStarRating.coins
    }

    // Streak bonus
    if streakDay > 0 {
        totalCoins += CoinEarningEvent.dailyStreakBonus(streakDay: streakDay).coins
    }

    // Single award + single save
    if totalCoins > 0 {
        player.coins += Int64(totalCoins)
        player.totalCoinsEarned += Int64(totalCoins)
        do {
            try ctx.save()
        } catch {
            #if DEBUG
            print("[CoinService] Error saving session coins: \(error)")
            #endif
        }
        loadCurrentBalance()
    }
}
```

- [ ] **Step 3: Build + test, commit**

```bash
git commit -m "refactor: batch CoinService session coin awards into single save"
```

---

### Task 34: Final M4 verification + merge

- [ ] **Step 1: Full build + tests**
- [ ] **Step 2: Merge**

```bash
git checkout main
git merge cleanup/m4-thread-safety
```

---

## Chunk 5: M5 — Service Consolidation

**Branch:** `cleanup/m5-service-consolidation`

### Task 35: Setup branch

```bash
git checkout main
git tag pre-m5
git checkout -b cleanup/m5-service-consolidation
```

---

### Task 36: Merge Cloud services into CloudService

**Files:**
- Create: `TechnIQ/Services/Cloud/CloudService.swift`
- Create: `TechnIQ/Services/Cloud/CloudService+Upload.swift`
- Create: `TechnIQ/Services/Cloud/CloudService+Download.swift`
- Create: `TechnIQ/Services/Cloud/CloudService+Restore.swift`
- Create: `TechnIQ/Services/Cloud/CloudService+ConflictResolution.swift`
- Create: `TechnIQ/Services/Protocols/CloudServiceProtocol.swift`
- Delete: `TechnIQ/Services/CloudDataService.swift`
- Delete: `TechnIQ/Services/CloudSyncManager.swift`
- Delete: `TechnIQ/Services/CloudRestoreService.swift`
- Delete: Old cloud protocol files

- [ ] **Step 1: Create Cloud directory**

```bash
mkdir -p TechnIQ/Services/Cloud
```

- [ ] **Step 2: Create CloudServiceProtocol**

Merge the public interfaces of all 3 cloud services into one protocol.

- [ ] **Step 3: Create CloudService.swift (core)**

```swift
@MainActor
final class CloudService: ObservableObject, CloudServiceProtocol {
    static let shared = CloudService()

    // Merge published properties from all 3 services
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isRestoring: Bool = false

    // Shared dependencies
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    // etc.
}
```

- [ ] **Step 4: Create extension files**

Move methods from each old service into the appropriate extension:
- `CloudDataService` upload methods → `CloudService+Upload.swift`
- `CloudSyncManager` sync methods → `CloudService+Download.swift`
- `CloudRestoreService` restore methods → `CloudService+Restore.swift`
- Conflict resolution methods → `CloudService+ConflictResolution.swift`

Each extension file must be under 500 lines.

- [ ] **Step 5: Update all references**

```bash
# Find and replace all old service references
grep -rn "CloudDataService" TechnIQ/ --include="*.swift"
grep -rn "CloudSyncManager" TechnIQ/ --include="*.swift"
grep -rn "CloudRestoreService" TechnIQ/ --include="*.swift"
```

Replace with `CloudService.shared` everywhere.

- [ ] **Step 6: Delete old files**

```bash
git rm TechnIQ/Services/CloudDataService.swift
git rm TechnIQ/Services/CloudSyncManager.swift
git rm TechnIQ/Services/CloudRestoreService.swift
```

- [ ] **Step 7: Build + test, commit**

```bash
git add -A
git commit -m "refactor: merge Cloud services into single CloudService"
```

---

### Task 37: Merge YouTube services

**Files:**
- Create: `TechnIQ/Services/YouTubeService.swift` (merge of YouTubeAPIService + YouTubeDataService)
- Delete old files

Same pattern as Task 36 but simpler (2 services → 1).

```bash
git commit -m "refactor: merge YouTubeAPIService + YouTubeDataService into YouTubeService"
```

---

### Task 38: Rename CloudMLService → AIRecommendationService

**Files:**
- Rename: `TechnIQ/Services/CloudMLService.swift` → `TechnIQ/Services/AIRecommendationService.swift`

- [ ] **Step 1: Rename file**

```bash
git mv TechnIQ/Services/CloudMLService.swift TechnIQ/Services/AIRecommendationService.swift
```

- [ ] **Step 2: Rename class inside file**

Find and replace `CloudMLService` → `AIRecommendationService` in the file.

- [ ] **Step 3: Update all 9 references**

```bash
grep -rn "CloudMLService" TechnIQ/ --include="*.swift"
```

Replace all with `AIRecommendationService`.

- [ ] **Step 4: Build + test, commit**

```bash
git add -A
git commit -m "refactor: rename CloudMLService to AIRecommendationService"
```

---

### Task 39: Add Phase 2 protocols for remaining services

Add protocols for: AvatarService, AuthenticationManager, AIRecommendationService, CustomDrillService, YouTubeService, InsightsEngine, SubscriptionManager, WeaknessAnalysisService, AICoachService, CommunityService.

One commit per 2-3 protocols:

```bash
git commit -m "refactor: add protocols for Avatar, Auth, AIRecommendation services"
git commit -m "refactor: add protocols for CustomDrill, YouTube, Insights services"
git commit -m "refactor: add protocols for Subscription, Weakness, AICoach, Community services"
```

---

### Task 40: Final M5 verification + merge

- [ ] **Step 1: Verify zero references to old service names**

```bash
grep -rn "CloudDataService\|CloudSyncManager\|CloudRestoreService\|CloudMLService\|YouTubeAPIService\|YouTubeDataService" TechnIQ/ --include="*.swift"
```

Expected: 0 results.

- [ ] **Step 2: Full build + tests, merge**

```bash
git checkout main
git merge cleanup/m5-service-consolidation
```

---

## Chunk 6: M6 — View Decomposition

**Branch:** `cleanup/m6-view-decomposition`

### Task 41: Setup branch

```bash
git checkout main
git tag pre-m6
git checkout -b cleanup/m6-view-decomposition
```

---

### Task 42: Decompose DashboardView

**Files:**
- Modify: `TechnIQ/Views/Dashboard/DashboardView.swift`
- Create: `TechnIQ/Views/Dashboard/DashboardStatsSection.swift`
- Create: `TechnIQ/Views/Dashboard/DashboardQuickActions.swift`
- Create: `TechnIQ/Views/Dashboard/DashboardRecentActivity.swift`
- Create: `TechnIQ/Views/Dashboard/DashboardMatchesSection.swift`
- Create: `TechnIQ/Views/Dashboard/DashboardAIDrillBanner.swift`

- [ ] **Step 1: Read DashboardView.swift fully**

Identify each computed property that returns `some View` — these become separate structs.

- [ ] **Step 2: Extract each section into its own file**

For each section (stats, quick actions, recent activity, matches, AI drill banner):
1. Create a new file with a struct conforming to `View`
2. Move the computed property body into the struct's `body`
3. Pass required data as init params
4. Add `#Preview` block

Pattern:
```swift
// TechnIQ/Views/Dashboard/DashboardStatsSection.swift
import SwiftUI

struct DashboardStatsSection: View {
    let player: Player

    var body: some View {
        // Move content from DashboardView.modernStatsOverview()
    }
}

#Preview {
    DashboardStatsSection(player: .preview)
}
```

- [ ] **Step 3: Update DashboardView to compose sections**

Replace computed properties with struct instantiation. Target: DashboardView.swift under 300 lines.

- [ ] **Step 4: Build + test, commit**

```bash
git add -A
git commit -m "refactor: decompose DashboardView into 5 section components"
```

---

### Task 43: Decompose ExerciseLibraryView

Same pattern — extract ExerciseFilterBar, ExerciseGridItem, ExerciseSearchResults.

```bash
git commit -m "refactor: decompose ExerciseLibraryView into subviews"
```

---

### Task 44: Decompose NewSessionView

Extract SessionSetupStep, ExerciseSelectionStep, SessionReviewStep.

```bash
git commit -m "refactor: decompose NewSessionView into step views"
```

---

### Task 45: Decompose SessionCalendarView

Extract CalendarGrid, SessionDayDetail.

```bash
git commit -m "refactor: decompose SessionCalendarView into subviews"
```

---

### Task 46: Decompose UnifiedOnboardingView

Extract individual step views.

```bash
git commit -m "refactor: decompose UnifiedOnboardingView into step views"
```

---

### Task 47: Decompose PlayerProgressView

Extract ProgressStatsCard, ProgressCharts, ProgressTimeline.

```bash
git commit -m "refactor: decompose PlayerProgressView into subviews"
```

---

### Task 48: Fix @StateObject → @ObservedObject for singletons

**Files:**
- ~20 view files

- [ ] **Step 1: Find all misused @StateObject**

```bash
grep -rn "@StateObject.*\.shared" TechnIQ/ --include="*.swift"
```

- [ ] **Step 2: Replace each with @ObservedObject**

For each match, change `@StateObject` to `@ObservedObject`. No other changes needed.

- [ ] **Step 3: Build + test, commit**

```bash
git add -A
git commit -m "fix: replace @StateObject with @ObservedObject for singleton services"
```

---

### Task 49: Final M6 verification + merge

- [ ] **Step 1: Verify no view file over 500 lines in decomposed views**

```bash
wc -l TechnIQ/Views/Dashboard/*.swift TechnIQ/Views/Training/NewSessionView.swift TechnIQ/Views/Training/SessionCalendarView.swift TechnIQ/Views/Analytics/PlayerProgressView.swift TechnIQ/Views/Auth/UnifiedOnboardingView.swift TechnIQ/Views/Exercises/ExerciseLibraryView.swift | sort -rn | head -10
```

- [ ] **Step 2: Full build + tests, merge**

```bash
git checkout main
git merge cleanup/m6-view-decomposition
```

---

## Chunk 7: M7 — Error Handling + Test Coverage

**Branch:** `cleanup/m7-error-handling-tests`

### Task 50: Setup branch

```bash
git checkout main
git tag pre-m7
git checkout -b cleanup/m7-error-handling-tests
```

---

### Task 51: Define ServiceError type

**Files:**
- Create: `TechnIQ/Services/ServiceError.swift`

- [ ] **Step 1: Create error enum**

```swift
// TechnIQ/Services/ServiceError.swift
import Foundation

enum ServiceError: LocalizedError {
    case network(String)
    case coreData(String)
    case validation(String)
    case sync(String)
    case auth(String)
    case notFound(String)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return "Network error: \(msg)"
        case .coreData(let msg): return "Data error: \(msg)"
        case .validation(let msg): return "Validation error: \(msg)"
        case .sync(let msg): return "Sync error: \(msg)"
        case .auth(let msg): return "Authentication error: \(msg)"
        case .notFound(let msg): return "\(msg) not found"
        }
    }
}
```

- [ ] **Step 2: Build, commit**

```bash
git add TechnIQ/Services/ServiceError.swift
git commit -m "feat: add ServiceError enum for standardized error handling"
```

---

### Task 52: Add lastError to services

**Files:**
- Modify: All service files (one at a time)

- [ ] **Step 1: Add @Published var lastError to each service**

For each service protocol and implementation:

```swift
// In protocol:
var lastError: ServiceError? { get }

// In implementation:
@Published private(set) var lastError: ServiceError?
```

- [ ] **Step 2: Replace silent error swallowing**

Find `#if DEBUG print` error patterns:

```bash
grep -rn '#if DEBUG' TechnIQ/Services/ --include="*.swift" -A2 | grep 'print.*error\|print.*Error'
```

Replace with:
```swift
// BEFORE:
} catch {
    #if DEBUG
    print("Error: \(error)")
    #endif
    return []
}

// AFTER:
} catch {
    AppLogger.shared.error("Description: \(error)")
    lastError = .coreData(error.localizedDescription)
    return []
}
```

Do this incrementally — one service per commit:

```bash
git commit -m "refactor: add error handling to CoinService"
git commit -m "refactor: add error handling to XPService"
# etc.
```

---

### Task 53: Expand TestCoreDataStack factories

**Files:**
- Modify: `TechnIQTests/TestHelpers/TestCoreDataStack.swift`

- [ ] **Step 1: Add TrainingPlan factory**

```swift
@discardableResult
func makeTrainingPlan(
    player: Player,
    name: String = "Test Plan",
    isActive: Bool = false
) -> TrainingPlan {
    let plan = TrainingPlan(context: context)
    plan.id = UUID()
    plan.name = name
    plan.player = player
    plan.isActive = isActive
    plan.createdAt = Date()
    try? context.save()
    return plan
}
```

- [ ] **Step 2: Add PlanWeek, PlanDay factories**

Similar pattern.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "test: expand TestCoreDataStack with plan entity factories"
```

---

### Task 54: Write service integration tests

**Files:**
- Create: `TechnIQTests/TrainingPlanServiceTests.swift`
- Create: `TechnIQTests/CloudServiceTests.swift`
- Modify: `TechnIQTests/CoinServiceTests.swift` (add integration tests)
- Modify: `TechnIQTests/AchievementServiceTests.swift` (add integration tests)

- [ ] **Step 1: TrainingPlanService tests**

Test key methods: plan creation, getCurrentDay, completion progression.

- [ ] **Step 2: MatchService integration tests**

Test CRUD operations with mock CoreDataManager.

- [ ] **Step 3: CoinService integration tests**

Test awardCoins, deductCoins, awardSessionCoins with real Core Data stack.

- [ ] **Step 4: ActiveSessionManager tests**

Test session lifecycle, XP award correctness for partial vs full sessions.

Each batch of tests → build + test → commit:

```bash
git commit -m "test: add TrainingPlanService tests"
git commit -m "test: add MatchService integration tests"
git commit -m "test: add CoinService integration tests"
git commit -m "test: add ActiveSessionManager tests"
```

---

### Task 55: Final M7 verification + merge

- [ ] **Step 1: Full build + tests**
- [ ] **Step 2: Check test count**

```bash
xcodebuild test ... 2>&1 | grep "Test Case" | wc -l
```

Should be significantly higher than baseline.

- [ ] **Step 3: Merge**

```bash
git checkout main
git merge cleanup/m7-error-handling-tests
```

- [ ] **Step 4: Clean up tags**

```bash
git tag cleanup-complete
```
