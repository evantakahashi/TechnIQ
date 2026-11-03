import XCTest
import CoreData
@testable import TechnIQ

// MARK: - Benchmark summary (pure)

final class BenchmarkSummaryTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func entry(_ type: BenchmarkType, _ value: Int, day: Int, camera: Bool = false) -> BenchmarkEntry {
        BenchmarkEntry(type: type, value: value, date: day0.addingTimeInterval(Double(day) * 86_400), cameraVerified: camera)
    }

    func test_noEntries_noSummary() {
        XCTAssertTrue(BenchmarkSummary.summarize([]).isEmpty)
        XCTAssertNil(BenchmarkSummary.summary(for: .juggling, in: [entry(.toeTaps30, 30, day: 0)]))
    }

    func test_firstEntry_isLastAndBest_butNotANewBest() throws {
        let summary = try XCTUnwrap(BenchmarkSummary.summary(for: .juggling, in: [entry(.juggling, 14, day: 0)]))
        XCTAssertEqual(summary.last.value, 14)
        XCTAssertEqual(summary.best.value, 14)
        XCTAssertNil(summary.previous)
        XCTAssertFalse(summary.isNewBest, "a first result has nothing to beat")
        XCTAssertEqual(summary.metaText, "Last 14 · Best 14")
    }

    func test_lastVsBest_usesDatesNotInputOrder() throws {
        let entries = [entry(.juggling, 22, day: 5), entry(.juggling, 14, day: 0), entry(.juggling, 18, day: 9)]
        let summary = try XCTUnwrap(BenchmarkSummary.summary(for: .juggling, in: entries))
        XCTAssertEqual(summary.last.value, 18)
        XCTAssertEqual(summary.previous?.value, 22)
        XCTAssertEqual(summary.best.value, 22)
        XCTAssertFalse(summary.isNewBest)
        XCTAssertEqual(summary.metaText, "Last 18 · Best 22")
    }

    func test_newBest_onlyWhenStrictlyAboveEveryEarlierValue() throws {
        let beat = try XCTUnwrap(BenchmarkSummary.summary(for: .toeTaps30, in: [entry(.toeTaps30, 30, day: 0), entry(.toeTaps30, 31, day: 1)]))
        XCTAssertTrue(beat.isNewBest)
        let tie = try XCTUnwrap(BenchmarkSummary.summary(for: .toeTaps30, in: [entry(.toeTaps30, 30, day: 0), entry(.toeTaps30, 30, day: 1)]))
        XCTAssertFalse(tie.isNewBest, "equalling the best is not a new best")
        XCTAssertFalse(BenchmarkSummary.isNewBest(value: 5, previousBest: nil))
        XCTAssertTrue(BenchmarkSummary.isNewBest(value: 1, previousBest: 0))
    }

    func test_bestTie_prefersCameraVerified_thenEarliest() throws {
        let camera = try XCTUnwrap(BenchmarkSummary.summary(for: .juggling, in: [
            entry(.juggling, 20, day: 0), entry(.juggling, 20, day: 1, camera: true), entry(.juggling, 9, day: 2)
        ]))
        XCTAssertTrue(camera.best.cameraVerified)
        let earliest = try XCTUnwrap(BenchmarkSummary.summary(for: .juggling, in: [entry(.juggling, 20, day: 3), entry(.juggling, 20, day: 1)]))
        XCTAssertEqual(earliest.best.date, earliest.best.date)
        XCTAssertEqual(earliest.best.date, day0.addingTimeInterval(86_400))
    }

    func test_summarize_keepsTypesApart() {
        let summaries = BenchmarkSummary.summarize([entry(.juggling, 3, day: 0), entry(.wallPasses30, 12, day: 0), entry(.juggling, 5, day: 1)])
        XCTAssertEqual(Set(summaries.keys), [.juggling, .wallPasses30])
        XCTAssertEqual(summaries[.juggling]?.last.value, 5)
        XCTAssertEqual(summaries[.wallPasses30]?.last.value, 12)
    }
}

// MARK: - Assessment flow (pure)

final class AssessmentFlowTests: XCTestCase {
    func test_happyPath_walksEveryStepAndCollectsResults() {
        var flow = AssessmentFlow()
        XCTAssertEqual(flow.step, .intro)
        XCTAssertEqual(flow.stepNumber, 0)
        flow.begin()
        XCTAssertEqual(flow.step, .warmup)
        flow.finishWarmup(ranSeconds: 120)
        XCTAssertEqual(flow.step, .juggling)
        XCTAssertEqual(flow.currentType, .juggling)

        flow.addJugglingAttempt(8, cameraVerified: false)
        flow.addJugglingAttempt(15, cameraVerified: true)
        flow.addJugglingAttempt(11, cameraVerified: false)
        XCTAssertEqual(flow.remainingJugglingAttempts, 0)
        flow.addJugglingAttempt(40, cameraVerified: false)
        XCTAssertEqual(flow.jugglingAttempts.count, 3, "never more than three attempts")
        flow.finishJuggling(elapsedSeconds: 90)
        XCTAssertEqual(flow.results[.juggling], .init(value: 15, cameraVerified: true), "best of three counts")

        XCTAssertEqual(flow.step, .wallPasses)
        XCTAssertEqual(flow.timedPhase, .ready)
        flow.startClock()
        XCTAssertEqual(flow.timedPhase, .running)
        flow.clockEnded(ranSeconds: 30)
        XCTAssertEqual(flow.timedPhase, .entry)
        flow.enterCount(21)
        XCTAssertEqual(flow.step, .toeTaps)
        flow.startClock()
        flow.clockEnded(ranSeconds: 31)
        flow.enterCount(0)
        XCTAssertTrue(flow.isFinished)
        XCTAssertEqual(flow.results[.wallPasses30]?.value, 21)
        XCTAssertEqual(flow.results[.toeTaps30], .init(value: 0, cameraVerified: false), "0 is a legitimate typed result")
        XCTAssertEqual(flow.activeSeconds, 120 + 90 + 30 + 30, "clock time is capped at each window")
        XCTAssertEqual(flow.verifiedTouches, 15)
    }

    func test_skippedWarmup_countsOnlyTheSecondsThatRan() {
        var flow = AssessmentFlow()
        flow.begin()
        flow.finishWarmup(ranSeconds: 14)
        XCTAssertEqual(flow.activeSeconds, 14)
        XCTAssertEqual(flow.step, .juggling)
    }

    func test_jugglingNeedsAnAttempt_andTimeIsCapped() {
        var flow = AssessmentFlow()
        flow.begin()
        flow.finishWarmup(ranSeconds: 0)
        flow.finishJuggling(elapsedSeconds: 50)
        XCTAssertEqual(flow.step, .juggling, "no attempt, no move")
        flow.addJugglingAttempt(-1, cameraVerified: false)
        XCTAssertTrue(flow.jugglingAttempts.isEmpty)
        flow.addJugglingAttempt(0, cameraVerified: false)
        flow.finishJuggling(elapsedSeconds: 10_000)
        XCTAssertEqual(flow.step, .wallPasses)
        XCTAssertEqual(flow.activeSeconds, AssessmentFlow.maxJugglingSeconds)
    }

    func test_outOfOrderCallsAreIgnored() {
        var flow = AssessmentFlow()
        flow.enterCount(5)
        flow.startClock()
        flow.addJugglingAttempt(5, cameraVerified: false)
        flow.finishWarmup(ranSeconds: 60)
        XCTAssertEqual(flow, AssessmentFlow(), "nothing happens before the intro is left")

        flow.begin()
        flow.finishWarmup(ranSeconds: 120)
        flow.addJugglingAttempt(5, cameraVerified: false)
        flow.finishJuggling(elapsedSeconds: 0)
        flow.enterCount(9)
        XCTAssertNil(flow.results[.wallPasses30], "a count needs the clock to have run")
        flow.clockEnded(ranSeconds: 30)
        XCTAssertEqual(flow.timedPhase, .ready)
    }

    func test_redoClock_keepsTheTimeAlreadyRun() {
        var flow = AssessmentFlow()
        flow.begin()
        flow.finishWarmup(ranSeconds: 0)
        flow.addJugglingAttempt(1, cameraVerified: false)
        flow.finishJuggling(elapsedSeconds: 0)
        flow.startClock()
        flow.clockEnded(ranSeconds: 4)
        flow.redoClock()
        XCTAssertEqual(flow.timedPhase, .ready)
        flow.startClock()
        flow.clockEnded(ranSeconds: 30)
        XCTAssertEqual(flow.activeSeconds, 34)
        flow.enterCount(12, cameraVerified: true)
        XCTAssertEqual(flow.verifiedTouches, 12, "camera-counted timed tests count too")
    }
}

// MARK: - Benchmark service (Core Data)

@MainActor
final class BenchmarkServiceTests: XCTestCase {
    var stack: TestCoreDataStack!
    var sut: BenchmarkService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = BenchmarkService(context: stack.context)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    func test_record_storesTypedValuesIncludingZero_rejectsNegatives() throws {
        let player = stack.makePlayer()
        let zero = try XCTUnwrap(sut.record(type: .juggling, value: 0, cameraVerified: false, player: player))
        XCTAssertEqual(zero.type, BenchmarkType.juggling.rawValue)
        XCTAssertEqual(zero.value, 0)
        XCTAssertFalse(zero.cameraVerified)
        XCTAssertNotNil(zero.id)
        XCTAssertEqual(zero.player, player)
        XCTAssertNil(sut.record(type: .juggling, value: -3, cameraVerified: false, player: player))
        XCTAssertEqual(sut.entries(for: player).count, 1)
        XCTAssertTrue(sut.hasBenchmarks(player))
    }

    func test_summaries_readBackLastAndBest() {
        let player = stack.makePlayer()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        sut.record(type: .wallPasses30, value: 18, cameraVerified: false, player: player, date: start)
        sut.record(type: .wallPasses30, value: 24, cameraVerified: true, player: player, date: start.addingTimeInterval(86_400))
        sut.record(type: .wallPasses30, value: 20, cameraVerified: false, player: player, date: start.addingTimeInterval(2 * 86_400))
        let summary = sut.summaries(for: player)[.wallPasses30]
        XCTAssertEqual(summary?.metaText, "Last 20 · Best 24")
        XCTAssertEqual(summary?.best.cameraVerified, true)
        XCTAssertNil(sut.summaries(for: stack.makePlayer(name: "Other"))[.wallPasses30], "per player")
    }

    func test_cameraRunMapping() {
        XCTAssertEqual(BenchmarkService.benchmarkType(forCameraRunOf: .juggling, count: 12, duration: 8), .juggling)
        XCTAssertEqual(BenchmarkService.benchmarkType(forCameraRunOf: .toeTaps, count: 40, duration: 30), .toeTaps30)
        XCTAssertEqual(BenchmarkService.benchmarkType(forCameraRunOf: .wallPasses, count: 20, duration: 29.5), .wallPasses30)
        XCTAssertNil(BenchmarkService.benchmarkType(forCameraRunOf: .wallPasses, count: 9, duration: 12), "a run stopped early isn't 30 s")
        XCTAssertNil(BenchmarkService.benchmarkType(forCameraRunOf: .juggling, count: 0, duration: 2), "a 0 from the camera isn't recorded")
        XCTAssertNil(BenchmarkService.benchmarkType(forCameraRunOf: .weakFootJuggling, count: 9, duration: 9))
        XCTAssertNil(BenchmarkService.benchmarkType(forCameraRunOf: .alternatingJuggling, count: 9, duration: 9))
    }

    func test_finishAssessment_savesThreeBenchmarksAndOneSession() throws {
        let player = stack.makePlayer()
        var flow = AssessmentFlow()
        XCTAssertNil(sut.finishAssessment(flow, player: player, planSession: nil, startedAt: Date()), "an unfinished flow saves nothing")

        flow.begin()
        flow.finishWarmup(ranSeconds: 120)
        flow.addJugglingAttempt(9, cameraVerified: true)
        flow.addJugglingAttempt(6, cameraVerified: false)
        flow.finishJuggling(elapsedSeconds: 60)
        flow.startClock(); flow.clockEnded(ranSeconds: 30); flow.enterCount(17)
        flow.startClock(); flow.clockEnded(ranSeconds: 30); flow.enterCount(35)
        let started = Date(timeIntervalSinceNow: -9 * 60)

        let outcome = try XCTUnwrap(sut.finishAssessment(flow, player: player, planSession: nil, startedAt: started))
        let entries = sut.entries(for: player)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.first { $0.type == .juggling }, entries.first { $0.type == .juggling && $0.value == 9 && $0.cameraVerified })
        XCTAssertEqual(entries.first { $0.type == .wallPasses30 }?.value, 17)
        XCTAssertEqual(entries.first { $0.type == .toeTaps30 }?.cameraVerified, false)

        let session = outcome.session
        XCTAssertEqual(session.sessionType, "Assessment")
        XCTAssertEqual(session.activeSeconds, 240)
        XCTAssertEqual(session.verifiedTouches, 9)
        XCTAssertEqual(session.duration, 9)
        XCTAssertEqual(session.player, player)
        XCTAssertNil(session.planSession)
    }
}

// MARK: - Camera runs write benchmarks

@MainActor
final class CameraRunBenchmarkTests: XCTestCase {
    func test_cameraRunOfABenchmarkDrill_recordsACameraVerifiedBenchmark() throws {
        let stack = TestCoreDataStack()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CameraRunBenchmarkTests"))
        defaults.removePersistentDomain(forName: "CameraRunBenchmarkTests")
        defer { defaults.removePersistentDomain(forName: "CameraRunBenchmarkTests") }
        let service = CameraRunService(context: stack.context, defaults: defaults, coins: CoinService(coreDataManager: stack))
        let player = stack.makePlayer()

        service.record(drill: .juggling, count: 12, duration: 9, player: player)
        service.record(drill: .juggling, count: 7, duration: 5, player: player, recordsBenchmark: false)
        service.record(drill: .weakFootJuggling, count: 5, duration: 4, player: player)
        service.record(drill: .juggling, count: 0, duration: 1, player: player)

        let entries = BenchmarkService(context: stack.context).entries(for: player)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.type, .juggling)
        XCTAssertEqual(entries.first?.value, 12)
        XCTAssertEqual(entries.first?.cameraVerified, true)
    }

    func test_cameraDrillList_hidesSoonDrillsUnlessFlagged() {
        XCTAssertEqual(CameraDrill.listed(showingSoon: false), CameraDrill.allCases.filter(\.isAvailable))
        XCTAssertFalse(CameraDrill.listed(showingSoon: false).contains(.toeTaps))
        XCTAssertEqual(CameraDrill.listed(showingSoon: true), CameraDrill.allCases)
    }
}

// MARK: - Tabs (Community flag)

final class TabFlagTests: XCTestCase {
    typealias Tab = DesignSystem.Icons.Tab

    func test_visibleTabs_hideCommunityByDefault() {
        XCTAssertEqual(Tab.visible(community: false), [.home, .train, .plans, .you])
        XCTAssertEqual(Tab.visible(community: true), [.home, .train, .plans, .community, .you])
        XCTAssertFalse(FeatureFlags.community, "Community is off unless -TQCommunity / ff.community")
    }

    func test_launchValue_acceptsStableIdsAndNames_hiddenFallsBackHome() {
        let four = Tab.visible(community: false)
        XCTAssertEqual(Tab.fromLaunchValue("4", visible: four), .you)
        XCTAssertEqual(Tab.fromLaunchValue("2", visible: four), .plans)
        XCTAssertEqual(Tab.fromLaunchValue("plans", visible: four), .plans)
        XCTAssertEqual(Tab.fromLaunchValue("3", visible: four), .home, "community hidden")
        XCTAssertEqual(Tab.fromLaunchValue("3", visible: Tab.visible(community: true)), .community)
        XCTAssertEqual(Tab.fromLaunchValue("9", visible: four), .home)
        XCTAssertEqual(Tab.fromLaunchValue("nope", visible: four), .home)
    }
}
