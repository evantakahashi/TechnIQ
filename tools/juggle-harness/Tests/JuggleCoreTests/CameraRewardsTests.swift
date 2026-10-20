import XCTest
@testable import JuggleCore

final class CameraRewardsTests: XCTestCase {
    func testAnOrdinaryRunEarnsTheBaseReward() {
        let reward = CameraRewards.reward(count: 12, isPersonalBest: false, beatChallenge: false, rewardedRunsToday: 0)

        XCTAssertEqual(reward, CameraReward(xp: 5, coins: 2, countsTowardCap: true))
    }

    func testRunsUnderThreeTouchesEarnNothing() {
        let reward = CameraRewards.reward(count: 2, isPersonalBest: false, beatChallenge: false, rewardedRunsToday: 0)

        XCTAssertEqual(reward, .none)
    }

    func testTheDailyCapStopsTheBaseRewardButNotAPersonalBest() {
        let capped = CameraRewards.reward(count: 12, isPersonalBest: false, beatChallenge: false, rewardedRunsToday: 10)
        let cappedBest = CameraRewards.reward(count: 40, isPersonalBest: true, beatChallenge: false, rewardedRunsToday: 10)

        XCTAssertEqual(capped, .none)
        XCTAssertEqual(cappedBest, CameraReward(xp: 25, coins: 10, countsTowardCap: false))
    }

    func testPersonalBestAndChallengeStackOnTheBase() {
        let reward = CameraRewards.reward(count: 40, isPersonalBest: true, beatChallenge: true, rewardedRunsToday: 3)

        XCTAssertEqual(reward, CameraReward(xp: 5 + 25 + 100, coins: 2 + 10 + 50, countsTowardCap: true))
    }

    func testPersonalBestNeedsThreeTouchesAndToBeatThePrevious() {
        XCTAssertTrue(CameraRewards.isPersonalBest(count: 3, previousBest: nil))
        XCTAssertFalse(CameraRewards.isPersonalBest(count: 2, previousBest: nil))
        XCTAssertFalse(CameraRewards.isPersonalBest(count: 20, previousBest: 20))
        XCTAssertTrue(CameraRewards.isPersonalBest(count: 21, previousBest: 20))
    }

    func testOnlyIPhone12AndNewerAreSupported() {
        XCTAssertFalse(CameraDrillSupport.isSupported(machine: "iPhone12,1"))  // iPhone 11
        XCTAssertTrue(CameraDrillSupport.isSupported(machine: "iPhone13,2"))   // iPhone 12
        XCTAssertTrue(CameraDrillSupport.isSupported(machine: "iPhone18,3"))
        XCTAssertFalse(CameraDrillSupport.isSupported(machine: "iPad13,1"))
        XCTAssertFalse(CameraDrillSupport.isSupported(machine: "garbage"))
    }
}
