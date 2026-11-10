import Foundation

// MARK: - Progress summary
//
// The pure numbers behind You → Progress: totals for a time range, minutes per bucket (days for a
// week, weeks otherwise), how sessions felt and which skills the drills trained. Views hand in
// plain facts; nothing here touches Core Data.

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 months"
    case all = "All time"

    var displayName: String { rawValue }

    /// First instant inside the range; nil = everything.
    func start(from now: Date, calendar: Calendar) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .week: return calendar.date(byAdding: .day, value: -6, to: today)
        case .month: return calendar.date(byAdding: .day, value: -29, to: today)
        case .threeMonths: return calendar.date(byAdding: .day, value: -90, to: today)
        case .all: return nil
        }
    }
}

struct ProgressSummary: Equatable {
    struct SessionFact: Equatable {
        let date: Date
        let minutes: Int
        let feel: SessionFeel?
        let skills: [String]
    }

    struct Bucket: Identifiable, Equatable {
        let start: Date
        let label: String
        let minutes: Int
        let sessions: Int
        let isCurrent: Bool
        var id: Date { start }
    }

    struct SkillShare: Identifiable, Equatable {
        let name: String
        let count: Int
        /// 0…1 of the most-trained skill, for the bar.
        let share: Double
        var id: String { name }
    }

    let totalSessions: Int
    let totalMinutes: Int
    let sessionsPerWeek: Double
    let buckets: [Bucket]
    let feel: [SessionFeel: Int]
    let skills: [SkillShare]

    var isEmpty: Bool { totalSessions == 0 }
    var feelTotal: Int { feel.values.reduce(0, +) }

    /// "4 h 05" above an hour, "45 min" below.
    var timeValue: (value: String, unit: String) {
        totalMinutes >= 60 ? (String(format: "%.1f", Double(totalMinutes) / 60), "h") : ("\(totalMinutes)", "min")
    }

    var averageBucketMinutes: Int {
        guard !buckets.isEmpty else { return 0 }
        return Int((Double(buckets.map(\.minutes).reduce(0, +)) / Double(buckets.count)).rounded())
    }

    static func build(facts: [SessionFact], range: TimeRange, now: Date, calendar: Calendar) -> ProgressSummary {
        let start = range.start(from: now, calendar: calendar)
        let inRange = facts.filter { fact in
            guard fact.date <= now else { return false }
            guard let start else { return true }
            return fact.date >= start
        }

        let buckets = makeBuckets(facts: inRange, range: range, now: now, calendar: calendar)

        var feel: [SessionFeel: Int] = [:]
        var skillCounts: [String: Int] = [:]
        for fact in inRange {
            if let felt = fact.feel { feel[felt, default: 0] += 1 }
            for skill in fact.skills {
                let name = skill.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { skillCounts[name.capitalized, default: 0] += 1 }
            }
        }
        let top = skillCounts.values.max() ?? 0
        let skills = skillCounts
            .map { SkillShare(name: $0.key, count: $0.value, share: top > 0 ? Double($0.value) / Double(top) : 0) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }

        // Span in weeks: the range's length, or first session → now for "all time".
        let spanStart = start ?? inRange.map(\.date).min() ?? now
        let days = max(1, (calendar.dateComponents([.day], from: calendar.startOfDay(for: spanStart), to: now).day ?? 0) + 1)
        let weeks = max(1, Double(days) / 7)

        return ProgressSummary(
            totalSessions: inRange.count,
            totalMinutes: inRange.map(\.minutes).reduce(0, +),
            sessionsPerWeek: Double(inRange.count) / weeks,
            buckets: buckets,
            feel: feel,
            skills: Array(skills.prefix(6))
        )
    }

    /// Days for the week range; otherwise calendar weeks (5 for a month, 13 for three months,
    /// up to 26 for all time).
    private static func makeBuckets(facts: [SessionFact], range: TimeRange, now: Date, calendar: Calendar) -> [Bucket] {
        let today = calendar.startOfDay(for: now)
        if range == .week {
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.locale = calendar.locale ?? .current
            formatter.dateFormat = "EEEEE"
            return (0..<7).reversed().compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                      let next = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                let hits = facts.filter { $0.date >= day && $0.date < next }
                return Bucket(start: day, label: formatter.string(from: day), minutes: hits.map(\.minutes).reduce(0, +),
                              sessions: hits.count, isCurrent: offset == 0)
            }
        }

        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let count: Int
        switch range {
        case .month: count = 5
        case .threeMonths: count = 13
        default:
            let first = facts.map(\.date).min() ?? now
            let firstWeek = calendar.dateInterval(of: .weekOfYear, for: first)?.start ?? thisWeek
            let span = (calendar.dateComponents([.day], from: firstWeek, to: thisWeek).day ?? 0) / 7 + 1
            count = min(26, max(8, span))
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? .current
        formatter.dateFormat = "d MMM"
        return (0..<count).reversed().compactMap { offset in
            guard let week = calendar.date(byAdding: .day, value: -7 * offset, to: thisWeek),
                  let next = calendar.date(byAdding: .day, value: 7, to: week) else { return nil }
            let hits = facts.filter { $0.date >= week && $0.date < next }
            return Bucket(start: week, label: formatter.string(from: week), minutes: hits.map(\.minutes).reduce(0, +),
                          sessions: hits.count, isCurrent: offset == 0)
        }
    }
}
