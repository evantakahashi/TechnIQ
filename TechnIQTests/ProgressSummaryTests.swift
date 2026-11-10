import XCTest
@testable import TechnIQ

final class ProgressSummaryTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_GB")
        return calendar
    }()

    /// Tuesday 10 Nov 2026, 12:00 UTC.
    private var now: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 12))! }

    private func fact(daysAgo: Int, minutes: Int = 30, feel: SessionFeel? = nil, skills: [String] = []) -> ProgressSummary.SessionFact {
        .init(date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, minutes: minutes, feel: feel, skills: skills)
    }

    func test_empty_hasNoSessionsButStillHasBuckets() {
        let summary = ProgressSummary.build(facts: [], range: .week, now: now, calendar: calendar)
        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.buckets.count, 7)
        XCTAssertEqual(summary.averageBucketMinutes, 0)
        XCTAssertEqual(summary.feelTotal, 0)
    }

    func test_weekRange_countsOnlyTheLastSevenDays_andBucketsByDay() {
        let summary = ProgressSummary.build(
            facts: [fact(daysAgo: 0, minutes: 20), fact(daysAgo: 1, minutes: 40), fact(daysAgo: 6, minutes: 10), fact(daysAgo: 7, minutes: 99)],
            range: .week, now: now, calendar: calendar
        )
        XCTAssertEqual(summary.totalSessions, 3)
        XCTAssertEqual(summary.totalMinutes, 70)
        XCTAssertEqual(summary.buckets.map(\.minutes), [10, 0, 0, 0, 0, 40, 20])
        XCTAssertEqual(summary.buckets.last?.isCurrent, true)
        XCTAssertEqual(summary.buckets.filter(\.isCurrent).count, 1)
        XCTAssertEqual(summary.sessionsPerWeek, 3, accuracy: 0.001)
    }

    func test_monthRange_bucketsByCalendarWeek_currentWeekLast() {
        let summary = ProgressSummary.build(
            facts: [fact(daysAgo: 1, minutes: 30), fact(daysAgo: 8, minutes: 45), fact(daysAgo: 7, minutes: 15)],
            range: .month, now: now, calendar: calendar
        )
        XCTAssertEqual(summary.buckets.count, 5)
        XCTAssertEqual(summary.buckets.suffix(2).map(\.minutes), [60, 30])
        XCTAssertEqual(summary.buckets.suffix(2).map(\.sessions), [2, 1])
    }

    func test_allTime_usesFirstSessionForTheSpan_andCapsBuckets() {
        let summary = ProgressSummary.build(
            facts: [fact(daysAgo: 0), fact(daysAgo: 13), fact(daysAgo: 400)],
            range: .all, now: now, calendar: calendar
        )
        XCTAssertEqual(summary.totalSessions, 3)
        XCTAssertEqual(summary.buckets.count, 26)
        XCTAssertEqual(summary.sessionsPerWeek, 3 / (401.0 / 7), accuracy: 0.001)
    }

    func test_futureSessionsAreIgnored() {
        let summary = ProgressSummary.build(facts: [fact(daysAgo: -2)], range: .all, now: now, calendar: calendar)
        XCTAssertTrue(summary.isEmpty)
    }

    func test_feelAndSkills_areTalliedAndRanked() {
        let summary = ProgressSummary.build(
            facts: [
                fact(daysAgo: 0, feel: .right, skills: ["passing", "First touch"]),
                fact(daysAgo: 1, feel: .right, skills: ["Passing"]),
                fact(daysAgo: 2, feel: .tooHard, skills: ["  ", "shooting"]),
                fact(daysAgo: 3, feel: nil)
            ],
            range: .week, now: now, calendar: calendar
        )
        XCTAssertEqual(summary.feel[.right], 2)
        XCTAssertEqual(summary.feel[.tooHard], 1)
        XCTAssertNil(summary.feel[.tooEasy])
        XCTAssertEqual(summary.feelTotal, 3)
        XCTAssertEqual(summary.skills.map(\.name), ["Passing", "First Touch", "Shooting"])
        XCTAssertEqual(summary.skills.first?.count, 2)
        XCTAssertEqual(summary.skills.first?.share, 1)
        XCTAssertEqual(summary.skills.last?.share ?? 0, 0.5, accuracy: 0.001)
    }

    func test_timeValue_switchesToHoursAtSixtyMinutes() {
        let short = ProgressSummary.build(facts: [fact(daysAgo: 0, minutes: 45)], range: .week, now: now, calendar: calendar)
        XCTAssertEqual(short.timeValue.value, "45")
        XCTAssertEqual(short.timeValue.unit, "min")
        let long = ProgressSummary.build(facts: [fact(daysAgo: 0, minutes: 90)], range: .week, now: now, calendar: calendar)
        XCTAssertEqual(long.timeValue.value, "1.5")
        XCTAssertEqual(long.timeValue.unit, "h")
    }

    func test_benchmarkTrend_ordersByDate_andReportsDelta() {
        let entries = [
            BenchmarkEntry(type: .juggling, value: 22, date: now, cameraVerified: true),
            BenchmarkEntry(type: .juggling, value: 14, date: now.addingTimeInterval(-86_400 * 7), cameraVerified: false),
            BenchmarkEntry(type: .toeTaps30, value: 40, date: now, cameraVerified: false)
        ]
        let juggling = BenchmarkTrend(type: .juggling, entries: entries)
        XCTAssertEqual(juggling?.values, [14, 22])
        XCTAssertEqual(juggling?.deltaText, "+8")
        XCTAssertEqual(juggling?.best, 22)
        XCTAssertNil(BenchmarkTrend(type: .toeTaps30, entries: entries)?.deltaText, "one entry has no trend")
        XCTAssertNil(BenchmarkTrend(type: .wallPasses30, entries: entries))
    }
}
