import XCTest
@testable import TechnIQ

@MainActor
final class CoinServiceTests: XCTestCase {

    // MARK: - CoinEarningEvent Calculations

    func test_sessionCompleted_shortDuration_returns10() {
        let coins = CoinEarningEvent.sessionCompleted(duration: 5).coins
        XCTAssertEqual(coins, 10)
    }

    func test_sessionCompleted_longDuration_returns25() {
        let coins = CoinEarningEvent.sessionCompleted(duration: 60).coins
        XCTAssertEqual(coins, 25)
    }

    func test_sessionCompleted_normalDuration_scalesCorrectly() {
        let coins = CoinEarningEvent.sessionCompleted(duration: 30).coins
        XCTAssertEqual(coins, 15)
    }

    func test_dailyStreakBonus_scales() {
        XCTAssertEqual(CoinEarningEvent.dailyStreakBonus(streakDay: 1).coins, 5)
        XCTAssertEqual(CoinEarningEvent.dailyStreakBonus(streakDay: 10).coins, 50)
    }

    func test_levelUp_scalesWithLevel() {
        let level5 = CoinEarningEvent.levelUp(newLevel: 5).coins
        let level20 = CoinEarningEvent.levelUp(newLevel: 20).coins
        XCTAssertEqual(level5, 75)
        XCTAssertEqual(level20, 150)
    }

    func test_achievementUnlocked_clamped() {
        let small = CoinEarningEvent.achievementUnlocked(xpReward: 50).coins
        XCTAssertEqual(small, 25)

        let large = CoinEarningEvent.achievementUnlocked(xpReward: 5000).coins
        XCTAssertEqual(large, 100)
    }

    func test_fixedEventCoins() {
        XCTAssertEqual(CoinEarningEvent.firstSessionOfDay.coins, 10)
        XCTAssertEqual(CoinEarningEvent.fiveStarRating.coins, 15)
        XCTAssertEqual(CoinEarningEvent.weeklyStreakMilestone.coins, 50)
        XCTAssertEqual(CoinEarningEvent.trainingPlanWeekCompleted.coins, 75)
        XCTAssertEqual(CoinEarningEvent.trainingPlanCompleted.coins, 200)
    }

    // MARK: - canAfford

    func test_canAfford_basic() {
        let service = CoinService(coreDataManager: MockCoreDataManager())
        XCTAssertFalse(service.canAfford(100))
        XCTAssertTrue(service.canAfford(0))
    }
}

// MARK: - Integration Tests (real Core Data stack)

@MainActor
final class CoinServiceIntegrationTests: XCTestCase {
    var sut: CoinService!
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = CoinService(coreDataManager: stack)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - awardCoins

    func test_awardCoins_increasesBalance() {
        let player = stack.makePlayer(coins: 50)
        let newBalance = sut.awardCoins(100, for: .sessionCompleted(duration: 30), context: stack.context)
        XCTAssertEqual(newBalance, 150)
        XCTAssertEqual(player.coins, 150)
        XCTAssertEqual(player.totalCoinsEarned, 100)
    }

    func test_awardCoins_updatesPublishedBalance() {
        _ = stack.makePlayer(coins: 0)
        _ = sut.awardCoins(50, for: .firstSessionOfDay, context: stack.context)
        XCTAssertEqual(sut.currentBalance, 50)
    }

    func test_awardCoins_noPlayer_returnsZero() {
        // No player created
        let result = sut.awardCoins(100, for: .firstSessionOfDay, context: stack.context)
        XCTAssertEqual(result, 0)
        XCTAssertNotNil(sut.lastError)
    }

    func test_awardCoins_setsLastTransaction() {
        _ = stack.makePlayer(coins: 0)
        _ = sut.awardCoins(42, for: .fiveStarRating, context: stack.context)
        XCTAssertEqual(sut.lastTransaction?.amount, 42)
        XCTAssertEqual(sut.lastTransaction?.type, .earned)
    }

    // MARK: - deductCoins

    func test_deductCoins_sufficientFunds_succeeds() {
        let player = stack.makePlayer(coins: 200)
        let result = sut.deductCoins(150, for: "Avatar item", context: stack.context)
        XCTAssertTrue(result)
        XCTAssertEqual(player.coins, 50)
        XCTAssertEqual(sut.currentBalance, 50)
    }

    func test_deductCoins_insufficientFunds_fails() {
        let player = stack.makePlayer(coins: 10)
        let result = sut.deductCoins(100, for: "Too expensive", context: stack.context)
        XCTAssertFalse(result)
        XCTAssertEqual(player.coins, 10)
    }

    func test_deductCoins_noPlayer_returnsFalse() {
        let result = sut.deductCoins(10, for: "Nothing", context: stack.context)
        XCTAssertFalse(result)
    }

    func test_deductCoins_setsLastTransaction() {
        _ = stack.makePlayer(coins: 100)
        _ = sut.deductCoins(30, for: "Shop", context: stack.context)
        XCTAssertEqual(sut.lastTransaction?.amount, 30)
        XCTAssertEqual(sut.lastTransaction?.type, .spent)
    }

    // MARK: - awardSessionCoins

    func test_awardSessionCoins_baseOnly() {
        let player = stack.makePlayer(coins: 0)
        let earned = sut.awardSessionCoins(
            duration: 30, isFirstOfDay: false,
            rating: nil, streakDay: 0, context: stack.context
        )
        let expectedBase = CoinEarningEvent.sessionCompleted(duration: 30).coins
        XCTAssertEqual(earned, expectedBase)
        XCTAssertEqual(player.coins, Int64(expectedBase))
    }

    func test_awardSessionCoins_withBonuses() {
        let player = stack.makePlayer(coins: 0)
        let earned = sut.awardSessionCoins(
            duration: 30, isFirstOfDay: true,
            rating: 5, streakDay: 7, context: stack.context
        )
        // base + firstOfDay + fiveStarRating + dailyStreakBonus(7) + weeklyMilestone
        let expected = CoinEarningEvent.sessionCompleted(duration: 30).coins
            + CoinEarningEvent.firstSessionOfDay.coins
            + CoinEarningEvent.fiveStarRating.coins
            + CoinEarningEvent.dailyStreakBonus(streakDay: 7).coins
            + CoinEarningEvent.weeklyStreakMilestone.coins
        XCTAssertEqual(earned, expected)
        XCTAssertEqual(player.coins, Int64(expected))
    }

    func test_awardSessionCoins_noPlayer_returnsZero() {
        let earned = sut.awardSessionCoins(
            duration: 30, isFirstOfDay: false,
            rating: nil, streakDay: 0, context: stack.context
        )
        XCTAssertEqual(earned, 0)
    }

    // MARK: - getBalance / getTotalEarned

    func test_getBalance_reflectsPlayerCoins() {
        _ = stack.makePlayer(coins: 999)
        sut.loadCurrentBalance()
        XCTAssertEqual(sut.getBalance(), 999)
    }

    func test_getTotalEarned_reflectsCumulative() {
        let player = stack.makePlayer(coins: 0)
        _ = sut.awardCoins(100, for: .firstSessionOfDay, context: stack.context)
        _ = sut.awardCoins(50, for: .fiveStarRating, context: stack.context)
        XCTAssertEqual(player.totalCoinsEarned, 150)
        XCTAssertEqual(sut.getTotalEarned(), 150)
    }
}
