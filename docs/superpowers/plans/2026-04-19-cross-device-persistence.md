# Cross-Device Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make user profiles round-trip losslessly across devices — sign in on a new device and get back exactly what the previous device had.

**Architecture:** Close the five concrete persistence gaps in `CloudService`: (1) sync `PlayerStats`, (2) sync `Match` + `Season`, (3) restore `PlanSession.exercises` relationship, (4) link anonymous accounts into real ones so onboarding data isn't orphaned, (5) harden `hasCloudData()` so partial uploads don't trigger ghost restores. All work is additive to existing Firestore schema under `users/{uid}/{collection}`, which is already allowed by the `firestore.rules` subcollection wildcard (firestore.rules:28-30) — no rules changes needed. Tests exercise the pure `createXDocument`/`restoreX` helpers as round-trip pairs using `TestCoreDataStack`.

**Tech Stack:** Swift, Core Data, Firebase Auth (`Auth.auth().currentUser.link(with:)`), Firestore, XCTest + `TestCoreDataStack` in-memory store.

---

## File Structure

**Modify:**
- `TechnIQ/Services/Cloud/CloudService+Upload.swift` — add `syncPlayerStats`, `syncMatches`, `syncSeasons`, `createPlayerStatsDocument`, `createMatchDocument`, `createSeasonDocument`; extend `fetchAllUserData()` + `CloudUserData`; harden `hasCloudData()`; store `seasonID` in match doc.
- `TechnIQ/Services/Cloud/CloudService+Restore.swift` — add `restorePlayerStats`, `restoreSeason`, `restoreMatch`; add post-pass to wire `PlanSession.exercises` from `exerciseIDs`; change restore order so Seasons precede Matches.
- `TechnIQ/Services/Cloud/CloudService+Sync.swift` — add `syncPlayerStatsData`, `syncMatchData` (which handles seasons then matches) to `performFullSync()`.
- `TechnIQ/Services/AuthenticationManager.swift` — add `linkAnonymousAccount(with credential:)` path used by `signUp`/`signInWithGoogle`/`signInWithApple` when `currentUser?.isAnonymous == true`.
- `TechnIQTests/TestHelpers/TestCoreDataStack.swift` — add `makePlayerStats`, `makeTrainingPlanWithExercises` factories.

**Create:**
- `TechnIQTests/CloudServicePersistenceTests.swift` — round-trip tests for PlayerStats, Match, Season, PlanSession.exercises; `hasCloudData` empty/partial/complete cases.

**No changes:**
- `firestore.rules` — the `users/{uid}/{subcollection}` wildcard (line 28-30) already permits any new owner-scoped subcollection.
- Core Data model — all required entities (`PlayerStats`, `Match`, `Season`) already exist with the right fields.

---

### Task 1: PlayerStats round-trip

**Files:**
- Modify: `TechnIQ/Services/Cloud/CloudService+Upload.swift`
- Modify: `TechnIQ/Services/Cloud/CloudService+Restore.swift`
- Modify: `TechnIQ/Services/Cloud/CloudService+Sync.swift`
- Modify: `TechnIQTests/TestHelpers/TestCoreDataStack.swift`
- Create: `TechnIQTests/CloudServicePersistenceTests.swift`

- [ ] **Step 1: Add `makePlayerStats` factory to `TestCoreDataStack`**

Append after `makeSeason` in `TechnIQTests/TestHelpers/TestCoreDataStack.swift:230`:

```swift
    @discardableResult
    func makePlayerStats(
        player: Player,
        date: Date = Date(),
        skillRatings: [String: Double] = ["passing": 4.0, "shooting": 3.5],
        totalHours: Double = 12.5,
        totalSessions: Int32 = 8
    ) -> PlayerStats {
        let stats = PlayerStats(context: context)
        stats.id = UUID()
        stats.player = player
        stats.date = date
        stats.skillRatings = skillRatings
        stats.totalTrainingHours = totalHours
        stats.totalSessions = totalSessions
        try? context.save()
        return stats
    }
```

- [ ] **Step 2: Write failing round-trip test for PlayerStats**

Create `TechnIQTests/CloudServicePersistenceTests.swift`:

```swift
import XCTest
import CoreData
import FirebaseFirestore
@testable import TechnIQ

@MainActor
final class CloudServicePersistenceTests: XCTestCase {
    var stack: TestCoreDataStack!
    var sut: CloudService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = CloudService.shared
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - PlayerStats round-trip

    func test_playerStats_encodeDecode_preservesAllFields() throws {
        let player = stack.makePlayer()
        let ratings: [String: Double] = ["passing": 4.2, "shooting": 3.8, "dribbling": 4.0]
        let original = stack.makePlayerStats(
            player: player,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            skillRatings: ratings,
            totalHours: 42.5,
            totalSessions: 17
        )

        let doc = sut.createPlayerStatsDocument(stats: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restorePlayerStats(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.stats?.allObjects as? [PlayerStats])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.date?.timeIntervalSince1970, original.date?.timeIntervalSince1970)
        XCTAssertEqual(restored?.totalTrainingHours, 42.5)
        XCTAssertEqual(restored?.totalSessions, 17)
        XCTAssertEqual(restored?.skillRatings?["passing"], 4.2)
        XCTAssertEqual(restored?.skillRatings?["shooting"], 3.8)
        XCTAssertEqual(restored?.skillRatings?["dribbling"], 4.0)
    }
}
```

- [ ] **Step 3: Run test, confirm compile failure**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests test 2>&1 | tail -20`

Expected: compile failure — `createPlayerStatsDocument` and `restorePlayerStats` don't exist.

- [ ] **Step 4: Implement `createPlayerStatsDocument` in `CloudService+Upload.swift`**

Add at the bottom of the `extension CloudService { ... }` (document-creation block), after line 420 (after `createCustomExerciseDocument`):

```swift
    func createPlayerStatsDocument(stats: PlayerStats) -> [String: Any] {
        return [
            "id": stats.id?.uuidString ?? "",
            "date": stats.date ?? Date(),
            "skillRatings": stats.skillRatings ?? [:],
            "totalTrainingHours": stats.totalTrainingHours,
            "totalSessions": stats.totalSessions
        ]
    }
```

- [ ] **Step 5: Implement `restorePlayerStats` in `CloudService+Restore.swift`**

Add after `restorePlayerGoal` (around line 206):

```swift
    func restorePlayerStats(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let stats = PlayerStats(context: context)
        stats.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        stats.date = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
        stats.skillRatings = data["skillRatings"] as? [String: Double]
        stats.totalTrainingHours = data["totalTrainingHours"] as? Double ?? 0
        stats.totalSessions = Int32(data["totalSessions"] as? Int ?? 0)
        stats.player = player
        player.addToStats(stats)
    }
```

Note on the `Timestamp`/`Date` fallback: Firestore round-trips dates as `Timestamp`, but the unit test round-trips an in-memory `[String: Any]` where `date` is still a `Date`. The fallback handles both paths.

- [ ] **Step 6: Run test, confirm PASS**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests/test_playerStats_encodeDecode_preservesAllFields test 2>&1 | tail -10`

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Add `syncPlayerStats` batch upload helper**

In `CloudService+Upload.swift`, after `syncPlayerGoals` (line 51):

```swift
    func syncPlayerStats(_ statsList: [PlayerStats], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(statsList) { batch, stats in
            let statsData = self.createPlayerStatsDocument(stats: stats)
            let docRef = self.db.collection("users").document(userUID)
                .collection("playerStats").document(stats.id?.uuidString ?? UUID().uuidString)
            batch.setData(statsData, forDocument: docRef, merge: true)
        }
    }
```

- [ ] **Step 8: Wire `syncPlayerStats` into `performFullSync`**

In `CloudService+Sync.swift`:

- Add a new private sync method after `syncTrainingHistory` (line 100):

```swift
    private func syncPlayerStatsData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try context.fetch(playerRequest)

        for player in players {
            if let stats = player.stats?.allObjects as? [PlayerStats], !stats.isEmpty {
                try await syncPlayerStats(stats, for: player)
            }
        }
    }
```

- Add the call inside `performFullSync()` between `syncTrainingHistory()` (line 21) and `syncAvatarData()` (line 22):

```swift
            try await syncPlayerData()
            try await syncTrainingHistory()
            try await syncPlayerStatsData()
            try await syncAvatarData()
```

- [ ] **Step 9: Extend `CloudUserData` + `fetchAllUserData` to include playerStats**

In `CloudService+Upload.swift`, find `CloudUserData` (declared in `CloudService.swift` — grep for it). Add a `playerStats: [[String: Any]]` field.

Grep to locate the struct:

```bash
rg -n "struct CloudUserData" TechnIQ/Services/Cloud/
```

Then add the field to the struct and update `fetchAllUserData()` (CloudService+Upload.swift:163):

```swift
        async let statsSnapshot = userRef.collection("playerStats").getDocuments()

        let (profiles, goals, sessions, feedback, avatar, ownedItems, exercises, plans, stats) = try await (
            profilesSnapshot, goalsSnapshot, sessionsSnapshot, feedbackSnapshot,
            avatarSnapshot, ownedItemsSnapshot, customExercisesSnapshot, trainingPlansSnapshot,
            statsSnapshot
        )

        return CloudUserData(
            playerProfiles: profiles.documents.compactMap { $0.data() },
            playerGoals: goals.documents.compactMap { $0.data() },
            trainingSessions: sessions.documents.compactMap { $0.data() },
            recommendationFeedback: feedback.documents.compactMap { $0.data() },
            avatarConfiguration: avatar.documents.first?.data(),
            ownedAvatarItems: ownedItems.documents.compactMap { $0.data() },
            customExercises: exercises.documents.compactMap { $0.data() },
            trainingPlans: plans.documents.compactMap { $0.data() },
            playerStats: stats.documents.compactMap { $0.data() }
        )
```

- [ ] **Step 10: Add playerStats to `restoreFromCloud()`**

In `CloudService+Restore.swift`, between the existing `restoreProgress = 0.7` exercises loop (line 75-78) and `restoreProgress = 0.8` sessions loop (line 80-83):

```swift
            restoreProgress = 0.75
            for statsData in cloudData.playerStats {
                try restorePlayerStats(from: statsData, for: player, in: context)
            }
```

- [ ] **Step 11: Build and commit**

Build: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -10`

Expected: `** BUILD SUCCEEDED **`.

```bash
git add TechnIQ/Services/Cloud/CloudService+Upload.swift \
        TechnIQ/Services/Cloud/CloudService+Restore.swift \
        TechnIQ/Services/Cloud/CloudService+Sync.swift \
        TechnIQ/Services/Cloud/CloudService.swift \
        TechnIQTests/TestHelpers/TestCoreDataStack.swift \
        TechnIQTests/CloudServicePersistenceTests.swift
git commit -m "feat(cloud): sync PlayerStats across devices"
```

---

### Task 2: Match + Season round-trip (ordering matters)

**Files:**
- Modify: `TechnIQ/Services/Cloud/CloudService+Upload.swift`
- Modify: `TechnIQ/Services/Cloud/CloudService+Restore.swift`
- Modify: `TechnIQ/Services/Cloud/CloudService+Sync.swift`
- Modify: `TechnIQ/Services/Cloud/CloudService.swift` (CloudUserData struct)
- Modify: `TechnIQTests/CloudServicePersistenceTests.swift`

- [ ] **Step 1: Write failing tests for Season and Match round-trip + Match→Season relationship**

Append to `CloudServicePersistenceTests.swift`:

```swift
    // MARK: - Season round-trip

    func test_season_encodeDecode_preservesAllFields() throws {
        let player = stack.makePlayer()
        let original = stack.makeSeason(player: player, name: "2025-26", isActive: true)
        original.team = "FC Test"
        original.endDate = Date(timeIntervalSince1970: 1_800_000_000)
        try stack.context.save()

        let doc = sut.createSeasonDocument(season: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreSeason(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.seasons?.allObjects as? [Season])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.name, "2025-26")
        XCTAssertEqual(restored?.team, "FC Test")
        XCTAssertEqual(restored?.isActive, true)
        XCTAssertEqual(restored?.endDate?.timeIntervalSince1970, 1_800_000_000)
    }

    // MARK: - Match round-trip with Season link

    func test_match_encodeDecode_preservesSeasonRelationship() throws {
        let player = stack.makePlayer()
        let season = stack.makeSeason(player: player, name: "2025-26")
        let original = stack.makeMatch(
            player: player, date: Date(timeIntervalSince1970: 1_700_000_000),
            goals: 2, assists: 1, minutesPlayed: 88, result: "W", season: season
        )
        original.opponent = "Rival FC"
        original.competition = "League"
        original.rating = 4
        original.xpEarned = 150
        try stack.context.save()

        let seasonDoc = sut.createSeasonDocument(season: season)
        let matchDoc = sut.createMatchDocument(match: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreSeason(from: seasonDoc, for: restoredPlayer, in: restoredContext)
        try sut.restoreMatch(from: matchDoc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.matches?.allObjects as? [Match])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, original.id)
        XCTAssertEqual(restored?.opponent, "Rival FC")
        XCTAssertEqual(restored?.competition, "League")
        XCTAssertEqual(restored?.goals, 2)
        XCTAssertEqual(restored?.assists, 1)
        XCTAssertEqual(restored?.minutesPlayed, 88)
        XCTAssertEqual(restored?.result, "W")
        XCTAssertEqual(restored?.rating, 4)
        XCTAssertEqual(restored?.xpEarned, 150)
        XCTAssertNotNil(restored?.season, "Season relationship must be rewired by UUID")
        XCTAssertEqual(restored?.season?.id, season.id)
    }

    func test_match_withoutSeason_restoresWithNilSeason() throws {
        let player = stack.makePlayer()
        let original = stack.makeMatch(player: player, goals: 1, result: "D", season: nil)
        let matchDoc = sut.createMatchDocument(match: original)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreMatch(from: matchDoc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.matches?.allObjects as? [Match])?.first
        XCTAssertNotNil(restored)
        XCTAssertNil(restored?.season)
    }
```

- [ ] **Step 2: Confirm tests fail**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests test 2>&1 | tail -10`

Expected: compile failure — `createSeasonDocument`, `createMatchDocument`, `restoreSeason`, `restoreMatch` don't exist.

- [ ] **Step 3: Implement Season + Match document creators in `CloudService+Upload.swift`**

Add after `createPlayerStatsDocument` from Task 1:

```swift
    func createSeasonDocument(season: Season) -> [String: Any] {
        return [
            "id": season.id?.uuidString ?? "",
            "name": season.name ?? "",
            "team": season.team ?? "",
            "startDate": season.startDate ?? Date(),
            "endDate": season.endDate as Any,
            "isActive": season.isActive,
            "createdAt": season.createdAt ?? Date()
        ]
    }

    func createMatchDocument(match: Match) -> [String: Any] {
        return [
            "id": match.id?.uuidString ?? "",
            "date": match.date ?? Date(),
            "opponent": match.opponent ?? "",
            "competition": match.competition ?? "",
            "minutesPlayed": match.minutesPlayed,
            "goals": match.goals,
            "assists": match.assists,
            "positionPlayed": match.positionPlayed ?? "",
            "isHomeGame": match.isHomeGame,
            "result": match.result ?? "",
            "notes": match.notes ?? "",
            "rating": match.rating,
            "xpEarned": match.xpEarned,
            "strengths": match.strengths ?? "",
            "weaknesses": match.weaknesses ?? "",
            "createdAt": match.createdAt ?? Date(),
            "seasonID": match.season?.id?.uuidString ?? ""
        ]
    }
```

- [ ] **Step 4: Implement Season + Match restore helpers in `CloudService+Restore.swift`**

Add after `restorePlayerStats` from Task 1. Match restore looks up Season by ID in the player's restored seasons — this is why Season MUST restore first.

```swift
    func restoreSeason(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let season = Season(context: context)
        season.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        season.name = data["name"] as? String
        season.team = data["team"] as? String
        season.startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? (data["startDate"] as? Date) ?? Date()
        season.endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? (data["endDate"] as? Date)
        season.isActive = data["isActive"] as? Bool ?? false
        season.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Date) ?? Date()
        season.player = player
        player.addToSeasons(season)
    }

    func restoreMatch(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let match = Match(context: context)
        match.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        match.date = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
        match.opponent = data["opponent"] as? String
        match.competition = data["competition"] as? String
        match.minutesPlayed = Int16(data["minutesPlayed"] as? Int ?? 0)
        match.goals = Int16(data["goals"] as? Int ?? 0)
        match.assists = Int16(data["assists"] as? Int ?? 0)
        match.positionPlayed = data["positionPlayed"] as? String
        match.isHomeGame = data["isHomeGame"] as? Bool ?? false
        match.result = data["result"] as? String
        match.notes = data["notes"] as? String
        match.rating = Int16(data["rating"] as? Int ?? 0)
        match.xpEarned = Int32(data["xpEarned"] as? Int ?? 0)
        match.strengths = data["strengths"] as? String
        match.weaknesses = data["weaknesses"] as? String
        match.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Date) ?? Date()
        match.player = player
        player.addToMatches(match)

        if let seasonIDString = data["seasonID"] as? String,
           !seasonIDString.isEmpty,
           let seasonID = UUID(uuidString: seasonIDString),
           let seasons = player.seasons?.allObjects as? [Season],
           let matchingSeason = seasons.first(where: { $0.id == seasonID }) {
            match.season = matchingSeason
        }
    }
```

- [ ] **Step 5: Verify all three new tests pass**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests test 2>&1 | tail -10`

Expected: `Test Suite 'CloudServicePersistenceTests' passed` with 4 tests.

- [ ] **Step 6: Add `syncSeasons` and `syncMatches` batch helpers**

In `CloudService+Upload.swift`, after `syncPlayerStats`:

```swift
    func syncSeasons(_ seasons: [Season], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(seasons) { batch, season in
            let seasonData = self.createSeasonDocument(season: season)
            let docRef = self.db.collection("users").document(userUID)
                .collection("seasons").document(season.id?.uuidString ?? UUID().uuidString)
            batch.setData(seasonData, forDocument: docRef, merge: true)
        }
    }

    func syncMatches(_ matches: [Match], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(matches) { batch, match in
            let matchData = self.createMatchDocument(match: match)
            let docRef = self.db.collection("users").document(userUID)
                .collection("matches").document(match.id?.uuidString ?? UUID().uuidString)
            batch.setData(matchData, forDocument: docRef, merge: true)
        }
    }
```

- [ ] **Step 7: Wire into `performFullSync` and extend fetch/restore**

In `CloudService+Sync.swift`, add after `syncPlayerStatsData`:

```swift
    private func syncMatchData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try context.fetch(playerRequest)

        for player in players {
            if let seasons = player.seasons?.allObjects as? [Season], !seasons.isEmpty {
                try await syncSeasons(seasons, for: player)
            }
            if let matches = player.matches?.allObjects as? [Match], !matches.isEmpty {
                try await syncMatches(matches, for: player)
            }
        }
    }
```

Add the call to `performFullSync()` after `syncPlayerStatsData()`:

```swift
            try await syncPlayerData()
            try await syncTrainingHistory()
            try await syncPlayerStatsData()
            try await syncMatchData()
            try await syncAvatarData()
```

In `CloudService+Upload.swift`, replace the whole `fetchAllUserData()` body (lines 163-194 as originally, plus whatever Task 1 added) with:

```swift
    func fetchAllUserData() async throws -> CloudUserData {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        let userRef = db.collection("users").document(userUID)

        async let profilesSnapshot = userRef.collection("playerProfiles").getDocuments()
        async let goalsSnapshot = userRef.collection("playerGoals").getDocuments()
        async let sessionsSnapshot = userRef.collection("trainingSessions").getDocuments()
        async let feedbackSnapshot = userRef.collection("recommendationFeedback").getDocuments()
        async let avatarSnapshot = userRef.collection("avatarConfiguration").getDocuments()
        async let ownedItemsSnapshot = userRef.collection("ownedAvatarItems").getDocuments()
        async let customExercisesSnapshot = userRef.collection("customExercises").getDocuments()
        async let trainingPlansSnapshot = userRef.collection("trainingPlans").getDocuments()
        async let statsSnapshot = userRef.collection("playerStats").getDocuments()
        async let seasonsSnapshot = userRef.collection("seasons").getDocuments()
        async let matchesSnapshot = userRef.collection("matches").getDocuments()

        let (profiles, goals, sessions, feedback, avatar, ownedItems, exercises, plans, stats, seasons, matches) = try await (
            profilesSnapshot, goalsSnapshot, sessionsSnapshot, feedbackSnapshot,
            avatarSnapshot, ownedItemsSnapshot, customExercisesSnapshot, trainingPlansSnapshot,
            statsSnapshot, seasonsSnapshot, matchesSnapshot
        )

        return CloudUserData(
            playerProfiles: profiles.documents.compactMap { $0.data() },
            playerGoals: goals.documents.compactMap { $0.data() },
            trainingSessions: sessions.documents.compactMap { $0.data() },
            recommendationFeedback: feedback.documents.compactMap { $0.data() },
            avatarConfiguration: avatar.documents.first?.data(),
            ownedAvatarItems: ownedItems.documents.compactMap { $0.data() },
            customExercises: exercises.documents.compactMap { $0.data() },
            trainingPlans: plans.documents.compactMap { $0.data() },
            playerStats: stats.documents.compactMap { $0.data() },
            seasons: seasons.documents.compactMap { $0.data() },
            matches: matches.documents.compactMap { $0.data() }
        )
    }
```

Update the `CloudUserData` struct (grep `struct CloudUserData` to find it — likely in `CloudService.swift`) to add the three new fields. Example final shape:

```swift
struct CloudUserData {
    let playerProfiles: [[String: Any]]
    let playerGoals: [[String: Any]]
    let trainingSessions: [[String: Any]]
    let recommendationFeedback: [[String: Any]]
    let avatarConfiguration: [String: Any]?
    let ownedAvatarItems: [[String: Any]]
    let customExercises: [[String: Any]]
    let trainingPlans: [[String: Any]]
    let playerStats: [[String: Any]]
    let seasons: [[String: Any]]
    let matches: [[String: Any]]
}
```

In `CloudService+Restore.swift` `restoreFromCloud()`, add **between** stats restore (0.75) and sessions restore (0.8). Seasons MUST come before matches:

```swift
            restoreProgress = 0.77
            for seasonData in cloudData.seasons {
                try restoreSeason(from: seasonData, for: player, in: context)
            }
            for matchData in cloudData.matches {
                try restoreMatch(from: matchData, for: player, in: context)
            }
```

- [ ] **Step 8: Build, run full test target, commit**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test 2>&1 | tail -15`

Expected: `** TEST SUCCEEDED **`, no regressions in MatchServiceTests / other suites.

```bash
git add TechnIQ/Services/Cloud/ TechnIQTests/CloudServicePersistenceTests.swift
git commit -m "feat(cloud): sync matches and seasons across devices"
```

---

### Task 3: Restore `PlanSession.exercises` relationship

**Files:**
- Modify: `TechnIQ/Services/Cloud/CloudService+Restore.swift`
- Modify: `TechnIQTests/TestHelpers/TestCoreDataStack.swift`
- Modify: `TechnIQTests/CloudServicePersistenceTests.swift`

Upload already stores `exerciseIDs` per PlanSession (CloudService+Upload.swift:445). Restore (CloudService+Restore.swift:342-360) never reads them back.

**Design decision (revised after review):** Resolve exerciseIDs *inline* during plan restore by looking up already-restored exercises on the player. This works because `restoreFromCloud()` already restores custom exercises (progress 0.7) before plans (progress 0.9) — the exercises are in-context by the time we get to plan sessions. No transient state on the `CloudService` singleton, no second-pass method, no cleanup concerns. Thread the `player` down through `restoreTrainingPlan` → `restorePlanWeek` → `restorePlanDay` → `restorePlanSession`.

- [ ] **Step 1: Add `makePlanSession` + `makeTrainingPlanWithExercises` factories**

Append to `TestCoreDataStack.swift`:

```swift
    @discardableResult
    func makePlanSession(
        day: PlanDay,
        exercises: [Exercise] = [],
        sessionType: String = "training"
    ) -> PlanSession {
        let session = PlanSession(context: context)
        session.id = UUID()
        session.sessionType = sessionType
        session.duration = 30
        session.day = day
        if !exercises.isEmpty {
            session.exercises = NSSet(array: exercises)
        }
        try? context.save()
        return session
    }
```

- [ ] **Step 2: Write failing test**

Append to `CloudServicePersistenceTests.swift`:

```swift
    // MARK: - PlanSession.exercises restore

    func test_trainingPlan_restoresPlanSessionExerciseRelationship() throws {
        let player = stack.makePlayer()
        let e1 = stack.makeExercise(player: player, name: "Passing Drill")
        let e2 = stack.makeExercise(player: player, name: "Shooting Drill")
        let plan = stack.makeTrainingPlan(player: player)
        let week = stack.makePlanWeek(plan: plan, weekNumber: 1)
        let day = stack.makePlanDay(week: week, dayNumber: 1)
        _ = stack.makePlanSession(day: day, exercises: [e1, e2])

        let customExerciseDocs: [[String: Any]] = [e1, e2].map { sut.createCustomExerciseDocument(exercise: $0) }
        let planDoc = sut.createTrainingPlanDocument(plan: plan)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        // Mirror production order: exercises first (so plan restore can resolve exerciseIDs inline),
        // then the plan itself.
        for exerciseDoc in customExerciseDocs {
            try sut.restoreCustomExercise(from: exerciseDoc, for: restoredPlayer, in: restoredContext)
        }
        try sut.restoreTrainingPlan(from: planDoc, for: restoredPlayer, in: restoredContext)

        let restoredPlan = (restoredPlayer.trainingPlans?.allObjects as? [TrainingPlan])?.first
        let restoredWeek = (restoredPlan?.weeks?.allObjects as? [PlanWeek])?.first
        let restoredDay = (restoredWeek?.days?.allObjects as? [PlanDay])?.first
        let restoredSession = (restoredDay?.sessions?.allObjects as? [PlanSession])?.first
        let restoredExercises = (restoredSession?.exercises as? Set<Exercise>) ?? []

        XCTAssertEqual(restoredExercises.count, 2)
        XCTAssertEqual(Set(restoredExercises.compactMap { $0.id }), Set([e1.id!, e2.id!]))
    }

    func test_trainingPlan_restoresWithNoExercises_whenSessionHasEmptyExerciseIDs() throws {
        let player = stack.makePlayer()
        let plan = stack.makeTrainingPlan(player: player)
        let week = stack.makePlanWeek(plan: plan, weekNumber: 1)
        let day = stack.makePlanDay(week: week, dayNumber: 1)
        _ = stack.makePlanSession(day: day, exercises: [])

        let planDoc = sut.createTrainingPlanDocument(plan: plan)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreTrainingPlan(from: planDoc, for: restoredPlayer, in: restoredContext)

        let restoredSession = ((restoredPlayer.trainingPlans?.allObjects as? [TrainingPlan])?.first?
            .weeks?.allObjects as? [PlanWeek])?.first?.days?.allObjects as? [PlanDay]
        XCTAssertEqual(restoredSession?.first?.sessions?.count, 1)
    }
```

This test requires `createCustomExerciseDocument`, `restoreCustomExercise`, `createTrainingPlanDocument`, and `restoreTrainingPlan` to be internal (not private). **Check their access level before running.** Apply this to: `createCustomExerciseDocument` (line 400), `createTrainingPlanDocument` (line 423), `restoreCustomExercise` (line 208), `restoreTrainingPlan` (line 263). Same goes for `restorePlanWeek`/`restorePlanDay`/`restorePlanSession`.

- [ ] **Step 3: Relax access modifiers**

Open `CloudService+Upload.swift` and `CloudService+Restore.swift`. Remove `private` from the listed methods so they compile as internal.

- [ ] **Step 4: Thread `player` through the plan restore chain**

In `CloudService+Restore.swift`, change the four nested restore methods so `player` is passed all the way down to `restorePlanSession`.

Change `restoreTrainingPlan` (around line 263) signature already takes `player` — good. Inside its body, update the call to `restorePlanWeek` (line 289-293) to pass player:

```swift
        if let weeksData = data["weeks"] as? [[String: Any]] {
            for weekData in weeksData {
                try restorePlanWeek(from: weekData, for: plan, player: player, in: context)
            }
        }
```

Change `restorePlanWeek` signature (line 296) from:

```swift
    func restorePlanWeek(from data: [String: Any], for plan: TrainingPlan, in context: NSManagedObjectContext) throws {
```

to:

```swift
    func restorePlanWeek(from data: [String: Any], for plan: TrainingPlan, player: Player, in context: NSManagedObjectContext) throws {
```

And update its internal call to `restorePlanDay` (around line 312-314):

```swift
        if let daysData = data["days"] as? [[String: Any]] {
            for dayData in daysData {
                try restorePlanDay(from: dayData, for: week, player: player, in: context)
            }
        }
```

Change `restorePlanDay` signature (line 318) the same way, adding `player: Player`, and update its internal call:

```swift
        if let sessionsData = data["sessions"] as? [[String: Any]] {
            for sessionData in sessionsData {
                try restorePlanSession(from: sessionData, for: day, player: player, in: context)
            }
        }
```

- [ ] **Step 5: Resolve exerciseIDs inline in `restorePlanSession`**

Replace the existing `restorePlanSession` (lines 342-360) with this version, which looks up the already-restored exercises on the player and wires them in directly:

```swift
    func restorePlanSession(from data: [String: Any], for day: PlanDay, player: Player, in context: NSManagedObjectContext) throws {
        let session = PlanSession(context: context)
        session.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        session.sessionType = data["sessionType"] as? String
        session.duration = Int16(data["duration"] as? Int ?? 30)
        session.intensity = Int16(data["intensity"] as? Int ?? 5)
        session.orderIndex = Int16(data["orderIndex"] as? Int ?? 0)
        session.notes = data["notes"] as? String
        session.isCompleted = data["isCompleted"] as? Bool ?? false
        session.actualDuration = Int16(data["actualDuration"] as? Int ?? 0)
        session.actualIntensity = Int16(data["actualIntensity"] as? Int ?? 0)

        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            session.completedAt = completedAtTimestamp.dateValue()
        }

        session.day = day
        day.addToSessions(session)

        if let exerciseIDStrings = data["exerciseIDs"] as? [String], !exerciseIDStrings.isEmpty {
            let targetIDs = Set(exerciseIDStrings.compactMap { UUID(uuidString: $0) })
            let restoredExercises = (player.exercises?.allObjects as? [Exercise]) ?? []
            let matching = restoredExercises.filter { exercise in
                guard let id = exercise.id else { return false }
                return targetIDs.contains(id)
            }
            if !matching.isEmpty {
                session.exercises = NSSet(array: matching)
            }
        }
    }
```

No singleton state, no second pass, no cleanup required. The lookup is O(exercises) per session — fine for realistic plan sizes (~weeks × 7 × sessions_per_day).

- [ ] **Step 6: Run tests**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests test 2>&1 | tail -10`

Expected: all 6 persistence tests pass.

- [ ] **Step 7: Build full app, commit**

```bash
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5
git add TechnIQ/Services/Cloud/ TechnIQTests/
git commit -m "fix(cloud): wire PlanSession.exercises relationship on restore"
```

---

### Task 4: Link anonymous accounts into real ones

**Files:**
- Modify: `TechnIQ/Services/AuthenticationManager.swift`
- Create: `TechnIQTests/AuthenticationLinkingTests.swift` (lightweight unit test for decision logic; full Firebase integration test deferred)

Today `signUp(email:password:)`, `signInWithGoogle()`, and `signInWithApple()` all call `Auth.auth().createUser`/`signIn(with:)`, which *replaces* the current session with a new UID. If the user was anonymous, the old UID's Firestore data is orphaned. The fix is to detect `currentUser?.isAnonymous == true` and call `currentUser.link(with: credential)` instead — this merges the anon session into the email/Google/Apple credential while keeping the same Firebase UID. All existing Firestore data stays keyed correctly.

- [ ] **Step 1: Read current signUp/signIn flows**

Read: `TechnIQ/Services/AuthenticationManager.swift` top-to-bottom. Note existing patterns for `signUp`, `signInWithGoogle`, `signInWithApple`.

- [ ] **Step 2: Add a helper that decides link-vs-signin**

Add near the other auth helpers:

```swift
    // MARK: - Anonymous Linking

    /// If the current user is anonymous, upgrade them to the given credential
    /// instead of creating a new auth session. This preserves their UID so Firestore
    /// data stays accessible.
    /// - Returns: The AuthDataResult for the now-upgraded user.
    private func linkOrSignIn(with credential: AuthCredential) async throws -> AuthDataResult {
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            do {
                return try await currentUser.link(with: credential)
            } catch let error as NSError
                where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue
                   || error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                #if DEBUG
                print("⚠️ Anonymous link conflict — credential belongs to existing account. Falling back to sign-in (anon data will be orphaned).")
                #endif
                return try await Auth.auth().signIn(with: credential)
            }
        }
        return try await Auth.auth().signIn(with: credential)
    }
```

- [ ] **Step 3: Use `linkOrSignIn` in `signInWithGoogle`**

In `signInWithGoogle()`, replace:

```swift
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
```

with:

```swift
            // Link to existing anonymous user if present, otherwise sign in
            let authResult = try await linkOrSignIn(with: credential)
```

- [ ] **Step 4: Use `linkOrSignIn` in `signInWithApple`**

In `signInWithApple()` at `AuthenticationManager.swift:282`, replace:

```swift
            let result = try await Auth.auth().signIn(with: firebaseCredential)
```

with:

```swift
            let result = try await linkOrSignIn(with: firebaseCredential)
```

Leave the rest of the function (name-saving block at lines 284-294) unchanged.

- [ ] **Step 5: Upgrade `signUp(email:password:)` to link when anonymous**

Replace the body's `createUser` call. Find:

```swift
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
```

Replace with:

```swift
            let result: AuthDataResult
            if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
                let credential = EmailAuthProvider.credential(withEmail: email, password: password)
                do {
                    result = try await currentUser.link(with: credential)
                } catch let error as NSError
                    where error.code == AuthErrorCode.emailAlreadyInUse.rawValue {
                    #if DEBUG
                    print("⚠️ Email already exists — falling back to createUser (anon data orphaned)")
                    #endif
                    result = try await Auth.auth().createUser(withEmail: email, password: password)
                }
            } else {
                result = try await Auth.auth().createUser(withEmail: email, password: password)
            }
```

- [ ] **Step 6: Write a unit test for the fallback path decision**

The decision logic calls through to Firebase SDK, which can't be trivially mocked without protocol extraction. We smoke-test by asserting that when there's no current user the code takes the `signIn`/`createUser` branch (test-visible via code review rather than runtime — skip a dedicated test file here). **Instead, add a QA manual test checklist entry.**

Append to the plan's Task 4 section at the bottom of this commit:

Create `docs/superpowers/plans/2026-04-19-cross-device-persistence-qa.md` with:

```markdown
# Anonymous Upgrade QA Checklist

Run these on-device before shipping:

1. Fresh install → Skip auth (anonymous) → Complete onboarding → Add 2 custom exercises → Complete 1 training session.
2. Open Settings → Sign up with email + password.
3. Verify: Firebase UID in Firestore console hasn't changed. Player profile, exercises, and session are all still visible in the app.
4. Sign out → Sign back in with same email on a second simulator. Verify same data restores.
5. Repeat 1–4 with Google Sign-In and Apple Sign-In.
6. Negative case: start anon → try to sign in with a pre-existing email. Expect fallback: new UID, warning logged, old anon data orphaned (this is the documented least-bad outcome).
```

- [ ] **Step 7: Build and commit**

```bash
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' build 2>&1 | tail -5
git add TechnIQ/Services/AuthenticationManager.swift docs/superpowers/plans/2026-04-19-cross-device-persistence-qa.md
git commit -m "feat(auth): link anonymous accounts on signup/google/apple to preserve data"
```

---

### Task 5: Harden `hasCloudData()` so partial uploads don't trigger ghost restores

**Files:**
- Modify: `TechnIQ/Services/Cloud/CloudService+Upload.swift`
- Modify: `TechnIQTests/CloudServicePersistenceTests.swift`

Today `hasCloudData()` (CloudService+Upload.swift:197-210) only checks that ANY document exists in `playerProfiles`. A partial upload that wrote a mostly-empty profile doc (e.g., during onboarding that crashed before the user chose a position) triggers restore and creates a ghost user.

**Design decision (revised after review):** Do NOT require sibling collections. A user who completed onboarding and then reinstalled before their first session must still restore their profile — that IS the "profile saves across devices" case. Instead, gate on profile *completeness*: require the doc to contain both `position` and `experienceLevel` (both always set by the onboarding flow). An incomplete/abandoned onboarding upload will miss one of them and be treated as no-data.

- [ ] **Step 1: Write failing tests for the decision helper**

Add to `CloudServicePersistenceTests.swift`:

```swift
    // MARK: - hasCloudData gating

    func test_hasMeaningfulCloudProfile_completeProfile_returnsTrue() {
        let doc: [String: Any] = [
            "playerId": UUID().uuidString,
            "position": "Midfielder",
            "experienceLevel": "Intermediate"
        ]
        XCTAssertTrue(sut.hasMeaningfulCloudProfile(doc))
    }

    func test_hasMeaningfulCloudProfile_missingPosition_returnsFalse() {
        let doc: [String: Any] = [
            "playerId": UUID().uuidString,
            "position": "",
            "experienceLevel": "Intermediate"
        ]
        XCTAssertFalse(sut.hasMeaningfulCloudProfile(doc), "Partial onboarding upload should not trigger restore")
    }

    func test_hasMeaningfulCloudProfile_missingExperienceLevel_returnsFalse() {
        let doc: [String: Any] = [
            "playerId": UUID().uuidString,
            "position": "Midfielder",
            "experienceLevel": ""
        ]
        XCTAssertFalse(sut.hasMeaningfulCloudProfile(doc))
    }

    func test_hasMeaningfulCloudProfile_missingFields_returnsFalse() {
        let doc: [String: Any] = ["playerId": UUID().uuidString]
        XCTAssertFalse(sut.hasMeaningfulCloudProfile(doc))
    }
```

- [ ] **Step 2: Implement `hasMeaningfulCloudProfile` and refactor `hasCloudData`**

Replace the existing `hasCloudData()` in `CloudService+Upload.swift:197-210` with:

```swift
    /// Pure decision: does this cloud profile document represent a user who actually finished onboarding,
    /// or is it a partial upload that should NOT trigger a restore?
    /// We consider a profile "meaningful" only if both `position` and `experienceLevel` are set —
    /// both are mandatory fields in the onboarding flow, so a doc missing either was written by a
    /// crash or abandoned session.
    func hasMeaningfulCloudProfile(_ doc: [String: Any]) -> Bool {
        let position = (doc["position"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let experienceLevel = (doc["experienceLevel"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        return !position.isEmpty && !experienceLevel.isEmpty
    }

    /// Check if a restorable cloud profile exists for the current user.
    func hasCloudData() async throws -> Bool {
        guard let userUID = auth.currentUser?.uid else {
            return false
        }

        guard isNetworkAvailable else {
            return false
        }

        let snapshot = try await db.collection("users").document(userUID)
            .collection("playerProfiles").limit(to: 1).getDocuments()

        guard let doc = snapshot.documents.first?.data() else {
            return false
        }

        return hasMeaningfulCloudProfile(doc)
    }
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' -only-testing:TechnIQTests/CloudServicePersistenceTests test 2>&1 | tail -10`

Expected: all 9 persistence tests pass.

- [ ] **Step 4: Build full test target, commit**

```bash
xcodebuild -scheme TechnIQ -sdk iphonesimulator -destination 'id=197B259E-335F-47CF-855E-B5CE0FC385A1' test 2>&1 | tail -10
git add TechnIQ/Services/Cloud/CloudService+Upload.swift TechnIQTests/CloudServicePersistenceTests.swift
git commit -m "fix(cloud): require meaningful data to trigger restore (avoid partial-upload ghost users)"
```

---

## Unresolved questions

- `SessionExercise.exercise` round-trip: nested exerciseId is uploaded (Upload.swift:320) but restore (Restore.swift:250-260) never rewires it to the Exercise entity — in scope or follow-up?
- Incremental sync (`syncRecentChanges`) filters by `updatedAt > lastSync`. Stats/Match/Season docs don't carry `updatedAt`, so they'll only full-sync. Add `updatedAt` now or defer?
- Existing users whose previous partial uploads are still in Firestore: accept they'll be ignored by the new `hasMeaningfulCloudProfile` gate, or write a one-off reconciliation?
- Restore flow currently uses `CoreDataManager.shared.context` directly — leave, or inject for testability?
