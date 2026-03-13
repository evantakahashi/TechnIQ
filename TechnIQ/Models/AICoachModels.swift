import Foundation

// MARK: - Daily Coaching Models

struct DailyCoaching: Codable {
    let focusArea: String
    let reasoning: String
    let recommendedDrill: RecommendedDrill
    let additionalTips: [String]
    let streakMessage: String?
    let insights: [AIInsight]
    let fetchDate: Date
}

struct RecommendedDrill: Codable {
    let name: String
    let description: String
    let category: String
    let difficulty: Int
    let duration: Int
    let steps: [String]
    let equipment: [String]
    let targetSkills: [String]
    let isFromLibrary: Bool
    let libraryExerciseID: String?
}

struct AIInsight: Codable {
    let title: String
    let description: String
    let type: String       // "celebration", "recommendation", "warning", "pattern"
    let priority: Int
    let actionable: String?
}

// MARK: - Plan Adaptation Models

struct PlanAdaptationResponse: Codable {
    let summary: String
    let adaptations: [PlanAdaptation]
}

struct PlanAdaptation: Codable {
    let type: String           // "add_session", "modify_difficulty", "remove_session", "swap_exercise"
    let day: Int
    let sessionIndex: Int?
    let description: String
    let drill: RecommendedDrill?
    let oldDifficulty: Int?
    let newDifficulty: Int?
}
