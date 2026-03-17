import SwiftUI

// MARK: - Data Models

enum TimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
    case all = "All Time"

    var displayName: String { rawValue }
}

struct OverallStats {
    let totalSessions: Int
    let totalHours: Double
    let averageRating: Double
    let improvementPercentage: Double
    let currentStreak: Int
    let longestStreak: Int
    let sessionsPerWeek: Double
    let technicalPercentage: Double
    let physicalPercentage: Double
    let tacticalPercentage: Double
}

struct SkillProgress: Identifiable {
    let id: UUID
    let skillName: String
    let currentLevel: Double
    let change: Double
    let sessionsCount: Int
}

struct ProgressAchievement: Identifiable {
    let id: UUID
    let icon: String
    let title: String
    let description: String
    let date: Date
    let color: Color
}
