import XCTest
import CoreData
@testable import TechnIQ

/// The one-screen editor's service calls, run against the app's own store with a throwaway player
/// that is deleted afterwards (the editing API is bound to `CoreDataManager.shared.context`).
@MainActor
final class PlanEditingTests: XCTestCase {
    private var context: NSManagedObjectContext { CoreDataManager.shared.context }
    private var player: Player!
    private let service = TrainingPlanService.shared

    override func setUp() async throws {
        try await super.setUp()
        player = Player(context: context)
        player.id = UUID()
        player.name = "Editing Test \(UUID().uuidString.prefix(6))"
        player.firebaseUID = "test-\(UUID().uuidString)"
        player.createdAt = Date()
        try context.save()
    }

    override func tearDown() async throws {
        for plan in service.fetchAllPlans(for: player) { service.deletePlan(plan) }
        context.delete(player)
        try? context.save()
        player = nil
        try await super.tearDown()
    }

    private func makePlan(weeks: Int = 2, days: [DayOfWeek] = [.monday, .thursday]) -> TrainingPlanModel {
        let spec = TrainingPlanService.CustomPlanSpec(
            name: "Editable", description: "", weeks: weeks, trainingDays: days,
            sessionType: .technical, minutes: 30, intensity: 3, difficulty: .beginner, category: .technical
        )
        return service.createCustomPlan(spec, for: player)!.toModel()
    }

    private func reload(_ plan: TrainingPlanModel) -> TrainingPlanModel {
        service.fetchPlan(byId: plan.id)!
    }

    func test_customPlanSpec_buildsAFullSkeleton() {
        let plan = makePlan(weeks: 3, days: [.monday, .wednesday, .friday])
        XCTAssertEqual(plan.weeks.count, 3)
        XCTAssertEqual(plan.durationWeeks, 3)
        for week in plan.weeks {
            XCTAssertEqual(week.days.count, 7)
            XCTAssertEqual(week.days.filter { !$0.isRestDay }.count, 3)
            XCTAssertTrue(week.days.filter { !$0.isRestDay }.allSatisfy { $0.sessions.count == 1 && $0.sessions[0].duration == 30 })
        }
        XCTAssertNotNil(TrainingPlanService.peekCurrentDay(in: plan), "a custom plan can be followed straight away")
    }

    func test_appendAndRemoveWeek_mirrorThePatternAndKeepProgressSafe() {
        var plan = makePlan(weeks: 1)
        XCTAssertTrue(service.appendWeek(planId: plan.id))
        plan = reload(plan)
        XCTAssertEqual(plan.weeks.count, 2)
        XCTAssertEqual(plan.durationWeeks, 2)
        let added = plan.weeks.first { $0.weekNumber == 2 }!
        XCTAssertEqual(added.days.filter { !$0.isRestDay }.map { $0.dayOfWeek }, [.monday, .thursday])
        XCTAssertTrue(added.days.flatMap(\.sessions).allSatisfy { !$0.isCompleted })

        // Completing a session in the last week protects it.
        let lastSession = added.days.first { !$0.isRestDay }!.sessions[0]
        service.markSessionCompleted(lastSession, actualDuration: 30, actualIntensity: 3)
        XCTAssertFalse(service.removeLastWeek(planId: plan.id), "a week with completed sessions stays")
        XCTAssertEqual(reload(plan).weeks.count, 2)
    }

    func test_removeLastWeek_neverRemovesTheOnlyWeek() {
        let plan = makePlan(weeks: 1)
        XCTAssertFalse(service.removeLastWeek(planId: plan.id))
        XCTAssertEqual(reload(plan).weeks.count, 1)
        XCTAssertTrue(service.appendWeek(planId: plan.id))
        XCTAssertTrue(service.removeLastWeek(planId: plan.id))
        XCTAssertEqual(reload(plan).weeks.count, 1)
    }

    func test_sessionsAndDrills_onADay() {
        var plan = makePlan(weeks: 1)
        let monday = plan.weeks[0].days.first { $0.dayOfWeek == .monday }!
        XCTAssertNotNil(service.addSession(dayId: monday.id, sessionType: .physical, duration: 20, intensity: 4))
        plan = reload(plan)
        var day = plan.weeks[0].days.first { $0.id == monday.id }!
        XCTAssertEqual(day.sessions.count, 2)
        XCTAssertEqual(day.sessions.map(\.orderIndex).sorted(), [0, 1])

        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = "Wall passes"
        exercise.player = player
        try? context.save()
        let second = day.sessions.sorted { $0.orderIndex < $1.orderIndex }[1]
        XCTAssertTrue(service.setSessionExercises(sessionId: second.id, exerciseIDs: [exercise.id!]))
        plan = reload(plan)
        day = plan.weeks[0].days.first { $0.id == monday.id }!
        XCTAssertEqual(day.sessions.first { $0.id == second.id }?.exerciseIDs, [exercise.id!])

        XCTAssertTrue(service.removeSession(sessionId: second.id))
        plan = reload(plan)
        day = plan.weeks[0].days.first { $0.id == monday.id }!
        XCTAssertEqual(day.sessions.count, 1)
        XCTAssertEqual(day.sessions[0].orderIndex, 0)
        context.delete(exercise)
        try? context.save()
    }

    func test_restToggle_andPlanDetails() {
        var plan = makePlan(weeks: 1)
        let tuesday = plan.weeks[0].days.first { $0.dayOfWeek == .tuesday }!
        XCTAssertTrue(tuesday.isRestDay)
        XCTAssertTrue(service.setRestDay(dayId: tuesday.id, isRestDay: false))
        XCTAssertNotNil(service.addSession(dayId: tuesday.id, sessionType: .tactical, duration: 45, intensity: 2))
        plan = reload(plan)
        XCTAssertFalse(plan.weeks[0].days.first { $0.id == tuesday.id }!.isRestDay)

        XCTAssertTrue(service.updatePlanDetails(planId: plan.id, name: "Renamed", description: "Sharper", difficulty: .advanced))
        plan = reload(plan)
        XCTAssertEqual(plan.name, "Renamed")
        XCTAssertEqual(plan.description, "Sharper")
        XCTAssertEqual(plan.difficulty, .advanced)
    }
}
