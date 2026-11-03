import XCTest
@testable import TechnIQ

/// Touchline session mechanics on ActiveSessionManager: clock, reps, one-tap advance, active time,
/// and the session-level feel that back-fills drill ratings.
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

    // MARK: - Reps

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

    // MARK: - Advance

    func test_advance_completesDrillWithProvisionalRatingAndRestartsClock() {
        let (sut, _) = makeSUT(durations: [10, 10])
        sut.start()
        sut.tick(); sut.tick()
        sut.advance()

        XCTAssertEqual(sut.phase, .exercise)
        XCTAssertEqual(sut.currentExerciseIndex, 1)
        XCTAssertEqual(sut.exerciseRatings[0], SessionFeel.right.rating)
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
        XCTAssertEqual(sut.exerciseRatings, [SessionFeel.right.rating, 0])
        XCTAssertEqual(sut.exerciseDurations, [0, 1])
        XCTAssertEqual(sut.totalMinutes, 1, "any time spent rounds up to a minute")
    }

    func test_finishSession_withNoCompletedDrillSavesNothing() {
        let (sut, player) = makeSUT(durations: [10, 10])
        sut.start()
        sut.tick()
        sut.endSessionEarly()
        let xpBefore = player.totalXP
        let sessionsBefore = (player.sessions as? Set<TrainingSession>)?.count ?? 0

        let result = sut.finishSession(player: player, context: stack.context)

        XCTAssertNil(result.xpBreakdown, "nothing completed → nothing to award")
        XCTAssertNil(result.newLevel)
        XCTAssertTrue(result.achievements.isEmpty)
        XCTAssertNil(sut.completedSession)
        XCTAssertEqual(player.totalXP, xpBefore)
        XCTAssertEqual((player.sessions as? Set<TrainingSession>)?.count ?? 0, sessionsBefore, "no session row is created")
    }

    // MARK: - Active time + XP

    func test_finishSession_persistsActiveSecondsAndPaysTimeXP() {
        let (sut, player) = makeSUT(durations: [600, 600])
        sut.start()
        for _ in 0..<130 { sut.tick() }
        sut.pauseClock()                       // paused time is not active time
        sut.advance()
        for _ in 0..<70 { sut.tick() }
        sut.advance()

        let result = sut.finishSession(player: player, context: stack.context)

        XCTAssertEqual(sut.completedSession?.activeSeconds, 200)
        XCTAssertEqual(sut.completedSession?.verifiedTouches, 0, "tapped reps are not verified")
        XCTAssertEqual(result.xpBreakdown, SessionXPBreakdown(timeXP: 3, touchXP: 0))
        XCTAssertEqual(sut.completedSession?.xpEarned, 3)
        XCTAssertNil(sut.completedSession?.feel, "no feel until the player picks one")
        XCTAssertFalse(sut.completedSession?.countsTowardStreak ?? true, "under five minutes")
    }

    // MARK: - Session feel

    func test_applyFeel_rewritesCompletedRatingsSessionAndSkillScores() {
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
        XCTAssertEqual(session?.overallRating, Int16(SessionFeel.right.rating))
        let firstExercise = (session?.exercises as? Set<SessionExercise>)?.first { $0.exercise?.name == "Ex 0" }
        XCTAssertEqual(firstExercise?.reps, 30)

        let statsBefore = (player.stats as? Set<PlayerStats>)?.first?.skillRatings?["Passing"]
        XCTAssertEqual(statsBefore, 80, "provisional Right = 4 → 80")

        sut.applyFeel(.tooHard, to: session, player: player, context: stack.context)

        XCTAssertEqual(session?.feel, SessionFeel.tooHard.rawValue)
        XCTAssertEqual(sut.exerciseRatings, [2, 2])
        XCTAssertEqual(session?.overallRating, 2)
        for se in (session?.exercises as? Set<SessionExercise>) ?? [] {
            XCTAssertEqual(se.performanceRating, 2)
        }
        let statsAfter = (player.stats as? Set<PlayerStats>)?.first?.skillRatings?["Passing"]
        XCTAssertEqual(statsAfter, 40, "re-derived from the pre-session snapshot, not averaged twice")
    }

    func test_sessionFeel_mapping() {
        XCTAssertEqual(SessionFeel.allCases.map(\.label), ["Too easy", "Right", "Too hard"])
        XCTAssertEqual(SessionFeel.tooEasy.rating, 5)
        XCTAssertEqual(SessionFeel.right.rating, 4)
        XCTAssertEqual(SessionFeel.tooHard.rating, 2)
        XCTAssertEqual(SessionFeel(raw: "tooHard"), .tooHard)
        XCTAssertNil(SessionFeel(raw: nil))
        XCTAssertNil(SessionFeel(raw: "good"))
    }
}
