import Foundation

// MARK: - PlanRequestExtras
//
// The builder's overrides and schedule facts sent with `generate_training_plan`: weak spots (the
// player's, or what the builder picked), the position the builder shows, and the next match with
// today's date so the coach can place the match-day rules. The app re-applies those rules
// deterministically after saving (MatchDayRules), so the prompt is guidance only.

struct PlanRequestExtras: Equatable {
    var weakSpots: [String]? = nil
    var position: String? = nil
    var nextMatchDate: Date? = nil
    var planStartDate: Date = Date()

    /// "yyyy-MM-dd" in the given calendar's time zone (the player's local day).
    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 1970, components.month ?? 1, components.day ?? 1)
    }

    /// Top-level request fields. `profileWeakSpots` is used when the builder sent none.
    func requestFields(profileWeakSpots: [String]?, calendar: Calendar) -> [String: Any] {
        var fields: [String: Any] = ["plan_start_date": Self.dayString(planStartDate, calendar: calendar)]
        let spots = (weakSpots ?? profileWeakSpots ?? []).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !spots.isEmpty { fields["weak_spots"] = spots }
        if let nextMatchDate, calendar.startOfDay(for: nextMatchDate) >= calendar.startOfDay(for: planStartDate) {
            fields["next_match_date"] = Self.dayString(nextMatchDate, calendar: calendar)
        }
        return fields
    }
}
