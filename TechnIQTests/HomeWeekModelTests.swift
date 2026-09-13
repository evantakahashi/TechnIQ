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
        // Sessions on Mon, Wed, Thu; plan has four dated training days: Mon, Wed, Thu, Sat.
        let sessions = [day(-5), day(-3), day(-2)]
        let planned: [HomeWeekModel.PlannedDay] = [
            .init(date: day(-5), sessionCount: 1, isDone: true),
            .init(date: day(-3), sessionCount: 1, isDone: true),
            .init(date: day(-2), sessionCount: 1, isDone: true),
            .init(date: day(0), sessionCount: 1, isDone: false)
        ]

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: sessions, plannedDays: planned)

        XCTAssertEqual(week.todayIndex, 5)
        XCTAssertEqual(week.cells.map(\.state), [.done, .rest, .done, .done, .rest, .today, .rest])
        XCTAssertEqual(week.done, 3)
        XCTAssertEqual(week.target, 4)
        XCTAssertEqual(week.summary, "3 / 4")
    }

    func testFirstRun_noPlanNoSessions_showsTodayAndNoTarget() {
        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [], plannedDays: nil)

        XCTAssertEqual(week.cells.map(\.state), [.rest, .rest, .rest, .rest, .rest, .today, .rest])
        XCTAssertEqual(week.done, 0)
        XCTAssertNil(week.target)
        XCTAssertEqual(week.summary, "0 / —")
    }

    func testPlannedDaysOutsideThisWeekAreIgnored() {
        let planned: [HomeWeekModel.PlannedDay] = [
            .init(date: day(-8), sessionCount: 1, isDone: false),   // last week
            .init(date: day(1), sessionCount: 2, isDone: false),    // Sunday
            .init(date: day(3), sessionCount: 1, isDone: false)     // next week
        ]

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [], plannedDays: planned)

        XCTAssertEqual(week.cells.map(\.state), [.rest, .rest, .rest, .rest, .rest, .today, .planned])
        XCTAssertEqual(week.cells[6].sessions, 2)
        XCTAssertEqual(week.target, 1)
    }

    func testMissedPastPlannedDayIsMarkedMissed() {
        let planned: [HomeWeekModel.PlannedDay] = [
            .init(date: day(-5), sessionCount: 1, isDone: false),   // Monday, never trained
            .init(date: day(0), sessionCount: 1, isDone: false)
        ]

        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [], plannedDays: planned)

        XCTAssertEqual(week.cells[0].state, .missed)
        XCTAssertEqual(week.cells[5].state, .today)
        XCTAssertEqual(week.target, 2)
    }

    func testSessionTodayMarksTodayDone() {
        let week = HomeWeekModel.build(today: saturday, calendar: calendar, sessionDates: [saturday], plannedDays: nil)

        XCTAssertEqual(week.cells[5].state, .done)
        XCTAssertEqual(week.done, 1)
        XCTAssertEqual(week.summary, "1 / —")
    }
}
