import Foundation

/// A saved run, as the trends see it (`CameraRun` without Core Data).
struct TrendRun: Equatable {
    var drill: CameraDrill
    var count: Int
    var date: Date
    var endReason: RunEndReason?
    var stats: RunStats?
}

/// Trends over saved runs: the value of logging that costs the player nothing. Pure.
enum CameraTrends {
    struct DayBest: Equatable {
        var day: Date
        var best: Int
    }

    struct Ending: Equatable {
        var reason: RunEndReason
        var count: Int
    }

    struct DayShare: Equatable {
        var day: Date
        /// Left-foot touches / all foot touches that day.
        var share: Double
    }

    struct DayTempo: Equatable {
        var day: Date
        var touchesPerMinute: Double
    }

    /// The best run of each day, oldest first: the chart line.
    static func dailyBests(_ runs: [TrendRun], drill: CameraDrill, calendar: Calendar = .current) -> [DayBest] {
        byDay(runs, drill: drill, calendar: calendar).map { DayBest(day: $0.day, best: $0.runs.map(\.count).max() ?? 0) }
    }

    /// "Weak-foot juggling: 8 → 23 in 3 weeks": best of the first week vs best of the last week, once there's
    /// at least a week of history and a real gain (3+ touches and 20%+).
    static func headline(_ runs: [TrendRun], drill: CameraDrill) -> String? {
        let mine = runs.filter { $0.drill == drill }.sorted { $0.date < $1.date }
        guard let first = mine.first?.date, let last = mine.last?.date else { return nil }
        let week = 7 * 86_400.0
        let span = last.timeIntervalSince(first)
        guard span >= week else { return nil }
        let from = mine.filter { $0.date.timeIntervalSince(first) < week }.map(\.count).max() ?? 0
        let to = mine.filter { last.timeIntervalSince($0.date) < week }.map(\.count).max() ?? 0
        guard to - from >= 3, Double(to) >= Double(from) * 1.2 else { return nil }
        let weeks = max(1, Int((span / week).rounded()))
        return "\(drill.title): \(from) → \(to) in \(weeks) week\(weeks == 1 ? "" : "s")"
    }

    /// How runs end, most common first: where the player keeps failing.
    static func endings(_ runs: [TrendRun], drill: CameraDrill) -> [Ending] {
        let reasons = runs.filter { $0.drill == drill }.compactMap(\.endReason).filter { $0 != .stopped }
        return Dictionary(grouping: reasons, by: { $0 })
            .map { Ending(reason: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.reason.rawValue < $1.reason.rawValue }
    }

    /// Share of foot touches made with the left foot, per day (days with 4+ foot touches).
    static func leftFootShare(_ runs: [TrendRun], drill: CameraDrill, calendar: Calendar = .current) -> [DayShare] {
        byDay(runs, drill: drill, calendar: calendar).compactMap { day in
            let left = day.runs.compactMap(\.stats).map(\.leftFoot).reduce(0, +)
            let right = day.runs.compactMap(\.stats).map(\.rightFoot).reduce(0, +)
            guard left + right >= 4 else { return nil }
            return DayShare(day: day.day, share: Double(left) / Double(left + right))
        }
    }

    /// Average touches a minute per day.
    static func tempo(_ runs: [TrendRun], drill: CameraDrill, calendar: Calendar = .current) -> [DayTempo] {
        byDay(runs, drill: drill, calendar: calendar).compactMap { day in
            let rates = day.runs.compactMap { $0.stats?.touchesPerMinute }
            guard !rates.isEmpty else { return nil }
            return DayTempo(day: day.day, touchesPerMinute: rates.reduce(0, +) / Double(rates.count))
        }
    }

    private static func byDay(_ runs: [TrendRun], drill: CameraDrill, calendar: Calendar) -> [(day: Date, runs: [TrendRun])] {
        Dictionary(grouping: runs.filter { $0.drill == drill }) { calendar.startOfDay(for: $0.date) }
            .map { (day: $0.key, runs: $0.value) }
            .sorted { $0.day < $1.day }
    }
}
