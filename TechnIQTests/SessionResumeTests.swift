import XCTest
import CoreData
@testable import TechnIQ

/// Resume an interrupted session: the snapshot round-trips through UserDefaults, goes stale after
/// 12 hours, and rebuilds a paused manager with its counters intact.
@MainActor
final class SessionResumeTests: XCTestCase {
    var stack: TestCoreDataStack!
    var defaults: UserDefaults!
    private let suite = "SessionResumeTests"

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
        stack = nil
        super.tearDown()
    }

    private func makeManager(count: Int) -> ActiveSessionManager {
        let player = stack.makePlayer()
        let exercises = (0..<count).map { index -> Exercise in
            let exercise = stack.makeExercise(player: player, name: "Ex \(index)")
            exercise.estimatedDurationSeconds = 60
            return exercise
        }
        try? stack.context.save()
        return ActiveSessionManager(exercises: exercises)
    }

    private func snapshot(ids: [String], savedAt: Date = Date(), index: Int = 1) -> SessionSnapshot {
        SessionSnapshot(
            exerciseIDs: ids, planSessionID: nil, currentExerciseIndex: index,
            exerciseRatings: [4, 0, 0], exerciseNotes: ["good", "", ""], reps: [10, 3, 0],
            exerciseDurations: [70, 0, 0], elapsedSeconds: 25, savedAt: savedAt
        )
    }

    func test_snapshot_roundTripsAndReportsTotalSeconds() {
        let original = snapshot(ids: [UUID().uuidString, UUID().uuidString, UUID().uuidString])
        original.save(to: defaults)
        let loaded = SessionSnapshot.load(from: defaults)
        XCTAssertEqual(loaded?.exerciseIDs, original.exerciseIDs)
        XCTAssertEqual(loaded?.currentExerciseIndex, 1)
        XCTAssertEqual(loaded?.reps, [10, 3, 0])
        XCTAssertEqual(loaded?.totalSeconds, 95, "finished drills plus the current one")
        SessionSnapshot.clear(from: defaults)
        XCTAssertNil(SessionSnapshot.load(from: defaults))
    }

    func test_staleSnapshot_isDroppedOnLoad() {
        snapshot(ids: [UUID().uuidString], savedAt: Date().addingTimeInterval(-SessionSnapshot.maxAge - 60)).save(to: defaults)
        XCTAssertNil(SessionSnapshot.load(from: defaults))
        XCTAssertNil(defaults.data(forKey: SessionSnapshot.key), "stale data is removed")
    }

    func test_managerPersistsWhileRunning_andNotAfterFinishing() {
        let sut = makeManager(count: 2)
        sut.persistSnapshot(to: defaults)
        let saved = SessionSnapshot.load(from: defaults)
        XCTAssertEqual(saved?.exerciseIDs.count, 2)
        XCTAssertEqual(saved?.currentExerciseIndex, 0)

        sut.phase = .sessionComplete
        sut.clearSnapshot(from: defaults)
        sut.persistSnapshot(to: defaults)
        XCTAssertNil(SessionSnapshot.load(from: defaults), "a finished session leaves nothing to resume")
    }

    func test_restore_rebuildsAPausedManagerFromTheStore() {
        let source = makeManager(count: 3)
        let ids = source.exercises.map { $0.id!.uuidString }
        let restored = ActiveSessionManager.restore(snapshot(ids: ids), in: stack.context)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.exercises.map { $0.id }, source.exercises.map { $0.id })
        XCTAssertEqual(restored?.currentExerciseIndex, 1)
        XCTAssertEqual(restored?.exerciseRatings, [4, 0, 0])
        XCTAssertEqual(restored?.exerciseNotes, ["good", "", ""])
        XCTAssertEqual(restored?.reps, [10, 3, 0])
        XCTAssertEqual(restored?.exerciseDurations, [70, 0, 0])
        XCTAssertEqual(restored?.elapsedSeconds, 25)
        XCTAssertEqual(restored?.isRunning, false, "clock waits for Resume")
        XCTAssertEqual(restored?.phase, .exercise)
    }

    func test_restore_failsWhenADrillIsGone() {
        let source = makeManager(count: 2)
        var ids = source.exercises.map { $0.id!.uuidString }
        ids.append(UUID().uuidString)
        XCTAssertNil(ActiveSessionManager.restore(snapshot(ids: ids), in: stack.context))
        XCTAssertNil(ActiveSessionManager.restore(snapshot(ids: ["not-a-uuid"]), in: stack.context))
    }

    func test_apply_clampsTheIndexAndPadsCounters() {
        let sut = makeManager(count: 2)
        sut.apply(snapshot(ids: [], index: 9))
        XCTAssertEqual(sut.currentExerciseIndex, 1)
        XCTAssertEqual(sut.exerciseRatings, [4, 0])
        XCTAssertEqual(sut.reps, [10, 3])
        XCTAssertEqual(sut.exerciseDurations, [70, 0])

        let wide = makeManager(count: 4)
        wide.apply(snapshot(ids: [], index: -1))
        XCTAssertEqual(wide.currentExerciseIndex, 0)
        XCTAssertEqual(wide.exerciseRatings, [4, 0, 0, 0])
        XCTAssertEqual(wide.exerciseNotes, ["good", "", "", ""])
    }
}
