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

    // MARK: Weekly review trigger

    func test_weeklyReview_firesWhenTheWeeksWindowHasEnded_andClearsWhenReviewed() throws {
        let spec = TrainingPlanService.CustomPlanSpec(name: "Review", description: "", weeks: 3, trainingDays: [.monday], sessionType: .technical, minutes: 30, intensity: 3, difficulty: .beginner, category: .technical)
        let plan = service.createCustomPlan(spec, for: player)!
        service.activatePlan(plan.toModel(), for: player)
        // Anchor 10 days back: week 1 has ended, week 2 is in progress.
        plan.startedAt = Calendar.current.date(byAdding: .day, value: -10, to: Calendar.current.startOfDay(for: Date()))
        try context.save()

        let coach = AICoachService.shared
        coach.dismissWeeklyCheckIn()
        coach.refreshWeeklyReview(for: player, now: Date(), calendar: Calendar.current)
        XCTAssertTrue(coach.weeklyCheckInAvailable)
        XCTAssertEqual(coach.completedWeekNumber, 1)

        coach.markWeekReviewed(planID: plan.id!, weekNumber: 1)
        XCTAssertFalse(coach.weeklyCheckInAvailable)
        coach.refreshWeeklyReview(for: player, now: Date(), calendar: Calendar.current)
        XCTAssertFalse(coach.weeklyCheckInAvailable, "week 2 has not ended yet")
        UserDefaults.standard.removeObject(forKey: "weeklyReview.reviewed.\(plan.id!.uuidString)")
    }

    // MARK: - Training profile → plan re-bind

    private func trainingWeekdays(_ plan: TrainingPlanModel, week: Int) -> [DayOfWeek] {
        plan.weeks.first { $0.weekNumber == week }!.days.filter { !$0.isRestDay }.sorted { $0.dayNumber < $1.dayNumber }.compactMap { $0.dayOfWeek }
    }

    func test_rebindTrainingDays_movesFutureWeeksAndLeavesTheCurrentOne() {
        var plan = makePlan(weeks: 3, days: [.monday, .thursday])
        XCTAssertTrue(service.rebindTrainingDays(planId: plan.id, to: [.saturday, .tuesday]))
        plan = reload(plan)
        XCTAssertEqual(trainingWeekdays(plan, week: 1), [.monday, .thursday], "the week in progress keeps its days")
        XCTAssertEqual(trainingWeekdays(plan, week: 2), [.tuesday, .saturday])
        XCTAssertEqual(trainingWeekdays(plan, week: 3), [.tuesday, .saturday])
        for week in plan.weeks where week.weekNumber > 1 {
            XCTAssertEqual(week.days.flatMap(\.sessions).count, 2, "sessions move, none are lost or duplicated")
            XCTAssertTrue(week.days.filter { $0.isRestDay }.allSatisfy { $0.sessions.isEmpty })
        }
    }

    func test_rebindTrainingDays_fewerDaysStackSessions_moreDaysCopyTheLast() {
        var plan = makePlan(weeks: 2, days: [.monday, .thursday])
        XCTAssertTrue(service.rebindTrainingDays(planId: plan.id, to: [.wednesday]))
        plan = reload(plan)
        let wednesday = plan.weeks.first { $0.weekNumber == 2 }!.days.first { $0.dayOfWeek == .wednesday }!
        XCTAssertFalse(wednesday.isRestDay)
        XCTAssertEqual(wednesday.sessions.count, 2, "two sessions land on the one training day")
        XCTAssertEqual(wednesday.sessions.map(\.orderIndex).sorted(), [0, 1])

        XCTAssertTrue(service.rebindTrainingDays(planId: plan.id, to: [.monday, .wednesday, .friday]))
        plan = reload(plan)
        XCTAssertEqual(trainingWeekdays(plan, week: 2), [.monday, .wednesday, .friday])
        let week2 = plan.weeks.first { $0.weekNumber == 2 }!
        XCTAssertEqual(week2.days.flatMap(\.sessions).count, 3, "the third day gets a copy of the last session")
        XCTAssertTrue(week2.days.filter { !$0.isRestDay }.allSatisfy { $0.sessions.count == 1 })
    }

    func test_rebindTrainingDays_isANoOpWithoutFutureWeeksOrDays() {
        let plan = makePlan(weeks: 1)
        XCTAssertFalse(service.rebindTrainingDays(planId: plan.id, to: [.friday]))
        XCTAssertEqual(trainingWeekdays(reload(plan), week: 1), [.monday, .thursday])
        XCTAssertFalse(service.rebindTrainingDays(planId: makePlan(weeks: 2).id, to: []))
    }

    func test_trainingDayList_roundTripsSortedAndFallsBackToTheDefault() throws {
        let profile = PlayerProfile(context: context)
        profile.id = UUID()
        profile.player = player
        XCTAssertEqual(profile.trainingDayList, [.monday, .wednesday, .friday], "unset means the onboarding default")

        profile.trainingDayList = [.saturday, .tuesday, .saturday]
        XCTAssertEqual(profile.trainingDays, "Tuesday,Saturday")
        XCTAssertEqual(profile.trainingDayList, [.tuesday, .saturday])

        profile.trainingDays = "Friday, Monday,notaday"
        XCTAssertEqual(profile.trainingDayList, [.monday, .friday], "unknown names are ignored")

        profile.trainingDayList = []
        XCTAssertNil(profile.trainingDays)
        context.delete(profile)
    }
}
