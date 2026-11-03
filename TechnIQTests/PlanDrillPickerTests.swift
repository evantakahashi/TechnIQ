import XCTest
import CoreData
@testable import TechnIQ

final class PlanDrillPickerTests: XCTestCase {
    /// The ten catalog drills as candidates, plus optional own drills.
    private func candidates(own: [PlanDrillCandidate] = []) -> [PlanDrillCandidate] {
        PrebuiltDrillCatalog.all.map {
            PlanDrillCandidate(id: UUID(), name: $0.name, prebuiltKey: $0.key, targetSkills: $0.targetSkills)
        } + own
    }

    private func keys(_ ids: [UUID], in pool: [PlanDrillCandidate]) -> [String] {
        ids.compactMap { id in pool.first { $0.id == id }.map { $0.prebuiltKey ?? $0.name } }
    }

    func test_assessmentAndMatchSessions_getNoDrills() {
        let pool = candidates()
        XCTAssertEqual(PlanDrillPicker.pick(suggestedNames: ["Juggling"], sessionType: .assessment, candidates: pool, rotation: 0), [])
        XCTAssertEqual(PlanDrillPicker.pick(suggestedNames: [], sessionType: .match, candidates: pool, rotation: 0), [])
    }

    func test_fill_givesTwoDrillsThatSuitTheSessionType() {
        let pool = candidates()
        for type in [SessionType.technical, .physical, .tactical, .recovery, .warmup, .cooldown] {
            let picked = keys(PlanDrillPicker.pick(suggestedNames: [], sessionType: type, candidates: pool, rotation: 0), in: pool)
            XCTAssertEqual(picked.count, 2, "\(type)")
            XCTAssertEqual(Set(picked).count, 2, "\(type): no duplicates")
            XCTAssertTrue(Set(picked).isSubset(of: PlanDrillPicker.preferredKeys(for: type)), "\(type): \(picked)")
        }
    }

    func test_rotation_avoidsRepeatingThePairDayAfterDay() {
        let pool = candidates()
        for type in [SessionType.technical, .physical, .recovery] {
            var previous: Set<String> = []
            for rotation in 0..<6 {
                let pair = Set(keys(PlanDrillPicker.pick(suggestedNames: [], sessionType: type, candidates: pool, rotation: rotation), in: pool))
                XCTAssertNotEqual(pair, previous, "\(type) rotation \(rotation) repeats the previous pair")
                previous = pair
            }
        }
    }

    func test_suggestedNames_matchByNameThenSkill() {
        let pool = candidates()
        let byName = keys(PlanDrillPicker.pick(suggestedNames: ["Cone dribbling", "Juggling"], sessionType: .technical,
                                               candidates: pool, rotation: 0), in: pool)
        XCTAssertEqual(byName, ["dribbling_cones", "juggling"])

        let bySkill = keys(PlanDrillPicker.pick(suggestedNames: ["Wall passing"], sessionType: .technical,
                                                candidates: pool, rotation: 0), in: pool)
        XCTAssertEqual(bySkill.first, "passing_accuracy")
        XCTAssertEqual(bySkill.count, 2, "topped up to two")

        let sprint = keys(PlanDrillPicker.pick(suggestedNames: ["Sprint intervals"], sessionType: .physical,
                                               candidates: pool, rotation: 0), in: pool)
        XCTAssertEqual(sprint.first, "sprint_training")
    }

    func test_unknownSuggestion_fallsBackToTheSessionType() {
        let pool = candidates()
        let picked = keys(PlanDrillPicker.pick(suggestedNames: ["Rondo 4v2 with transitions"], sessionType: .physical,
                                               candidates: pool, rotation: 0), in: pool)
        XCTAssertEqual(picked.count, 2)
        XCTAssertTrue(Set(picked).isSubset(of: PlanDrillPicker.preferredKeys(for: .physical)))
    }

    func test_ownDrills_matchByNameButNeverFillByType() {
        let mine = PlanDrillCandidate(id: UUID(), name: "Weak-foot finishing", prebuiltKey: nil, targetSkills: ["Weak Foot"])
        let pool = candidates(own: [mine])
        let matched = PlanDrillPicker.pick(suggestedNames: ["Weak foot finishing"], sessionType: .technical, candidates: pool, rotation: 0)
        XCTAssertEqual(matched.first, mine.id)
        for rotation in 0..<5 {
            let filled = PlanDrillPicker.pick(suggestedNames: [], sessionType: .technical, candidates: pool, rotation: rotation)
            XCTAssertFalse(filled.contains(mine.id))
        }
    }

    func test_missingPreferredDrills_fallBackToAnyCatalogDrill() {
        let pool = candidates().filter { !PlanDrillPicker.preferredKeys(for: .tactical).contains($0.prebuiltKey ?? "") }
        let picked = PlanDrillPicker.pick(suggestedNames: [], sessionType: .tactical, candidates: pool, rotation: 0)
        XCTAssertEqual(picked.count, 2)
        XCTAssertEqual(PlanDrillPicker.pick(suggestedNames: [], sessionType: .technical, candidates: [], rotation: 0), [])
    }

    // MARK: TrainingPlanService wiring

    func test_planCandidates_skipOldTemplateLibraryRows() {
        let stack = TestCoreDataStack()
        let player = stack.makePlayer()
        let imported = stack.makeExercise(player: player, name: "Rondo Circle")
        imported.source = TrainDrill.Source.template.rawValue
        let mine = stack.makeExercise(player: player, name: "Weak-foot finishing")
        mine.source = TrainDrill.Source.ai.rawValue
        PrebuiltDrillSeeder.sync(player: player, context: stack.context, createMissing: true)

        let all = (player.exercises as? Set<Exercise>) ?? []
        let eligible = all.filter { $0.prebuiltKey != nil || TrainingPlanService.isOwnPlanDrill($0) }
        XCTAssertEqual(eligible.count, 11)
        XCTAssertFalse(eligible.contains(imported))
        XCTAssertTrue(eligible.contains(mine))
    }
}
