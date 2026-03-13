import Foundation

// MARK: - XP Rewards Constants

struct XPRewards {
    static let sessionBase: Int32 = 50
    static let intensityBonus: Int32 = 10
    static let firstSessionOfDay: Int32 = 25
    static let allExercisesCompleted: Int32 = 20
    static let sessionRated: Int32 = 5
    static let sessionNotes: Int32 = 5
    static let weeklyGoalCompleted: Int32 = 100
    static let streak7Day: Int32 = 150
    static let streak14Day: Int32 = 200
    static let streak30Day: Int32 = 500
    static let streak60Day: Int32 = 750
    static let streak100Day: Int32 = 1000
    static let streak365Day: Int32 = 5000
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

struct SessionXPBreakdown {
    let baseXP: Int32
    let intensityBonus: Int32
    let firstSessionBonus: Int32
    let completionBonus: Int32
    let ratingBonus: Int32
    let notesBonus: Int32
    let streakBonus: Int32

    var total: Int32 {
        baseXP + intensityBonus + firstSessionBonus + completionBonus + ratingBonus + notesBonus + streakBonus
    }
}
