import XCTest
import CoreData
@testable import TechnIQ

/// The figures a player sees must agree with each other: drill provenance, the free AI drill budget,
/// live plan progress, shared-drill steps, and the rating card's difficulty labels.
final class TrustTheNumbersTests: XCTestCase {
    var stack: TestCoreDataStack!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        stack = nil
        super.tearDown()
    }

    // MARK: - Drill provenance

    func test_drillSource_storedValueWins() {
        let player = stack.makePlayer()
        let exercise = stack.makeExercise(player: player, name: "Any")
        exercise.exerciseDescription = "[AI-Generated Custom Drill]\n\nLooks like AI"
        exercise.source = TrainDrill.Source.community.rawValue
        XCTAssertEqual(exercise.drillSource, .community)
        XCTAssertEqual(exercise.trainDrill.source, .community)
        XCTAssertTrue(exercise.trainDrill.isMine)
    }

    func test_drillSource_legacyRowsFallBackToDescriptionMarkers() {
        let player = stack.makePlayer()

        let template = stack.makeExercise(player: player, name: "Passing Accuracy")
        template.exerciseDescription = "Short passing against a wall"
        XCTAssertEqual(template.drillSource, .template)

        let ai = stack.makeExercise(player: player, name: "AI")
        ai.exerciseDescription = "[AI-Generated Custom Drill]\n\nWeak-foot finishing"
        XCTAssertEqual(ai.drillSource, .ai)

        let structuredManual = stack.makeExercise(player: player, name: "Mine")
        structuredManual.exerciseDescription = "Manual Drill"
        XCTAssertEqual(structuredManual.drillSource, .manual, "the structured creator's old stamp")

        let saved = stack.makeExercise(player: player, name: "Saved")
        saved.exerciseDescription = "[AI-Generated Custom Drill]\nFrom the community"
        saved.communityDrillID = "abc"
        XCTAssertEqual(saved.drillSource, .community, "a community id beats the prefix the old save path added")

        let video = stack.makeExercise(player: player, name: "Clip")
        video.exerciseDescription = "YouTube Video: https://youtube.com/watch?v=x"
        XCTAssertEqual(video.drillSource, .video)
    }

    func test_drillSource_manualDrillsCountAsMineInTrain() {
        let player = stack.makePlayer()
        let manual = stack.makeExercise(player: player, name: "My rondo")
        manual.source = TrainDrill.Source.manual.rawValue
        manual.exerciseDescription = "Whatever the player typed"
        let layout = TrainLibraryModel.build(drills: [manual.trainDrill, stack.makeExercise(player: player).trainDrill], pinned: [], weakSpots: [])
        XCTAssertEqual(layout.sections.first?.kind, .mine)
        XCTAssertEqual(layout.sections.first?.drills.map(\.name), ["My rondo"])
    }

    // MARK: - Free AI drills

    private func freshDefaults() -> UserDefaults {
        let suite = "TrustTheNumbersTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func test_freeDrillAllowance_threeForLifeThenPro() {
        let allowance = FreeDrillAllowance(userUID: "u1", defaults: freshDefaults())
        XCTAssertEqual(allowance.remaining, 3)
        XCTAssertTrue(allowance.canGenerate(isPro: false))
        allowance.recordGeneration(isPro: false)
        allowance.recordGeneration(isPro: false)
        XCTAssertEqual(allowance.remaining, 1)
        XCTAssertEqual(allowance.label, "1 free drill left")
        allowance.recordGeneration(isPro: false)
        XCTAssertEqual(allowance.remaining, 0)
        XCTAssertEqual(allowance.label, "No free drills left")
        XCTAssertFalse(allowance.canGenerate(isPro: false))
        XCTAssertTrue(allowance.canGenerate(isPro: true), "Pro never runs out")
    }

    func test_freeDrillAllowance_proGenerationsAreNotCounted_andBudgetIsPerUser() {
        let defaults = freshDefaults()
        let pro = FreeDrillAllowance(userUID: "u1", defaults: defaults)
        pro.recordGeneration(isPro: true)
        XCTAssertEqual(pro.remaining, 3, "a later downgrade still leaves the three free drills")
        XCTAssertEqual(pro.label, "3 free drills left")

        pro.recordGeneration(isPro: false)
        XCTAssertEqual(FreeDrillAllowance(userUID: "u2", defaults: defaults).remaining, 3, "another account on the phone has its own budget")
        XCTAssertEqual(FreeDrillAllowance(userUID: "u1", defaults: defaults).remaining, 2)
    }

    // MARK: - Plan progress

    func test_planProgress_countsSessionsAndSkipsRestAndSkippedDays() {
        let player = stack.makePlayer()
        let plan = stack.makeTrainingPlan(player: player, isActive: true, durationWeeks: 1)
        let week = stack.makePlanWeek(plan: plan)
        let day1 = stack.makePlanDay(week: week, dayNumber: 1)
        let day2 = stack.makePlanDay(week: week, dayNumber: 2)
        let rest = stack.makePlanDay(week: week, dayNumber: 3, isRestDay: true)
        let skipped = stack.makePlanDay(week: week, dayNumber: 4)
        skipped.isSkipped = true
        let s1 = stack.makePlanSession(day: day1)
        let s2 = stack.makePlanSession(day: day2)
        stack.makePlanSession(day: rest)
        stack.makePlanSession(day: skipped)

        XCTAssertEqual(TrainingPlanService.progressPercentage(of: plan), 0)
        s1.isCompleted = true
        XCTAssertEqual(TrainingPlanService.progressPercentage(of: plan), 50, "half way after one of two real sessions, before the week closes")
        s2.isCompleted = true
        XCTAssertEqual(TrainingPlanService.progressPercentage(of: plan), 100)
    }

    func test_planProgress_emptyPlanIsZero() {
        let player = stack.makePlayer()
        let plan = stack.makeTrainingPlan(player: player)
        XCTAssertEqual(TrainingPlanService.progressPercentage(of: plan), 0)
    }

    // MARK: - Sharing and rating

    func test_shareableSteps_parsesDrillStepsOrFallsBackToLines() {
        let formatted = "**Setup:** two cones\n**Steps:**\n1. Pass\n2. Move\n**Coaching Points:**\n- Head up"
        XCTAssertEqual(CommunityService.shareableSteps(from: formatted), ["Pass", "Move"])
        XCTAssertEqual(CommunityService.shareableSteps(from: "Dribble out\n\nTurn back  "), ["Dribble out", "Turn back"])
        XCTAssertEqual(CommunityService.shareableSteps(from: nil), [])
    }

    func test_difficultyFeedbackLabel_roundTripsTheThreeChips() {
        XCTAssertEqual(CoreDataManager.difficultyFeedbackLabel(for: 1), "easy")
        XCTAssertEqual(CoreDataManager.difficultyFeedbackLabel(for: 3), "right")
        XCTAssertEqual(CoreDataManager.difficultyFeedbackLabel(for: 5), "hard")
    }
}
