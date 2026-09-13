import Foundation

// MARK: - PlayerRecords
//
// Personal bests and a this-week-vs-last-week line, from plain session facts so the You tab and
// Progress agree and the numbers can be unit-tested. Weeks run Monday to Sunday.

struct PlayerRecords: Equatable {
    struct SessionFact: Equatable {
        var date: Date
        var minutes: Int
        var drillCount: Int
    }

    struct WeekComparison: Equatable {
        let thisWeekSessions: Int
        let lastWeekSessions: Int
        let thisWeekMinutes: Int
        let lastWeekMinutes: Int

        /// "3 sessions · 1 more than last week" / "2 sessions · same as last week" / "No sessions yet this week".
        var line: String {
            guard thisWeekSessions > 0 else {
                return lastWeekSessions > 0 ? "No sessions yet this week · \(lastWeekSessions) last week" : "No sessions yet this week"
            }
            return "\(thisWeekSessions) session\(thisWeekSessions == 1 ? "" : "s") · \(delta)"
        }

        /// The comparison alone, for under a headline that already carries the count:
        /// "1 more than last week" / "same as last week" / "3 last week".
        var delta: String {
            guard thisWeekSessions > 0 else {
                return lastWeekSessions > 0 ? "\(lastWeekSessions) last week" : "None last week either"
            }
            let difference = thisWeekSessions - lastWeekSessions
            switch difference {
            case 0: return "same as last week"
            case 1...: return "\(difference) more than last week"
            default: return "\(-difference) fewer than last week"
            }
        }
    }

    let longestSessionMinutes: Int
    let longestSessionDate: Date?
    let bestWeekSessions: Int
    let bestWeekStart: Date?
    let mostDrillsInADay: Int
    let mostDrillsDate: Date?
    let totalSessions: Int
    let comparison: WeekComparison

    static func build(sessions: [SessionFact], now: Date, calendar: Calendar) -> PlayerRecords {
        let longest = sessions.max { ($0.minutes, $0.date) < ($1.minutes, $1.date) }

        var byWeek: [Date: Int] = [:]
        var byDay: [Date: Int] = [:]
        for session in sessions {
            byWeek[weekStart(of: session.date, calendar: calendar), default: 0] += 1
            byDay[calendar.startOfDay(for: session.date), default: 0] += session.drillCount
        }
        let bestWeek = byWeek.max { ($0.value, $0.key) < ($1.value, $1.key) }
        let bestDay = byDay.max { ($0.value, $0.key) < ($1.value, $1.key) }

        let thisWeekStart = weekStart(of: now, calendar: calendar)
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart) ?? thisWeekStart
        let thisWeek = sessions.filter { weekStart(of: $0.date, calendar: calendar) == thisWeekStart }
        let lastWeek = sessions.filter { weekStart(of: $0.date, calendar: calendar) == lastWeekStart }

        return PlayerRecords(
            longestSessionMinutes: longest?.minutes ?? 0,
            longestSessionDate: longest?.date,
            bestWeekSessions: bestWeek?.value ?? 0,
            bestWeekStart: bestWeek?.key,
            mostDrillsInADay: bestDay?.value ?? 0,
            mostDrillsDate: bestDay?.key,
            totalSessions: sessions.count,
            comparison: WeekComparison(
                thisWeekSessions: thisWeek.count,
                lastWeekSessions: lastWeek.count,
                thisWeekMinutes: thisWeek.reduce(0) { $0 + $1.minutes },
                lastWeekMinutes: lastWeek.reduce(0) { $0 + $1.minutes }
            )
        )
    }

    /// Monday 00:00 of the week containing `date`, regardless of the calendar's first weekday.
    static func weekStart(of date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        let offset = HomeWeekModel.mondayIndex(of: start, calendar: calendar)
        return calendar.date(byAdding: .day, value: -offset, to: start) ?? start
    }
}
