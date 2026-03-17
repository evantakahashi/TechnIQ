import XCTest
@testable import TechnIQ

@MainActor
final class XPServiceTests: XCTestCase {
    var sut: XPService!
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        sut = XPService()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Level System

    func test_xpRequiredForLevel_level1_returnsZero() {
        XCTAssertEqual(sut.xpRequiredForLevel(1), 0)
    }

    func test_xpRequiredForLevel_level2_returns100() {
        XCTAssertEqual(sut.xpRequiredForLevel(2), 100)
    }

    func test_xpRequiredForLevel_increases_exponentially() {
        let xp2 = sut.xpRequiredForLevel(2)
        let xp3 = sut.xpRequiredForLevel(3)
        let xp4 = sut.xpRequiredForLevel(4)
        XCTAssertTrue(xp3 - xp2 < xp4 - xp3, "XP gap should increase per level")
    }

    func test_levelForXP_zeroXP_returnsLevel1() {
        XCTAssertEqual(sut.levelForXP(0), 1)
    }

    func test_levelForXP_exactThreshold_advancesLevel() {
        let xpForLevel5 = sut.xpRequiredForLevel(5)
        XCTAssertEqual(sut.levelForXP(xpForLevel5), 5)
    }

    func test_levelForXP_justBelow_staysAtPreviousLevel() {
        let xpForLevel5 = sut.xpRequiredForLevel(5)
        XCTAssertEqual(sut.levelForXP(xpForLevel5 - 1), 4)
    }

    func test_levelForXP_maxLevel_cappedAt50() {
        XCTAssertEqual(sut.levelForXP(999_999_999_999), 50)
    }

    func test_progressToNextLevel_midway_returnsHalf() {
        let xpLevel2 = sut.xpRequiredForLevel(2)
        let xpLevel3 = sut.xpRequiredForLevel(3)
        let midpoint = xpLevel2 + (xpLevel3 - xpLevel2) / 2
        let progress = sut.progressToNextLevel(totalXP: midpoint, currentLevel: 2)
        XCTAssertEqual(progress, 0.5, accuracy: 0.01)
    }

    func test_progressToNextLevel_atMaxLevel_returns1() {
        XCTAssertEqual(sut.progressToNextLevel(totalXP: 999_999, currentLevel: 50), 1.0)
    }

    func test_tierForLevel_level1_returnsGrassroots() {
        let tier = sut.tierForLevel(1)
        XCTAssertEqual(tier?.title, "Grassroots")
    }

    func test_tierForLevel_level50_returnsLivingLegend() {
        let tier = sut.tierForLevel(50)
        XCTAssertEqual(tier?.title, "Living Legend")
    }

    // MARK: - Session XP Calculation

    func test_calculateSessionXP_baseOnly_returns50() {
        let xp = sut.calculateSessionXP(
            intensity: 0, exerciseCount: 0,
            allExercisesCompleted: false, hasRating: false,
            hasNotes: false, isFirstSessionOfDay: false, currentStreak: 0
        )
        XCTAssertEqual(xp.total, 50)
    }

    func test_calculateSessionXP_allBonuses_addsCorrectly() {
        let xp = sut.calculateSessionXP(
            intensity: 3, exerciseCount: 5,
            allExercisesCompleted: true, hasRating: true,
            hasNotes: true, isFirstSessionOfDay: true, currentStreak: 7
        )
        XCTAssertEqual(xp.baseXP, 50)
        XCTAssertEqual(xp.intensityBonus, 30)
        XCTAssertEqual(xp.firstSessionBonus, 25)
        XCTAssertEqual(xp.completionBonus, 20)
        XCTAssertEqual(xp.ratingBonus, 5)
        XCTAssertEqual(xp.notesBonus, 5)
        XCTAssertEqual(xp.streakBonus, 150)
        XCTAssertEqual(xp.total, 285)
    }

    func test_calculateSessionXP_streakMilestones() {
        let streak30 = sut.calculateSessionXP(
            intensity: 0, exerciseCount: 0,
            allExercisesCompleted: false, hasRating: false,
            hasNotes: false, isFirstSessionOfDay: false, currentStreak: 30
        )
        XCTAssertEqual(streak30.streakBonus, 500)

        let streak100 = sut.calculateSessionXP(
            intensity: 0, exerciseCount: 0,
            allExercisesCompleted: false, hasRating: false,
            hasNotes: false, isFirstSessionOfDay: false, currentStreak: 100
        )
        XCTAssertEqual(streak100.streakBonus, 1000)
    }

    func test_calculateSessionXP_nonMilestoneStreak_noBonus() {
        let xp = sut.calculateSessionXP(
            intensity: 0, exerciseCount: 0,
            allExercisesCompleted: false, hasRating: false,
            hasNotes: false, isFirstSessionOfDay: false, currentStreak: 8
        )
        XCTAssertEqual(xp.streakBonus, 0)
    }

    // MARK: - Award XP & Level Up

    func test_awardXP_noLevelUp_returnsNil() {
        let player = stack.makePlayer(level: 1, xp: 0)
        let levelUp = sut.awardXP(to: player, amount: 10)
        XCTAssertNil(levelUp)
        XCTAssertEqual(player.totalXP, 10)
    }

    func test_awardXP_triggersLevelUp_returnsNewLevel() {
        let player = stack.makePlayer(level: 1, xp: 90)
        let levelUp = sut.awardXP(to: player, amount: 20)
        XCTAssertEqual(levelUp, 2)
        XCTAssertEqual(player.currentLevel, 2)
    }

    // MARK: - Streak

    func test_updateStreak_firstEver_setsTo1() {
        let player = stack.makePlayer()
        player.lastTrainingDate = nil
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 1)
    }

    func test_updateStreak_consecutiveDay_increments() {
        let player = stack.makePlayer(streak: 5)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        player.lastTrainingDate = yesterday
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 6)
    }

    func test_updateStreak_sameDay_noChange() {
        let player = stack.makePlayer(streak: 5)
        player.lastTrainingDate = Date()
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 5)
    }

    func test_updateStreak_missedDay_resetsTo1() {
        let player = stack.makePlayer(streak: 10)
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        player.lastTrainingDate = threeDaysAgo
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 1)
    }

    func test_updateStreak_missedOneDayWithFreeze_continues() {
        let player = stack.makePlayer(streak: 10, streakFreezes: 1)
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        player.lastTrainingDate = twoDaysAgo
        sut.updateStreak(for: player)
        XCTAssertEqual(player.currentStreak, 11)
        XCTAssertEqual(player.streakFreezes, 0)
    }

    func test_updateStreak_updatesLongestStreak() {
        let player = stack.makePlayer(streak: 9, longestStreak: 9)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        player.lastTrainingDate = yesterday
        sut.updateStreak(for: player)
        XCTAssertEqual(player.longestStreak, 10)
    }

    // MARK: - Streak Freeze Purchase

    func test_purchaseStreakFreeze_sufficientXP_succeeds() {
        let player = stack.makePlayer(xp: 1000)
        let result = sut.purchaseStreakFreeze(for: player, context: stack.context)
        XCTAssertTrue(result)
        XCTAssertEqual(player.totalXP, 500)
        XCTAssertEqual(player.streakFreezes, 1)
    }

    func test_purchaseStreakFreeze_insufficientXP_fails() {
        let player = stack.makePlayer(xp: 100)
        let result = sut.purchaseStreakFreeze(for: player, context: stack.context)
        XCTAssertFalse(result)
        XCTAssertEqual(player.totalXP, 100)
        XCTAssertEqual(player.streakFreezes, 0)
    }
}
