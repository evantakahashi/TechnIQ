import Foundation

// MARK: - AIRecommendationService Protocol

@MainActor
protocol AIRecommendationServiceProtocol: AnyObject {
    var recommendationStatus: AIRecommendationService.RecommendationStatus { get }
    var isTrainingModel: Bool { get }

    func getYouTubeRecommendations(for player: Player, limit: Int) async throws -> [YouTubeVideoRecommendation]
    func getCloudRecommendations(for player: Player, limit: Int) async throws -> [MLDrillRecommendation]
    func generateTrainingPlan(
        for player: Player,
        duration: Int,
        difficulty: String,
        category: String,
        targetRole: String?,
        focusAreas: [String],
        preferredDays: [String],
        restDays: [String]
    ) async throws -> GeneratedPlanStructure
}
