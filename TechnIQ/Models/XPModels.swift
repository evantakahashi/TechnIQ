import Foundation

// Pure Foundation: symlinked into tools/juggle-harness (JuggleCore) so camera rewards use the same formula.

// MARK: - XP formula

/// The one source of XP: training. A session (or one camera sitting) earns
/// time XP = 1 per full active minute, up to 20, plus
/// touch XP = 1 per 10 camera-verified touches, up to 10,
/// so 30 at most. Under a minute of active time earns nothing. Achievements, match logs and streaks
/// pay no XP.
enum XPFormula {
    static let maxPerSession = 30
    static let maxTimeXP = 20
    static let maxTouchXP = 10
    static let touchesPerXP = 10
    static let minimumActiveSeconds: Double = 60

    static func session(verifiedTouches: Int, activeSeconds: Double) -> SessionXPBreakdown {
        guard activeSeconds.isFinite, activeSeconds >= minimumActiveSeconds else { return .zero }
        let time = min(Int(activeSeconds / 60), maxTimeXP)
        let touches = min(max(verifiedTouches, 0) / touchesPerXP, maxTouchXP)
        return SessionXPBreakdown(timeXP: Int32(time), touchXP: Int32(touches))
    }

    // MARK: Level curve

    static let maxLevel = 50
    /// XP to go from level 1 to 2.
    static let firstLevelCost: Int64 = 50
    /// Each later level costs this much more than the one before.
    static let levelCostStep: Int64 = 8

    /// Total XP needed to reach `level`: level n → n+1 costs 50 + 8·(n−1) XP. At 20–30 XP a session,
    /// level 2 (50 XP) takes 2–3 sessions, level 10 (738 XP) about two months at 3–4 sessions a week
    /// and level 50 (11,858 XP) about three years.
    static func xpRequired(forLevel level: Int) -> Int64 {
        guard level > 1 else { return 0 }
        let steps = Int64(min(level, maxLevel) - 1)
        return firstLevelCost * steps + levelCostStep * steps * (steps - 1) / 2
    }

    static func level(forXP xp: Int64) -> Int {
        var level = 1
        while level < maxLevel && xp >= xpRequired(forLevel: level + 1) { level += 1 }
        return level
    }
}

// MARK: - Level Tier

struct LevelTier: Identifiable {
    let id = UUID()
    let minLevel: Int
    let maxLevel: Int
    let title: String
    let description: String
    let icon: String
}

// MARK: - Session XP Breakdown

/// The two parts of `XPFormula.session`; together never more than `XPFormula.maxPerSession`.
struct SessionXPBreakdown: Equatable {
    let timeXP: Int32
    let touchXP: Int32

    static let zero = SessionXPBreakdown(timeXP: 0, touchXP: 0)

    var total: Int32 { timeXP + touchXP }
}
