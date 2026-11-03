import Foundation

// MARK: - PlanBuilderPrefill
//
// What the plan builders (AI and custom) start from: the Training Profile's level, position, weak
// spots, training days and next match. Every field stays editable in the builder. Pure; the view
// reads the Core Data values and hands them in.

struct PlanBuilderPrefill: Equatable {
    var difficulty: PlanDifficulty
    /// One of `OnboardingMapping.positions`, or nil when the profile has none.
    var position: String?
    var weakSpots: [WeaknessCategory]
    var trainingDays: [DayOfWeek]
    /// Only a match from today on.
    var nextMatchDate: Date?

    static func make(
        experienceLevel: String?,
        position: String?,
        weaknesses: [String]?,
        trainingDays: [DayOfWeek],
        nextMatchDate: Date?,
        now: Date,
        calendar: Calendar
    ) -> PlanBuilderPrefill {
        PlanBuilderPrefill(
            difficulty: difficulty(forExperience: experienceLevel),
            position: normalizedPosition(position),
            weakSpots: weakSpots(from: weaknesses),
            trainingDays: trainingDays.isEmpty ? [.monday, .wednesday, .friday] : Array(Set(trainingDays)).sorted(),
            nextMatchDate: MatchScheduleLink.upcoming(nextMatchDate, now: now, calendar: calendar)
        )
    }

    /// Same mapping as onboarding (Professional → Elite); tolerant of case and the legacy "expert".
    static func difficulty(forExperience experience: String?) -> PlanDifficulty {
        let trimmed = (experience ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "expert" { return .advanced }
        if trimmed.lowercased() == "elite" { return .elite }
        let raw = OnboardingMapping.difficulty(forExperience: trimmed.capitalized)
        return PlanDifficulty(rawValue: raw) ?? .intermediate
    }

    static func normalizedPosition(_ position: String?) -> String? {
        let trimmed = (position ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return OnboardingMapping.positions.first { $0.caseInsensitiveCompare(trimmed) == .orderedSame } ?? trimmed.capitalized
    }

    /// Profile weak spots (display names) → categories, in order, capped like the profile.
    static func weakSpots(from names: [String]?) -> [WeaknessCategory] {
        var result: [WeaknessCategory] = []
        for name in names ?? [] {
            guard let category = WeaknessCategory.allCases.first(where: { $0.displayName.caseInsensitiveCompare(name) == .orderedSame || $0.rawValue == name }),
                  !result.contains(category) else { continue }
            result.append(category)
        }
        return Array(result.prefix(OnboardingMapping.maxWeakSpots))
    }

    /// Custom plans: week n focuses on weak spot ((n − 1) mod count); nil without weak spots.
    static func focusArea(week: Int, weakSpots: [WeaknessCategory]) -> String? {
        guard !weakSpots.isEmpty else { return nil }
        return weakSpots[(max(week, 1) - 1) % weakSpots.count].displayName
    }
}

extension PlanBuilderPrefill {
    /// Reads the player and its profile.
    static func from(player: Player, now: Date = Date(), calendar: Calendar = .current) -> PlanBuilderPrefill {
        let profile = player.playerProfile
        return make(
            experienceLevel: player.experienceLevel,
            position: player.position,
            weaknesses: profile?.selfIdentifiedWeaknesses,
            trainingDays: profile?.trainingDayList ?? [.monday, .wednesday, .friday],
            nextMatchDate: profile?.nextMatchDate,
            now: now,
            calendar: calendar
        )
    }
}
