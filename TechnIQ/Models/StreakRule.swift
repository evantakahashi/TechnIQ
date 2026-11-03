import CoreData
import Foundation

/// The one rule for what extends a streak: at least five minutes of active (unpaused) training.
/// A shorter session still saves and earns its XP; it just doesn't count as a training day.
enum StreakRule {
    static let minimumActiveSeconds: Double = 300
    /// Rows saved before `activeSeconds` existed only have `duration` (minutes).
    static let legacyMinimumMinutes: Double = 5

    static func counts(activeSeconds: Double, durationMinutes: Double) -> Bool {
        if activeSeconds > 0 { return activeSeconds >= minimumActiveSeconds }
        return durationMinutes >= legacyMinimumMinutes
    }
}

extension TrainingSession {
    /// Whether this session extends the streak (`StreakRule`).
    var countsTowardStreak: Bool {
        StreakRule.counts(activeSeconds: activeSeconds, durationMinutes: duration)
    }
}
