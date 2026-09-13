import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData

// MARK: - Cloud ML Service for Advanced Recommendations

@MainActor
class AIRecommendationService: ObservableObject, AIRecommendationServiceProtocol {
    static let shared = AIRecommendationService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    @Published var recommendationStatus: RecommendationStatus = .idle
    @Published var isTrainingModel: Bool = false
    
    // Rate limiting
    private var lastRequestTimes: [String: Date] = [:]
    private let requestCooldown: TimeInterval = 30
    
    enum RecommendationStatus {
        case idle
        case loading
        case success
        case error(String)
        case fallbackToRules
    }
    
    private init() {}

    private func checkRateLimit(for endpoint: String) throws {
        if let lastTime = lastRequestTimes[endpoint],
           Date().timeIntervalSince(lastTime) < requestCooldown {
            let remaining = Int(requestCooldown - Date().timeIntervalSince(lastTime))
            throw MLError.rateLimited(retryAfter: remaining)
        }
        lastRequestTimes[endpoint] = Date()
    }
    
    // MARK: - Main Recommendation Functions
    
    func getYouTubeRecommendations(for player: Player, limit: Int = 1) async throws -> [YouTubeVideoRecommendation] {
        try checkRateLimit(for: "get_youtube_recommendations")
        #if DEBUG
        print("CloudMLService: Fetching single YouTube recommendation for \(player.name ?? "Unknown")")
        #endif
        #if DEBUG
        print("CloudMLService: Checking prerequisites...")

        #endif
        recommendationStatus = .loading
        
        // Retry up to 3 times to get non-duplicate recommendations
        var attempts = 0
        let maxAttempts = 3
        var seenVideoIds = Set<String>()
        
        // Get existing video IDs to avoid duplicates
        let existingVideoIds = getExistingYouTubeVideoIds(for: player)
        seenVideoIds.formUnion(existingVideoIds)
        #if DEBUG
        print("CloudMLService: Will avoid \(existingVideoIds.count) existing video IDs")
        
        #endif
        while attempts < maxAttempts {
            attempts += 1
            #if DEBUG
            print("CloudMLService: Attempt \(attempts)/\(maxAttempts) - calling fetchYouTubeRecommendations...")
            
            #endif
            do {
                // Try cloud-based YouTube ML recommendations
                let youtubeRecommendations = try await fetchYouTubeRecommendations(player: player, limit: limit)
                
                // Filter out duplicates that we've already seen
                let newRecommendations = youtubeRecommendations.filter { recommendation in
                    let videoId = recommendation.videoId
                    let title = recommendation.title
                    
                    if seenVideoIds.contains(videoId) {
                        #if DEBUG
                        print("CloudMLService: Skipping duplicate video ID: \(videoId) - '\(title)'")
                        #endif
                        return false
                    }
                    
                    // Also check if this exercise already exists by checking Core Data directly
                    let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                    request.predicate = NSPredicate(format: "youtubeVideoID == %@", videoId)
                    do {
                        let existingCount = try CoreDataManager.shared.context.count(for: request)
                        if existingCount > 0 {
                            #if DEBUG
                            print("CloudMLService: Exercise with video ID '\(videoId)' already exists in Core Data - '\(title)'")
                            #endif
                            return false
                        }
                    } catch {
                        #if DEBUG
                        print("CloudMLService: Error checking for existing exercise: \(error)")
                        #endif
                    }
                    
                    seenVideoIds.insert(videoId)
                    return true
                }
                
                if !newRecommendations.isEmpty {
                    recommendationStatus = .success
                    #if DEBUG
                    print("CloudMLService: Successfully fetched \(newRecommendations.count) unique YouTube recommendation(s) on attempt \(attempts)")
                    #endif
                    return newRecommendations
                } else {
                    #if DEBUG
                    print("CloudMLService: All recommendations were duplicates on attempt \(attempts)")
                    #endif
                    if attempts < maxAttempts {
                        // Wait a bit before retrying to get different results
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        continue
                    }
                }
                
            } catch {
                #if DEBUG
                print("CloudMLService: YouTube recommendations failed on attempt \(attempts): \(error.localizedDescription)")
                #endif
                if attempts >= maxAttempts {
                    recommendationStatus = .error("YouTube recommendations unavailable")
                    throw error
                }
                // Wait before retrying
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        // If all attempts failed or returned duplicates
        recommendationStatus = .error("No unique recommendations found")
        throw MLError.insufficientData
    }
    
    // MARK: - YouTube Recommendations Integration
    
    private func fetchYouTubeRecommendations(player: Player, limit: Int) async throws -> [YouTubeVideoRecommendation] {
        #if DEBUG
        print("CloudMLService: fetchYouTubeRecommendations called, checking authentication...")
        
        #endif
        // Try without authentication first (for testing Firebase Functions)
        let userUID = auth.currentUser?.uid ?? "test_user_\(UUID().uuidString.prefix(8))"
        #if DEBUG
        print("CloudMLService: Using user ID: \(userUID.prefix(8))... (may be unauthenticated for testing)")
        
        #endif
        // Build player profile for ML analysis
        let playerProfile = buildPlayerProfile(for: player)
        
        // Call Firebase Functions YouTube endpoint
        return try await callFirebaseYouTubeRecommendations(userUID: userUID, playerProfile: playerProfile, limit: limit)
    }
    
    private func callFirebaseYouTubeRecommendations(userUID: String, playerProfile: [String: Any], limit: Int) async throws -> [YouTubeVideoRecommendation] {
        // Construct Firebase Functions URL for YouTube recommendations
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_youtube_recommendations"
        
        guard let url = URL(string: functionsURL) else {
            throw MLError.networkError
        }
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "user_id": userUID,
            "limit": limit,
            "player_profile": playerProfile
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Try to add Firebase Auth token if available, but don't require it for testing
        do {
            if let user = auth.currentUser {
                let idToken = try await user.getIDToken()
                request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
                #if DEBUG
                print("CloudMLService: Added Firebase Auth token to request")
                #endif
            } else {
                #if DEBUG
                print("CloudMLService: No Firebase user authenticated, proceeding without token (testing mode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("CloudMLService: Could not get auth token (\(error.localizedDescription)), proceeding without authentication")
            #endif
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        #if DEBUG
        print("CloudMLService: Calling Firebase Function at \(functionsURL)")
        #endif
        let (data, response) = try await performRequestWithRetry(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            print("CloudMLService: Invalid HTTP response")
            #endif
            throw MLError.networkError
        }

        #if DEBUG

        print("CloudMLService: HTTP Status Code: \(httpResponse.statusCode)")


        #endif
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            #if DEBUG
            print("CloudMLService: Firebase Function error (\(httpResponse.statusCode)): \(errorBody)")
            
            #endif
            // Provide more specific error information
            if httpResponse.statusCode == 401 {
                #if DEBUG
                print("CloudMLService: 401 Unauthorized - This may indicate the Firebase Function is not deployed or authentication is required")
                #endif
                #if DEBUG
                print("CloudMLService: Try deploying the Firebase Functions first: firebase deploy --only functions")
                #endif
            } else if httpResponse.statusCode == 404 {
                #if DEBUG
                print("CloudMLService: 404 Not Found - Firebase Function endpoint may not exist or be deployed")
                #endif
            } else if httpResponse.statusCode >= 500 {
                #if DEBUG
                print("CloudMLService: Server error - Firebase Function may have crashed or have configuration issues")
                #endif
            }
            
            throw MLError.networkError
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recommendations = json["recommendations"] as? [[String: Any]] else {
            throw MLError.modelNotAvailable
        }
        
        // Convert to YouTubeVideoRecommendation objects
        var youtubeRecommendations: [YouTubeVideoRecommendation] = []
        
        for recData in recommendations {
            // Log the LLM-generated search query
            if let searchQuery = recData["search_query"] as? String {
                #if DEBUG
                print("LLM Query: \"\(searchQuery)\" → \(recData["title"] as? String ?? "Unknown")")
                #endif
            }
            
            let youtubeRec = YouTubeVideoRecommendation(
                videoId: recData["video_id"] as? String ?? "",
                title: recData["title"] as? String ?? "Unknown Video",
                channelTitle: recData["channel_title"] as? String ?? "Unknown Channel",
                description: String((recData["description"] as? String ?? "").prefix(200)), // Truncate description
                thumbnailUrl: recData["thumbnail_url"] as? String ?? "",
                duration: recData["duration"] as? String ?? "Unknown",
                durationSeconds: recData["duration_seconds"] as? Int ?? 0,
                isShort: recData["is_short"] as? Bool ?? false,
                viewCount: recData["view_count"] as? Int ?? 0,
                confidenceScore: recData["final_score"] as? Double ?? 0.5,
                reasoning: recData["reasoning"] ?? "Personalized for your training goals",
                searchQuery: recData["search_query"] as? String ?? "",
                engagementScore: recData["engagement_score"] as? Double ?? 0.5,
                createdAt: Date()
            )
            youtubeRecommendations.append(youtubeRec)
        }
        
        #if DEBUG
        
        print("Received \(youtubeRecommendations.count) YouTube recommendation(s) from Firebase Functions")
        
        #endif
        return youtubeRecommendations
    }
    
    private func buildPlayerProfile(for player: Player) -> [String: Any] {
        // Extract goals as strings
        var goals: [String] = []
        if let playerGoals = player.playerGoals?.allObjects as? [PlayerGoal] {
            goals = playerGoals.compactMap { $0.skillName }
        }

        var profile: [String: Any] = [
            "position": player.position ?? "midfielder",
            "age": Int(player.age),
            "experienceLevel": player.experienceLevel ?? "intermediate",
            "playingStyle": player.playingStyle ?? "",
            "playerRoleModel": player.playerRoleModel ?? "",
            "competitiveLevel": player.competitiveLevel ?? "",
            "dominantFoot": player.dominantFoot ?? "",
            "goals": goals
        ]

        // Add match insights from recent matches for targeted recommendations
        let matchInsights = getMatchInsights(for: player)
        if !matchInsights.isEmpty {
            profile["matchInsights"] = matchInsights
        }

        return profile
    }

    // MARK: - Match Insights for Recommendations

    /// Analyzes recent matches to provide insights for video recommendations
    private func getMatchInsights(for player: Player, limit: Int = 10) -> [String: Any] {
        let matches = MatchService.shared.fetchMatches(for: player)
        let recentMatches = Array(matches.prefix(limit))

        guard !recentMatches.isEmpty else { return [:] }

        // Count weakness and strength occurrences
        var weaknessCount: [String: Int] = [:]
        var strengthCount: [String: Int] = [:]

        for match in recentMatches {
            // Parse weaknesses
            if let weaknessString = match.weaknesses, !weaknessString.isEmpty {
                let weaknesses = weaknessString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                for weakness in weaknesses {
                    weaknessCount[weakness, default: 0] += 1
                }
            }

            // Parse strengths
            if let strengthString = match.strengths, !strengthString.isEmpty {
                let strengths = strengthString.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                for strength in strengths {
                    strengthCount[strength, default: 0] += 1
                }
            }
        }

        // Get top weaknesses and strengths by frequency
        let topWeaknesses = weaknessCount.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let topStrengths = strengthCount.sorted { $0.value > $1.value }.prefix(3).map { $0.key }

        var result: [String: Any] = [:]

        if !topWeaknesses.isEmpty {
            result["weaknessAreas"] = topWeaknesses
            // Generate a focus recommendation based on top weakness
            result["focusRecommendation"] = "\((topWeaknesses.first ?? "skill").lowercased()) training drills"
        }

        if !topStrengths.isEmpty {
            result["strengthAreas"] = topStrengths
        }

        return result
    }

    // MARK: - AI Training Plan Generation

    func generateTrainingPlan(
        for player: Player,
        duration: Int,
        difficulty: String,
        category: String,
        targetRole: String?,
        focusAreas: [String],
        preferredDays: [String] = [],
        restDays: [String] = []
    ) async throws -> GeneratedPlanStructure {
        try checkRateLimit(for: "generate_training_plan")
        #if DEBUG
        print("CloudMLService: Generating AI training plan for \(player.name ?? "Unknown")")
        print("Parameters: \(duration) weeks, \(difficulty), \(category), role: \(targetRole ?? "none")")
        if !preferredDays.isEmpty { print("Preferred days: \(preferredDays.joined(separator: ", "))") }
        if !restDays.isEmpty { print("Rest days: \(restDays.joined(separator: ", "))") }
        #endif

        guard let userUID = auth.currentUser?.uid else {
            throw MLError.notAuthenticated
        }

        // Build comprehensive player profile
        let playerProfile = buildPlayerProfile(for: player)

        // Call Firebase Function for AI plan generation
        return try await callFirebaseAIPlanGeneration(
            userUID: userUID,
            playerProfile: playerProfile,
            duration: duration,
            difficulty: difficulty,
            category: category,
            targetRole: targetRole,
            focusAreas: focusAreas,
            preferredDays: preferredDays,
            restDays: restDays
        )
    }

    private func callFirebaseAIPlanGeneration(
        userUID: String,
        playerProfile: [String: Any],
        duration: Int,
        difficulty: String,
        category: String,
        targetRole: String?,
        focusAreas: [String],
        preferredDays: [String],
        restDays: [String]
    ) async throws -> GeneratedPlanStructure {

        // Construct Firebase Functions URL for AI plan generation
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/generate_training_plan"

        guard let url = URL(string: functionsURL) else {
            throw MLError.networkError
        }

        // Prepare request body
        var requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerProfile,
            "duration_weeks": duration,
            "difficulty": difficulty,
            "category": category,
            "focus_areas": focusAreas
        ]

        if let role = targetRole {
            requestBody["target_role"] = role
        }

        // Add schedule preferences (Phase 2)
        if !preferredDays.isEmpty {
            requestBody["preferred_days"] = preferredDays
        }
        if !restDays.isEmpty {
            requestBody["rest_days"] = restDays
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // AI generation may take longer

        // Add Firebase Auth token
        if let user = auth.currentUser {
            let idToken = try await user.getIDToken()
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            #if DEBUG
            print("CloudMLService: Added Firebase Auth token")
            #endif
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        #if DEBUG
        print("CloudMLService: Calling AI plan generation at \(functionsURL)")
        #endif

        let (data, response) = try await performRequestWithRetry(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MLError.networkError
        }

        #if DEBUG
        print("CloudMLService: HTTP Status Code: \(httpResponse.statusCode)")
        #endif

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            #if DEBUG
            print("CloudMLService: AI plan generation error (\(httpResponse.statusCode)): \(errorBody)")
            #endif
            throw MLError.networkError
        }

        // Parse AI-generated plan response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let generatedPlan = try decoder.decode(GeneratedPlanStructure.self, from: data)

            #if DEBUG
            print("CloudMLService: Successfully generated plan '\(generatedPlan.name)' with \(generatedPlan.weeks.count) weeks")
            #endif

            return generatedPlan

        } catch {
            #if DEBUG
            print("CloudMLService: JSON parsing error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw response: \(jsonString.prefix(500))")
            }
            #endif
            throw MLError.modelNotAvailable
        }
    }

    // MARK: - Retry Helper

    private func performRequestWithRetry(_ request: URLRequest, maxRetries: Int = 2) async throws -> (Data, URLResponse) {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 500, attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                    continue
                }
                return (data, response)
            } catch {
                lastError = error
                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt))) * 1_000_000_000)
                }
            }
        }
        throw lastError ?? MLError.networkError
    }

    // MARK: - Helper Functions
    
    private func getExistingYouTubeVideoIds(for player: Player) -> Set<String> {
        var videoIds = Set<String>()
        
        // Get all exercises for this player that have YouTube video IDs
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "isYouTubeContent == true AND youtubeVideoID != nil AND youtubeVideoID != ''")
        
        do {
            let exercises = try CoreDataManager.shared.context.fetch(request)
            for exercise in exercises {
                if let videoId = exercise.youtubeVideoID {
                    videoIds.insert(videoId)
                }
            }
            #if DEBUG
            print("CloudMLService: Found \(videoIds.count) existing YouTube video IDs")
            #endif
        } catch {
            #if DEBUG
            print("CloudMLService: Error fetching existing YouTube exercises: \(error)")
            #endif
        }
        
        return videoIds
    }
    
    private func calculateEnhancedConfidence(for rec: YouTubeService.DrillRecommendation, player: Player) -> Double {
        // Enhanced confidence calculation that mimics ML scoring
        var confidence = rec.confidenceScore
        
        // Boost confidence based on player's experience level
        let playerDifficulty = mapExperienceLevelToNumber(player.experienceLevel ?? "Beginner")
        if Int(rec.exercise.difficulty) == playerDifficulty {
            confidence += 0.1
        }
        
        // Boost for recent category focus
        if isRecentFocusArea(category: categoryToString(rec.category), for: player) {
            confidence += 0.15
        }
        
        return min(confidence, 1.0)
    }
    
    private func enhanceReasoning(_ originalReasoning: String, with mlInsight: String) -> String {
        return "\(mlInsight): \(originalReasoning)"
    }
    
    private func extractTargetSkills(from rec: YouTubeService.DrillRecommendation) -> [String] {
        // Extract skills from the recommendation category and description
        var skills: [String] = []
        
        let categoryStr = categoryToString(rec.category)
        switch categoryStr.lowercased() {
        case "technical":
            skills = ["Ball Control", "First Touch", "Passing"]
        case "physical":
            skills = ["Speed", "Agility", "Endurance"]
        case "tactical":
            skills = ["Decision Making", "Positioning", "Game Awareness"]
        case "mental":
            skills = ["Focus", "Confidence", "Pressure Handling"]
        default:
            skills = ["General Soccer Skills"]
        }
        
        return skills
    }
    
    private func generatePersonalizedInstructions(for rec: YouTubeService.DrillRecommendation, player: Player) -> String {
        let baseInstructions = "Complete this exercise focusing on proper technique."
        let playerLevel = player.experienceLevel ?? "Beginner"
        
        switch playerLevel.lowercased() {
        case "beginner":
            return "\(baseInstructions) Take your time and focus on getting the movements right before increasing speed."
        case "intermediate":
            return "\(baseInstructions) Challenge yourself to maintain quality while increasing intensity."
        case "advanced", "expert":
            return "\(baseInstructions) Focus on game-like intensity and decision-making under pressure."
        default:
            return baseInstructions
        }
    }
    
    private func estimateImprovement(for rec: YouTubeService.DrillRecommendation, player: Player) -> Double {
        // Estimate expected skill improvement (0.0 - 1.0)
        let baseImprovement = 0.1
        let playerDifficulty = mapExperienceLevelToNumber(player.experienceLevel ?? "Beginner")
        let difficultyMultiplier = Int(rec.exercise.difficulty) == playerDifficulty ? 1.2 : 0.8
        return min(baseImprovement * difficultyMultiplier, 1.0)
    }
    
    private func isRecentFocusArea(category: String, for player: Player) -> Bool {
        // Check if this category was trained in the last 3 training sessions
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]
        request.fetchLimit = 3

        do {
            let recentSessions = try CoreDataManager.shared.context.fetch(request)

            // Check exercises in recent sessions for matching category
            for session in recentSessions {
                if let exercises = session.exercises?.allObjects as? [SessionExercise] {
                    for sessionExercise in exercises {
                        if let exercise = sessionExercise.exercise,
                           let exerciseCategory = exercise.category,
                           exerciseCategory.lowercased().contains(category.lowercased()) {
                            return true
                        }
                    }
                }
            }

            return false
        } catch {
            return false
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchRecentTrainingSessions(for player: Player, limit: Int) async throws -> [TrainingSession] {
        // Fetch from Core Data for now
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]
        request.fetchLimit = limit
        
        return try CoreDataManager.shared.context.fetch(request)
    }
    
    // MARK: - Helper Functions for Type Conversion
    
    private func categoryToString(_ category: YouTubeService.RecommendationCategory) -> String {
        switch category {
        case .skillGap:
            return "Technical"
        case .difficultyProgression:
            return "Physical"
        case .varietyBalance:
            return "Tactical"
        case .repeatSuccess:
            return "Mental"
        case .complementarySkill:
            return "Technical"
        }
    }
    
    private func mapExperienceLevelToNumber(_ level: String) -> Int {
        switch level.lowercased() {
        case "beginner":
            return 1
        case "intermediate":
            return 3
        case "advanced":
            return 4
        case "expert":
            return 5
        default:
            return 2
        }
    }
}

// MARK: - Data Models

struct YouTubeVideoRecommendation: Identifiable {
    let id = UUID()
    let videoId: String
    let title: String
    let channelTitle: String
    let description: String
    let thumbnailUrl: String
    let duration: String
    let durationSeconds: Int
    let isShort: Bool
    let viewCount: Int
    let confidenceScore: Double
    let reasoning: Any
    let searchQuery: String
    let engagementScore: Double
    let createdAt: Date
    
    var youtubeURL: URL? {
        return URL(string: "https://www.youtube.com/watch?v=\(videoId)")
    }
    
    var formattedViewCount: String {
        if viewCount >= 1_000_000 {
            return String(format: "%.1fM views", Double(viewCount) / 1_000_000.0)
        } else if viewCount >= 1_000 {
            return String(format: "%.1fK views", Double(viewCount) / 1_000.0)
        } else {
            return "\(viewCount) views"
        }
    }
    
    var contentTypeDescription: String {
        return isShort ? "Short" : "Video"
    }
    
    var durationDisplay: String {
        return duration != "Unknown" ? duration : (isShort ? "Short" : "Video")
    }
}

enum MLError: LocalizedError {
    case notAuthenticated
    case networkError
    case modelNotAvailable
    case insufficientData
    case rateLimited(retryAfter: Int)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError:
            return "Network connection error"
        case .modelNotAvailable:
            return "ML model not available"
        case .insufficientData:
            return "Insufficient data for recommendations"
        case .rateLimited(let seconds):
            return "Please wait \(seconds) seconds before trying again"
        }
    }
}
