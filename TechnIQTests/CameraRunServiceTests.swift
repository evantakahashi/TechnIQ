import XCTest
import CoreData
@testable import TechnIQ

@MainActor
final class CameraRunServiceTests: XCTestCase {
    var stack: TestCoreDataStack!
    var sut: CameraRunService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = CameraRunService(context: stack.context)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    func test_firstRun_isAPersonalBest_andPaysTheFormula() throws {
        let player = stack.makePlayer(xp: 0)

        // 30 s of live time: under the one-minute floor, so no XP yet.
        let outcome = try XCTUnwrap(sut.record(drill: .juggling, count: 12, duration: 30, player: player))

        XCTAssertTrue(outcome.isPersonalBest)
        XCTAssertNil(outcome.previousBest)
        XCTAssertEqual(outcome.xp, 0)
        XCTAssertEqual(player.totalXP, 0)
        XCTAssertEqual(sut.personalBest(for: .juggling, player: player), 12)
    }

    func test_runsInOneSitting_arePaidTheIncrease() throws {
        let player = stack.makePlayer(xp: 0)
        let sitting = CameraSitting()

        let first = try XCTUnwrap(sut.record(drill: .toeTaps, count: 40, duration: 30, player: player, sitting: sitting))
        let second = try XCTUnwrap(sut.record(drill: .toeTaps, count: 45, duration: 30, player: player, sitting: sitting))

        XCTAssertEqual(first.xp, 0)
        XCTAssertEqual(second.xp, 1 + 8, "60 s and 85 touches over the sitting")
        XCTAssertEqual(second.run.xpEarned, 9)
        XCTAssertEqual(player.totalXP, 9)
        XCTAssertEqual(sitting.xpAwarded, 9)
    }

    func test_aSittingIsCappedAtThirty_noBonusForPersonalBests() throws {
        let player = stack.makePlayer(xp: 0)
        let sitting = CameraSitting()
        var paid = 0
        for count in stride(from: 50, through: 500, by: 50) {
            let outcome = try XCTUnwrap(sut.record(drill: .juggling, count: count, duration: 180, player: player, sitting: sitting))
            XCTAssertTrue(outcome.isPersonalBest)
            paid += outcome.xp
        }

        XCTAssertEqual(paid, 30)
        XCTAssertEqual(player.totalXP, 30)
    }

    func test_aNewSitting_canEarnAgain() throws {
        let player = stack.makePlayer(xp: 0)
        let morning = CameraSitting()
        sut.record(drill: .juggling, count: 300, duration: 1_500, player: player, sitting: morning)

        let evening = try XCTUnwrap(sut.record(drill: .juggling, count: 20, duration: 120, player: player, sitting: CameraSitting()))

        XCTAssertEqual(player.totalXP, Int64(30 + evening.xp))
        XCTAssertEqual(evening.xp, 2 + 2)
    }

    func test_lowerRun_isNotABest_andBestIsPerDrill() throws {
        let player = stack.makePlayer()
        sut.record(drill: .juggling, count: 20, duration: 12, player: player)

        let outcome = try XCTUnwrap(sut.record(drill: .juggling, count: 8, duration: 5, player: player))

        XCTAssertFalse(outcome.isPersonalBest)
        XCTAssertEqual(outcome.previousBest, 20)
        XCTAssertNil(sut.personalBest(for: .toeTaps, player: player))
    }

    func test_zeroTouchRunIsNotStored() {
        let player = stack.makePlayer()
        let sitting = CameraSitting()

        XCTAssertNil(sut.record(drill: .juggling, count: 0, duration: 90, player: player, sitting: sitting))
        XCTAssertEqual(player.cameraRuns?.count ?? 0, 0)
        XCTAssertEqual(sitting.liveSeconds, 0)
    }
}
