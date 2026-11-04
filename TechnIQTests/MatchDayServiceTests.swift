import XCTest
import CoreData
@testable import TechnIQ

/// The match-day rules persisted on stored plans and the next match as one shared profile fact,
/// against the app's own store with a throwaway player (deleted afterwards).
@MainActor
final class MatchDayServiceTests: XCTestCase {
    private var context: NSManagedObjectContext { CoreDataManager.shared.context }
    private var player: Player!
    private let service = TrainingPlanService.shared
    private let calendar = Calendar.current

    override func setUp() async throws {
        try await super.setUp()
        player = Player(context: context)
        player.id = UUID()
        player.name = "Match Day Test \(UUID().uuidString.prefix(6))"
        player.firebaseUID = "test-\(UUID().uuidString)"
        player.createdAt = Date()
        try context.save()
    }

    override func tearDown() async throws {
        for plan in service.fetchAllPlans(for: player) { service.deletePlan(plan) }
        for match in (player.matches as? Set<Match>) ?? [] { context.delete(match) }
        if let profile = player.playerProfile { context.delete(profile) }
        context.delete(player)
        try? context.save()
        player = nil
        try await super.tearDown()
    }

    private func today(plus days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: Date()))!
    }

    /// An active plan that trains every day at intensity 5, starting today.
    private func makeActivePlan(weeks: Int = 2) -> TrainingPlanModel {
        let spec = TrainingPlanService.CustomPlanSpec(
            name: "Every day", description: "", weeks: weeks, trainingDays: DayOfWeek.allCases,
            sessionType: .physical, minutes: 60, intensity: 5, difficulty: .elite, category: .physical
        )
        let plan = service.createCustomPlan(spec, for: player)!.toModel()
        service.activatePlan(plan, for: player)
        return service.fetchPlan(byId: plan.id)!
    }

    private func day(on date: Date, in plan: TrainingPlanModel) -> PlanDayModel? {
        let start = PlanSchedule.startDate(of: plan)
        for week in plan.weeks {
            for day in week.days where calendar.isDate(PlanSchedule.date(of: day, in: week, startDate: start, calendar: calendar), inSameDayAs: date) {
                return day
            }
        }
        return nil
    }

    func test_applyPersistsTheRules() {
        let plan = makeActivePlan()
        let match = today(plus: 3)
        XCTAssertTrue(service.applyMatchDayRules(to: plan.id, matchDates: [match]))
        let stored = service.fetchPlan(byId: plan.id)!

        XCTAssertTrue(day(on: match, in: stored)!.isMatchDay)
        let before = day(on: today(plus: 2), in: stored)!.sessions[0]
        XCTAssertEqual(before.sessionType, .technical)
        XCTAssertLessThanOrEqual(before.intensity, 2)
        XCTAssertLessThanOrEqual(before.duration, 30)
        let after = day(on: today(plus: 4), in: stored)!.sessions[0]
        XCTAssertEqual(after.sessionType, .recovery)
        XCTAssertEqual(after.intensity, 1)
        XCTAssertEqual(day(on: today(plus: 1), in: stored)!.sessions[0].intensity, 5)
        XCTAssertEqual(service.activePlan?.id, plan.id)

        XCTAssertFalse(service.applyMatchDayRules(to: plan.id, matchDates: [match]), "second run changes nothing")
    }

    func test_setNextMatch_writesTheProfileAndShapesTheActivePlan() {
        let plan = makeActivePlan()
        let match = today(plus: 5)
        service.setNextMatch(match.addingTimeInterval(3600 * 15), for: player)
        XCTAssertEqual(player.playerProfile?.nextMatchDate, match, "stored as the start of the day")
        XCTAssertTrue(day(on: match, in: service.fetchPlan(byId: plan.id)!)!.isMatchDay)

        // Moving the match hands the old day back.
        let moved = today(plus: 8)
        service.setNextMatch(moved, for: player)
        let stored = service.fetchPlan(byId: plan.id)!
        XCTAssertFalse(day(on: match, in: stored)!.isRestDay)
        XCTAssertTrue(day(on: moved, in: stored)!.isMatchDay)

        service.setNextMatch(nil, for: player)
        XCTAssertNil(player.playerProfile?.nextMatchDate)
        XCTAssertFalse(day(on: moved, in: service.fetchPlan(byId: plan.id)!)!.isRestDay)
    }

    func test_newPlansAreShapedAroundTheNextMatch() {
        service.setNextMatch(today(plus: 2), for: player)
        let plan = makeActivePlan()
        XCTAssertTrue(day(on: today(plus: 2), in: plan)!.isMatchDay)
        XCTAssertEqual(day(on: today(plus: 1), in: plan)!.sessions[0].sessionType, .technical)
    }

    func test_customSpecWeakSpotsBecomeWeekFocus() {
        var spec = TrainingPlanService.CustomPlanSpec(
            name: "Focus", description: "", weeks: 3, trainingDays: [.monday], sessionType: .technical,
            minutes: 30, intensity: 3, difficulty: .beginner, category: .technical
        )
        spec.weakSpots = [.weakFoot, .passing]
        spec.position = "Defender"
        let plan = service.createCustomPlan(spec, for: player)!.toModel()
        let weeks = plan.weeks.sorted { $0.weekNumber < $1.weekNumber }
        XCTAssertEqual(weeks.filter { !$0.isRetest }.map(\.focusArea), ["Weak Foot", "Passing", "Weak Foot"])
        XCTAssertEqual(weeks.last?.isRetest, true, "Closing retest week stays last")
        XCTAssertEqual(plan.targetRole, "Defender")
        XCTAssertEqual(plan.weeks[0].days.first { !$0.isRestDay }?.sessions[0].notes?.hasPrefix("Focus: "), true)
    }

    func test_loggingTheMatchClearsTheNextOneButKeepsMatchDay() {
        let plan = makeActivePlan()
        let matchDay = today(plus: 0)
        service.setNextMatch(matchDay, for: player)
        XCTAssertTrue(day(on: matchDay, in: service.fetchPlan(byId: plan.id)!)!.isMatchDay)

        let match = Match(context: context)
        match.id = UUID()
        match.date = Date()
        match.player = player
        try? context.save()
        service.matchLogged(on: Date(), for: player)

        XCTAssertNil(player.playerProfile?.nextMatchDate, "played: the next match is cleared")
        XCTAssertTrue(day(on: matchDay, in: service.fetchPlan(byId: plan.id)!)!.isMatchDay, "the logged match keeps today a match day")
    }

    func test_loggingAnEarlierMatchKeepsTheNextOne() {
        let next = today(plus: 4)
        service.setNextMatch(next, for: player)
        service.matchLogged(on: today(plus: -1), for: player)
        XCTAssertEqual(player.playerProfile?.nextMatchDate, next)
    }
}
