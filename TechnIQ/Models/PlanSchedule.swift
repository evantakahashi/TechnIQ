import Foundation

// MARK: - PlanSchedule
//
// Puts calendar dates on a plan. Progression stays completion-based (the next thing to do is
// always the first day not yet done), but every day also has a date: week n covers the seven days
// from the plan's start date + 7(n−1); a day pinned to a weekday lands on that weekday's first
// occurrence inside its week; an unpinned day counts from the start of its week. With dates the
// app can say "Rest day · next Thu", mark a missed Monday as missed, and remind on training days.
// Missed sessions shift forward: the first incomplete day is today's session whatever its date.

enum PlanSchedule {
    struct Next: Equatable {
        let week: Int
        let day: Int
        let date: Date
    }

    enum Today: Equatable {
        /// A session is due: today's, or an earlier one not yet done (`overdue`).
        case session(week: Int, day: Int, scheduled: Date, overdue: Bool)
        /// Nothing due today; the next session (if any) is in the future.
        case rest(next: Next?)
        /// Every day is done.
        case complete
    }

    /// The plan's calendar anchor: activation, else creation.
    static func startDate(of plan: TrainingPlanModel) -> Date {
        plan.startedAt ?? plan.createdAt
    }

    /// Date of a plan day. Week windows are seven days long starting on the anchor's day.
    static func date(week: Int, dayNumber: Int, dayOfWeek: DayOfWeek?, startDate: Date, calendar: Calendar) -> Date {
        let anchor = calendar.startOfDay(for: startDate)
        let weekStart = calendar.date(byAdding: .day, value: 7 * max(week - 1, 0), to: anchor) ?? anchor
        guard let dayOfWeek else {
            return calendar.date(byAdding: .day, value: max(dayNumber - 1, 0), to: weekStart) ?? weekStart
        }
        let startIndex = HomeWeekModel.mondayIndex(of: weekStart, calendar: calendar)   // 0 = Monday
        let offset = (dayOfWeek.sortOrder - startIndex + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart
    }

    static func date(of day: PlanDayModel, in week: PlanWeekModel, startDate: Date, calendar: Calendar) -> Date {
        date(week: week.weekNumber, dayNumber: day.dayNumber, dayOfWeek: day.dayOfWeek, startDate: startDate, calendar: calendar)
    }

    struct Entry {
        let week: PlanWeekModel
        let day: PlanDayModel
        let date: Date
    }

    /// Every non-rest day in calendar order (date, then week and day number). With a mid-week
    /// anchor the days of a plan week rotate so that the calendar, not the day number, rules.
    static func trainingDays(in plan: TrainingPlanModel, startDate: Date, calendar: Calendar) -> [Entry] {
        var entries: [Entry] = []
        for week in plan.weeks {
            for day in week.days where !day.isRestDay {
                entries.append(Entry(week: week, day: day, date: date(of: day, in: week, startDate: startDate, calendar: calendar)))
            }
        }
        return entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date < rhs.date }
            if lhs.week.weekNumber != rhs.week.weekNumber { return lhs.week.weekNumber < rhs.week.weekNumber }
            return lhs.day.dayNumber < rhs.day.dayNumber
        }
    }

    static func today(in plan: TrainingPlanModel, startDate: Date, now: Date, calendar: Calendar) -> Today {
        let todayStart = calendar.startOfDay(for: now)
        guard let next = trainingDays(in: plan, startDate: startDate, calendar: calendar).first(where: { !$0.day.isDone }) else {
            return .complete
        }
        if next.date <= todayStart {
            return .session(week: next.week.weekNumber, day: next.day.dayNumber, scheduled: next.date, overdue: next.date < todayStart)
        }
        return .rest(next: Next(week: next.week.weekNumber, day: next.day.dayNumber, date: next.date))
    }

    /// Days whose date has passed without being done or skipped.
    static func missedCount(in plan: TrainingPlanModel, startDate: Date, now: Date, calendar: Calendar) -> Int {
        let todayStart = calendar.startOfDay(for: now)
        return trainingDays(in: plan, startDate: startDate, calendar: calendar)
            .filter { !$0.day.isDone && $0.date < todayStart }
            .count
    }

    /// Upcoming training days from today on, for reminders and previews.
    static func upcoming(in plan: TrainingPlanModel, startDate: Date, now: Date, calendar: Calendar, limit: Int) -> [Entry] {
        let todayStart = calendar.startOfDay(for: now)
        return Array(trainingDays(in: plan, startDate: startDate, calendar: calendar)
            .filter { !$0.day.isDone && $0.date >= todayStart }
            .prefix(limit))
    }

    /// "Today", "Tomorrow", "Thu", or "Thu 18 Sep" once it is more than a week out.
    static func label(for date: Date, now: Date, calendar: Calendar) -> String {
        let todayStart = calendar.startOfDay(for: now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: todayStart, to: target).day ?? 0
        switch days {
        case ..<0: return "Overdue"
        case 0: return "Today"
        case 1: return "Tomorrow"
        case 2...6:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "EEE"
            return formatter.string(from: target)
        default:
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "EEE d MMM"
            return formatter.string(from: target)
        }
    }
}
