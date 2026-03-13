import XCTest
@testable import TechnIQ

final class ActiveSessionManagerTests: XCTestCase {
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        stack = nil
        super.tearDown()
    }

    private func makeSUT(exerciseCount: Int = 3) -> ActiveSessionManager {
        let player = stack.makePlayer()
        let exercises = (0..<exerciseCount).map { i in
            stack.makeExercise(player: player, name: "Ex \(i)")
        }
        try? stack.context.save()
        return ActiveSessionManager(exercises: exercises)
    }

    // MARK: - Initial State

    func test_initialState_isPreparing() {
        let sut = makeSUT()
        sut.start()
        XCTAssertEqual(sut.phase, .preparing)
        XCTAssertEqual(sut.currentExerciseIndex, 0)
    }

    // MARK: - Exercise Flow

    func test_completeExercise_transitionsToExerciseComplete() {
        let sut = makeSUT()
        sut.start()
        sut.phase = .exerciseActive
        sut.completeExercise()
        XCTAssertEqual(sut.phase, .exerciseComplete)
    }

    func test_completeExercise_freezesDuration() {
        let sut = makeSUT()
        sut.start()
        sut.phase = .exerciseActive
        sut.completeExercise()
        XCTAssertGreaterThanOrEqual(sut.exerciseDurations[0], 0)
    }

    func test_completeExercise_notActive_noOp() {
        let sut = makeSUT()
        sut.start()
        sut.completeExercise()
        XCTAssertEqual(sut.phase, .preparing)
    }

    func test_rateExercise_storesRatingAndNotes() {
        let sut = makeSUT()
        sut.rateExercise(4, notes: "Good form")
        XCTAssertEqual(sut.exerciseRatings[0], 4)
        XCTAssertEqual(sut.exerciseNotes[0], "Good form")
    }

    func test_nextExercise_startsRest_whenNotLast() {
        let sut = makeSUT(exerciseCount: 3)
        sut.start()
        sut.phase = .exerciseActive
        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.phase, .rest)
    }

    func test_nextExercise_completesSession_whenLast() {
        let sut = makeSUT(exerciseCount: 1)
        sut.start()
        sut.phase = .exerciseActive
        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    func test_skipRest_advancesToNextExercise() {
        let sut = makeSUT(exerciseCount: 3)
        sut.start()
        sut.phase = .exerciseActive
        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.phase, .rest)
        sut.skipRest()
        XCTAssertEqual(sut.phase, .exerciseActive)
        XCTAssertEqual(sut.currentExerciseIndex, 1)
    }

    func test_endSessionEarly_fromAnyPhase() {
        let sut = makeSUT()
        sut.start()
        sut.phase = .exerciseActive
        sut.endSessionEarly()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    // MARK: - Pause/Resume

    func test_pauseResume_togglesFlag() {
        let sut = makeSUT()
        sut.start()
        sut.phase = .exerciseActive
        XCTAssertFalse(sut.isPaused)
        sut.pause()
        XCTAssertTrue(sut.isPaused)
        sut.resume()
        XCTAssertFalse(sut.isPaused)
    }

    // MARK: - Helpers

    func test_averageRating_defaultsTo3() {
        let sut = makeSUT()
        XCTAssertEqual(sut.averageRating(), 3)
    }

    func test_averageRating_calculatesCorrectly() {
        let sut = makeSUT(exerciseCount: 2)
        sut.exerciseRatings = [4, 2]
        XCTAssertEqual(sut.averageRating(), 3)
    }

    func test_formattedTime() {
        let sut = makeSUT()
        XCTAssertEqual(sut.formattedTime(65), "1:05")
        XCTAssertEqual(sut.formattedTime(0), "0:00")
    }

    func test_isLastExercise() {
        let sut = makeSUT(exerciseCount: 2)
        XCTAssertFalse(sut.isLastExercise)
        sut.currentExerciseIndex = 1
        XCTAssertTrue(sut.isLastExercise)
    }

    func test_completedExerciseCount() {
        let sut = makeSUT(exerciseCount: 3)
        sut.exerciseDurations = [10, 0, 5]
        XCTAssertEqual(sut.completedExerciseCount, 2)
    }
}
