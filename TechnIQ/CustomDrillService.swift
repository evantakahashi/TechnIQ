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
        print("🤖 CustomDrillService: Starting custom drill generation")
        print("📝 Request: \(request.skillDescription)")
        
        generationState = .generating
        isGenerating = true
        generationProgress = 0.1
        generationMessage = "Preparing your request..."
        
        do {
            // Step 1: Validate request
            guard request.isValid else {
                throw CustomDrillError.invalidRequest
            }
            
            generationProgress = 0.2
            generationMessage = "Analyzing your requirements..."
            
            // Step 2: Build player profile for context
            let playerProfile = buildPlayerProfile(for: player)
            
            generationProgress = 0.3
            generationMessage = "Generating personalized drill..."
            
            // Step 3: Call Firebase Function to generate drill
            let drillResponse = try await callFirebaseCustomDrillFunction(
                request: request,
                playerProfile: playerProfile
            )
            
            generationProgress = 0.8
            generationMessage = "Creating exercise..."
            
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
            
            print("✅ CustomDrillService: Successfully generated custom drill: \(drillResponse.name)")
            return exercise
            
        } catch {
            generationState = .error(error.localizedDescription)
            isGenerating = false
            generationProgress = 0.0
            generationMessage = "Generation failed"
            
            print("❌ CustomDrillService: Failed to generate drill: \(error)")
            throw error
        }
    }
    
    // MARK: - Firebase Function Integration
    
    private func callFirebaseCustomDrillFunction(
        request: CustomDrillRequest,
        playerProfile: [String: Any]
    ) async throws -> CustomDrillResponse {
        
        let functionsURL = "https://us-central1-techniq-b9a27.cloudfunctions.net/generate_custom_drill"
        
        guard let url = URL(string: functionsURL) else {
            throw CustomDrillError.networkError
        }
        
        // Get user ID
        let userUID = auth.currentUser?.uid ?? "anonymous_user"
        
        // Prepare request body
        let requestBody: [String: Any] = [
            "user_id": userUID,
            "player_profile": playerProfile,
            "requirements": [
                "skill_description": request.skillDescription,
                "category": request.category.rawValue,
                "difficulty": request.difficulty.rawValue,
                "equipment": request.equipmentList,
                "duration": request.duration,
                "focus_area": request.focusArea.rawValue
            ]
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
                print("⚠️ Could not get auth token: \(error.localizedDescription)")
            }
        }
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🌐 Calling Firebase Function for custom drill generation...")
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CustomDrillError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Firebase Function error: \(httpResponse.statusCode) - \(errorMessage)")

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
        
        // Save to Core Data
        try CoreDataManager.shared.save()
        
        return exercise
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
        
        return profile
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