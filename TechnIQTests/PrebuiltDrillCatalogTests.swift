import XCTest
import CoreData
@testable import TechnIQ

/// The ten pre-built drills: content completeness, compiled diagram + film, seeding and upgrade.
final class PrebuiltDrillCatalogTests: XCTestCase {
    private var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        stack = nil
        super.tearDown()
    }

    private let legacyNames = ["Ball Control", "Juggling", "Dribbling Cones", "Shooting Practice", "Passing Accuracy",
                               "Sprint Training", "Agility Ladder", "Endurance Run", "1v1 Practice", "Small-Sided Games"]

    // MARK: Content

    func test_catalog_hasTheTenDrillsUnderTheirShippedNames() {
        let all = PrebuiltDrillCatalog.all
        XCTAssertEqual(all.count, 10)
        XCTAssertEqual(Set(all.map(\.key)).count, 10, "keys are unique")
        XCTAssertEqual(Set(all.map(\.name)), Set(legacyNames), "names match the rows seeded before 1.1")
    }

    func test_everyDrill_hasConcreteContent() {
        for drill in PrebuiltDrillCatalog.all {
            XCTAssertTrue((3...6).contains(drill.steps.count), "\(drill.key): 3–6 steps")
            XCTAssertFalse(drill.steps.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty }, "\(drill.key): no empty step")
            XCTAssertFalse(drill.coachingPoint.trimmingCharacters(in: .whitespaces).isEmpty, "\(drill.key): coaching point")
            XCTAssertFalse(drill.cue.trimmingCharacters(in: .whitespaces).isEmpty, "\(drill.key): cue")
            XCTAssertLessThanOrEqual(drill.cue.split(separator: " ").count, 10, "\(drill.key): cue is short")
            XCTAssertFalse(drill.equipment.isEmpty, "\(drill.key): equipment")
            XCTAssertFalse(drill.equipment.contains { $0.contains(",") }, "\(drill.key): items are stored comma-joined")
            XCTAssertFalse(drill.space.trimmingCharacters(in: .whitespaces).isEmpty, "\(drill.key): space")
            XCTAssertFalse(drill.dsl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(drill.key): DSL")
            XCTAssertGreaterThan(drill.durationMinutes, 0, "\(drill.key): duration")
            if drill.videoClip != nil {
                XCTAssertNotNil(drill.videoURL, "\(drill.key): a named clip must be in the bundle")
            }
        }
    }

    func test_noPlaceholderTextAnywhere() {
        for drill in PrebuiltDrillCatalog.all {
            let text = ([drill.name, drill.summary, drill.coachingPoint, drill.cue, drill.space, drill.instructionsText]
                        + drill.steps + drill.equipment).joined(separator: "\n").lowercased()
            XCTAssertFalse(text.contains("follow standard"), "\(drill.key): placeholder text")
            XCTAssertFalse(text.contains("protocol"), "\(drill.key): placeholder text")
        }
    }

    func test_everyDrill_hasACompiledDiagramAndFilm() throws {
        for drill in PrebuiltDrillCatalog.all {
            let diagram = try XCTUnwrap(drill.diagram, "\(drill.key): diagramJSON decodes as DrillDiagram")
            XCTAssertFalse(diagram.elements.isEmpty, "\(drill.key): diagram has elements")
            XCTAssertFalse((diagram.paths ?? []).isEmpty, "\(drill.key): diagram has steps")
            XCTAssertTrue(diagram.elements.contains { $0.elementType == .player }, "\(drill.key): a player")

            let data = try XCTUnwrap(drill.animationJSON.data(using: .utf8))
            let film = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any], "\(drill.key): film is an object")
            let phases = try XCTUnwrap(film["phases"] as? [[String: Any]], "\(drill.key): film has phases")
            XCTAssertGreaterThanOrEqual(phases.count, 1, "\(drill.key): at least one phase")
            XCTAssertNotNil(DrillWebAnimationView.composedJSON(diagramJSON: drill.diagramJSON, animationJSON: drill.animationJSON))
            XCTAssertTrue(TQSessionDiagram.hasContent(diagramJSON: drill.diagramJSON, animationJSON: drill.animationJSON),
                          "\(drill.key): the session screen renders it")
        }
    }

    func test_instructionsText_parsesBackToStepsAndOneCoachingPoint() {
        for drill in PrebuiltDrillCatalog.all {
            let content = DrillContent.parse(drill.instructionsText)
            XCTAssertEqual(content.steps, drill.steps, drill.key)
            XCTAssertEqual(content.coachingPoints, [drill.coachingPoint], drill.key)
        }
    }

    func test_lookup_byKeyAndName() {
        XCTAssertEqual(PrebuiltDrillCatalog.drill(forKey: "juggling")?.name, "Juggling")
        XCTAssertEqual(PrebuiltDrillCatalog.drill(named: "  small-sided games ")?.key, "small_sided_games")
        XCTAssertNil(PrebuiltDrillCatalog.drill(forKey: nil))
        XCTAssertNil(PrebuiltDrillCatalog.drill(named: "Rondo"))
    }

    // MARK: Seeding

    private func rows(_ player: Player) -> [Exercise] {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        return (try? stack.context.fetch(request)) ?? []
    }

    func test_seed_createsAllTenRowsWithEveryField() throws {
        let player = stack.makePlayer()
        let result = PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        XCTAssertTrue(result.changed)
        XCTAssertEqual(result.rows.count, 10)
        XCTAssertEqual(rows(player).count, 10)

        for exercise in rows(player) {
            let key = try XCTUnwrap(exercise.prebuiltKey)
            let drill = try XCTUnwrap(PrebuiltDrillCatalog.drill(forKey: key))
            XCTAssertNotNil(exercise.id)
            XCTAssertEqual(exercise.drillSource, .template)
            XCTAssertEqual(exercise.name, drill.name)
            XCTAssertEqual(exercise.cue, drill.cue)
            XCTAssertEqual(exercise.coachCue, drill.cue)
            XCTAssertEqual(exercise.equipmentList, drill.equipment)
            XCTAssertEqual(exercise.space, drill.space)
            XCTAssertEqual(exercise.dsl, drill.dsl)
            XCTAssertEqual(exercise.diagramJSON, drill.diagramJSON)
            XCTAssertEqual(exercise.animationJSON, drill.animationJSON)
            XCTAssertEqual(exercise.unlockCriteria, drill.unlockCriteria)
            XCTAssertEqual(Int(exercise.estimatedDurationSeconds), drill.durationMinutes * 60)
            XCTAssertEqual(DrillContent.parse(exercise.instructions).steps, drill.steps)
            XCTAssertFalse((exercise.instructions ?? "").contains("Follow standard"))
        }
    }

    func test_seed_isIdempotent() {
        let player = stack.makePlayer()
        PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        try? stack.context.save()
        let again = PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        XCTAssertFalse(again.changed, "a second run changes nothing")
        XCTAssertEqual(rows(player).count, 10)
    }

    func test_seed_fillsMissingDrillsForPlayersWithOtherExercises() {
        let player = stack.makePlayer()
        let mine = stack.makeExercise(player: player, name: "My rondo")
        mine.source = TrainDrill.Source.manual.rawValue
        PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        XCTAssertEqual(rows(player).count, 11)
        XCTAssertNil(mine.prebuiltKey, "the player's own drill is untouched")
    }

    func test_upgrade_adoptsLegacyRowsInPlace() throws {
        let player = stack.makePlayer()
        let legacy = stack.makeExercise(player: player, name: "Juggling")
        legacy.source = TrainDrill.Source.template.rawValue
        legacy.instructions = "Follow standard juggling protocol"
        legacy.isFavorite = true
        legacy.personalNotes = "best 14"
        let lastUsed = Date(timeIntervalSince1970: 1_700_000_000)
        legacy.lastUsedAt = lastUsed
        let id = legacy.id

        // Pre-1.0 row: no source, just the placeholder.
        let unsourced = stack.makeExercise(player: player, name: "Endurance Run")
        unsourced.instructions = "Follow standard endurance run protocol"

        let result = PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: false)
        XCTAssertTrue(result.changed)
        XCTAssertEqual(legacy.prebuiltKey, "juggling")
        XCTAssertEqual(legacy.id, id)
        XCTAssertTrue(legacy.isFavorite)
        XCTAssertEqual(legacy.personalNotes, "best 14")
        XCTAssertEqual(legacy.lastUsedAt, lastUsed)
        XCTAssertEqual(legacy.cue, PrebuiltDrillCatalog.drill(forKey: "juggling")?.cue)
        XCTAssertFalse((legacy.instructions ?? "").contains("Follow standard"))
        XCTAssertEqual(unsourced.prebuiltKey, "endurance_run")
        XCTAssertEqual(rows(player).count, 2, "createMissing: false adds nothing")

        PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        XCTAssertEqual(rows(player).count, 10, "the upgraded rows count; no duplicates")
    }

    func test_upgrade_leavesThePlayersOwnSameNamedDrillAlone() {
        let player = stack.makePlayer()
        let own = stack.makeExercise(player: player, name: "Juggling")
        own.source = TrainDrill.Source.manual.rawValue
        own.instructions = "1. My way"
        PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)
        XCTAssertNil(own.prebuiltKey)
        XCTAssertEqual(own.instructions, "1. My way")
        XCTAssertEqual(rows(player).count, 11)
    }

    func test_refresh_updatesCompiledAssetsButKeepsEdits() {
        let player = stack.makePlayer()
        let row = PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true).rows["dribbling_cones"]
        row?.name = "My cone weave"
        row?.diagramJSON = "{}"
        row?.animationJSON = nil
        let result = PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: false)
        XCTAssertTrue(result.changed)
        XCTAssertEqual(row?.name, "My cone weave", "player edits stay")
        XCTAssertEqual(row?.diagramJSON, PrebuiltDrillCatalog.drill(forKey: "dribbling_cones")?.diagramJSON)
        XCTAssertNotNil(row?.animationJSON)
    }

    // MARK: Accessors

    func test_coachCue_prefersCueThenFirstCoachingPoint() {
        XCTAssertEqual(Exercise.coachCue(cue: "  Lock the ankle ", instructions: nil), "Lock the ankle")
        let block = "**Instructions:**\n1. Pass\n\n**Coaching Points:**\n• Open your hips\n• Second point"
        XCTAssertEqual(Exercise.coachCue(cue: nil, instructions: block), "Open your hips")
        XCTAssertEqual(Exercise.coachCue(cue: "   ", instructions: block), "Open your hips")
        XCTAssertNil(Exercise.coachCue(cue: nil, instructions: "1. Pass\n2. Receive"))
    }

    func test_equipmentList_roundTrips() {
        XCTAssertEqual(Exercise.equipmentList(from: "1 ball, 4 cones , ,A wall"), ["1 ball", "4 cones", "A wall"])
        XCTAssertEqual(Exercise.equipmentList(from: nil), [])
        XCTAssertEqual(Exercise.equipmentText(["1 ball", " 2 cones "]), "1 ball, 2 cones")
        XCTAssertNil(Exercise.equipmentText([]))
    }

    func test_unlockCriteria_defaultsWhenMissing() {
        let player = stack.makePlayer()
        let exercise = stack.makeExercise(player: player)
        XCTAssertEqual(exercise.unlockCriteria, .default)
        exercise.unlockCriteriaJSON = UnlockCriteria(kind: .benchmark, target: 20, times: 3, benchmark: .juggling).encoded()
        XCTAssertEqual(exercise.unlockCriteria.summary, "20 consecutive juggles, 3 times")
    }
}
