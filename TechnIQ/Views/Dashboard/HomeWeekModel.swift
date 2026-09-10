import Foundation

// MARK: - HomeWeekModel
//
// Pure mapping from this week's training sessions + the active plan's current week onto the
// seven Home week-strip cells (Monday first). Plans are completion-based, not calendar-based,
// so plan days with no weekday are laid out from today forward.

enum HomeWeekModel {
    struct PlanDay {
        var weekday: Int?        // 1 = Monday … 7 = Sunday, nil when the plan doesn't pin days
        var isRest: Bool
        var isCompleted: Bool
        var sessionCount: Int
    }

    struct PlanWeek {
        var days: [PlanDay]
    }

    struct Week {
        let cells: [TQDayCell]   // 7 cells, Monday first
        let todayIndex: Int      // 0…6
        let done: Int            // days trained this week
        let target: Int?         // training days in the plan week; nil without a plan

        var summary: String {
            if let target {
                return "\(done) / \(max(target, done))"
            }
            return "\(done) / —"
        }
    }

    static func build(today: Date, calendar: Calendar, sessionDates: [Date], plan: PlanWeek?) -> Week {
        let todayIndex = mondayIndex(of: today, calendar: calendar)
        let startOfToday = calendar.startOfDay(for: today)
        guard let monday = calendar.date(byAdding: .day, value: -todayIndex, to: startOfToday) else {
            return Week(cells: Array(repeating: .rest, count: 7), todayIndex: todayIndex, done: 0, target: nil)
        }

        // Sessions per weekday this week.
        var sessionsPerDay = Array(repeating: 0, count: 7)
        for date in sessionDates {
            let start = calendar.startOfDay(for: date)
            guard let offset = calendar.dateComponents([.day], from: monday, to: start).day, (0..<7).contains(offset) else { continue }
            sessionsPerDay[offset] += 1
        }

        // Planned sessions per weekday: pinned weekdays first, unpinned days laid out from today.
        var plannedPerDay = Array(repeating: 0, count: 7)
        var target: Int? = nil
        if let plan {
            let trainingDays = plan.days.filter { !$0.isRest }
            target = trainingDays.count
            var cursor = todayIndex
            for day in trainingDays {
                if let weekday = day.weekday, (1...7).contains(weekday) {
                    plannedPerDay[weekday - 1] += max(day.sessionCount, 1)
                } else if !day.isCompleted {
                    // Unpinned, still to do: fill today and the following days in order.
                    while cursor < 7 && (sessionsPerDay[cursor] > 0 || plannedPerDay[cursor] > 0) { cursor += 1 }
                    guard cursor < 7 else { break }
                    plannedPerDay[cursor] += max(day.sessionCount, 1)
                    cursor += 1
                }
            }
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
