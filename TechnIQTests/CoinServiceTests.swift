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
