import Foundation

struct YouTubeConfig {
    static let baseURL = "https://www.googleapis.com/youtube/v3"
    static let maxResults = 25
    static let defaultQuota = 10000
    
    static var apiKey: String {
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let key = plist["YOUTUBE_API_KEY"] as? String,
              key != "YOUR_YOUTUBE_API_KEY_HERE" else {
            print("⚠️ YouTube API key not configured. Please add your API key to Info.plist")
            return ""
        }
        return key
    }
    
    static var isConfigured: Bool {
        return !apiKey.isEmpty
    }
    
    enum SearchOrder: String {
        case relevance = "relevance"
        case date = "date"
        case rating = "rating"
        case title = "title"
        case viewCount = "viewCount"
    }
    
    enum VideoDuration: String {
        case any = "any"
        case short = "short"      // < 4 minutes
        case medium = "medium"    // 4-20 minutes
        case long = "long"        // > 20 minutes
    }
    
    static let soccerKeywords = [
        "soccer drill", "football training", "soccer skills",
        "dribbling drill", "passing drill", "shooting drill",
        "soccer technique", "football skills", "soccer practice"
    ]
}