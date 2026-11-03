import XCTest
import CoreData
@testable import TechnIQ

// MARK: - Retest week (pure)

@MainActor
final class RetestWeekTests: XCTestCase {
    private func weeks(_ count: Int, days: [DayOfWeek] = [.monday, .wednesday, .saturday]) -> [PlanWeekModel] {
        TrainingPlanService.templateWeeks(count: count, trainingDays: days, sessionType: .technical, difficulty: .intermediate, focus: ["A"])
    }

    func test_retestWeek_followsThePlansPattern_assessmentFirstThenLightDays() throws {
        let drill = UUID()
        var source = weeks(2)
        // Give week 2's sessions a drill so the light days reuse it.
        source[1].days = source[1].days.map { day in
            var day = day
            day.sessions = day.sessions.map { session in
                PlanSessionModel(id: session.id, sessionType: session.sessionType, duration: session.duration, intensity: session.intensity,
                                 orderIndex: 0, notes: nil, isCompleted: false, completedAt: nil, actualDuration: nil,
                                 actualIntensity: nil, exerciseIDs: [drill])
            }
            return day
        }
        let all = RetestWeek.appending(to: source)
        XCTAssertEqual(all.count, 3)
        let retest = try XCTUnwrap(all.last)
        XCTAssertTrue(retest.isRetest)
        XCTAssertEqual(retest.weekNumber, 3)
        XCTAssertEqual(retest.focusArea, "Retest week")
        XCTAssertEqual(retest.days.count, 7)
        XCTAssertEqual(retest.days.filter { !$0.isRestDay }.compactMap(\.dayOfWeek), [.monday, .wednesday, .saturday], "rest days per the plan")

        let training = retest.days.filter { !$0.isRestDay }.sorted { $0.dayNumber < $1.dayNumber }
        let assessment = try XCTUnwrap(training.first?.sessions.first)
        XCTAssertEqual(training.first?.sessions.count, 1)
        XCTAssertEqual(assessment.sessionType, .assessment)
        XCTAssertEqual(assessment.duration, 10)
        XCTAssertEqual(assessment.intensity, 3)
        XCTAssertTrue(assessment.exerciseIDs.isEmpty, "the assessment has no drills")
        for day in training.dropFirst() {
            XCTAssertEqual(day.sessions.count, 1)
            XCTAssertEqual(day.sessions[0].sessionType, .technical)
            XCTAssertEqual(day.sessions[0].duration, 20)
            XCTAssertEqual(day.sessions[0].intensity, 2)
            XCTAssertEqual(day.sessions[0].exerciseIDs, [drill])
        }
        XCTAssertTrue(retest.days.filter(\.isRestDay).allSatisfy { $0.sessions.isEmpty })
    }

    func test_appending_isIdempotent() {
        let once = RetestWeek.appending(to: weeks(3))
        let twice = RetestWeek.appending(to: once)
        XCTAssertEqual(twice.count, 4)
        XCTAssertEqual(twice.map(\.id), once.map(\.id))
        XCTAssertTrue(RetestWeek.endsWithRetest(once))
        XCTAssertFalse(RetestWeek.endsWithRetest(weeks(3)))
    }

    func test_noPattern_usesDefaultDays_andAnAllRestPlanStillGetsTheAssessment() throws {
        let empty = RetestWeek.week(after: [])
        XCTAssertEqual(empty.weekNumber, 1)
        XCTAssertEqual(empty.days.filter { !$0.isRestDay }.compactMap(\.dayOfWeek), RetestWeek.defaultTrainingDays)

        let allRest = RetestWeek.week(after: weeks(1, days: []))
        let training = allRest.days.filter { !$0.isRestDay }
        XCTAssertEqual(training.count, 1)
        XCTAssertEqual(training.first?.sessions.first?.sessionType, .assessment)
    }

    func test_prebuiltTemplates_endWithARetestWeekCountedInTheirLength() {
        for template in TrainingPlanService.shared.availablePlans {
            XCTAssertTrue(template.weeks.last?.isRetest == true, template.name)
            XCTAssertEqual(template.weeks.filter(\.isRetest).count, 1, template.name)
            XCTAssertEqual(template.durationWeeks, template.weeks.count, template.name)
            let first = template.weeks.last?.days.first { !$0.isRestDay }
            XCTAssertEqual(first?.sessions.first?.sessionType, .assessment, template.name)
        }
    }

    func test_pickableSessionTypes_leaveOutTheAssessment() {
        XCTAssertFalse(SessionType.pickable.contains(.assessment))
        XCTAssertEqual(SessionType.pickable.count, SessionType.allCases.count - 1)
    }
}

// MARK: - Retest week on stored plans

/// Every creation path ends a plan with exactly one retest week. Runs against the app store with a
/// throwaway player, like PlanEditingTests (the plan service is bound to `CoreDataManager.shared.context`).
@MainActor
final class RetestWeekPlanTests: XCTestCase {
    private var context: NSManagedObjectContext { CoreDataManager.shared.context }
    private var player: Player!
    private let service = TrainingPlanService.shared

    override func setUp() async throws {
        try await super.setUp()
        player = Player(context: context)
        player.id = UUID()
        player.name = "Retest Test \(UUID().uuidString.prefix(6))"
        player.firebaseUID = "test-\(UUID().uuidString)"
        player.createdAt = Date()
        try context.save()
    }

    override func tearDown() async throws {
        for plan in service.fetchAllPlans(for: player) { service.deletePlan(plan) }
        for exercise in (player.exercises as? Set<Exercise>) ?? [] { context.delete(exercise) }
        context.delete(player)
        try? context.save()
        player = nil
        try await super.tearDown()
    }

    private func assertEndsWithOneRetest(_ plan: TrainingPlanModel, weeks: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(plan.weeks.count, weeks, file: file, line: line)
        XCTAssertEqual(plan.durationWeeks, weeks, "durationWeeks counts the retest week", file: file, line: line)
        XCTAssertEqual(plan.weeks.filter(\.isRetest).map(\.weekNumber), [weeks], file: file, line: line)
        let retest = plan.weeks.first { $0.isRetest }
        let sessions = retest?.days.sorted { $0.dayNumber < $1.dayNumber }.filter { !$0.isRestDay }.flatMap(\.sessions) ?? []
        XCTAssertEqual(sessions.first?.sessionType, .assessment, file: file, line: line)
        XCTAssertEqual(sessions.filter { $0.sessionType == .assessment }.count, 1, file: file, line: line)
    }

    func test_customPlan_endsWithARetestWeek() {
        let spec = TrainingPlanService.CustomPlanSpec(name: "Custom", description: "", weeks: 3, trainingDays: [.tuesday, .friday],
                                                       sessionType: .technical, minutes: 30, intensity: 3, difficulty: .beginner, category: .technical)
        let plan = service.createCustomPlan(spec, for: player)!.toModel()
        assertEndsWithOneRetest(plan, weeks: 4)
        let retest = plan.weeks.first { $0.isRetest }!
        XCTAssertEqual(retest.days.filter { !$0.isRestDay }.compactMap(\.dayOfWeek), [.tuesday, .friday])
    }

    func test_aiPlan_endsWithARetestWeek() {
        let day = { (n: Int, weekday: String, rest: Bool) in
            GeneratedDay(dayNumber: n, dayOfWeek: weekday, isRestDay: rest, notes: nil,
                         sessions: rest ? [] : [GeneratedSession(sessionType: "Technical", duration: 30, intensity: 3, notes: nil, suggestedExerciseNames: [])])
        }
        let week = { (n: Int) in
            GeneratedWeek(weekNumber: n, focusArea: "Focus \(n)", notes: nil, days: [
                day(1, "Monday", false), day(2, "Tuesday", true), day(3, "Wednesday", false), day(4, "Thursday", true),
                day(5, "Friday", false), day(6, "Saturday", true), day(7, "Sunday", true)
            ])
        }
        let generated = GeneratedPlanStructure(name: "AI", description: "", difficulty: "Beginner", category: "Technical",
                                               targetRole: nil, weeks: [week(1), week(2)])
        let plan = service.createPlanFromAIGeneration(generated, for: player)!.toModel()
        assertEndsWithOneRetest(plan, weeks: 3)
    }

    func test_prebuiltPlan_endsWithOneRetestWeek_notTwo() throws {
        let template = try XCTUnwrap(service.availablePlans.first)
        let plan = try XCTUnwrap(service.instantiatePrebuiltPlan(template, for: player)).toModel()
        assertEndsWithOneRetest(plan, weeks: template.weeks.count)
        let assessment = plan.weeks.last!.days.flatMap(\.sessions).first { $0.sessionType == .assessment }
        XCTAssertEqual(assessment?.exerciseIDs, [], "no drills on the assessment")
    }

    func test_appendRetestWeek_isIdempotent_andClonesKeepIt() throws {
        let spec = TrainingPlanService.CustomPlanSpec(name: "Twice", description: "", weeks: 1, trainingDays: [.monday],
                                                       sessionType: .technical, minutes: 20, intensity: 2, difficulty: .beginner, category: .technical)
        let stored = try XCTUnwrap(service.createCustomPlan(spec, for: player))
        service.appendRetestWeek(to: stored)
        try context.save()
        assertEndsWithOneRetest(stored.toModel(), weeks: 2)
        let clone = try XCTUnwrap(service.clonePlan(stored.toModel(), for: player)).toModel()
        assertEndsWithOneRetest(clone, weeks: 2)
    }

    func test_addAndRemoveWeek_keepTheRetestWeekLast() throws {
        let spec = TrainingPlanService.CustomPlanSpec(name: "Edit", description: "", weeks: 2, trainingDays: [.monday, .thursday],
                                                       sessionType: .technical, minutes: 30, intensity: 3, difficulty: .beginner, category: .technical)
        var plan = service.createCustomPlan(spec, for: player)!.toModel()
        XCTAssertTrue(service.appendWeek(planId: plan.id))
        plan = try XCTUnwrap(service.fetchPlan(byId: plan.id))
        assertEndsWithOneRetest(plan, weeks: 4)
        let added = try XCTUnwrap(plan.weeks.first { $0.weekNumber == 3 })
        XCTAssertFalse(added.isRetest)
        XCTAssertTrue(added.days.flatMap(\.sessions).allSatisfy { $0.sessionType == .technical && $0.duration == 30 },
                      "the new week mirrors the last training week, not the retest")

        XCTAssertTrue(service.removeLastWeek(planId: plan.id))
        XCTAssertTrue(service.removeLastWeek(planId: plan.id))
        plan = try XCTUnwrap(service.fetchPlan(byId: plan.id))
        assertEndsWithOneRetest(plan, weeks: 2)
        XCTAssertFalse(service.removeLastWeek(planId: plan.id), "the only training week stays")
    }
}
