import Foundation

// MARK: - YouTube API Error Handling
enum YouTubeAPIError: LocalizedError {
    case apiKeyNotConfigured
    case quotaExceeded
    case invalidSearchQuery
    case videoNotFound
    case networkError(Error)
    case parsingError
    case rateLimitExceeded
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "YouTube API key is not configured"
        case .quotaExceeded:
            return "YouTube API quota exceeded"
        case .invalidSearchQuery:
            return "Invalid search query"
        case .videoNotFound:
            return "Video not found"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Error parsing YouTube response"
        case .rateLimitExceeded:
            return "Rate limit exceeded, please try again later"
        }
    }
}

// MARK: - YouTube API Response Models
struct YouTubeSearchResponse: Codable {
    let kind: String
    let etag: String
    let nextPageToken: String?
    let regionCode: String?
    let pageInfo: PageInfo
    let items: [SearchItem]
}

struct PageInfo: Codable {
    let totalResults: Int
    let resultsPerPage: Int
}

struct SearchItem: Codable {
    let kind: String
    let etag: String
    let id: VideoId
    let snippet: VideoSnippet
}

struct VideoId: Codable {
    let kind: String
    let videoId: String
}

struct VideoSnippet: Codable {
    let publishedAt: String
    let channelId: String
    let title: String
    let description: String
    let thumbnails: Thumbnails
    let channelTitle: String
    let tags: [String]?
    let categoryId: String?
    let liveBroadcastContent: String?
    let defaultLanguage: String?
    let localized: LocalizedInfo?
}

struct Thumbnails: Codable {
    let `default`: ThumbnailInfo?
    let medium: ThumbnailInfo?
    let high: ThumbnailInfo?
    let standard: ThumbnailInfo?
    let maxres: ThumbnailInfo?
}

struct ThumbnailInfo: Codable {
    let url: String
    let width: Int
    let height: Int
}

struct LocalizedInfo: Codable {
    let title: String
    let description: String
}

// MARK: - Video Details Response
struct YouTubeVideoResponse: Codable {
    let kind: String
    let etag: String
    let items: [VideoDetails]
}

struct VideoDetails: Codable {
    let kind: String
    let etag: String
    let id: String
    let snippet: VideoSnippet
    let contentDetails: ContentDetails?
    let statistics: VideoStatistics?
}

struct ContentDetails: Codable {
    let duration: String
    let dimension: String?
    let definition: String?
    let caption: String?
    let licensedContent: Bool?
    let regionRestriction: RegionRestriction?
}

struct VideoStatistics: Codable {
    let viewCount: String?
    let likeCount: String?
    let dislikeCount: String?
    let favoriteCount: String?
    let commentCount: String?
}

struct RegionRestriction: Codable {
    let allowed: [String]?
    let blocked: [String]?
}

// MARK: - Local Models for App Use
struct DrillVideo {
    let youtubeVideoId: String
    let title: String
    let description: String
    let thumbnailURL: String
    let duration: Int // in seconds
    let channelTitle: String
    let tags: [String]
    let category: String
    let difficulty: Int // 1-3 based on content analysis
    let targetSkills: [String]
    
    // Convert YouTube duration (ISO 8601) to seconds
    static func parseYouTubeDuration(_ duration: String) -> Int {
        // YouTube duration format: PT4M13S (4 minutes, 13 seconds)
        let pattern = #"PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: duration, range: NSRange(duration.startIndex..., in: duration)) else {
            return 0
        }
        
        var totalSeconds = 0
        
        // Hours
        if let hoursRange = Range(match.range(at: 1), in: duration) {
            totalSeconds += Int(duration[hoursRange]) ?? 0 * 3600
        }
        
        // Minutes
        if let minutesRange = Range(match.range(at: 2), in: duration) {
            totalSeconds += (Int(duration[minutesRange]) ?? 0) * 60
        }
        
        // Seconds
        if let secondsRange = Range(match.range(at: 3), in: duration) {
            totalSeconds += Int(duration[secondsRange]) ?? 0
        }
        
        return totalSeconds
    }
    
    // Analyze content to determine difficulty and target skills
    static func analyzeDrillContent(title: String, description: String, tags: [String]) -> (difficulty: Int, skills: [String], category: String) {
        let content = (title + " " + description + " " + tags.joined(separator: " ")).lowercased()
        
        var difficulty = 1
        var skills: [String] = []
        var category = "Technical"
        
        // Difficulty analysis
        if content.contains("advanced") || content.contains("professional") || content.contains("expert") {
            difficulty = 3
        } else if content.contains("intermediate") || content.contains("complex") {
            difficulty = 2
        }
        
        // Skills analysis
        if content.contains("dribbling") || content.contains("dribble") {
            skills.append("Dribbling")
        }
        if content.contains("passing") || content.contains("pass") {
            skills.append("Passing")
        }
        if content.contains("shooting") || content.contains("shot") {
            skills.append("Shooting")
        }
        if content.contains("control") || content.contains("touch") {
            skills.append("Ball Control")
        }
        if content.contains("speed") || content.contains("sprint") {
            skills.append("Speed")
        }
        if content.contains("agility") || content.contains("footwork") {
            skills.append("Agility")
        }
        
        // Category analysis
        if content.contains("fitness") || content.contains("conditioning") || content.contains("strength") {
            category = "Physical"
        } else if content.contains("tactical") || content.contains("strategy") || content.contains("formation") {
            category = "Tactical"
        }
        
        return (difficulty, skills, category)
    }
}