import XCTest
import CoreData
import FirebaseFirestore
@testable import TechnIQ

/// Round-trip coverage for the sync fields added in the sync-architecture pass: a TrainingSession
/// keeps its xpEarned and its performed-exercise link, and a custom Exercise keeps the drill-schema
/// fields. All in-memory Core Data, no network — entity -> document dict -> restored entity.
@MainActor
final class CloudSyncRoundTripTests: XCTestCase {
    var stack: TestCoreDataStack!
    var sut: CloudService!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = CloudService.shared
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - TrainingSession round-trip (xpEarned + exercise link)

    func test_trainingSession_roundTrip_preservesXpAndExerciseLink() throws {
        let player = stack.makePlayer()
        let exercise = stack.makeExercise(player: player, name: "Cone Weave")

        let session = TrainingSession(context: stack.context)
        session.id = UUID()
        session.player = player
        session.date = Date(timeIntervalSince1970: 1_700_000_000)
        session.duration = 45
        session.intensity = 4
        session.overallRating = 5
        session.xpEarned = 120
        session.notes = "Great session"

        let se = SessionExercise(context: stack.context)
        se.id = UUID()
        se.session = session
        se.exercise = exercise
        se.sets = 3
        se.reps = 10
        se.performanceRating = 4
        try stack.context.save()

        let doc = try sut.createTrainingSessionDocument(session: session)

        // Restore into a fresh store. The exercise must exist first so the link is rewired by id.
        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        let restoredExercise = Exercise(context: restoredContext)
        restoredExercise.id = exercise.id
        restoredExercise.name = "Cone Weave"
        restoredExercise.player = restoredPlayer
        restoredPlayer.addToExercises(restoredExercise)

        try sut.restoreTrainingSession(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.sessions?.allObjects as? [TrainingSession])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, session.id)
        XCTAssertEqual(restored?.xpEarned, 120, "xpEarned must survive the round trip")
        XCTAssertEqual(restored?.intensity, 4)
        XCTAssertEqual(restored?.overallRating, 5)
        XCTAssertEqual(restored?.notes, "Great session")

        let restoredSE = (restored?.exercises?.allObjects as? [SessionExercise])?.first
        XCTAssertNotNil(restoredSE, "Session exercise must be restored")
        XCTAssertEqual(restoredSE?.exercise?.id, exercise.id, "Exercise link must be rewired by id")
        XCTAssertEqual(restoredSE?.exercise?.name, "Cone Weave")
        XCTAssertEqual(restoredSE?.sets, 3)
        XCTAssertEqual(restoredSE?.reps, 10)
        XCTAssertEqual(restoredSE?.performanceRating, 4)
    }

    // MARK: - Custom Exercise round-trip (drill-schema fields)

    func test_customExercise_roundTrip_preservesDrillSchemaFields() throws {
        let player = stack.makePlayer()
        let exercise = stack.makeExercise(player: player, name: "Rondo Press")
        exercise.difficulty = 3
        exercise.estimatedDurationSeconds = 900
        exercise.variationsJSON = "[{\"name\":\"tight space\"}]"
        exercise.weaknessCategories = "passing:under-pressure,vision:scanning"
        exercise.communityAuthor = "Coach Rivera"
        exercise.communityDrillID = "drill-abc-123"
        exercise.diagramJSON = "{\"elements\":[]}"
        exercise.metabolicLoad = 6
        exercise.technicalComplexity = 8
        try stack.context.save()

        let doc = sut.createCustomExerciseDocument(exercise: exercise)

        let restoredContext = TestCoreDataStack().context
        let restoredPlayer = Player(context: restoredContext)
        restoredPlayer.id = UUID()
        try sut.restoreCustomExercise(from: doc, for: restoredPlayer, in: restoredContext)

        let restored = (restoredPlayer.exercises?.allObjects as? [Exercise])?.first
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored?.id, exercise.id)
        XCTAssertEqual(restored?.name, "Rondo Press")
        XCTAssertEqual(restored?.difficulty, 3)
        XCTAssertEqual(restored?.estimatedDurationSeconds, 900)
        XCTAssertEqual(restored?.variationsJSON, "[{\"name\":\"tight space\"}]")
        XCTAssertEqual(restored?.weaknessCategories, "passing:under-pressure,vision:scanning")
        XCTAssertEqual(restored?.communityAuthor, "Coach Rivera")
        XCTAssertEqual(restored?.communityDrillID, "drill-abc-123")
        XCTAssertEqual(restored?.diagramJSON, "{\"elements\":[]}")
        XCTAssertEqual(restored?.metabolicLoad, 6)
        XCTAssertEqual(restored?.technicalComplexity, 8)
    }

    // MARK: - Cross-account restore filter

    func test_docBelongs_filtersChildDocsByPlayerId() {
        let playerId = UUID().uuidString
        XCTAssertTrue(sut.docBelongs(["playerId": playerId], to: playerId))
        XCTAssertFalse(sut.docBelongs(["playerId": UUID().uuidString], to: playerId),
                       "A doc stamped with another player's id must not restore into this player")
        XCTAssertTrue(sut.docBelongs([:], to: playerId),
                      "Legacy docs written before playerId stamping are treated as belonging")
        XCTAssertTrue(sut.docBelongs(["playerId": ""], to: playerId),
                      "Empty playerId is treated as legacy/belonging")
    }
}
