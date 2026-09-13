import Foundation

// MARK: - CoachIdentity
//
// The player names their coach. The name fronts every coach surface (Home note, Train strip,
// suggestions, the weekly review, Progress tips, the generator) and is sent to the functions so
// the model speaks as that coach.

enum CoachIdentity {
    static let defaultName = "Coach"
    private static let key = "coach.name"

    static func name(from defaults: UserDefaults = .standard) -> String {
        let stored = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return stored.isEmpty ? defaultName : String(stored.prefix(24))
    }

    static func setName(_ value: String, in defaults: UserDefaults = .standard) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == defaultName {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(String(trimmed.prefix(24)), forKey: key)
        }
    }

    /// "Coach" → "the coach"; "Marta" → "Marta". For sentences like "Built by \(possessive)".
    static func possessive(from defaults: UserDefaults = .standard) -> String {
        let value = name(from: defaults)
        return value == defaultName ? "the coach's" : "\(value)'s"
    }
}

// MARK: - WeekRecap
//
// The numbers the weekly review opens with, computed from the plan week and the sessions that
// fell inside its dates. Pure, so the review can be tested without Core Data.

struct WeekRecap: Equatable {
    struct Session: Equatable {
        var date: Date
        var minutes: Int
        var rating: Int          // 1–5 overall, 0 when unrated
        var drillNames: [String]
        var drillRatings: [String: Int]   // name → 1–5
    }

    let weekNumber: Int
    let planned: Int
    let done: Int
    let missed: Int
    let minutes: Int
    let averageEffort: Double?          // 1–5
    let previousAverageEffort: Double?
    let bestDrill: String?

    var effortLabel: String {
        guard let averageEffort else { return "n/a" }
        return String(format: "%.1f/5", averageEffort)
    }

    /// "Steadier than last week" / "Harder than last week" / nil when there is nothing to compare.
    var effortTrend: String? {
        guard let averageEffort, let previousAverageEffort else { return nil }
        let delta = averageEffort - previousAverageEffort
        if abs(delta) < 0.3 { return "About the same effort as last week" }
        return delta > 0 ? "Harder than last week" : "Easier than last week"
    }

    var headline: String {
        if planned == 0 { return "No sessions were planned" }
        if done >= planned { return "Every session done" }
        if done == 0 { return "No sessions this week" }
        return "\(done) of \(planned) sessions done"
    }

    /// Serialised for the review function.
    var payload: [String: Any] {
        var dict: [String: Any] = ["done": done, "planned": planned, "minutes": minutes, "missed": missed, "effort": effortLabel]
        if let bestDrill { dict["best_drill"] = bestDrill }
        return dict
    }

    static func build(plan: TrainingPlanModel, weekNumber: Int, sessions: [Session], previousSessions: [Session], startDate: Date, now: Date, calendar: Calendar) -> WeekRecap {
        let week = plan.weeks.first { $0.weekNumber == weekNumber }
        let days = week?.days.filter { !$0.isRestDay } ?? []
        let todayStart = calendar.startOfDay(for: now)
        let planned = days.count
        let done = days.filter { $0.isCompleted }.count
        let missed = days.filter { day in
            guard let week, !day.isDone else { return false }
            return PlanSchedule.date(of: day, in: week, startDate: startDate, calendar: calendar) < todayStart
        }.count

        let minutes = sessions.reduce(0) { $0 + $1.minutes }
        func average(_ list: [Session]) -> Double? {
            let rated = list.map(\.rating).filter { $0 > 0 }
            guard !rated.isEmpty else { return nil }
            return Double(rated.reduce(0, +)) / Double(rated.count)
        }

        var drillScores: [String: [Int]] = [:]
        for session in sessions {
            for (name, rating) in session.drillRatings where rating > 0 {
                drillScores[name, default: []].append(rating)
            }
        }
        let best = drillScores
            .map { (name: $0.key, score: Double($0.value.reduce(0, +)) / Double($0.value.count), count: $0.value.count) }
            .sorted { ($0.score, $0.count, $0.name) > ($1.score, $1.count, $1.name) }
            .first?.name

        return WeekRecap(
            weekNumber: weekNumber,
            planned: planned,
            done: done,
            missed: missed,
            minutes: minutes,
            averageEffort: average(sessions),
            previousAverageEffort: average(previousSessions),
            bestDrill: best
        )
    }
}
