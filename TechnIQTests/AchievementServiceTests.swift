import XCTest
import CoreData
@testable import TechnIQ

final class AchievementServiceTests: XCTestCase {
    var sut: AchievementService!
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        sut = AchievementService()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Achievement Data

    func test_allAchievements_has30() {
        XCTAssertEqual(AchievementService.allAchievements.count, 30)
    }

    func test_allAchievements_uniqueIds() {
        let ids = AchievementService.allAchievements.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Achievement IDs must be unique")
    }

    func test_allAchievements_categoryCounts() {
        let byCategory = Dictionary(grouping: AchievementService.allAchievements, by: \.category)
        XCTAssertEqual(byCategory[.consistency]?.count, 10)
        XCTAssertEqual(byCategory[.volume]?.count, 10)
        XCTAssertEqual(byCategory[.skills]?.count, 10)
    }

    // MARK: - Unlock Logic

    func test_getUnlockedAchievements_emptyByDefault() {
        let player = stack.makePlayer()
        player.unlockedAchievements = []
        let unlocked = sut.getUnlockedAchievements(for: player)
        XCTAssertTrue(unlocked.isEmpty)
    }

    func test_isUnlocked_returnsCorrectly() {
        let player = stack.makePlayer()
        player.unlockedAchievements = ["first_training"]
        XCTAssertTrue(sut.isUnlocked("first_training", for: player))
        XCTAssertFalse(sut.isUnlocked("week_warrior", for: player))
    }

    func test_getLockedAchievements_excludesUnlocked() {
        let player = stack.makePlayer()
        player.unlockedAchievements = ["first_training"]
        let locked = sut.getLockedAchievements(for: player)
        XCTAssertEqual(locked.count, 29)
        XCTAssertFalse(locked.contains { $0.id == "first_training" })
    }

    func test_checkAndUnlock_sessionCount1_unlocksFirstTraining() {
        let player = stack.makePlayer()
        player.unlockedAchievements = []
        stack.makeSession(player: player)

        let newly = sut.checkAndUnlockAchievements(for: player, in: stack.context)
        XCTAssertTrue(newly.contains { $0.id == "first_training" })
    }

    func test_checkAndUnlock_idempotent_noDoubleUnlock() {
        let player = stack.makePlayer()
        player.unlockedAchievements = []
        stack.makeSession(player: player)

        let first = sut.checkAndUnlockAchievements(for: player, in: stack.context)
        let second = sut.checkAndUnlockAchievements(for: player, in: stack.context)
        let firstTrainingCount = first.filter { $0.id == "first_training" }.count
        let secondTrainingCount = second.filter { $0.id == "first_training" }.count

        XCTAssertEqual(firstTrainingCount, 1)
        XCTAssertEqual(secondTrainingCount, 0, "Should not unlock again")
    }

    func test_checkAndUnlock_streakDays7_unlocksWeekWarrior() {
        let player = stack.makePlayer(streak: 7)
        player.unlockedAchievements = []

        let newly = sut.checkAndUnlockAchievements(for: player, in: stack.context)
        XCTAssertTrue(newly.contains { $0.id == "week_warrior" })
    }

    func test_checkAndUnlock_awardsXP() {
        let player = stack.makePlayer(xp: 0)
        player.unlockedAchievements = []
        stack.makeSession(player: player)
        let xpBefore = player.totalXP

        _ = sut.checkAndUnlockAchievements(for: player, in: stack.context)
        XCTAssertGreaterThan(player.totalXP, xpBefore, "Should award XP for unlocked achievements")
    }

    // MARK: - Progress

    func test_getProgress_sessionCount_partial() {
        let player = stack.makePlayer()
        player.unlockedAchievements = []

        let gettingStarted = AchievementService.allAchievements.first { $0.id == "getting_started" }!
        stack.makeSession(player: player)

        let progress = sut.getProgress(for: gettingStarted, player: player, in: stack.context)
        XCTAssertEqual(progress, 0.1, accuracy: 0.01)
    }

    func test_getProgress_streakDays_partial() {
        let player = stack.makePlayer(streak: 3, longestStreak: 3)
        let weekWarrior = AchievementService.allAchievements.first { $0.id == "week_warrior" }!
        let progress = sut.getProgress(for: weekWarrior, player: player, in: stack.context)
        XCTAssertEqual(progress, 3.0 / 7.0, accuracy: 0.01)
    }
}
