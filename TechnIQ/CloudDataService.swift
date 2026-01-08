import Foundation
import FirebaseFirestore
import FirebaseAuth
import Network

// MARK: - Cloud Data Service for Firebase Firestore Integration

@MainActor
class CloudDataService: ObservableObject {
    static let shared = CloudDataService()
    
    let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var syncStatus: CloudSyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isNetworkAvailable = true
    
    enum CloudSyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }
    
    private init() {
        setupFirestore()
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Firestore Configuration
    
    private func setupFirestore() {
        let settings = FirestoreSettings()
        // Use only supported settings - removed deprecated ones
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isNetworkAvailable = path.status == .satisfied
                if path.status != .satisfied {
                    #if DEBUG
                    print("🌐 Network connection lost - will skip cloud sync operations")
                    #endif
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Player Profile Sync
    
    func syncPlayerProfile(_ player: Player, with profile: PlayerProfile) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }
        
        syncStatus = .syncing
        
        do {
            let playerData = try createPlayerProfileDocument(player: player, profile: profile)
            
            try await db.collection("users").document(userUID)
                .collection("playerProfiles").document(player.id?.uuidString ?? UUID().uuidString)
                .setData(playerData, merge: true)
            
            // Update local sync status
            player.lastCloudSync = Date()
            
            syncStatus = .success
            lastSyncDate = Date()
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }
    
    func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        let batch = db.batch()
        
        for goal in goals {
            let goalData = try createPlayerGoalDocument(goal: goal)
            let docRef = db.collection("users").document(userUID)
                .collection("playerGoals").document(goal.id?.uuidString ?? UUID().uuidString)
            batch.setData(goalData, forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Training Session Sync
    
    func syncTrainingSession(_ session: TrainingSession) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }
        
        let sessionData = try createTrainingSessionDocument(session: session)
        
        try await db.collection("users").document(userUID)
            .collection("trainingSessions").document(session.id?.uuidString ?? UUID().uuidString)
            .setData(sessionData, merge: true)
    }
    
    // MARK: - Recommendation Feedback Sync
    
    func syncRecommendationFeedback(_ feedback: [RecommendationFeedback]) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        let batch = db.batch()
        
        for feedbackItem in feedback {
            let feedbackData = try createRecommendationFeedbackDocument(feedback: feedbackItem)
            let docRef = db.collection("users").document(userUID)
                .collection("recommendationFeedback").document(feedbackItem.id?.uuidString ?? UUID().uuidString)
            batch.setData(feedbackData, forDocument: docRef, merge: true)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Data Retrieval
    
    func fetchPlayerProfile(for playerID: String) async throws -> [String: Any]? {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        let document = try await db.collection("users").document(userUID)
            .collection("playerProfiles").document(playerID).getDocument()
        
        return document.data()
    }
    
    func fetchAllUserData() async throws -> CloudUserData {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }
        
        let userRef = db.collection("users").document(userUID)
        
        // Fetch all collections in parallel
        async let profilesSnapshot = userRef.collection("playerProfiles").getDocuments()
        async let goalsSnapshot = userRef.collection("playerGoals").getDocuments()
        async let sessionsSnapshot = userRef.collection("trainingSessions").getDocuments()
        async let feedbackSnapshot = userRef.collection("recommendationFeedback").getDocuments()
        
        let (profiles, goals, sessions, feedback) = try await (
            profilesSnapshot, goalsSnapshot, sessionsSnapshot, feedbackSnapshot
        )
        
        return CloudUserData(
            playerProfiles: profiles.documents.compactMap { $0.data() },
            playerGoals: goals.documents.compactMap { $0.data() },
            trainingSessions: sessions.documents.compactMap { $0.data() },
            recommendationFeedback: feedback.documents.compactMap { $0.data() }
        )
    }
    
    // MARK: - Analytics and ML Data Collection
    
    func submitMLAnalyticsData(_ data: MLAnalyticsData) async throws {
        let analyticsData = try createMLAnalyticsDocument(data: data)
        
        try await db.collection("mlAnalytics").document(data.sessionId).setData(analyticsData, merge: true)
    }
    
    func fetchSimilarPlayerProfiles(for playerProfile: PlayerProfile, limit: Int = 10) async throws -> [CloudPlayerProfile] {
        // Query for players with similar skill goals and attributes
        let skillGoalsQuery = db.collection("aggregatedProfiles")
            .whereField("skillGoals", arrayContainsAny: playerProfile.skillGoals ?? [])
            .limit(to: limit)
        
        let snapshot = try await skillGoalsQuery.getDocuments()
        return snapshot.documents.compactMap { document in
            try? createCloudPlayerProfile(from: document.data())
        }
    }
    
    // MARK: - Offline Queue Management

    func syncOfflineChanges() async throws {
        // Implement offline change queue sync
        // This would sync any changes made while offline
        syncStatus = .syncing

        // Fetch pending changes from Core Data
        // Sync each change type in order
        // Mark changes as synced

        syncStatus = .success
        lastSyncDate = Date()
    }

    // MARK: - Community Training Plans

    func shareTrainingPlan(_ plan: TrainingPlanModel, message: String) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        let planData = try createSharedPlanDocument(plan: plan, message: message, userUID: userUID)

        try await db.collection("communityPlans").document(plan.id.uuidString)
            .setData(planData, merge: false)

        #if DEBUG
        print("✅ Successfully shared plan '\(plan.name)' to community")
        #endif
    }
}

// MARK: - Document Creation Helpers

extension CloudDataService {
    private func createPlayerProfileDocument(player: Player, profile: PlayerProfile) throws -> [String: Any] {
        return [
            "playerId": player.id?.uuidString ?? "",
            "firebaseUID": player.firebaseUID ?? "",
            "name": player.name ?? "",
            "age": player.age,
            "position": player.position ?? "",
            "experienceLevel": player.experienceLevel ?? "",
            "competitiveLevel": player.competitiveLevel ?? "",
            "playerRoleModel": player.playerRoleModel ?? "",
            "skillGoals": profile.skillGoals ?? [],
            "physicalFocusAreas": profile.physicalFocusAreas ?? [],
            "selfIdentifiedWeaknesses": profile.selfIdentifiedWeaknesses ?? [],
            "preferredIntensity": profile.preferredIntensity,
            "preferredSessionDuration": profile.preferredSessionDuration,
            "preferredDrillComplexity": profile.preferredDrillComplexity ?? "",
            "yearsPlaying": profile.yearsPlaying,
            "trainingBackground": profile.trainingBackground ?? "",
            "createdAt": profile.createdAt ?? Date(),
            "updatedAt": Date()
        ]
    }
    
    private func createPlayerGoalDocument(goal: PlayerGoal) throws -> [String: Any] {
        return [
            "goalId": goal.id?.uuidString ?? "",
            "skillName": goal.skillName ?? "",
            "currentLevel": goal.currentLevel,
            "targetLevel": goal.targetLevel,
            "targetDate": goal.targetDate ?? NSNull(),
            "priority": goal.priority ?? "",
            "status": goal.status ?? "",
            "progressNotes": goal.progressNotes ?? "",
            "createdAt": goal.createdAt ?? Date(),
            "updatedAt": Date()
        ] as [String: Any]
    }
    
    private func createTrainingSessionDocument(session: TrainingSession) throws -> [String: Any] {
        var exercisesData: [[String: Any]] = []
        if let exercises = session.exercises as? Set<SessionExercise> {
            exercisesData = exercises.map { exercise in
                [
                    "exerciseId": exercise.exercise?.id?.uuidString ?? "",
                    "exerciseName": exercise.exercise?.name ?? "",
                    "duration": exercise.duration,
                    "sets": exercise.sets,
                    "reps": exercise.reps,
                    "performanceRating": exercise.performanceRating,
                    "notes": exercise.notes ?? ""
                ]
            }
        }
        
        return [
            "sessionId": session.id?.uuidString ?? "",
            "playerId": session.player?.id?.uuidString ?? "",
            "date": session.date ?? Date(),
            "duration": session.duration,
            "sessionType": session.sessionType ?? "",
            "intensity": session.intensity,
            "location": session.location ?? "",
            "overallRating": session.overallRating,
            "notes": session.notes ?? "",
            "exercises": exercisesData
        ]
    }
    
    private func createRecommendationFeedbackDocument(feedback: RecommendationFeedback) throws -> [String: Any] {
        return [
            "feedbackId": feedback.id?.uuidString ?? "",
            "playerId": feedback.player?.id?.uuidString ?? "",
            "exerciseID": feedback.exerciseID ?? "",
            "recommendationSource": feedback.recommendationSource ?? "",
            "feedbackType": feedback.feedbackType ?? "",
            "rating": feedback.rating,
            "wasCompleted": feedback.wasCompleted,
            "timeSpent": feedback.timeSpent,
            "difficultyRating": feedback.difficultyRating,
            "relevanceRating": feedback.relevanceRating,
            "notes": feedback.notes ?? "",
            "createdAt": feedback.createdAt ?? Date()
        ]
    }
    
    private func createMLAnalyticsDocument(data: MLAnalyticsData) throws -> [String: Any] {
        return [
            "sessionId": data.sessionId,
            "playerId": data.playerId,
            "timestamp": data.timestamp,
            "eventType": data.eventType.rawValue,
            "exerciseId": data.exerciseId as Any,
            "userAction": data.userAction,
            "contextData": data.contextData,
            "deviceInfo": data.deviceInfo
        ]
    }
    
    private func createCloudPlayerProfile(from data: [String: Any]) throws -> CloudPlayerProfile {
        return CloudPlayerProfile(
            playerId: data["playerId"] as? String ?? "",
            skillGoals: data["skillGoals"] as? [String] ?? [],
            experienceLevel: data["experienceLevel"] as? String ?? "",
            competitiveLevel: data["competitiveLevel"] as? String ?? "",
            position: data["position"] as? String ?? "",
            preferredIntensity: data["preferredIntensity"] as? Int ?? 5,
            physicalFocusAreas: data["physicalFocusAreas"] as? [String] ?? []
        )
    }

    private func createSharedPlanDocument(plan: TrainingPlanModel, message: String, userUID: String) throws -> [String: Any] {
        // Serialize weeks
        let weeksData = plan.weeks.map { week -> [String: Any] in
            let daysData = week.days.map { day -> [String: Any] in
                let sessionsData = day.sessions.map { session -> [String: Any] in
                    return [
                        "sessionType": session.sessionType.rawValue,
                        "duration": session.duration,
                        "intensity": session.intensity,
                        "notes": session.notes ?? "",
                        "exerciseIDs": session.exerciseIDs.map { $0.uuidString }
                    ]
                }

                return [
                    "dayNumber": day.dayNumber,
                    "dayOfWeek": day.dayOfWeek?.rawValue ?? "",
                    "isRestDay": day.isRestDay,
                    "notes": day.notes ?? "",
                    "sessions": sessionsData
                ]
            }

            return [
                "weekNumber": week.weekNumber,
                "focusArea": week.focusArea ?? "",
                "notes": week.notes ?? "",
                "days": daysData
            ]
        }

        return [
            "id": plan.id.uuidString,
            "name": plan.name,
            "description": plan.description,
            "durationWeeks": plan.durationWeeks,
            "difficulty": plan.difficulty.rawValue,
            "category": plan.category.rawValue,
            "targetRole": plan.targetRole ?? "",
            "estimatedTotalHours": plan.estimatedTotalHours,
            "weeks": weeksData,
            "contributorUID": userUID,
            "contributorMessage": message,
            "sharedAt": Date(),
            "upvotes": 0,
            "downloads": 0
        ] as [String: Any]
    }
}

// MARK: - Data Models

struct CloudUserData {
    let playerProfiles: [[String: Any]]
    let playerGoals: [[String: Any]]
    let trainingSessions: [[String: Any]]
    let recommendationFeedback: [[String: Any]]
}

struct CloudPlayerProfile {
    let playerId: String
    let skillGoals: [String]
    let experienceLevel: String
    let competitiveLevel: String
    let position: String
    let preferredIntensity: Int
    let physicalFocusAreas: [String]
}

struct MLAnalyticsData {
    let sessionId: String
    let playerId: String
    let timestamp: Date
    let eventType: MLEventType
    let exerciseId: String?
    let userAction: String
    let contextData: [String: Any]
    let deviceInfo: [String: String]
    
    enum MLEventType: String, CaseIterable {
        case sessionStart = "session_start"
        case exerciseView = "exercise_view"
        case exerciseComplete = "exercise_complete"
        case feedbackSubmit = "feedback_submit"
        case recommendationView = "recommendation_view"
        case recommendationClick = "recommendation_click"
        case sessionComplete = "session_complete"
    }
}

// MARK: - Errors

enum CloudDataError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network connection error"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}