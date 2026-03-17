import Foundation
import CoreData

// MARK: - YouTubeService Protocol

protocol YouTubeServiceProtocol: AnyObject {
    func createExerciseFromYouTubeVideo(
        for player: Player,
        videoId: String,
        title: String,
        description: String,
        thumbnailURL: String,
        duration: Int,
        channelTitle: String,
        category: String,
        difficulty: Int,
        targetSkills: [String]
    ) -> Exercise?

    func loadYouTubeDrillsFromAPI(
        for player: Player,
        category: String?,
        maxResults: Int,
        progressCallback: (@Sendable @MainActor (Double, String) -> Void)?
    ) async throws

    func getSmartRecommendations(for player: Player, limit: Int) -> [YouTubeService.DrillRecommendation]
    func removeDuplicateExercises(for player: Player)

    func searchSoccerDrills(query: String, maxResults: Int, order: YouTubeConfig.SearchOrder) async throws -> [DrillVideo]
    func searchDrillsByCategory(category: String, maxResults: Int) async throws -> [DrillVideo]
    func searchDrillsBySkill(skill: String, maxResults: Int) async throws -> [DrillVideo]
    func getThumbnailURL(for videoId: String, quality: String) -> String
    func getVideoURL(for videoId: String) -> String
}
