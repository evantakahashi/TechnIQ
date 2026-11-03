import XCTest
@testable import JuggleCore

final class CameraRewardsTests: XCTestCase {
    func testASittingUnderAMinuteOfLiveTimeEarnsNothing() {
        let sitting = CameraSitting()

        XCTAssertEqual(sitting.xp(forRunWith: 40, seconds: 59), 0)
    }

    func testARunIsPaidTheFormulaOverTheSittingSoFar() {
        let sitting = CameraSitting()

        // 2 full minutes + 25 touches → 2 + 2.
        XCTAssertEqual(sitting.xp(forRunWith: 25, seconds: 130), 4)
    }

    func testLaterRunsArePaidOnlyTheIncrease() {
        let sitting = CameraSitting()
        sitting.add(touches: 6, seconds: 40, xp: sitting.xp(forRunWith: 6, seconds: 40))   // 0 XP: under a minute
        let second = sitting.xp(forRunWith: 8, seconds: 30)                                 // 70 s, 14 touches → 1 + 1

        XCTAssertEqual(second, 2)
        sitting.add(touches: 8, seconds: 30, xp: second)
        XCTAssertEqual(sitting.xpAwarded, 2)
        XCTAssertEqual(sitting.touches, 14)
        XCTAssertEqual(sitting.liveSeconds, 70)
    }

    func testASittingNeverPassesThirty() {
        let sitting = CameraSitting()
        var total = 0
        for _ in 0..<40 {
            let xp = sitting.xp(forRunWith: 50, seconds: 90)
            sitting.add(touches: 50, seconds: 90, xp: xp)
            total += xp
        }

        XCTAssertEqual(total, 30)
        XCTAssertEqual(sitting.xp(forRunWith: 500, seconds: 600), 0)
    }

    func testBadDurationsCountAsZero() {
        let sitting = CameraSitting()

        XCTAssertEqual(sitting.xp(forRunWith: 10, seconds: -.infinity), 0)
        XCTAssertEqual(sitting.xp(forRunWith: 10, seconds: .nan), 0)
    }

    func testFormulaParts() {
        XCTAssertEqual(XPFormula.session(verifiedTouches: 0, activeSeconds: 59.9), .zero)
        XCTAssertEqual(XPFormula.session(verifiedTouches: 9, activeSeconds: 60), SessionXPBreakdown(timeXP: 1, touchXP: 0))
        XCTAssertEqual(XPFormula.session(verifiedTouches: 1_000, activeSeconds: 3_600).total, 30)
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
