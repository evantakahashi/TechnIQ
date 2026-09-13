import Foundation

// MARK: - HomeWeekModel
//
// Pure mapping from this week's training sessions + the active plan's dated days onto the seven
// Home week-strip cells (Monday first). Plan days carry calendar dates (see PlanSchedule), so a
// planned day earlier in the week with no session is shown as missed, today is today, and later
// planned days are planned. Skipped days are handed in as not planned, so they read as rest.

enum HomeWeekModel {
    struct PlannedDay {
        var date: Date
        var sessionCount: Int
        var isDone: Bool
    }

    struct Week {
        let cells: [TQDayCell]   // 7 cells, Monday first
        let todayIndex: Int      // 0…6
        let done: Int            // days trained this week
        let target: Int?         // planned training days this week; nil without a plan

        var summary: String {
            if let target {
                return "\(done) / \(max(target, done))"
            }
            return "\(done) / —"
        }
    }

    static func build(today: Date, calendar: Calendar, sessionDates: [Date], plannedDays: [PlannedDay]?) -> Week {
        let todayIndex = mondayIndex(of: today, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: today)
        guard let monday = calendar.date(byAdding: .day, value: -todayIndex, to: startOfToday) else {
            return Week(cells: Array(repeating: .rest, count: 7), todayIndex: todayIndex, done: 0, target: nil)
        }

        func offset(of date: Date) -> Int? {
            let start = calendar.startOfDay(for: date)
            guard let days = calendar.dateComponents([.day], from: monday, to: start).day, (0..<7).contains(days) else { return nil }
            return days
        }

        // Sessions per weekday this week.
        var sessionsPerDay = Array(repeating: 0, count: 7)
        for date in sessionDates {
            if let index = offset(of: date) { sessionsPerDay[index] += 1 }
        }

        // Planned sessions per weekday this week.
        var plannedPerDay = Array(repeating: 0, count: 7)
        var target: Int? = nil
        if let plannedDays {
            var planned = 0
            for day in plannedDays {
                guard let index = offset(of: day.date) else { continue }
                plannedPerDay[index] += max(day.sessionCount, 1)
                planned += 1
            }
            target = planned
        }

        var cells: [TQDayCell] = []
        var done = 0
        for index in 0..<7 {
            let trained = sessionsPerDay[index] > 0
            let planned = plannedPerDay[index] > 0
            let sessions = max(sessionsPerDay[index], plannedPerDay[index])
            let state: TQDayCellState
            if trained {
                state = .done
                done += 1
            } else if index == todayIndex {
                state = .today
            } else if planned && index < todayIndex {
                state = .missed
            } else if planned {
                state = .planned
            } else {
                state = .rest
            }
            cells.append(TQDayCell(state: state, sessions: state == .rest ? 0 : sessions))
        }

        return Week(cells: cells, todayIndex: todayIndex, done: done, target: target)
    }

    /// 0 = Monday … 6 = Sunday regardless of the calendar's first weekday.
    static func mondayIndex(of date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday … 7 = Saturday
        return (weekday + 5) % 7
    }
}
