import XCTest
@testable import TechnIQ

final class HomeWeekModelTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    /// Saturday 12 Sep 2026 12:00 UTC (the mock's dates are fictional; this is a real Saturday).
    private var saturday: Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 12, hour: 12))!
    }

    private func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: saturday)!
    }

    func testMockWeek_threeDoneOfFour_todayHighlighted() {
        // Sessions on Mon, Wed, Thu; plan has four training days: Mon, Wed, Thu, Sat.
        let sessions = [day(-5), day(-3), day(-2)]
        let plan = HomeWeekModel.PlanWeek(days: [
            .init(weekday: 1, isRest: false, isCompleted: true, sessionCount: 1),
            .init(weekday: 2, isRest: true, isCompleted: true, sessionCount: 0),
            .init(weekday: 3, isRest: false, isCompleted: true, sessionCount: 1),
            .init(weekday: 4, isRest: false, isCompleted: true, sessionCount: 1),
            .init(weekday: 5, isRest: true, isCompleted: true, sessionCount: 0),
            .init(weekday: 6, isRest: false, isCompleted: false, sessionCount: 1),
            .init(weekday: 7, isRest: true, isCompleted: false, sessionCount: 0)
        ])

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: sessions, plan: plan)

        XCTAssertEqual(week.todayIndex, 5)
        XCTAssertEqual(week.cells.map(\.state), [.done, .rest, .done, .done, .rest, .today, .rest])
        XCTAssertEqual(week.done, 3)
        XCTAssertEqual(week.target, 4)
        XCTAssertEqual(week.summary, "3 / 4")
    }

    func testFirstRun_noPlanNoSessions_showsTodayAndNoTarget() {
        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [], plan: nil)

        XCTAssertEqual(week.cells.map(\.state), [.rest, .rest, .rest, .rest, .rest, .today, .rest])
        XCTAssertEqual(week.done, 0)
        XCTAssertNil(week.target)
        XCTAssertEqual(week.summary, "0 / —")
    }

    func testPlanWithoutWeekdays_assignsRemainingDaysFromToday() {
        // Plan week has 3 training days without weekday info; one already done (Tuesday).
        let sessions = [day(-4)]
        let plan = HomeWeekModel.PlanWeek(days: [
            .init(weekday: nil, isRest: false, isCompleted: true, sessionCount: 1),
            .init(weekday: nil, isRest: true, isCompleted: true, sessionCount: 0),
            .init(weekday: nil, isRest: false, isCompleted: false, sessionCount: 1),
            .init(weekday: nil, isRest: false, isCompleted: false, sessionCount: 2)
        ])

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: sessions, plan: plan)

        // Tue done; today (Sat) planned; Sunday planned with two sessions.
        XCTAssertEqual(week.cells.map(\.state), [.rest, .done, .rest, .rest, .rest, .today, .planned])
        XCTAssertEqual(week.cells[6].sessions, 2)
        XCTAssertEqual(week.target, 3)
    }

    func testMissedPastPlannedDayIsMarkedMissed() {
        let plan = HomeWeekModel.PlanWeek(days: [
            .init(weekday: 1, isRest: false, isCompleted: false, sessionCount: 1),
            .init(weekday: 6, isRest: false, isCompleted: false, sessionCount: 1)
        ])

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [], plan: plan)

        XCTAssertEqual(week.cells[0].state, .missed)
        XCTAssertEqual(week.cells[5].state, .today)
        XCTAssertEqual(week.target, 2)
    }

    func testSessionTodayMarksTodayDone() {
        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [saturday], plan: nil)

        XCTAssertEqual(week.cells[5].state, .done)
        XCTAssertEqual(week.done, 1)
        XCTAssertEqual(week.summary, "1 / —")
    }
}
