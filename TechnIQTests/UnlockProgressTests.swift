import XCTest
import CoreData
@testable import TechnIQ

final class UnlockProgressTests: XCTestCase {
    private typealias Completion = UnlockProgress.Completion
    private typealias Result = UnlockProgress.BenchmarkResult

    func test_completions_skipTooHardAndCountNoFeel() {
        let progress = UnlockProgress.compute(
            criteria: .default,
            completions: [Completion(reps: 0, feel: .right), Completion(reps: 0, feel: .tooHard),
                          Completion(reps: 0, feel: nil)],
            benchmarks: [])
        XCTAssertEqual(progress, UnlockProgress(done: 2, needed: 3))
        XCTAssertEqual(progress.countLabel, "2 of 3")
        XCTAssertFalse(progress.isUnlocked)
        XCTAssertEqual(progress.fraction, 2.0 / 3.0, accuracy: 0.0001)
    }

    func test_reps_needTheTargetInOneCompletion() {
        let criteria = UnlockCriteria(kind: .reps, target: 50, times: 2, benchmark: nil)
        let progress = UnlockProgress.compute(
            criteria: criteria,
            completions: [Completion(reps: 60, feel: .right), Completion(reps: 40, feel: .tooEasy),
                          Completion(reps: 80, feel: .tooHard), Completion(reps: 50, feel: nil)],
            benchmarks: [])
        XCTAssertEqual(progress.done, 2)
        XCTAssertTrue(progress.isUnlocked)
    }

    func test_benchmark_countsResultsOfThatTypeAtOrAboveTarget() {
        let criteria = UnlockCriteria(kind: .benchmark, target: 20, times: 3, benchmark: .juggling)
        let progress = UnlockProgress.compute(
            criteria: criteria,
            completions: [Completion(reps: 0, feel: .right)],
            benchmarks: [Result(type: .juggling, value: 20), Result(type: .juggling, value: 19),
                         Result(type: .juggling, value: 34), Result(type: .toeTaps30, value: 60)])
        XCTAssertEqual(progress.countLabel, "2 of 3")
    }

    func test_unlocked_clampsTheLabelAndFraction() {
        let progress = UnlockProgress.compute(
            criteria: UnlockCriteria(kind: .completions, target: 0, times: 1, benchmark: nil),
            completions: Array(repeating: Completion(reps: 0, feel: .right), count: 4),
            benchmarks: [])
        XCTAssertTrue(progress.isUnlocked)
        XCTAssertEqual(progress.countLabel, "1 of 1")
        XCTAssertEqual(progress.fraction, 1)
    }

    func test_exerciseProgress_readsSessionsFeelAndBenchmarks() {
        let stack = TestCoreDataStack()
        let player = stack.makePlayer()
        let exercise = stack.makeExercise(player: player, name: "Juggling")
        exercise.unlockCriteriaJSON = UnlockCriteria(kind: .benchmark, target: 20, times: 2, benchmark: .juggling).encoded()
        for value in [25, 12, 21] {
            let benchmark = Benchmark(context: stack.context)
            benchmark.id = UUID()
            benchmark.type = BenchmarkType.juggling.rawValue
            benchmark.value = Int32(value)
            benchmark.date = Date()
            benchmark.player = player
        }
        XCTAssertTrue(exercise.unlockProgress.isUnlocked)

        let plain = stack.makeExercise(player: player, name: "Ball Control")
        for feel in [SessionFeel.right, .tooHard] {
            let session = TrainingSession(context: stack.context)
            session.id = UUID()
            session.player = player
            session.date = Date()
            session.feel = feel.rawValue
            let use = SessionExercise(context: stack.context)
            use.id = UUID()
            use.session = session
            use.exercise = plain
        }
        XCTAssertEqual(plain.unlockProgress, UnlockProgress(done: 1, needed: 3), "default criteria, too-hard run skipped")
    }
}
