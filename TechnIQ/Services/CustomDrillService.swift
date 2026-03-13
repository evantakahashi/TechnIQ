import Foundation
import FirebaseAuth
import FirebaseFirestore
import CoreData

// MARK: - Custom Drill Generation Service

@MainActor
class CustomDrillService: ObservableObject {
    static let shared = CustomDrillService()
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    @Published var generationState: DrillGenerationState = .idle
    @Published var isGenerating: Bool = false
    @Published var generationProgress: Double = 0.0
    @Published var generationMessage: String = ""
    
    private init() {}
    
    // MARK: - Main Generation Function
    
    func generateCustomDrill(
        request: CustomDrillRequest, 
        for player: Player
    ) async throws -> Exercise {
        #if DEBUG
        print("🤖 CustomDrillService: Starting custom drill generation")
        #endif
        #if DEBUG
        print("📝 Request: \(request.skillDescription)")
        
        #endif
        generationState = .generating
        isGenerating = true
        generationProgress = 0.1
        generationMessage = "Preparing your request..."
        
        do {
            // Step 1: Validate request
            guard request.isValid else {
                throw CustomDrillError.invalidRequest
            }

            generationProgress = 0.1
            generationMessage = "Preparing your request..."

            // Step 2: Build player profile for context
            let playerProfile = buildPlayerProfile(for: player)

            // Start animated progress for 4-phase pipeline
            startPhaseProgressAnimation()

            // Step 3: Call Firebase Function (runs 4-phase pipeline server-side)
            let drillResponse = try await callFirebaseCustomDrillFunction(
                request: request,
                playerProfile: playerProfile,
                player: player
            )

            generationProgress = 0.9
            generationMessage = "Finalizing..."
            
            // Step 4: Create Exercise from LLM response
            let exercise = try createExerciseFromLLMResponse(
                drillResponse, 
                originalRequest: request,
                for: player
            )
            
            generationProgress = 1.0
            generationMessage = "Complete!"
            
            generationState = .success(drillResponse)
            
            // Reset state after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isGenerating = false
                self.generationProgress = 0.0
                self.generationMessage = ""
                self.generationState = .idle
            }
            
            #if DEBUG
            
            print("✅ CustomDrillService: Successfully generated custom drill: \(drillResponse.name)")
            
            #endif
            return exercise
            
        } catch {
            generationState = .error(error.localizedDescription)
            isGenerating = false
            generationProgress = 0.0
            generationMessage = "Generation failed"
            
            #if DEBUG
            
            print("❌ CustomDrillService: Failed to generate drill: \(error)")
            
            #endif
            throw error
        }
    }
    
    // MARK: - Phase Progress Animation

    private func startPhaseProgressAnimation() {
        let phases: [(Double, String, Double)] = [
            (0.15, "Analyzing your training history...", 1.5),
            (0.35, "Designing drill layout...", 3.0),
            (0.55, "Writing instructions...", 5.0),
            (0.75, "Validating drill quality...", 7.0)
        ]

        for (progress, message, delay) in phases {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self, self.isGenerating else { return }
                self.generationProgress = progress
                self.generationMessage = message
            }
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
        throw lastError ?? CustomDrillError.networkError
    }

    // MARK: - Firebase Function Integration

    private func callFirebaseCustomDrillFunction(
        request: CustomDrillRequest,
        playerProfile: [String: Any],
        player: Player
    ) async throws -> CustomDrillResponse {

        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/generate_custom_drill"

        guard let url = URL(string: functionsURL) else {
            throw CustomDrillError.networkError
        }

        // Get user ID
        let userUID = auth.currentUser?.uid ?? "anonymous_user"

        // Build session context from recent training history
        let sessionContext = buildSessionContext(for: player)

        // Build drill feedback context from previous AI drills
        let drillFeedback = buildDrillFeedbackContext(for: player)

        // Build requirements dict
        var requirements: [String: Any] = [
            "skill_description": request.skillDescription,
            "category": request.category.rawValue,
            "difficulty": request.difficulty.rawValue,
            "equipment": request.equipmentList,
            "number_of_players": request.numberOfPlayers
        ]

        // Add structured weaknesses if present
        if !request.selectedWeaknesses.isEmpty {
            requirements["selected_weaknesses"] = request.selectedWeaknesses.map {
                ["category": $0.category, "specific": $0.specific]
            }
        }

        // Build recent drill names for anti-repetition
        let recentDrillNames = getRecentDrillNames(for: player, limit: 5)
        if !recentDrillNames.isEmpty {
            requirements["recent_drill_names"] = recentDrillNames
        }

        // Prepare request body
        let requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerProfile,
            "session_context": sessionContext,
            "drill_feedback": drillFeedback,
            "field_size": request.fieldSize.rawValue,
            "requirements": requirements
        ]
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Firebase Auth token if available
        if let user = auth.currentUser {
            do {
                let idToken = try await user.getIDToken()
                urlRequest.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            } catch {
                #if DEBUG
                print("⚠️ Could not get auth token: \(error.localizedDescription)")
                #endif
            }
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        urlRequest.timeoutInterval = 90

        #if DEBUG

        print("🌐 Calling Firebase Function for custom drill generation...")


        #endif
        let (data, response) = try await performRequestWithRetry(urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CustomDrillError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            #if DEBUG
            print("❌ Firebase Function error: \(httpResponse.statusCode) - \(errorMessage)")

            #endif
            // Check for OpenAI quota error
            if httpResponse.statusCode == 500 && errorMessage.contains("insufficient_quota") {
                throw CustomDrillError.quotaExceeded
            }

            throw CustomDrillError.serverError(errorMessage)
        }
        
        // Parse response
        let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let drillData = jsonResponse?["drill"] as? [String: Any] else {
            throw CustomDrillError.invalidResponse
        }
        
        // Convert to CustomDrillResponse
        let drillResponseData = try JSONSerialization.data(withJSONObject: drillData)
        let drillResponse = try JSONDecoder().decode(CustomDrillResponse.self, from: drillResponseData)
        
        return drillResponse
    }
    
    // MARK: - Exercise Creation
    
    private func createExerciseFromLLMResponse(
        _ response: CustomDrillResponse,
        originalRequest: CustomDrillRequest,
        for player: Player
    ) throws -> Exercise {
        
        let context = CoreDataManager.shared.context
        let exercise = Exercise(context: context)
        
        exercise.id = UUID()
        exercise.name = response.name
        exercise.category = response.category.capitalized
        exercise.difficulty = Int16(originalRequest.difficulty.numericValue)
        exercise.exerciseDescription = "🤖 AI-Generated Custom Drill\n\n" + response.description
        exercise.targetSkills = response.targetSkills
        exercise.setValue(player, forKey: "player")
        
        // Mark as custom generated content
        exercise.isYouTubeContent = false // This will help us identify custom content

        // Store diagram JSON if available
        if let diagram = response.diagram {
            let encoder = JSONEncoder()
            if let diagramData = try? encoder.encode(diagram),
               let diagramString = String(data: diagramData, encoding: .utf8) {
                exercise.diagramJSON = diagramString
            }
        }
        
        // Create detailed instructions
        var instructionsText = "**Setup:**\n\(response.setup)\n\n"
        instructionsText += "**Instructions:**\n"
        
        for (index, instruction) in response.instructions.enumerated() {
            instructionsText += "\(index + 1). \(instruction)\n"
        }
        
        if let coachingPoints = response.coachingPoints, !coachingPoints.isEmpty {
            instructionsText += "\n**Coaching Points:**\n"
            for point in coachingPoints {
                instructionsText += "• \(point)\n"
            }
        }
        
        if let progressions = response.progressions, !progressions.isEmpty {
            instructionsText += "\n**Progressions:**\n"
            for progression in progressions {
                instructionsText += "• \(progression)\n"
            }
        }
        
        if let safetyNotes = response.safetyNotes {
            instructionsText += "\n**Safety Notes:**\n\(safetyNotes)\n"
        }
        
        // Add generation metadata
        instructionsText += "\n**Generated:** \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))"
        instructionsText += "\n**Original Request:** \(originalRequest.skillDescription)"
        
        exercise.instructions = instructionsText

        // Store structured data
        exercise.estimatedDurationSeconds = Int16(response.estimatedDuration * 60)

        if let variations = response.variations, !variations.isEmpty {
            if let data = try? JSONEncoder().encode(variations),
               let jsonString = String(data: data, encoding: .utf8) {
                exercise.variationsJSON = jsonString
            }
        }

        // Store weakness categories from the request
        if !originalRequest.selectedWeaknesses.isEmpty {
            exercise.weaknessCategories = originalRequest.selectedWeaknesses
                .map { "\($0.category):\($0.specific)" }
                .joined(separator: ",")
        }

        // Save to Core Data
        try CoreDataManager.shared.save()

        return exercise
    }

    // MARK: - Anti-Repetition

    private func getRecentDrillNames(for player: Player, limit: Int) -> [String] {
        guard let exercises = player.exercises as? Set<Exercise> else { return [] }
        return exercises
            .filter { $0.exerciseDescription?.contains("AI-Generated") == true }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(limit)
            .compactMap { $0.name }
    }

    // MARK: - Player Profile Building

    private func buildPlayerProfile(for player: Player) -> [String: Any] {
        var profile: [String: Any] = [
            "name": player.name ?? "Unknown",
            "age": Int(player.age),
            "position": player.position ?? "Unknown",
            "experienceLevel": player.experienceLevel ?? "intermediate",
            "competitiveLevel": player.competitiveLevel ?? "recreational"
        ]

        if let playerRoleModel = player.playerRoleModel, !playerRoleModel.isEmpty {
            profile["playerRoleModel"] = playerRoleModel
        }

        if let playingStyle = player.playingStyle, !playingStyle.isEmpty {
            profile["playingStyle"] = playingStyle
        }

        if let dominantFoot = player.dominantFoot, !dominantFoot.isEmpty {
            profile["dominantFoot"] = dominantFoot
        }

        // Add goals from PlayerProfile if available
        if let playerProfile = player.playerProfile {
            if let skillGoals = playerProfile.skillGoals, !skillGoals.isEmpty {
                profile["skillGoals"] = skillGoals
            }

            if let weaknesses = playerProfile.selfIdentifiedWeaknesses, !weaknesses.isEmpty {
                profile["weaknesses"] = weaknesses
            }

            if let physicalFocusAreas = playerProfile.physicalFocusAreas, !physicalFocusAreas.isEmpty {
                profile["physicalFocusAreas"] = physicalFocusAreas
            }
        }

        // Add match performance data from recent matches
        let matchPerformance = getMatchPerformanceData(for: player, limit: 5)
        if !matchPerformance.isEmpty {
            profile["matchPerformance"] = matchPerformance
        }

        return profile
    }

    // MARK: - Match Performance Analysis

    /// Analyzes recent matches to extract strengths/weaknesses frequency
    private func getMatchPerformanceData(for player: Player, limit: Int = 5) -> [String: Any] {
        let matches = MatchService.shared.fetchMatches(for: player)
        let recentMatches = Array(matches.prefix(limit))

        guard !recentMatches.isEmpty else { return [:] }

        // Count weakness occurrences
        var weaknessCount: [String: Int] = [:]
        var strengthCount: [String: Int] = [:]
        var totalRating: Int = 0
        var ratedMatches: Int = 0

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

            // Track ratings
            if match.rating > 0 {
                totalRating += Int(match.rating)
                ratedMatches += 1
            }
        }

        // Sort by frequency, get top items
        let topWeaknesses = weaknessCount.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let topStrengths = strengthCount.sorted { $0.value > $1.value }.prefix(3).map { $0.key }
        let averageRating = ratedMatches > 0 ? Double(totalRating) / Double(ratedMatches) : 0.0

        var result: [String: Any] = [
            "matchCount": recentMatches.count
        ]

        if !topWeaknesses.isEmpty {
            result["recentWeaknesses"] = topWeaknesses
        }

        if !topStrengths.isEmpty {
            result["recentStrengths"] = topStrengths
        }

        if averageRating > 0 {
            result["averageRating"] = averageRating
        }

        return result
    }

    // MARK: - Session Context Building

    private func buildSessionContext(for player: Player) -> [String: Any] {
        let sessions = CoreDataManager.shared.fetchTrainingSessions(for: player.firebaseUID ?? "")
        let recentSessions = Array(sessions.prefix(5))

        var exerciseHistory: [[String: Any]] = []
        for session in recentSessions {
            guard let exercises = session.exercises?.allObjects as? [SessionExercise] else { continue }
            for ex in exercises {
                exerciseHistory.append([
                    "skill": ex.exercise?.category ?? "Unknown",
                    "rating": ex.performanceRating,
                    "notes": ex.notes ?? ""
                ])
            }
        }

        // Limit to 10 most recent exercise records
        return ["recent_exercises": Array(exerciseHistory.prefix(10))]
    }

    // MARK: - Drill Feedback Context Building

    private func buildDrillFeedbackContext(for player: Player) -> [[String: Any]] {
        let feedback = CoreDataManager.shared.fetchDrillFeedback(for: player, limit: 5)

        return feedback.map { fb in
            var feedbackDict: [String: Any] = [
                "rating": fb.rating,
                "feedback_type": fb.feedbackType ?? "Neutral"
            ]

            // Map difficulty rating to descriptive string
            switch fb.difficultyRating {
            case 1:
                feedbackDict["difficulty_feedback"] = "too_easy"
            case 5:
                feedbackDict["difficulty_feedback"] = "too_hard"
            default:
                feedbackDict["difficulty_feedback"] = "appropriate"
            }

            if let notes = fb.notes, !notes.isEmpty {
                feedbackDict["notes"] = notes
            }

            return feedbackDict
        }
    }
}

// MARK: - Custom Errors

enum CustomDrillError: LocalizedError {
    case invalidRequest
    case networkError
    case serverError(String)
    case invalidResponse
    case authenticationRequired
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Please provide a valid skill description (at least 10 characters)"
        case .networkError:
            return "Network connection error. Please check your internet connection."
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidResponse:
            return "Invalid response from server. Please try again."
        case .authenticationRequired:
            return "Authentication required to generate custom drills."
        case .quotaExceeded:
            return "AI service is temporarily unavailable due to usage limits. Please try again later or contact support."
        }
    }
}