import XCTest
@testable import TechnIQ

/// Calendar dates on a completion-based plan: where days land, what "today" is, what counts as
/// missed, and which reminders follow from it.
@MainActor
final class PlanScheduleTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    /// Monday 7 Sep 2026 and Saturday 12 Sep 2026 are real weekdays.
    private var monday: Date { date(2026, 9, 7) }
    private var saturday: Date { date(2026, 9, 12) }

    private func plan(weeks: [PlanWeekModel], startedAt: Date?) -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(), name: "Dated", description: "", durationWeeks: weeks.count, difficulty: .beginner, category: .technical,
            targetRole: nil, isPrebuilt: false, isActive: true, currentWeek: 1, progressPercentage: 0,
            startedAt: startedAt, completedAt: nil, createdAt: monday, updatedAt: monday, weeks: weeks
        )
    }

    private func mark(_ week: PlanWeekModel, done: Set<DayOfWeek> = [], skipped: Set<DayOfWeek> = []) -> PlanWeekModel {
        let days = week.days.map { day -> PlanDayModel in
            PlanDayModel(
                id: day.id, dayNumber: day.dayNumber, dayOfWeek: day.dayOfWeek, isRestDay: day.isRestDay,
                isSkipped: day.dayOfWeek.map(skipped.contains) ?? false, notes: day.notes,
                isCompleted: day.dayOfWeek.map(done.contains) ?? false, completedAt: nil, sessions: day.sessions
            )
        }
        return PlanWeekModel(id: week.id, weekNumber: week.weekNumber, focusArea: week.focusArea, notes: week.notes, isCompleted: false, completedAt: nil, days: days)
    }

    // MARK: Dates

    func test_dates_mondayAnchorPinsWeekdaysInsideEachWeek() {
        let weeks = TrainingPlanService.templateWeeks(count: 2, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: weeks, startedAt: monday)
        let entries = PlanSchedule.trainingDays(in: p, startDate: PlanSchedule.startDate(of: p), calendar: calendar)
        XCTAssertEqual(entries.map { calendar.startOfDay(for: $0.date) },
                       [date(2026, 9, 7), date(2026, 9, 10), date(2026, 9, 14), date(2026, 9, 17)].map { calendar.startOfDay(for: $0) })
        XCTAssertEqual(entries.map { "\($0.week.weekNumber):\($0.day.dayOfWeek!.shortName)" }, ["1:Mon", "1:Thu", "2:Mon", "2:Thu"])
    }

    func test_dates_saturdayAnchorRotatesTheWeekSoNothingIsMissedOnDayOne() {
        // Plan trains Mon and Sat; created on a Saturday. Saturday's session is today, Monday's is in two days.
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .saturday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: weeks, startedAt: saturday)
        let entries = PlanSchedule.trainingDays(in: p, startDate: saturday, calendar: calendar)
        XCTAssertEqual(entries.map { $0.day.dayOfWeek }, [.saturday, .monday])
        XCTAssertEqual(calendar.startOfDay(for: entries[1].date), calendar.startOfDay(for: date(2026, 9, 14)))
        XCTAssertEqual(PlanSchedule.missedCount(in: p, startDate: saturday, now: saturday, calendar: calendar), 0)
        XCTAssertEqual(PlanSchedule.today(in: p, startDate: saturday, now: saturday, calendar: calendar),
                       .session(week: 1, day: entries[0].day.dayNumber, scheduled: calendar.startOfDay(for: saturday), overdue: false))
    }

    func test_dates_unpinnedDaysCountFromTheWeekStart() {
        let start = calendar.startOfDay(for: saturday)
        XCTAssertEqual(PlanSchedule.date(week: 1, dayNumber: 3, dayOfWeek: nil, startDate: saturday, calendar: calendar),
                       calendar.date(byAdding: .day, value: 2, to: start))
        XCTAssertEqual(PlanSchedule.date(week: 2, dayNumber: 1, dayOfWeek: nil, startDate: saturday, calendar: calendar),
                       calendar.date(byAdding: .day, value: 7, to: start))
    }

    func test_startDate_prefersActivationOverCreation() {
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday], sessionType: .technical, difficulty: .beginner, focus: [])
        XCTAssertEqual(PlanSchedule.startDate(of: plan(weeks: weeks, startedAt: saturday)), saturday)
        XCTAssertEqual(PlanSchedule.startDate(of: plan(weeks: weeks, startedAt: nil)), monday)
    }

    // MARK: Today

    func test_today_restDayPointsAtTheNextSession() {
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: [mark(weeks[0], done: [.monday])], startedAt: monday)
        let tuesday = date(2026, 9, 8)
        let state = PlanSchedule.today(in: p, startDate: monday, now: tuesday, calendar: calendar)
        guard case .rest(let next) = state else { return XCTFail("expected rest, got \(state)") }
        XCTAssertEqual(next?.week, 1)
        XCTAssertEqual(next.map { calendar.startOfDay(for: $0.date) }, calendar.startOfDay(for: date(2026, 9, 10)))
        XCTAssertEqual(PlanSchedule.label(for: next!.date, now: tuesday, calendar: calendar), "Thu")
    }

    func test_today_missedSessionShiftsForwardAsOverdue() {
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: weeks, startedAt: monday)
        let wednesday = date(2026, 9, 9)
        let state = PlanSchedule.today(in: p, startDate: monday, now: wednesday, calendar: calendar)
        guard case .session(let week, _, let scheduled, let overdue) = state else { return XCTFail("expected session, got \(state)") }
        XCTAssertEqual(week, 1)
        XCTAssertTrue(overdue, "Monday went by untrained, so it is today's catch-up")
        XCTAssertEqual(calendar.startOfDay(for: scheduled), calendar.startOfDay(for: monday))
        XCTAssertEqual(PlanSchedule.missedCount(in: p, startDate: monday, now: wednesday, calendar: calendar), 1)
    }

    func test_today_skippedDaysAreNeitherDueNorMissed_andCompleteWhenAllDone() {
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        let skippedMonday = plan(weeks: [mark(weeks[0], skipped: [.monday])], startedAt: monday)
        let wednesday = date(2026, 9, 9)
        XCTAssertEqual(PlanSchedule.missedCount(in: skippedMonday, startDate: monday, now: wednesday, calendar: calendar), 0)
        guard case .rest = PlanSchedule.today(in: skippedMonday, startDate: monday, now: wednesday, calendar: calendar) else {
            return XCTFail("a skipped Monday leaves Wednesday a rest day before Thursday")
        }
        let allDone = plan(weeks: [mark(weeks[0], done: [.monday, .thursday])], startedAt: monday)
        XCTAssertEqual(PlanSchedule.today(in: allDone, startDate: monday, now: wednesday, calendar: calendar), .complete)
    }

    func test_label_buckets() {
        let now = saturday
        XCTAssertEqual(PlanSchedule.label(for: now, now: now, calendar: calendar), "Today")
        XCTAssertEqual(PlanSchedule.label(for: date(2026, 9, 13), now: now, calendar: calendar), "Tomorrow")
        XCTAssertEqual(PlanSchedule.label(for: date(2026, 9, 15), now: now, calendar: calendar), "Tue")
        XCTAssertEqual(PlanSchedule.label(for: date(2026, 9, 25), now: now, calendar: calendar), "Fri 25 Sep")
        XCTAssertEqual(PlanSchedule.label(for: date(2026, 9, 10), now: now, calendar: calendar), "Overdue")
    }

    func test_peekCurrentDay_followsTheCalendarOrder() {
        // Saturday anchor: Saturday (day 6) comes before Monday (day 1) even though its day number is higher.
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .saturday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: weeks, startedAt: saturday)
        XCTAssertEqual(TrainingPlanService.peekCurrentDay(in: p)?.day.dayOfWeek, .saturday)
    }

    // MARK: Reminders

    func test_reminders_followTrainingDaysAndStreak() {
        let weeks = TrainingPlanService.templateWeeks(count: 1, trainingDays: [.monday, .thursday], sessionType: .technical, difficulty: .beginner, focus: [])
        let p = plan(weeks: weeks, startedAt: monday)
        let settings = ReminderSettings(trainingDays: true, streakAtRisk: true, hour: 17, minute: 0)
        let planned = NotificationManager.plan(plan: p, streak: 4, trainedToday: false, settings: settings, now: monday, calendar: calendar)
        let ids = planned.map(\.identifier)
        XCTAssertEqual(planned.filter { $0.identifier.hasPrefix(NotificationManager.Identifier.planDayPrefix) }.count, 2, "Monday 17:00 (still ahead at noon) and Thursday")
        XCTAssertTrue(ids.contains(NotificationManager.Identifier.streakAtRisk))
        XCTAssertFalse(ids.contains(NotificationManager.Identifier.dailyReminder), "a plan replaces the blanket daily nudge")
        XCTAssertEqual(planned.first?.body, "Technical session · 30 min · week 1")
        XCTAssertEqual(calendar.component(.hour, from: planned.first!.fireDate), 17)
    }

    func test_reminders_dailyNudgeWithoutAPlan_andNothingWhenOff() {
        let on = ReminderSettings(trainingDays: true, streakAtRisk: true, hour: 8, minute: 30)
        let planned = NotificationManager.plan(plan: nil, streak: 0, trainedToday: false, settings: on, now: monday, calendar: calendar)
        XCTAssertEqual(planned.map(\.identifier), [NotificationManager.Identifier.dailyReminder], "no streak nudge at streak 0")
        XCTAssertTrue(planned[0].repeats)
        XCTAssertEqual(calendar.component(.minute, from: planned[0].fireDate), 30)

        let off = ReminderSettings(trainingDays: false, streakAtRisk: false, hour: 8, minute: 30)
        XCTAssertTrue(NotificationManager.plan(plan: nil, streak: 5, trainedToday: false, settings: off, now: monday, calendar: calendar).isEmpty)
    }

    func test_reminders_streakNudgeSkippedOnceTrainedOrPastTheEvening() {
        let settings = ReminderSettings(trainingDays: false, streakAtRisk: true, hour: 17, minute: 0)
        XCTAssertTrue(NotificationManager.plan(plan: nil, streak: 3, trainedToday: true, settings: settings, now: monday, calendar: calendar).isEmpty)
        let lateEvening = date(2026, 9, 7, hour: 21)
        XCTAssertTrue(NotificationManager.plan(plan: nil, streak: 3, trainedToday: false, settings: settings, now: lateEvening, calendar: calendar).isEmpty)
    }

    func test_reminderSettings_roundTripAndLabel() {
        let suite = "PlanScheduleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertEqual(ReminderSettings.load(from: defaults), ReminderSettings())
        var settings = ReminderSettings()
        settings.trainingDays = false
        settings.hour = 6
        settings.minute = 45
        settings.save(to: defaults)
        XCTAssertEqual(ReminderSettings.load(from: defaults), settings)
        XCTAssertEqual(calendar.component(.hour, from: settings.fireDate(on: monday, calendar: calendar)!), 6)
    }
}
