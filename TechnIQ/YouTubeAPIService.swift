import Foundation

class YouTubeAPIService: ObservableObject {
    static let shared = YouTubeAPIService()
    
    private let networkManager = NetworkManager.shared
    private var requestCount = 0
    private var lastRequestTime = Date()
    
    // Rate limiting: 100 requests per 100 seconds
    private let maxRequestsPerInterval = 100
    private let timeInterval: TimeInterval = 100
    
    private init() {}
    
    // MARK: - Search Functions
    
    func searchSoccerDrills(
        query: String,
        maxResults: Int = YouTubeConfig.maxResults,
        order: YouTubeConfig.SearchOrder = .relevance
    ) async throws -> [DrillVideo] {
        
        guard YouTubeConfig.isConfigured else {
            throw YouTubeAPIError.apiKeyNotConfigured
        }
        
        try checkRateLimit()
        
        let searchQuery = "\(query) soccer drill football training"
        let searchResponse = try await performSearch(
            query: searchQuery,
            maxResults: maxResults,
            order: order
        )
        
        // Get detailed video information for duration and additional metadata
        let videoIds = searchResponse.items.map { $0.id.videoId }
        let videoDetails = try await getVideoDetails(videoIds: videoIds)
        
        // Convert to DrillVideo objects
        return convertToDrillVideos(searchItems: searchResponse.items, videoDetails: videoDetails)
    }
    
    func searchDrillsByCategory(
        category: String,
        maxResults: Int = YouTubeConfig.maxResults
    ) async throws -> [DrillVideo] {
        
        let categoryQueries: [String: String] = [
            "Technical": "soccer technical skills dribbling passing ball control",
            "Physical": "soccer fitness conditioning speed agility training",
            "Tactical": "soccer tactics formation strategy team play"
        ]
        
        guard let query = categoryQueries[category] else {
            throw YouTubeAPIError.invalidSearchQuery
        }
        
        return try await searchSoccerDrills(query: query, maxResults: maxResults)
    }
    
    func searchDrillsBySkill(
        skill: String,
        maxResults: Int = YouTubeConfig.maxResults
    ) async throws -> [DrillVideo] {
        
        let skillQueries: [String: String] = [
            "Dribbling": "soccer dribbling skills moves footwork",
            "Passing": "soccer passing accuracy short long pass",
            "Shooting": "soccer shooting accuracy power finishing",
            "Ball Control": "soccer ball control first touch juggling",
            "Speed": "soccer speed training sprint acceleration",
            "Agility": "soccer agility ladder cone drills footwork"
        ]
        
        guard let query = skillQueries[skill] else {
            return try await searchSoccerDrills(query: "soccer \(skill) training")
        }
        
        return try await searchSoccerDrills(query: query, maxResults: maxResults)
    }
    
    // MARK: - Private Helper Functions
    
    private func performSearch(
        query: String,
        maxResults: Int,
        order: YouTubeConfig.SearchOrder
    ) async throws -> YouTubeSearchResponse {
        
        let queryItems = [
            URLQueryItem(name: "part", value: "snippet"),
            URLQueryItem(name: "maxResults", value: "\(maxResults)"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "video"),
            URLQueryItem(name: "order", value: order.rawValue),
            URLQueryItem(name: "videoDuration", value: "medium"), // 4-20 minutes ideal for drills
            URLQueryItem(name: "relevanceLanguage", value: "en"),
            URLQueryItem(name: "safeSearch", value: "strict"),
            URLQueryItem(name: "key", value: YouTubeConfig.apiKey)
        ]
        
        guard let url = networkManager.buildURL(
            baseURL: YouTubeConfig.baseURL,
            path: "/search",
            queryItems: queryItems
        ) else {
            throw YouTubeAPIError.invalidSearchQuery
        }
        
        do {
            incrementRequestCount()
            return try await networkManager.performRequest(url: url, responseType: YouTubeSearchResponse.self)
        } catch {
            throw YouTubeAPIError.networkError(error)
        }
    }
    
    private func getVideoDetails(videoIds: [String]) async throws -> [VideoDetails] {
        guard !videoIds.isEmpty else { return [] }
        
        let queryItems = [
            URLQueryItem(name: "part", value: "snippet,contentDetails,statistics"),
            URLQueryItem(name: "id", value: videoIds.joined(separator: ",")),
            URLQueryItem(name: "key", value: YouTubeConfig.apiKey)
        ]
        
        guard let url = networkManager.buildURL(
            baseURL: YouTubeConfig.baseURL,
            path: "/videos",
            queryItems: queryItems
        ) else {
            throw YouTubeAPIError.invalidSearchQuery
        }
        
        do {
            incrementRequestCount()
            let response = try await networkManager.performRequest(url: url, responseType: YouTubeVideoResponse.self)
            return response.items
        } catch {
            throw YouTubeAPIError.networkError(error)
        }
    }
    
    private func convertToDrillVideos(
        searchItems: [SearchItem],
        videoDetails: [VideoDetails]
    ) -> [DrillVideo] {
        
        return searchItems.compactMap { item in
            guard let details = videoDetails.first(where: { $0.id == item.id.videoId }) else {
                return nil
            }
            
            let duration = details.contentDetails?.duration ?? "PT0S"
            let durationSeconds = DrillVideo.parseYouTubeDuration(duration)
            
            // Skip very short videos (less than 1 minute) or very long ones (more than 30 minutes)
            guard durationSeconds >= 60 && durationSeconds <= 1800 else {
                return nil
            }
            
            let thumbnailURL = item.snippet.thumbnails.medium?.url ?? 
                              item.snippet.thumbnails.high?.url ?? 
                              item.snippet.thumbnails.default?.url ?? ""
            
            let tags = item.snippet.tags ?? []
            let analysis = DrillVideo.analyzeDrillContent(
                title: item.snippet.title,
                description: item.snippet.description,
                tags: tags
            )
            
            return DrillVideo(
                youtubeVideoId: item.id.videoId,
                title: item.snippet.title,
                description: item.snippet.description,
                thumbnailURL: thumbnailURL,
                duration: durationSeconds,
                channelTitle: item.snippet.channelTitle,
                tags: tags,
                category: analysis.category,
                difficulty: analysis.difficulty,
                targetSkills: analysis.skills
            )
        }
    }
    
    // MARK: - Rate Limiting
    
    private func checkRateLimit() throws {
        let now = Date()
        let timeSinceLastRequest = now.timeIntervalSince(lastRequestTime)
        
        if timeSinceLastRequest > timeInterval {
            requestCount = 0
            lastRequestTime = now
        }
        
        if requestCount >= maxRequestsPerInterval {
            throw YouTubeAPIError.rateLimitExceeded
        }
    }
    
    private func incrementRequestCount() {
        requestCount += 1
    }
    
    // MARK: - Utility Functions
    
    func getThumbnailURL(for videoId: String, quality: String = "medium") -> String {
        return "https://img.youtube.com/vi/\(videoId)/\(quality)default.jpg"
    }
    
    func getVideoURL(for videoId: String) -> String {
        return "https://www.youtube.com/watch?v=\(videoId)"
    }
    
    func validateAPIKey() async -> Bool {
        guard YouTubeConfig.isConfigured else { return false }
        
        do {
            _ = try await searchSoccerDrills(query: "test", maxResults: 1)
            return true
        } catch {
            print("API key validation failed: \(error)")
            return false
        }
    }
}