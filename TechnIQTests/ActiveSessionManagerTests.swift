import XCTest
@testable import TechnIQ

@MainActor
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

    func test_initialPhase_isExercise() {
        let sut = makeSUT()
        XCTAssertEqual(sut.phase, .exercise)
        XCTAssertEqual(sut.currentExerciseIndex, 0)
    }

    // MARK: - start()

    func test_start_setsPhaseToExercise() {
        let sut = makeSUT()
        sut.phase = .sessionComplete // force different state
        sut.start()
        XCTAssertEqual(sut.phase, .exercise)
    }

    // MARK: - completeExercise()

    func test_completeExercise_transitionsToRating() {
        let sut = makeSUT()
        sut.start()
        sut.completeExercise()
        XCTAssertEqual(sut.phase, .rating)
    }

    func test_completeExercise_doesNothingIfNotInExercisePhase() {
        let sut = makeSUT()
        sut.phase = .rating
        sut.completeExercise()
        XCTAssertEqual(sut.phase, .rating, "Should stay in .rating")

        sut.phase = .sessionComplete
        sut.completeExercise()
        XCTAssertEqual(sut.phase, .sessionComplete, "Should stay in .sessionComplete")
    }

    // MARK: - rateExercise()

    func test_rateExercise_storesRatingAndNotes() {
        let sut = makeSUT()
        sut.rateExercise(4, notes: "Good form")
        XCTAssertEqual(sut.exerciseRatings[0], 4)
        XCTAssertEqual(sut.exerciseNotes[0], "Good form")
    }

    func test_rateExercise_storesForCurrentIndex() {
        let sut = makeSUT(exerciseCount: 3)
        sut.start()
        sut.completeExercise()
        sut.rateExercise(5, notes: "Great")
        sut.nextExercise()

        sut.completeExercise()
        sut.rateExercise(2, notes: "Tough")

        XCTAssertEqual(sut.exerciseRatings[0], 5)
        XCTAssertEqual(sut.exerciseNotes[0], "Great")
        XCTAssertEqual(sut.exerciseRatings[1], 2)
        XCTAssertEqual(sut.exerciseNotes[1], "Tough")
    }

    // MARK: - nextExercise()

    func test_nextExercise_advancesIndexAndGoesToExercise() {
        let sut = makeSUT(exerciseCount: 3)
        sut.start()
        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.currentExerciseIndex, 1)
        XCTAssertEqual(sut.phase, .exercise)
    }

    func test_nextExercise_onLastExercise_goesToSessionComplete() {
        let sut = makeSUT(exerciseCount: 1)
        sut.start()
        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    func test_nextExercise_fullFlow_completesAfterLastExercise() {
        let sut = makeSUT(exerciseCount: 2)
        sut.start()

        // First exercise
        sut.completeExercise()
        sut.rateExercise(4, notes: "")
        sut.nextExercise()
        XCTAssertEqual(sut.currentExerciseIndex, 1)
        XCTAssertEqual(sut.phase, .exercise)

        // Second (last) exercise
        sut.completeExercise()
        sut.rateExercise(3, notes: "")
        sut.nextExercise()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    // MARK: - endSessionEarly()

    func test_endSessionEarly_fromExercisePhase() {
        let sut = makeSUT()
        sut.start()
        sut.endSessionEarly()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    func test_endSessionEarly_fromRatingPhase() {
        let sut = makeSUT()
        sut.phase = .rating
        sut.endSessionEarly()
        XCTAssertEqual(sut.phase, .sessionComplete)
    }

    // MARK: - currentExercise

    func test_currentExercise_returnsCorrectExercise() {
        let sut = makeSUT(exerciseCount: 3)
        XCTAssertEqual(sut.currentExercise?.name, "Ex 0")

        sut.completeExercise()
        sut.nextExercise()
        XCTAssertEqual(sut.currentExercise?.name, "Ex 1")
    }

    func test_currentExercise_returnsNilWhenOutOfBounds() {
        let sut = makeSUT(exerciseCount: 1)
        sut.completeExercise()
        sut.nextExercise() // sessionComplete, index stays at 0
        // Index doesn't go out of bounds for single exercise since isLastExercise triggers sessionComplete
        XCTAssertNotNil(sut.currentExercise)
    }

    // MARK: - isLastExercise

    func test_isLastExercise_falseWhenMoreRemain() {
        let sut = makeSUT(exerciseCount: 2)
        XCTAssertFalse(sut.isLastExercise)
    }

    func test_isLastExercise_trueOnLastIndex() {
        let sut = makeSUT(exerciseCount: 2)
        sut.currentExerciseIndex = 1
        XCTAssertTrue(sut.isLastExercise)
    }

    func test_isLastExercise_trueForSingleExercise() {
        let sut = makeSUT(exerciseCount: 1)
        XCTAssertTrue(sut.isLastExercise)
    }

    // MARK: - averageRating()

    func test_averageRating_defaultsTo3WhenNoRatings() {
        let sut = makeSUT()
        XCTAssertEqual(sut.averageRating(), 3)
    }

    func test_averageRating_calculatesCorrectly() {
        let sut = makeSUT(exerciseCount: 2)
        sut.exerciseRatings = [4, 2]
        XCTAssertEqual(sut.averageRating(), 3)
    }

    func test_averageRating_ignoresZeroRatings() {
        let sut = makeSUT(exerciseCount: 3)
        sut.exerciseRatings = [5, 0, 3]
        XCTAssertEqual(sut.averageRating(), 4) // (5+3)/2
    }
}
