import XCTest
@testable import TechnIQ

/// Logged matches and the next match on the dated plan and the Home week, the match-log date
/// rules, builder prefill from the profile, and the extra plan-request fields.
@MainActor
final class MatchScheduleLinkTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var monday: Date { date(2026, 9, 7) }

    private func plan(weeks: Int = 2, training: [DayOfWeek] = [.monday, .wednesday, .friday], start: Date? = nil) -> TrainingPlanModel {
        let built = TrainingPlanService.templateWeeks(count: weeks, trainingDays: training, sessionType: .technical, difficulty: .advanced, focus: [])
        return TrainingPlanModel(id: UUID(), name: "Link", description: "", durationWeeks: weeks, difficulty: .advanced, category: .technical,
                                 targetRole: nil, isPrebuilt: false, isActive: true, currentWeek: 1, progressPercentage: 0,
                                 startedAt: start ?? monday, completedAt: nil, createdAt: monday, updatedAt: monday, weeks: built)
    }

    private func logged(_ day: Date, _ opponent: String? = "Northside") -> MatchScheduleLink.LoggedMatch {
        .init(id: UUID(), date: day, opponent: opponent)
    }

    // MARK: Marks

    func test_marks_loggedWinsOverUpcomingOnTheSameDay() {
        let saturday = date(2026, 9, 12)
        let marks = MatchScheduleLink.marks(matches: [logged(date(2026, 9, 12, hour: 18))], nextMatchDate: saturday, calendar: calendar)
        XCTAssertEqual(marks[calendar.startOfDay(for: saturday)], .logged(opponent: "Northside"))
        XCTAssertEqual(marks.count, 1)
    }

    func test_labels() {
        XCTAssertEqual(MatchScheduleLink.Mark.logged(opponent: "Northside").label, "Match vs Northside")
        XCTAssertEqual(MatchScheduleLink.Mark.logged(opponent: "  ").label, "Match")
        XCTAssertEqual(MatchScheduleLink.Mark.logged(opponent: nil).label, "Match")
        XCTAssertEqual(MatchScheduleLink.Mark.upcoming.label, "Match day")
    }

    func test_dayMarks_linkLoggedAndUpcomingToPlanDaysIncludingRestDays() {
        let p = plan()
        let marks = MatchScheduleLink.dayMarks(
            in: p, startDate: monday,
            matches: [logged(date(2026, 9, 9, hour: 19)), logged(date(2026, 8, 30))],   // Wed wk 1; before the plan
            nextMatchDate: date(2026, 9, 19),                                           // Sat wk 2 (rest day)
            calendar: calendar)
        XCTAssertEqual(marks.map { "\($0.week):\($0.dayNumber)" }, ["1:3", "2:6"])
        XCTAssertEqual(marks.map(\.mark), [.logged(opponent: "Northside"), .upcoming])
        let saturdayWeek2 = p.weeks[1].days.first { $0.dayOfWeek == .saturday }!
        XCTAssertEqual(marks[1].dayID, saturdayWeek2.id)
        XCTAssertTrue(saturdayWeek2.isRestDay)
    }

    func test_dayMarks_emptyWithoutMatches() {
        XCTAssertEqual(MatchScheduleLink.dayMarks(in: plan(), startDate: monday, matches: [], nextMatchDate: nil, calendar: calendar), [])
    }

    func test_planDayForMatch() {
        let p = plan()
        let found = MatchScheduleLink.planDay(for: logged(date(2026, 9, 15, hour: 20)), in: p, startDate: monday, calendar: calendar)
        XCTAssertEqual(found?.week, 2)
        XCTAssertEqual(found?.dayNumber, 2)
        XCTAssertNil(MatchScheduleLink.planDay(for: logged(date(2026, 9, 30)), in: p, startDate: monday, calendar: calendar))
    }

    func test_weekMatchIndexes_onlyThisWeek() {
        let wednesday = date(2026, 9, 9)
        let indexes = MatchScheduleLink.weekMatchIndexes(
            today: wednesday,
            matches: [logged(date(2026, 9, 7)), logged(date(2026, 9, 5))],    // Mon this week, Sat last week
            nextMatchDate: date(2026, 9, 12), calendar: calendar)              // Sat this week
        XCTAssertEqual(indexes, [0, 5])
    }

    func test_homeWeek_marksMatchCellsWhateverTheirState() {
        let week = HomeWeekModel.build(today: date(2026, 9, 9), calendar: calendar, sessionDates: [date(2026, 9, 7)],
                                       plannedDays: nil, matchIndexes: [0, 5])
        XCTAssertEqual(week.cells.map(\.isMatch), [true, false, false, false, false, true, false])
        XCTAssertEqual(week.cells[0].state, .done)
        XCTAssertEqual(week.cells[5].state, .rest)
        XCTAssertEqual(HomeWeekModel.build(today: date(2026, 9, 9), calendar: calendar, sessionDates: [], plannedDays: nil).cells.filter(\.isMatch).count, 0)
    }

    // MARK: Match log

    func test_defaultLogDate() {
        let now = date(2026, 9, 12, hour: 17)
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: date(2026, 9, 12, hour: 0), now: now, calendar: calendar), now, "match today: now")
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: date(2026, 9, 11, hour: 0), now: now, calendar: calendar), date(2026, 9, 11, hour: 0))
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: date(2026, 9, 10, hour: 0), now: now, calendar: calendar), date(2026, 9, 10, hour: 0))
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: date(2026, 9, 9, hour: 0), now: now, calendar: calendar), now, "three days back: today")
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: date(2026, 9, 14), now: now, calendar: calendar), now, "future match: today")
        XCTAssertEqual(MatchScheduleLink.defaultLogDate(nextMatchDate: nil, now: now, calendar: calendar), now)
    }

    func test_clearsNextMatch() {
        let next = date(2026, 9, 12, hour: 0)
        XCTAssertTrue(MatchScheduleLink.clearsNextMatch(loggedOn: date(2026, 9, 12, hour: 18), nextMatchDate: next, calendar: calendar))
        XCTAssertTrue(MatchScheduleLink.clearsNextMatch(loggedOn: date(2026, 9, 13), nextMatchDate: next, calendar: calendar))
        XCTAssertFalse(MatchScheduleLink.clearsNextMatch(loggedOn: date(2026, 9, 11), nextMatchDate: next, calendar: calendar),
                       "an earlier match leaves the next one")
        XCTAssertFalse(MatchScheduleLink.clearsNextMatch(loggedOn: date(2026, 9, 12), nextMatchDate: nil, calendar: calendar))
    }

    func test_upcomingDropsPastMatches() {
        let now = date(2026, 9, 12, hour: 20)
        XCTAssertNotNil(MatchScheduleLink.upcoming(date(2026, 9, 12, hour: 0), now: now, calendar: calendar), "today still counts")
        XCTAssertNil(MatchScheduleLink.upcoming(date(2026, 9, 11), now: now, calendar: calendar))
        XCTAssertNil(MatchScheduleLink.upcoming(nil, now: now, calendar: calendar))
    }

    func test_nextMatchSuggestionIsTheComingSaturday() {
        XCTAssertEqual(NextMatchDefaults.suggested(now: date(2026, 9, 8), calendar: calendar), calendar.startOfDay(for: date(2026, 9, 12)))
        XCTAssertEqual(NextMatchDefaults.suggested(now: date(2026, 9, 12), calendar: calendar), calendar.startOfDay(for: date(2026, 9, 12)))
        XCTAssertEqual(NextMatchDefaults.suggested(now: date(2026, 9, 13), calendar: calendar), calendar.startOfDay(for: date(2026, 9, 19)))
    }

    // MARK: Builder prefill

    func test_prefill_mapsTheProfile() {
        let prefill = PlanBuilderPrefill.make(
            experienceLevel: "Professional", position: "midfielder",
            weaknesses: ["Weak Foot", "Passing", "Weak Foot", "Juggling"],
            trainingDays: [.friday, .monday, .friday],
            nextMatchDate: date(2026, 9, 12), now: monday, calendar: calendar)
        XCTAssertEqual(prefill.difficulty, .elite, "same as onboarding: Professional → Elite")
        XCTAssertEqual(prefill.position, "Midfielder")
        XCTAssertEqual(prefill.weakSpots, [.weakFoot, .passing], "known, deduplicated, in order")
        XCTAssertEqual(prefill.trainingDays, [.monday, .friday])
        XCTAssertEqual(prefill.nextMatchDate, date(2026, 9, 12))
    }

    func test_prefill_levels() {
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "Beginner"), .beginner)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "intermediate"), .intermediate)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "Advanced"), .advanced)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "professional"), .elite)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "expert"), .advanced)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: nil), .intermediate)
        XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: "???"), .intermediate)
        for level in OnboardingMapping.experienceLevels {
            XCTAssertEqual(PlanBuilderPrefill.difficulty(forExperience: level).rawValue, OnboardingMapping.difficulty(forExperience: level))
        }
    }

    func test_prefill_emptyProfile() {
        let prefill = PlanBuilderPrefill.make(experienceLevel: nil, position: "  ", weaknesses: nil, trainingDays: [],
                                              nextMatchDate: date(2026, 9, 6), now: monday, calendar: calendar)
        XCTAssertNil(prefill.position)
        XCTAssertEqual(prefill.weakSpots, [])
        XCTAssertEqual(prefill.trainingDays, [.monday, .wednesday, .friday])
        XCTAssertNil(prefill.nextMatchDate, "a past match is not prefilled")
    }

    func test_prefill_capsWeakSpots() {
        let names = WeaknessCategory.allCases.map(\.displayName)
        XCTAssertEqual(PlanBuilderPrefill.weakSpots(from: names).count, OnboardingMapping.maxWeakSpots)
    }

    func test_customPlanWeekFocusRotatesThroughWeakSpots() {
        let spots: [WeaknessCategory] = [.weakFoot, .passing]
        XCTAssertEqual((1...4).map { PlanBuilderPrefill.focusArea(week: $0, weakSpots: spots) }, ["Weak Foot", "Passing", "Weak Foot", "Passing"])
        XCTAssertNil(PlanBuilderPrefill.focusArea(week: 1, weakSpots: []))
    }

    // MARK: Plan request

    func test_requestFields() {
        let extras = PlanRequestExtras(weakSpots: ["Weak Foot"], position: "Forward",
                                       nextMatchDate: date(2026, 9, 12, hour: 23), planStartDate: date(2026, 9, 7, hour: 1))
        let fields = extras.requestFields(profileWeakSpots: ["Passing"], calendar: calendar)
        XCTAssertEqual(fields["plan_start_date"] as? String, "2026-09-07")
        XCTAssertEqual(fields["next_match_date"] as? String, "2026-09-12")
        XCTAssertEqual(fields["weak_spots"] as? [String], ["Weak Foot"], "the builder's pick wins")
    }

    func test_requestFields_fallbacksAndDrops() {
        let fields = PlanRequestExtras(nextMatchDate: date(2026, 9, 6), planStartDate: monday).requestFields(profileWeakSpots: ["Passing"], calendar: calendar)
        XCTAssertEqual(fields["weak_spots"] as? [String], ["Passing"], "profile weak spots when the builder sent none")
        XCTAssertNil(fields["next_match_date"], "a match before the plan starts is not sent")
        let bare = PlanRequestExtras(weakSpots: [], planStartDate: monday).requestFields(profileWeakSpots: nil, calendar: calendar)
        XCTAssertNil(bare["weak_spots"])
        XCTAssertEqual(bare.count, 1)
    }

    func test_dayStringUsesTheCalendarsTimeZone() {
        var tokyo = Calendar(identifier: .iso8601)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 20:00 UTC on 12 Sep is already 13 Sep in Tokyo.
        XCTAssertEqual(PlanRequestExtras.dayString(date(2026, 9, 12, hour: 20), calendar: tokyo), "2026-09-13")
        XCTAssertEqual(PlanRequestExtras.dayString(date(2026, 9, 12, hour: 20), calendar: calendar), "2026-09-12")
    }
}
