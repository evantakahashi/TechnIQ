import XCTest
import CoreData
@testable import TechnIQ

@MainActor
final class CameraRunServiceTests: XCTestCase {
    var stack: TestCoreDataStack!
    var defaults: UserDefaults!
    var sut: CameraRunService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        defaults = UserDefaults(suiteName: "CameraRunServiceTests")
        defaults.removePersistentDomain(forName: "CameraRunServiceTests")
        sut = CameraRunService(context: stack.context, defaults: defaults,
                               coins: CoinService(coreDataManager: stack))
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "CameraRunServiceTests")
        sut = nil
        stack = nil
        super.tearDown()
    }

    func test_firstRun_isAPersonalBest_andPaysBasePlusBest() throws {
        let player = stack.makePlayer(xp: 0, coins: 0)

        let outcome = try XCTUnwrap(sut.record(drill: .juggling, count: 12, duration: 9, player: player))

        XCTAssertTrue(outcome.isPersonalBest)
        XCTAssertNil(outcome.previousBest)
        XCTAssertEqual(outcome.reward, CameraReward(xp: 30, coins: 12, countsTowardCap: true))
        XCTAssertEqual(player.totalXP, 30)
        XCTAssertEqual(player.coins, 12)
        XCTAssertEqual(sut.personalBest(for: .juggling, player: player), 12)
    }

    func test_lowerRun_isNotABest_andBestIsPerDrill() throws {
        let player = stack.makePlayer()
        sut.record(drill: .juggling, count: 20, duration: 12, player: player)

        let outcome = try XCTUnwrap(sut.record(drill: .juggling, count: 8, duration: 5, player: player))

        XCTAssertFalse(outcome.isPersonalBest)
        XCTAssertEqual(outcome.previousBest, 20)
        XCTAssertNil(sut.personalBest(for: .toeTaps, player: player))
    }

    func test_baseRewardStopsAfterTenRunsADay() throws {
        let player = stack.makePlayer()
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for i in 0..<10 { sut.record(drill: .juggling, count: 5, duration: 3, player: player, now: day.addingTimeInterval(Double(i))) }

        let capped = try XCTUnwrap(sut.record(drill: .juggling, count: 5, duration: 3, player: player, now: day.addingTimeInterval(60)))
        let nextDay = try XCTUnwrap(sut.record(drill: .juggling, count: 5, duration: 3, player: player, now: day.addingTimeInterval(86_400)))

        XCTAssertEqual(capped.reward, .none)
        XCTAssertEqual(nextDay.reward.xp, 5)
    }

    func test_zeroTouchRunIsNotStored() {
        let player = stack.makePlayer()

        XCTAssertNil(sut.record(drill: .juggling, count: 0, duration: 1, player: player))
        XCTAssertEqual(player.cameraRuns?.count ?? 0, 0)
    }
}
