import XCTest
@testable import TechnIQ

/// Match-day shaping on dated plans: match day rests, the day before goes light technical, the day
/// after is recovery, and nothing hard (intensity ≥ 4) lands within a day of a match.
final class MatchDayRulesTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Monday 7 Sep 2026: plan anchor and "now" unless a test says otherwise.
    private var monday: Date { date(2026, 9, 7) }
    private let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }

    // MARK: Builders

    private func session(_ type: SessionType = .physical, intensity: Int = 5, duration: Int = 60, done: Bool = false) -> PlanSessionModel {
        PlanSessionModel(id: UUID(), sessionType: type, duration: duration, intensity: intensity, orderIndex: 0, notes: "Sprint ladder",
                         isCompleted: done, completedAt: nil, actualDuration: nil, actualIntensity: nil, exerciseIDs: [])
    }

    /// Seven days Monday first; `training` days get one session from `make`, others rest.
    private func week(_ number: Int, training: Set<DayOfWeek> = Set(DayOfWeek.allCases),
                      make: (DayOfWeek) -> [PlanSessionModel] = { _ in [] },
                      done: Set<DayOfWeek> = [], skipped: Set<DayOfWeek> = []) -> PlanWeekModel {
        let days = weekdays.enumerated().map { index, weekday -> PlanDayModel in
            let trains = training.contains(weekday)
            let built = make(weekday)
            let sessions = trains ? (built.isEmpty ? [session()] : built) : []
            return PlanDayModel(id: UUID(), dayNumber: index + 1, dayOfWeek: weekday, isRestDay: !trains, isSkipped: skipped.contains(weekday),
                                notes: nil, isCompleted: done.contains(weekday), completedAt: nil,
                                sessions: done.contains(weekday) ? sessions.map { $0.withDone() } : sessions)
        }
        return PlanWeekModel(id: UUID(), weekNumber: number, focusArea: nil, notes: nil, isCompleted: false, completedAt: nil, days: days)
    }

    private func plan(_ weeks: [PlanWeekModel], start: Date? = nil) -> TrainingPlanModel {
        TrainingPlanModel(id: UUID(), name: "Match test", description: "", durationWeeks: weeks.count, difficulty: .advanced, category: .physical,
                          targetRole: nil, isPrebuilt: false, isActive: true, currentWeek: 1, progressPercentage: 0,
                          startedAt: start ?? monday, completedAt: nil, createdAt: monday, updatedAt: monday, weeks: weeks)
    }

    private func apply(_ plan: TrainingPlanModel, matches: [Date], now: Date? = nil) -> MatchDayRules.Outcome {
        MatchDayRules.apply(to: plan, startDate: PlanSchedule.startDate(of: plan), matchDates: matches, now: now ?? monday, calendar: calendar)
    }

    private func day(_ plan: TrainingPlanModel, week: Int, _ weekday: DayOfWeek) -> PlanDayModel {
        plan.weeks.first { $0.weekNumber == week }!.days.first { $0.dayOfWeek == weekday }!
    }

    /// No open session at intensity ≥ 4 within one day of any match.
    private func assertHardSessionsClear(of matches: [Date], in plan: TrainingPlanModel, now: Date? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let today = calendar.startOfDay(for: now ?? monday)
        for week in plan.weeks {
            for day in week.days where !day.isRestDay && !day.isCompleted && !day.isSkipped {
                let dayDate = calendar.startOfDay(for: PlanSchedule.date(of: day, in: week, startDate: PlanSchedule.startDate(of: plan), calendar: calendar))
                guard dayDate >= today else { continue }
                for match in matches {
                    let distance = abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: match), to: dayDate).day!)
                    if distance < 2 {
                        XCTAssertTrue(day.sessions.allSatisfy { $0.intensity < MatchDayRules.hardIntensity },
                                      "WK \(week.weekNumber) \(day.dayOfWeek!.shortName) is \(distance) day(s) from a match", file: file, line: line)
                    }
                }
            }
        }
    }

    // MARK: The three rules

    func test_matchOnTrainingDay_restsAndShapesTheNeighbours() {
        let thursday = date(2026, 9, 10)
        let outcome = apply(plan([week(1), week(2)]), matches: [thursday])
        let shaped = outcome.plan

        let match = day(shaped, week: 1, .thursday)
        XCTAssertTrue(match.isRestDay)
        XCTAssertEqual(match.notes, MatchDayRules.matchDayNote)
        XCTAssertTrue(match.isMatchDay)
        XCTAssertEqual(match.sessions.count, 1, "sessions stay attached so a moved match hands the day back")

        let before = day(shaped, week: 1, .wednesday).sessions[0]
        XCTAssertEqual(before.sessionType, .technical)
        XCTAssertLessThanOrEqual(before.intensity, 2)
        XCTAssertLessThanOrEqual(before.duration, 30)
        XCTAssertEqual(before.notes, MatchDayRules.dayBeforeNote)

        let after = day(shaped, week: 1, .friday).sessions[0]
        XCTAssertEqual(after.sessionType, .recovery)
        XCTAssertEqual(after.intensity, 1)
        XCTAssertLessThanOrEqual(after.duration, 30)
        XCTAssertEqual(after.notes, MatchDayRules.dayAfterNote)

        // Two days out keeps its hard session.
        XCTAssertEqual(day(shaped, week: 1, .tuesday).sessions[0].intensity, 5)
        XCTAssertEqual(day(shaped, week: 1, .saturday).sessions[0].intensity, 5)

        XCTAssertEqual(outcome.changes.days.count, 1)
        XCTAssertEqual(outcome.changes.sessions.count, 2)
        XCTAssertTrue(outcome.changes.moves.isEmpty)
        assertHardSessionsClear(of: [thursday], in: shaped)
    }

    func test_matchOnRestDay_marksItAndShapesNeighbours() {
        let thursday = date(2026, 9, 10)
        let outcome = apply(plan([week(1, training: [.monday, .wednesday, .friday])]), matches: [thursday])
        let match = day(outcome.plan, week: 1, .thursday)
        XCTAssertTrue(match.isRestDay)
        XCTAssertEqual(match.notes, MatchDayRules.matchDayNote)
        XCTAssertTrue(match.sessions.isEmpty)
        XCTAssertEqual(day(outcome.plan, week: 1, .wednesday).sessions[0].sessionType, .technical)
        XCTAssertEqual(day(outcome.plan, week: 1, .friday).sessions[0].sessionType, .recovery)
    }

    func test_restDayNeighboursAreLeftAlone() {
        // Match Thursday, Wednesday and Friday already rest.
        let outcome = apply(plan([week(1, training: [.monday, .thursday, .saturday])]), matches: [date(2026, 9, 10)])
        XCTAssertEqual(outcome.changes.sessions, [])
        XCTAssertTrue(day(outcome.plan, week: 1, .wednesday).isRestDay)
        XCTAssertTrue(day(outcome.plan, week: 1, .friday).isRestDay)
        XCTAssertEqual(day(outcome.plan, week: 1, .saturday).sessions[0].intensity, 5)
    }

    func test_matchOnDayOneOfThePlan() {
        let outcome = apply(plan([week(1)]), matches: [monday])
        XCTAssertTrue(day(outcome.plan, week: 1, .monday).isMatchDay)
        XCTAssertEqual(day(outcome.plan, week: 1, .tuesday).sessions[0].sessionType, .recovery)
        XCTAssertEqual(day(outcome.plan, week: 1, .wednesday).sessions[0].intensity, 5)
        assertHardSessionsClear(of: [monday], in: outcome.plan)
    }

    func test_matchBeforePlanStart_onlyTheDayAfterCounts() {
        let sunday = date(2026, 9, 6)
        let outcome = apply(plan([week(1)]), matches: [sunday])
        XCTAssertEqual(day(outcome.plan, week: 1, .monday).sessions[0].sessionType, .recovery, "plan day 1 is the day after the match")
        XCTAssertEqual(day(outcome.plan, week: 1, .tuesday).sessions[0].intensity, 5)

        let saturday = date(2026, 9, 5)
        XCTAssertTrue(apply(plan([week(1)]), matches: [saturday]).changes.isEmpty, "two days before the start: nothing to do")
    }

    func test_matchAfterPlanEnd_onlyTheDayBeforeCounts() {
        // One week: Mon 7 – Sun 13 Sep.
        let outcome = apply(plan([week(1)]), matches: [date(2026, 9, 14)])
        XCTAssertEqual(day(outcome.plan, week: 1, .sunday).sessions[0].sessionType, .technical)
        XCTAssertEqual(outcome.changes.sessions.count, 1)
        XCTAssertTrue(apply(plan([week(1)]), matches: [date(2026, 9, 15)]).changes.isEmpty)
    }

    func test_matchAcrossAdjacentWeeks() {
        let nextMonday = date(2026, 9, 14)
        let outcome = apply(plan([week(1), week(2)]), matches: [nextMonday])
        XCTAssertEqual(day(outcome.plan, week: 1, .sunday).sessions[0].sessionType, .technical)
        XCTAssertTrue(day(outcome.plan, week: 2, .monday).isMatchDay)
        XCTAssertEqual(day(outcome.plan, week: 2, .tuesday).sessions[0].sessionType, .recovery)
        assertHardSessionsClear(of: [nextMonday], in: outcome.plan)
    }

    func test_midWeekAnchor_usesTheRotatedDates() {
        // Anchor Thursday 10 Sep: week 1 = Thu 10 – Wed 16, so week 1's Monday is the 14th.
        let thursday = date(2026, 9, 10)
        let p = plan([week(1), week(2)], start: thursday)
        let outcome = apply(p, matches: [date(2026, 9, 14)], now: thursday)
        XCTAssertTrue(day(outcome.plan, week: 1, .monday).isMatchDay)
        XCTAssertEqual(day(outcome.plan, week: 1, .sunday).sessions[0].sessionType, .technical)
        XCTAssertEqual(day(outcome.plan, week: 1, .tuesday).sessions[0].sessionType, .recovery)
        XCTAssertFalse(day(outcome.plan, week: 2, .monday).isMatchDay, "week 2's Monday is the 21st")
    }

    // MARK: Leave alone

    func test_completedSkippedAndPastDaysAreUntouched() {
        let thursday = date(2026, 9, 10)
        let outcome = apply(plan([week(1, done: [.wednesday], skipped: [.friday])]), matches: [thursday])
        XCTAssertEqual(day(outcome.plan, week: 1, .wednesday).sessions[0].intensity, 5, "completed day keeps what was done")
        XCTAssertEqual(day(outcome.plan, week: 1, .friday).sessions[0].intensity, 5, "skipped day is left alone")
        XCTAssertTrue(day(outcome.plan, week: 1, .thursday).isMatchDay)

        // Now Friday: Thursday's match was yesterday; Thursday is in the past, Friday (today) is recovery.
        let friday = date(2026, 9, 11)
        let later = apply(plan([week(1)]), matches: [thursday], now: friday)
        XCTAssertFalse(day(later.plan, week: 1, .thursday).isRestDay, "past days are history")
        XCTAssertEqual(day(later.plan, week: 1, .wednesday).sessions[0].intensity, 5)
        XCTAssertEqual(day(later.plan, week: 1, .friday).sessions[0].sessionType, .recovery)
    }

    func test_partlyCompletedDayIsUntouched() {
        let thursday = date(2026, 9, 10)
        let wednesday = week(1) { weekday in
            weekday == .wednesday ? [self.session(done: true), self.session()] : []
        }
        let outcome = apply(plan([wednesday]), matches: [thursday])
        XCTAssertEqual(day(outcome.plan, week: 1, .wednesday).sessions.map(\.intensity), [5, 5])
    }

    func test_alreadyLightSessionsAreNotChanged() {
        let thursday = date(2026, 9, 10)
        let light = week(1) { weekday in
            switch weekday {
            case .wednesday: return [self.session(.technical, intensity: 2, duration: 20)]
            case .friday: return [self.session(.recovery, intensity: 1, duration: 25)]
            default: return []
            }
        }
        let outcome = apply(plan([light]), matches: [thursday])
        XCTAssertEqual(outcome.changes.sessions, [])
        XCTAssertEqual(day(outcome.plan, week: 1, .wednesday).sessions[0].notes, "Sprint ladder", "untouched sessions keep their notes")
    }

    func test_everySessionOnTheDayBeforeIsCapped() {
        let thursday = date(2026, 9, 10)
        let double = week(1) { weekday in
            weekday == .wednesday ? [self.session(.tactical, intensity: 4, duration: 45), self.session(.physical, intensity: 5, duration: 90)] : []
        }
        let outcome = apply(plan([double]), matches: [thursday])
        let sessions = day(outcome.plan, week: 1, .wednesday).sessions
        XCTAssertEqual(sessions.map(\.sessionType), [.technical, .technical])
        XCTAssertTrue(sessions.allSatisfy { $0.intensity <= 2 && $0.duration <= 30 })
    }

    // MARK: Idempotent and reversible

    func test_applyingTwiceChangesNothing() {
        let matches = [date(2026, 9, 10), date(2026, 9, 19)]
        let first = apply(plan([week(1), week(2)]), matches: matches)
        XCTAssertFalse(first.changes.isEmpty)
        let second = apply(first.plan, matches: matches)
        XCTAssertTrue(second.changes.isEmpty)
        XCTAssertEqual(second.plan, first.plan)
    }

    func test_movedMatchHandsTheOldDayBack() {
        let first = apply(plan([week(1)]), matches: [date(2026, 9, 10)])
        let moved = apply(first.plan, matches: [date(2026, 9, 12)])
        let thursday = day(moved.plan, week: 1, .thursday)
        XCTAssertFalse(thursday.isRestDay, "Thursday trains again")
        XCTAssertNil(thursday.notes)
        XCTAssertEqual(thursday.sessions.count, 1)
        XCTAssertTrue(day(moved.plan, week: 1, .saturday).isMatchDay)
        XCTAssertEqual(day(moved.plan, week: 1, .sunday).sessions[0].sessionType, .recovery)
        XCTAssertEqual(day(moved.plan, week: 1, .friday).sessions[0].sessionType, .technical)
        // Thursday is now the day before the day before: its session is the original one.
        XCTAssertEqual(thursday.sessions[0].intensity, 5)
    }

    func test_clearedMatchHandsTheDayBackButPlainRestDaysStay() {
        let first = apply(plan([week(1, training: [.monday, .wednesday, .friday])]), matches: [date(2026, 9, 10)])
        let cleared = apply(first.plan, matches: [])
        let thursday = day(cleared.plan, week: 1, .thursday)
        XCTAssertTrue(thursday.isRestDay, "it was a rest day with no sessions")
        XCTAssertNil(thursday.notes)
        XCTAssertTrue(apply(cleared.plan, matches: []).changes.isEmpty)
    }

    // MARK: Assessment

    private func assessmentWeek(on weekday: DayOfWeek, training: Set<DayOfWeek> = Set(DayOfWeek.allCases)) -> PlanWeekModel {
        week(1, training: training) { day in
            day == weekday ? [self.session(.assessment, intensity: 3, duration: 10)] : []
        }
    }

    func test_assessmentOnMatchDayMovesToTheNextFreeTrainingDay() {
        // Match Thursday: Friday is the day after, so the next free day is Saturday.
        let outcome = apply(plan([assessmentWeek(on: .thursday)]), matches: [date(2026, 9, 10)])
        XCTAssertEqual(outcome.changes.moves.count, 1)
        let saturday = day(outcome.plan, week: 1, .saturday)
        XCTAssertEqual(saturday.sessions.map(\.sessionType), [.physical, .assessment])
        XCTAssertEqual(saturday.sessions.last?.orderIndex, 1)
        XCTAssertFalse(day(outcome.plan, week: 1, .thursday).sessions.contains { $0.sessionType == .assessment })
        XCTAssertTrue(day(outcome.plan, week: 1, .thursday).isMatchDay)
    }

    func test_assessmentOnTheDayAfterMovesAndKeepsItsType() {
        let outcome = apply(plan([assessmentWeek(on: .friday)]), matches: [date(2026, 9, 10)])
        let saturday = day(outcome.plan, week: 1, .saturday)
        XCTAssertEqual(saturday.sessions.last?.sessionType, .assessment)
        XCTAssertEqual(saturday.sessions.last?.intensity, 3)
        let friday = day(outcome.plan, week: 1, .friday)
        XCTAssertTrue(friday.sessions.isEmpty)
        XCTAssertTrue(friday.isRestDay, "Friday had only the assessment, so it rests")
    }

    func test_assessmentWithNoLaterDayMovesEarlier() {
        // Match Sunday 13, the week's last day: no later day, so the nearest earlier one (Saturday, the day before, is allowed).
        let outcome = apply(plan([assessmentWeek(on: .sunday, training: [.wednesday, .saturday, .sunday])]), matches: [date(2026, 9, 13)])
        let saturday = day(outcome.plan, week: 1, .saturday)
        XCTAssertEqual(saturday.sessions.last?.sessionType, .assessment, "the day before is a free training day")
        XCTAssertLessThanOrEqual(saturday.sessions.last!.intensity, 2, "but it is capped there")
    }

    func test_assessmentWithNowhereToGoStays() {
        // Only Thursday trains; match Thursday.
        let outcome = apply(plan([assessmentWeek(on: .thursday, training: [.thursday])]), matches: [date(2026, 9, 10)])
        XCTAssertTrue(outcome.changes.moves.isEmpty)
        let thursday = day(outcome.plan, week: 1, .thursday)
        XCTAssertEqual(thursday.sessions.map(\.sessionType), [.assessment], "never deleted")
    }

    func test_assessmentOnTheDayBeforeKeepsItsType() {
        let outcome = apply(plan([assessmentWeek(on: .wednesday)]), matches: [date(2026, 9, 10)])
        let wednesday = day(outcome.plan, week: 1, .wednesday).sessions[0]
        XCTAssertEqual(wednesday.sessionType, .assessment)
        XCTAssertEqual(wednesday.intensity, 2)
        XCTAssertEqual(wednesday.duration, 10)
    }

    func test_assessmentMovesAreIdempotent() {
        let matches = [date(2026, 9, 10)]
        let first = apply(plan([assessmentWeek(on: .thursday)]), matches: matches)
        XCTAssertTrue(apply(first.plan, matches: matches).changes.isEmpty)
    }

    // MARK: Invariant sweep

    func test_noHardSessionWithinADayOfAnyMatch_forEveryMatchDay() {
        for offset in -1...15 {
            let match = calendar.date(byAdding: .day, value: offset, to: monday)!
            let outcome = apply(plan([week(1), week(2)]), matches: [match])
            assertHardSessionsClear(of: [match], in: outcome.plan)
            XCTAssertTrue(apply(outcome.plan, matches: [match]).changes.isEmpty, "idempotent at offset \(offset)")
        }
    }

    func test_twoMatchesCloseTogether_recoveryWinsBetweenThem() {
        // Matches Wed 9 and Fri 11: Thursday is both the day after and the day before.
        let matches = [date(2026, 9, 9), date(2026, 9, 11)]
        let outcome = apply(plan([week(1)]), matches: matches)
        XCTAssertEqual(day(outcome.plan, week: 1, .thursday).sessions[0].sessionType, .recovery)
        XCTAssertEqual(MatchDayRules.role(of: date(2026, 9, 10), matchDates: matches, calendar: calendar), .dayAfter)
        assertHardSessionsClear(of: matches, in: outcome.plan)
    }

    // MARK: Match dates

    func test_relevantMatchDates_keepYesterdayOnDedupedAndSorted() {
        let now = date(2026, 9, 10)
        let dates = MatchDayRules.relevantMatchDates(
            nextMatch: date(2026, 9, 12, hour: 0),
            logged: [date(2026, 9, 9, hour: 18), date(2026, 9, 8), date(2026, 9, 12, hour: 15)],
            now: now, calendar: calendar)
        XCTAssertEqual(dates, [calendar.startOfDay(for: date(2026, 9, 9)), calendar.startOfDay(for: date(2026, 9, 12))])
        XCTAssertEqual(MatchDayRules.relevantMatchDates(nextMatch: nil, logged: [], now: now, calendar: calendar), [])
    }
}

private extension PlanSessionModel {
    func withDone() -> PlanSessionModel {
        PlanSessionModel(id: id, sessionType: sessionType, duration: duration, intensity: intensity, orderIndex: orderIndex, notes: notes,
                         isCompleted: true, completedAt: nil, actualDuration: nil, actualIntensity: nil, exerciseIDs: exerciseIDs)
    }
}
