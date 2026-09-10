import XCTest
@testable import TechnIQ

/// Touchline session mechanics on ActiveSessionManager: clock, reps, effort zone, one-tap advance,
/// and the session-level effort that back-fills drill ratings.
@MainActor
final class ActiveSessionTouchlineTests: XCTestCase {
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        stack = nil
        super.tearDown()
    }

    private func makeSUT(durations: [Int16], loads: [Int16]? = nil) -> (ActiveSessionManager, Player) {
        let player = stack.makePlayer()
        let exercises = durations.enumerated().map { index, seconds -> Exercise in
            let exercise = stack.makeExercise(player: player, name: "Ex \(index)")
            exercise.estimatedDurationSeconds = seconds
            exercise.difficulty = 2
            exercise.targetSkills = ["Passing"]
            if let loads, index < loads.count { exercise.metabolicLoad = loads[index] }
            return exercise
        }
        try? stack.context.save()
        return (ActiveSessionManager(exercises: exercises), player)
    }

    // MARK: - Clock

    func test_clock_countsDownFromEstimatedDurationAndStopsAtZero() {
        let (sut, _) = makeSUT(durations: [3])
        sut.start()
        XCTAssertTrue(sut.isRunning)
        XCTAssertEqual(sut.targetSeconds, 3)
        XCTAssertEqual(sut.clockSeconds, 3)

        sut.tick(); sut.tick()
        XCTAssertEqual(sut.clockSeconds, 1)
        XCTAssertFalse(sut.isTimeUp)

        sut.tick()
        XCTAssertEqual(sut.clockSeconds, 0)
        XCTAssertTrue(sut.isTimeUp)
        XCTAssertFalse(sut.isRunning, "clock stops when time is up")

        sut.tick()
        XCTAssertEqual(sut.clockSeconds, 0, "ticks are ignored while stopped")
    }

    func test_clock_countsUpWhenDrillHasNoDuration() {
        let (sut, _) = makeSUT(durations: [0])
        sut.start()
        XCTAssertNil(sut.targetSeconds)
        sut.tick(); sut.tick(); sut.tick()
        XCTAssertEqual(sut.clockSeconds, 3)
        XCTAssertFalse(sut.isTimeUp)
    }

    func test_pauseAndResume() {
        let (sut, _) = makeSUT(durations: [60])
        sut.start()
        sut.tick()
        sut.toggleClock()
        XCTAssertFalse(sut.isRunning)
        sut.tick()
        XCTAssertEqual(sut.elapsedSeconds, 1, "no ticks while paused")
        sut.toggleClock()
        sut.tick()
        XCTAssertEqual(sut.elapsedSeconds, 2)
    }

    // MARK: - Reps and effort

    func test_addReps_countsForCurrentDrillOnly() {
        let (sut, _) = makeSUT(durations: [60, 60])
        sut.start()
        sut.addReps()
        sut.addReps(10)
        XCTAssertEqual(sut.currentReps, 20)
        sut.advance()
        XCTAssertEqual(sut.currentReps, 0)
        XCTAssertEqual(sut.reps, [20, 0])
    }

    func test_effortZone_prefersMetabolicLoadThenDifficulty() {
        let (sut, _) = makeSUT(durations: [60, 60], loads: [4, 0])
        sut.start()
        XCTAssertEqual(sut.currentEffortZone, 4)
        sut.advance()
        XCTAssertEqual(sut.currentEffortZone, 2, "difficulty 2 → Z2 when no metabolic load")
    }

    // MARK: - Advance

    func test_advance_completesDrillWithProvisionalRatingAndRestartsClock() {
        let (sut, _) = makeSUT(durations: [10, 10])
        sut.start()
        sut.tick(); sut.tick()
        sut.advance()

        XCTAssertEqual(sut.phase, .exercise)
        XCTAssertEqual(sut.currentExerciseIndex, 1)
        XCTAssertEqual(sut.exerciseRatings[0], SessionEffort.good.rating)
        XCTAssertEqual(sut.exerciseDurations[0], 2)
        XCTAssertEqual(sut.elapsedSeconds, 0)
        XCTAssertTrue(sut.isRunning, "clock restarts for the next drill")

        sut.advance()
        XCTAssertEqual(sut.phase, .sessionComplete)
        XCTAssertFalse(sut.isRunning)
    }

    func test_endSessionEarly_keepsUnfinishedDrillUnrated() {
        let (sut, _) = makeSUT(durations: [10, 10])
        sut.start()
        sut.advance()
        sut.tick()
        sut.endSessionEarly()
        XCTAssertEqual(sut.phase, .sessionComplete)
        XCTAssertEqual(sut.exerciseRatings, [SessionEffort.good.rating, 0])
        XCTAssertEqual(sut.exerciseDurations, [0, 1])
        XCTAssertEqual(sut.totalMinutes, 1, "any time spent rounds up to a minute")
    }

    // MARK: - Session effort

    func test_applyEffort_rewritesCompletedRatingsSessionAndSkillScores() {
        let (sut, player) = makeSUT(durations: [10, 10])
        sut.start()
        sut.addReps(30)
        sut.advance()
        sut.advance()
        XCTAssertEqual(sut.phase, .sessionComplete)

        let result = sut.finishSession(player: player, context: stack.context)
        XCTAssertNotNil(result.xpBreakdown)
        let session = sut.completedSession
        XCTAssertNotNil(session)
        XCTAssertEqual(session?.overallRating, Int16(SessionEffort.good.rating))
        let firstExercise = (session?.exercises as? Set<SessionExercise>)?.first { $0.exercise?.name == "Ex 0" }
        XCTAssertEqual(firstExercise?.reps, 30)

        let statsBefore = (player.stats as? Set<PlayerStats>)?.first?.skillRatings?["Passing"]
        XCTAssertEqual(statsBefore, 80, "provisional Good = 4 → 80")

        sut.applyEffort(.hard, to: session, player: player, context: stack.context)

        XCTAssertEqual(sut.exerciseRatings, [2, 2])
        XCTAssertEqual(session?.overallRating, 2)
        for se in (session?.exercises as? Set<SessionExercise>) ?? [] {
            XCTAssertEqual(se.performanceRating, 2)
        }
        let statsAfter = (player.stats as? Set<PlayerStats>)?.first?.skillRatings?["Passing"]
        XCTAssertEqual(statsAfter, 40, "re-derived from the pre-session snapshot, not averaged twice")
    }

    func test_sessionEffort_mapping() {
        XCTAssertEqual(SessionEffort.easy.rating, 5)
        XCTAssertEqual(SessionEffort.good.rating, 4)
        XCTAssertEqual(SessionEffort.ok.rating, 3)
        XCTAssertEqual(SessionEffort.hard.rating, 2)
        XCTAssertEqual(SessionEffort.from(rating: 3), .ok)
        XCTAssertEqual(SessionEffort.from(rating: 9), .good)
    }
}
