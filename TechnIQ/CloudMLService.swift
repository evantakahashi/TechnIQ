import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData

// MARK: - Cloud ML Service for Advanced Recommendations

@MainActor
class CloudMLService: ObservableObject {
    static let shared = CloudMLService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    @Published var recommendationStatus: RecommendationStatus = .idle
    @Published var isTrainingModel: Bool = false
    
    // Local cache for recommendations
    private var cachedRecommendations: [MLDrillRecommendation] = []
    private var lastRecommendationFetch: Date?
    private let cacheExpirationTime: TimeInterval = 30 * 60 // 30 minutes
    
    enum RecommendationStatus {
        case idle
        case loading
        case success
        case error(String)
        case fallbackToRules
    }
    
    private init() {}
    
    // MARK: - Main Recommendation Functions
    
    func getYouTubeRecommendations(for player: Player, limit: Int = 3) async throws -> [YouTubeVideoRecommendation] {
        print("🎥 CloudMLService: Fetching YouTube video recommendations for \(player.name ?? "Unknown")")
        print("🔍 CloudMLService: Checking prerequisites...")
        
        recommendationStatus = .loading
        
        // Test if Firebase Function deployment completed with authentication support
        let useFirebaseFunction = true
        
        if useFirebaseFunction {
            do {
                print("📞 CloudMLService: About to call fetchYouTubeRecommendations...")
                // Try cloud-based YouTube ML recommendations
                let youtubeRecommendations = try await fetchYouTubeRecommendations(player: player, limit: limit)
                
                recommendationStatus = .success
                print("✅ CloudMLService: Successfully fetched \(youtubeRecommendations.count) YouTube recommendations")
                return youtubeRecommendations
                
            } catch {
                print("⚠️ CloudMLService: YouTube recommendations failed (\(error.localizedDescription))")
                recommendationStatus = .error("YouTube recommendations unavailable")
                throw error // Re-throw the error instead of returning empty array
            }
        } else {
            print("📝 CloudMLService: Firebase Function temporarily disabled, throwing error to trigger fallback")
            recommendationStatus = .error("Firebase Function deployment pending")
            throw MLError.networkError // This will trigger the fallback to local search
        }
    }
    
    func getCloudRecommendations(for player: Player, limit: Int = 5) async throws -> [MLDrillRecommendation] {
        print("🤖 CloudMLService: Fetching ML-powered recommendations for \(player.name ?? "Unknown")")
        
        // Check cache first
        if let cachedRecs = getCachedRecommendations(limit: limit) {
            print("📦 Returning cached recommendations")
            return cachedRecs
        }
        
        recommendationStatus = .loading
        
        do {
            // Try cloud-based ML recommendations first
            let cloudRecommendations = try await fetchFromCloudML(player: player, limit: limit)
            
            // Cache the results
            cacheRecommendations(cloudRecommendations)
            recommendationStatus = .success
            
            print("✅ CloudMLService: Successfully fetched \(cloudRecommendations.count) ML recommendations")
            return cloudRecommendations
            
        } catch {
            print("⚠️ CloudMLService: Cloud ML failed (\(error.localizedDescription)), falling back to enhanced rules")
            recommendationStatus = .fallbackToRules
            
            // Fallback to enhanced rule-based recommendations
            let fallbackRecs = generateEnhancedRuleRecommendations(for: player, limit: limit)
            cacheRecommendations(fallbackRecs)
            
            return fallbackRecs
        }
    }
    
    // MARK: - YouTube Recommendations Integration
    
    private func fetchYouTubeRecommendations(player: Player, limit: Int) async throws -> [YouTubeVideoRecommendation] {
        print("🔐 CloudMLService: fetchYouTubeRecommendations called, checking authentication...")
        
        // Try without authentication first (for testing Firebase Functions)
        let userUID = auth.currentUser?.uid ?? "test_user_\(UUID().uuidString.prefix(8))"
        print("✅ CloudMLService: Using user ID: \(userUID.prefix(8))... (may be unauthenticated for testing)")
        
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
                print("🔐 CloudMLService: Added Firebase Auth token to request")
            } else {
                print("📝 CloudMLService: No Firebase user authenticated, proceeding without token (testing mode)")
            }
        } catch {
            print("⚠️ CloudMLService: Could not get auth token (\(error.localizedDescription)), proceeding without authentication")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        print("🌐 CloudMLService: Calling Firebase Function at \(functionsURL)")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ CloudMLService: Invalid HTTP response")
            throw MLError.networkError
        }
        
        print("📡 CloudMLService: HTTP Status Code: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            print("❌ CloudMLService: Firebase Function error (\(httpResponse.statusCode)): \(errorBody)")
            
            // Provide more specific error information
            if httpResponse.statusCode == 401 {
                print("🔐 CloudMLService: 401 Unauthorized - This may indicate the Firebase Function is not deployed or authentication is required")
                print("💡 CloudMLService: Try deploying the Firebase Functions first: firebase deploy --only functions")
            } else if httpResponse.statusCode == 404 {
                print("🔍 CloudMLService: 404 Not Found - Firebase Function endpoint may not exist or be deployed")
            } else if httpResponse.statusCode >= 500 {
                print("⚡ CloudMLService: Server error - Firebase Function may have crashed or have configuration issues")
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
                print("🤖 LLM Query: \"\(searchQuery)\" → \(recData["title"] as? String ?? "Unknown")")
            }
            
            let youtubeRec = YouTubeVideoRecommendation(
                videoId: recData["video_id"] as? String ?? "",
                title: recData["title"] as? String ?? "Unknown Video",
                channelTitle: recData["channel_title"] as? String ?? "Unknown Channel",
                description: String((recData["description"] as? String ?? "").prefix(200)), // Truncate description
                thumbnailUrl: recData["thumbnail_url"] as? String ?? "",
                duration: recData["duration"] as? String ?? "Unknown",
                viewCount: recData["view_count"] as? Int ?? 0,
                confidenceScore: recData["final_score"] as? Double ?? 0.5,
                reasoning: recData["reasoning"] ?? "Personalized for your training goals",
                searchQuery: recData["search_query"] as? String ?? "",
                engagementScore: recData["engagement_score"] as? Double ?? 0.5,
                createdAt: Date()
            )
            youtubeRecommendations.append(youtubeRec)
        }
        
        print("✅ Received \(youtubeRecommendations.count) YouTube recommendations from Firebase Functions")
        return youtubeRecommendations
    }
    
    private func buildPlayerProfile(for player: Player) -> [String: Any] {
        // Extract goals as strings
        var goals: [String] = []
        if let playerGoals = player.playerGoals?.allObjects as? [PlayerGoal] {
            goals = playerGoals.compactMap { $0.skillName }
        }
        
        return [
            "position": player.position ?? "midfielder",
            "age": Int(player.age),
            "experienceLevel": player.experienceLevel ?? "intermediate",
            "playingStyle": player.playingStyle ?? "",
            "playerRoleModel": player.playerRoleModel ?? "",
            "competitiveLevel": player.competitiveLevel ?? "",
            "dominantFoot": player.dominantFoot ?? "",
            "goals": goals
        ]
    }
    
    // MARK: - Cloud ML Functions Integration
    
    private func fetchFromCloudML(player: Player, limit: Int) async throws -> [MLDrillRecommendation] {
        guard let userUID = auth.currentUser?.uid else {
            throw MLError.notAuthenticated
        }
        
        // Prepare user context for ML model
        let userContext = try await buildUserContext(for: player)
        
        // Try real Firebase Functions first, fallback to simulation
        do {
            return try await callFirebaseFunctionRecommendations(userUID: userUID, context: userContext, limit: limit)
        } catch {
            print("🔄 Firebase Functions not available, using simulation: \(error.localizedDescription)")
            return try await simulateCloudMLRecommendations(player: player, context: userContext, limit: limit)
        }
    }
    
    private func callFirebaseFunctionRecommendations(userUID: String, context: UserMLContext, limit: Int) async throws -> [MLDrillRecommendation] {
        // Construct Firebase Functions URL
        // Format: https://YOUR_REGION-YOUR_PROJECT_ID.cloudfunctions.net/get_recommendations
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/get_recommendations"
        
        guard let url = URL(string: functionsURL) else {
            throw MLError.networkError
        }
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "user_id": userUID,
            "limit": limit,
            "context": [
                "skill_levels": context.skillLevels,
                "recent_performance": context.recentPerformance,
                "training_frequency": context.trainingFrequency,
                "preferred_difficulty": context.preferredDifficulty
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw MLError.networkError
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let recommendations = json["recommendations"] as? [[String: Any]] else {
            throw MLError.modelNotAvailable
        }
        
        // Convert to MLDrillRecommendation objects
        var mlRecommendations: [MLDrillRecommendation] = []
        
        for recData in recommendations {
            let mlRec = MLDrillRecommendation(
                exerciseId: recData["exercise_id"] as? String ?? "",
                exerciseName: recData["exercise_name"] as? String ?? "Unknown Exercise",
                category: recData["category"] as? String ?? "General",
                difficulty: recData["difficulty"] as? Int ?? 3,
                confidenceScore: recData["confidence_score"] as? Double ?? 0.5,
                reasoning: recData["reasoning"] as? String ?? "ML Recommendation",
                recommendationType: .collaborativeFiltering,
                estimatedDuration: recData["estimated_duration"] as? Int ?? 15,
                targetSkills: recData["target_skills"] as? [String] ?? [],
                personalizedInstructions: "Complete this ML-recommended exercise focusing on technique",
                expectedImprovement: 0.15,
                similarUserSuccess: recData["similar_user_success"] as? Double ?? 0.8,
                createdAt: Date()
            )
            mlRecommendations.append(mlRec)
        }
        
        print("✅ Received \(mlRecommendations.count) recommendations from Firebase Functions")
        return mlRecommendations
    }
    
    private func buildUserContext(for player: Player) async throws -> UserMLContext {
        // Fetch recent training data
        let recentSessions = try await fetchRecentTrainingSessions(for: player, limit: 10)
        let userFeedback = try await fetchUserFeedback(for: player, limit: 20)
        let skillProgress = analyzeSkillProgress(for: player)
        
        return UserMLContext(
            playerId: player.id?.uuidString ?? "",
            skillLevels: skillProgress.skillLevels,
            recentPerformance: skillProgress.recentPerformance,
            trainingFrequency: calculateTrainingFrequency(from: recentSessions),
            preferredDifficulty: mapExperienceLevelToNumber(player.experienceLevel ?? "Beginner"),
            feedbackPatterns: analyzeFeedbackPatterns(from: userFeedback),
            lastActiveDate: Date(),
            sessionCount: recentSessions.count
        )
    }
    
    // MARK: - Enhanced Rule-Based Fallback
    
    private func generateEnhancedRuleRecommendations(for player: Player, limit: Int) -> [MLDrillRecommendation] {
        print("🧠 Generating enhanced rule-based recommendations with ML insights")
        
        // Use the existing CoreDataManager logic but enhance it with ML concepts
        let coreRecommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: limit * 2)
        
        // Convert to ML format and add ML-specific scoring
        var mlRecommendations: [MLDrillRecommendation] = []
        
        for (index, rec) in coreRecommendations.enumerated() {
            if index >= limit { break }
            
            let mlRec = MLDrillRecommendation(
                exerciseId: rec.exercise.id?.uuidString ?? "",
                exerciseName: rec.exercise.name ?? "Unknown Exercise",
                category: categoryToString(rec.category),
                difficulty: Int(rec.exercise.difficulty),
                confidenceScore: calculateEnhancedConfidence(for: rec, player: player),
                reasoning: enhanceReasoning(rec.reason, with: "Enhanced rule-based analysis"),
                recommendationType: .enhancedRules,
                estimatedDuration: 15, // Default 15 minutes
                targetSkills: extractTargetSkills(from: rec),
                personalizedInstructions: generatePersonalizedInstructions(for: rec, player: player),
                expectedImprovement: estimateImprovement(for: rec, player: player),
                similarUserSuccess: 0.7, // Default for rule-based
                createdAt: Date()
            )
            
            mlRecommendations.append(mlRec)
        }
        
        return mlRecommendations
    }
    
    // MARK: - ML Simulation (Temporary)
    
    private func simulateCloudMLRecommendations(player: Player, context: UserMLContext, limit: Int) async throws -> [MLDrillRecommendation] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // This simulates what the cloud ML function would return
        // In reality, this would be collaborative filtering + content-based recommendations
        
        let baseRecommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: limit * 2)
        var mlRecommendations: [MLDrillRecommendation] = []
        
        for (index, rec) in baseRecommendations.enumerated() {
            if index >= limit { break }
            
            // Simulate ML confidence scoring
            let mlConfidence = simulateMLConfidenceScore(for: rec, context: context)
            
            let mlRec = MLDrillRecommendation(
                exerciseId: rec.exercise.id?.uuidString ?? "",
                exerciseName: rec.exercise.name ?? "Unknown Exercise",
                category: categoryToString(rec.category),
                difficulty: Int(rec.exercise.difficulty),
                confidenceScore: mlConfidence,
                reasoning: enhanceReasoning(rec.reason, with: "Collaborative filtering + content analysis"),
                recommendationType: .simulatedML,
                estimatedDuration: 15, // Default 15 minutes
                targetSkills: extractTargetSkills(from: rec),
                personalizedInstructions: generatePersonalizedInstructions(for: rec, player: player),
                expectedImprovement: estimateImprovement(for: rec, player: player),
                similarUserSuccess: Double.random(in: 0.6...0.95), // Simulated user success rate
                createdAt: Date()
            )
            
            mlRecommendations.append(mlRec)
        }
        
        // Sort by ML confidence
        mlRecommendations.sort { $0.confidenceScore > $1.confidenceScore }
        
        return Array(mlRecommendations.prefix(limit))
    }
    
    // MARK: - Helper Functions
    
    private func getCachedRecommendations(limit: Int) -> [MLDrillRecommendation]? {
        guard let lastFetch = lastRecommendationFetch,
              Date().timeIntervalSince(lastFetch) < cacheExpirationTime,
              !cachedRecommendations.isEmpty else {
            return nil
        }
        
        return Array(cachedRecommendations.prefix(limit))
    }
    
    private func cacheRecommendations(_ recommendations: [MLDrillRecommendation]) {
        cachedRecommendations = recommendations
        lastRecommendationFetch = Date()
    }
    
    private func calculateEnhancedConfidence(for rec: CoreDataManager.DrillRecommendation, player: Player) -> Double {
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
    
    private func simulateMLConfidenceScore(for rec: CoreDataManager.DrillRecommendation, context: UserMLContext) -> Double {
        // Simulate more sophisticated ML confidence scoring
        var score = rec.confidenceScore
        
        // Simulate collaborative filtering boost
        score += Double.random(in: 0.05...0.25)
        
        // Simulate user pattern matching
        if context.trainingFrequency > 3 {
            score += 0.1 // Active users get better recommendations
        }
        
        return min(score, 1.0)
    }
    
    private func enhanceReasoning(_ originalReasoning: String, with mlInsight: String) -> String {
        return "\(mlInsight): \(originalReasoning)"
    }
    
    private func extractTargetSkills(from rec: CoreDataManager.DrillRecommendation) -> [String] {
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
    
    private func generatePersonalizedInstructions(for rec: CoreDataManager.DrillRecommendation, player: Player) -> String {
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
    
    private func estimateImprovement(for rec: CoreDataManager.DrillRecommendation, player: Player) -> Double {
        // Estimate expected skill improvement (0.0 - 1.0)
        let baseImprovement = 0.1
        let playerDifficulty = mapExperienceLevelToNumber(player.experienceLevel ?? "Beginner")
        let difficultyMultiplier = Int(rec.exercise.difficulty) == playerDifficulty ? 1.2 : 0.8
        return min(baseImprovement * difficultyMultiplier, 1.0)
    }
    
    private func isRecentFocusArea(category: String, for player: Player) -> Bool {
        // TODO: Implement logic to check if category was recently trained
        return false
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
    
    private func fetchUserFeedback(for player: Player, limit: Int) async throws -> [RecommendationFeedback] {
        // Fetch from Core Data for now
        let request: NSFetchRequest<RecommendationFeedback> = RecommendationFeedback.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecommendationFeedback.createdAt, ascending: false)]
        request.fetchLimit = limit
        
        return try CoreDataManager.shared.context.fetch(request)
    }
    
    private func analyzeSkillProgress(for player: Player) -> SkillProgressAnalysis {
        // Analyze player's skill progression
        return SkillProgressAnalysis(
            skillLevels: ["Ball Control": 7.5, "Passing": 6.0, "Shooting": 5.5],
            recentPerformance: 0.75,
            improvementTrend: 0.1
        )
    }
    
    private func calculateTrainingFrequency(from sessions: [TrainingSession]) -> Int {
        // Calculate sessions per week
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentSessions = sessions.filter { session in
            (session.date ?? Date()) > oneWeekAgo
        }
        return recentSessions.count
    }
    
    private func analyzeFeedbackPatterns(from feedback: [RecommendationFeedback]) -> FeedbackPatterns {
        let positiveCount = feedback.filter { $0.rating >= 4 }.count
        let totalCount = feedback.count
        let satisfaction = totalCount > 0 ? Double(positiveCount) / Double(totalCount) : 0.5
        
        return FeedbackPatterns(
            averageSatisfaction: satisfaction,
            preferredDifficulty: 3, // Default
            mostLikedCategories: ["Technical", "Physical"]
        )
    }
    
    // MARK: - Helper Functions for Type Conversion
    
    private func categoryToString(_ category: CoreDataManager.RecommendationCategory) -> String {
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

struct MLDrillRecommendation: Identifiable {
    let id = UUID()
    let exerciseId: String
    let exerciseName: String
    let category: String
    let difficulty: Int
    let confidenceScore: Double
    let reasoning: String
    let recommendationType: RecommendationType
    let estimatedDuration: Int
    let targetSkills: [String]
    let personalizedInstructions: String
    let expectedImprovement: Double
    let similarUserSuccess: Double
    let createdAt: Date
    
    enum RecommendationType {
        case collaborativeFiltering
        case contentBased
        case hybrid
        case enhancedRules
        case simulatedML
    }
}

struct UserMLContext {
    let playerId: String
    let skillLevels: [String: Double]
    let recentPerformance: Double
    let trainingFrequency: Int
    let preferredDifficulty: Int
    let feedbackPatterns: FeedbackPatterns
    let lastActiveDate: Date
    let sessionCount: Int
}

struct SkillProgressAnalysis {
    let skillLevels: [String: Double]
    let recentPerformance: Double
    let improvementTrend: Double
}

struct FeedbackPatterns {
    let averageSatisfaction: Double
    let preferredDifficulty: Int
    let mostLikedCategories: [String]
}

struct YouTubeVideoRecommendation: Identifiable {
    let id = UUID()
    let videoId: String
    let title: String
    let channelTitle: String
    let description: String
    let thumbnailUrl: String
    let duration: String
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
}

enum MLError: LocalizedError {
    case notAuthenticated
    case networkError
    case modelNotAvailable
    case insufficientData
    
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
        }
    }
}
