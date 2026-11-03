import Foundation

// MARK: - MatchScheduleLink
//
// Ties logged matches and the upcoming one to the dated plan (PlanSchedule) and the Home week:
// which plan day is a match day, which logged match belongs to which plan day, and the two small
// match-log rules (default date, when logging clears the next match). Pure, calendar-injected.

enum MatchScheduleLink {
    struct LoggedMatch: Equatable {
        let id: UUID
        let date: Date
        let opponent: String?
    }

    enum Mark: Equatable {
        /// A match already logged on that day.
        case logged(opponent: String?)
        /// The profile's next match.
        case upcoming

        /// "Match vs Northside", "Match", "Match day".
        var label: String {
            switch self {
            case .logged(let opponent):
                let name = (opponent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? "Match" : "Match vs \(name)"
            case .upcoming:
                return MatchDayRules.matchDayNote
            }
        }
    }

    /// Match marks by start of day. A logged match wins over the upcoming one on the same day.
    static func marks(matches: [LoggedMatch], nextMatchDate: Date?, calendar: Calendar) -> [Date: Mark] {
        var result: [Date: Mark] = [:]
        if let nextMatchDate { result[calendar.startOfDay(for: nextMatchDate)] = .upcoming }
        for match in matches.sorted(by: { $0.date < $1.date }) {
            result[calendar.startOfDay(for: match.date)] = .logged(opponent: match.opponent)
        }
        return result
    }

    struct DayMark: Equatable {
        let week: Int
        let dayNumber: Int
        let dayID: UUID
        let date: Date
        let mark: Mark
    }

    /// Every plan day (rest days included) that falls on a match day, in date order.
    static func dayMarks(in plan: TrainingPlanModel, startDate: Date, matches: [LoggedMatch], nextMatchDate: Date?, calendar: Calendar) -> [DayMark] {
        let byDay = marks(matches: matches, nextMatchDate: nextMatchDate, calendar: calendar)
        guard !byDay.isEmpty else { return [] }
        var result: [DayMark] = []
        for week in plan.weeks {
            for day in week.days {
                let date = calendar.startOfDay(for: PlanSchedule.date(of: day, in: week, startDate: startDate, calendar: calendar))
                if let mark = byDay[date] {
                    result.append(DayMark(week: week.weekNumber, dayNumber: day.dayNumber, dayID: day.id, date: date, mark: mark))
                }
            }
        }
        return result.sorted { ($0.date, $0.week, $0.dayNumber) < ($1.date, $1.week, $1.dayNumber) }
    }

    /// The plan day a logged match was played on, if the plan covers that date.
    static func planDay(for match: LoggedMatch, in plan: TrainingPlanModel, startDate: Date, calendar: Calendar) -> (week: Int, dayNumber: Int)? {
        let target = calendar.startOfDay(for: match.date)
        for week in plan.weeks {
            for day in week.days where calendar.startOfDay(for: PlanSchedule.date(of: day, in: week, startDate: startDate, calendar: calendar)) == target {
                return (week.weekNumber, day.dayNumber)
            }
        }
        return nil
    }

    /// Indexes 0…6 (Monday first) of this week's days that carry a match.
    static func weekMatchIndexes(today: Date, matches: [LoggedMatch], nextMatchDate: Date?, calendar: Calendar) -> Set<Int> {
        let todayIndex = HomeWeekModel.mondayIndex(of: today, calendar: calendar)
        guard let monday = calendar.date(byAdding: .day, value: -todayIndex, to: calendar.startOfDay(for: today)) else { return [] }
        var indexes = Set<Int>()
        for day in marks(matches: matches, nextMatchDate: nextMatchDate, calendar: calendar).keys {
            if let offset = calendar.dateComponents([.day], from: monday, to: day).day, (0..<7).contains(offset) {
                indexes.insert(offset)
            }
        }
        return indexes
    }

    // MARK: Match log

    /// The match log opens on the next match's date when that is today or up to two days back
    /// (logging a match just played); otherwise on today.
    static func defaultLogDate(nextMatchDate: Date?, now: Date, calendar: Calendar) -> Date {
        guard let nextMatchDate else { return now }
        let today = calendar.startOfDay(for: now)
        let match = calendar.startOfDay(for: nextMatchDate)
        guard let days = calendar.dateComponents([.day], from: match, to: today).day, (0...2).contains(days) else { return now }
        return days == 0 ? now : nextMatchDate
    }

    /// A match logged on or after the next match's day means that match was played.
    static func clearsNextMatch(loggedOn date: Date, nextMatchDate: Date?, calendar: Calendar) -> Bool {
        guard let nextMatchDate else { return false }
        return calendar.startOfDay(for: date) >= calendar.startOfDay(for: nextMatchDate)
    }

    /// The next match for display and the rules: dropped once its day has passed.
    static func upcoming(_ nextMatchDate: Date?, now: Date, calendar: Calendar) -> Date? {
        guard let nextMatchDate, calendar.startOfDay(for: nextMatchDate) >= calendar.startOfDay(for: now) else { return nil }
        return nextMatchDate
    }
}

extension Match {
    /// This match as a schedule-link input; nil without an id or date.
    var scheduleLink: MatchScheduleLink.LoggedMatch? {
        guard let id, let date else { return nil }
        return MatchScheduleLink.LoggedMatch(id: id, date: date, opponent: opponent)
    }
}
