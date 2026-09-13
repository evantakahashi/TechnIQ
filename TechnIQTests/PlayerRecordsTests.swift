import XCTest
@testable import TechnIQ

/// Personal bests and the this-week-vs-last-week line (You → Records, Progress "This week").
final class PlayerRecordsTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 1 // Sunday-first locale: weeks must still run Monday to Sunday.
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func fact(_ date: Date, minutes: Int = 20, drills: Int = 2) -> PlayerRecords.SessionFact {
        PlayerRecords.SessionFact(date: date, minutes: minutes, drillCount: drills)
    }

    // Wednesday 16 Sep 2026.
    private var now: Date { date(2026, 9, 16, hour: 15) }

    func test_emptyHistory_hasNoBestsAndAnEmptyWeekLine() {
        let records = PlayerRecords.build(sessions: [], now: now, calendar: calendar)
        XCTAssertEqual(records.longestSessionMinutes, 0)
        XCTAssertNil(records.longestSessionDate)
        XCTAssertEqual(records.bestWeekSessions, 0)
        XCTAssertEqual(records.mostDrillsInADay, 0)
        XCTAssertEqual(records.totalSessions, 0)
        XCTAssertEqual(records.comparison.line, "No sessions yet this week")
    }

    func test_bests_pickTheLongestSessionBestWeekAndBusiestDay() {
        let sessions = [
            fact(date(2026, 9, 1), minutes: 25, drills: 3),   // Tue, week of 31 Aug
            fact(date(2026, 9, 3), minutes: 40, drills: 1),   // Thu, week of 31 Aug
            fact(date(2026, 9, 5), minutes: 15, drills: 2),   // Sat, week of 31 Aug
            fact(date(2026, 9, 9, hour: 8), minutes: 30, drills: 2),  // Wed, week of 7 Sep
            fact(date(2026, 9, 9, hour: 18), minutes: 10, drills: 3), // same Wednesday
            fact(date(2026, 9, 15), minutes: 40, drills: 1)   // Tue, this week
        ]
        let records = PlayerRecords.build(sessions: sessions, now: now, calendar: calendar)

        XCTAssertEqual(records.longestSessionMinutes, 40)
        XCTAssertEqual(records.longestSessionDate, date(2026, 9, 15), "ties go to the most recent")
        XCTAssertEqual(records.bestWeekSessions, 3)
        XCTAssertEqual(records.bestWeekStart, calendar.startOfDay(for: date(2026, 8, 31)))
        XCTAssertEqual(records.mostDrillsInADay, 5)
        XCTAssertEqual(records.mostDrillsDate, calendar.startOfDay(for: date(2026, 9, 9)))
        XCTAssertEqual(records.totalSessions, 6)
    }

    func test_comparison_countsThisWeekAgainstLastWeek() {
        let sessions = [
            fact(date(2026, 9, 7), minutes: 20),   // Mon last week
            fact(date(2026, 9, 10), minutes: 25),  // Thu last week
            fact(date(2026, 9, 13), minutes: 30),  // Sun last week (still last week under Monday start)
            fact(date(2026, 9, 14), minutes: 35),  // Mon this week
            fact(date(2026, 9, 16), minutes: 15)   // Wed this week (today)
        ]
        let comparison = PlayerRecords.build(sessions: sessions, now: now, calendar: calendar).comparison
        XCTAssertEqual(comparison.thisWeekSessions, 2)
        XCTAssertEqual(comparison.lastWeekSessions, 3)
        XCTAssertEqual(comparison.thisWeekMinutes, 50)
        XCTAssertEqual(comparison.lastWeekMinutes, 75)
        XCTAssertEqual(comparison.line, "2 sessions · 1 fewer than last week")
    }

    func test_comparisonLine_coversEveryDirection() {
        typealias Comparison = PlayerRecords.WeekComparison
        XCTAssertEqual(Comparison(thisWeekSessions: 3, lastWeekSessions: 1, thisWeekMinutes: 0, lastWeekMinutes: 0).line, "3 sessions · 2 more than last week")
        XCTAssertEqual(Comparison(thisWeekSessions: 1, lastWeekSessions: 1, thisWeekMinutes: 0, lastWeekMinutes: 0).line, "1 session · same as last week")
        XCTAssertEqual(Comparison(thisWeekSessions: 0, lastWeekSessions: 2, thisWeekMinutes: 0, lastWeekMinutes: 0).line, "No sessions yet this week · 2 last week")
        XCTAssertEqual(Comparison(thisWeekSessions: 3, lastWeekSessions: 1, thisWeekMinutes: 0, lastWeekMinutes: 0).delta, "2 more than last week")
        XCTAssertEqual(Comparison(thisWeekSessions: 0, lastWeekSessions: 2, thisWeekMinutes: 0, lastWeekMinutes: 0).delta, "2 last week")
        XCTAssertEqual(Comparison(thisWeekSessions: 0, lastWeekSessions: 0, thisWeekMinutes: 0, lastWeekMinutes: 0).delta, "None last week either")
    }

    func test_weekStart_isMondayEvenWhenTheCalendarStartsOnSunday() {
        let sunday = date(2026, 9, 13, hour: 23)
        XCTAssertEqual(PlayerRecords.weekStart(of: sunday, calendar: calendar), calendar.startOfDay(for: date(2026, 9, 7)))
        let monday = date(2026, 9, 14, hour: 0)
        XCTAssertEqual(PlayerRecords.weekStart(of: monday, calendar: calendar), calendar.startOfDay(for: monday))
    }
}
