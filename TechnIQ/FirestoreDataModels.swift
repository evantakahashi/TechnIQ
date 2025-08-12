import Foundation
import FirebaseFirestore

// MARK: - Firestore Data Models for ML Recommendation System

// MARK: - User Profile Collection Schema

struct FirestorePlayerProfile: Codable {
    let id: String
    let firebaseUID: String
    let name: String
    let age: Int
    let position: String
    let experienceLevel: String
    let competitiveLevel: String
    let playerRoleModel: String?
    let skillGoals: [String]
    let physicalFocusAreas: [String]
    let selfIdentifiedWeaknesses: [String]
    let preferredIntensity: Int
    let preferredSessionDuration: Int
    let preferredDrillComplexity: String
    let yearsPlaying: Int
    let trainingBackground: String
    let createdAt: Date
    let updatedAt: Date
    let isActive: Bool
    
    // ML-specific attributes
    let skillLevels: [String: Double] // skill name -> current level (1-10)
    let trainingFrequency: Int // sessions per week
    let lastActiveDate: Date
    let profileCompleteness: Double // 0.0 - 1.0
}

struct FirestorePlayerGoal: Codable {
    let id: String
    let playerId: String
    let skillName: String
    let currentLevel: Double
    let targetLevel: Double
    let targetDate: Date?
    let priority: String // "High", "Medium", "Low"
    let status: String // "Active", "Completed", "Paused"
    let progressNotes: String
    let createdAt: Date
    let updatedAt: Date
    
    // ML tracking
    let progressHistory: [ProgressEntry]
    let estimatedTimeToComplete: Int? // weeks
    let difficultyScore: Double
}

struct ProgressEntry: Codable {
    let date: Date
    let level: Double
    let notes: String?
}

// MARK: - Training Data Collection Schema

struct FirestoreTrainingSession: Codable {
    let id: String
    let playerId: String
    let date: Date
    let duration: Double // minutes
    let sessionType: String
    let intensity: Int // 1-10
    let location: String
    let overallRating: Int // 1-5 stars
    let notes: String
    let exercises: [FirestoreSessionExercise]
    
    // ML context data
    let weatherConditions: String?
    let energyLevelBefore: Int? // 1-10
    let energyLevelAfter: Int? // 1-10
    let perceivedExertion: Int? // 1-10 RPE scale
    let equipmentUsed: [String]
    let trainingPartners: Int // number of people
    let sessionGoals: [String]
    let sessionOutcomes: [String]
}

struct FirestoreSessionExercise: Codable {
    let exerciseId: String
    let exerciseName: String
    let category: String
    let difficulty: Int
    let duration: Double
    let sets: Int
    let reps: Int
    let performanceRating: Int // 1-5
    let notes: String
    let targetSkills: [String]
    
    // Performance metrics
    let completionPercentage: Double
    let perceivedDifficulty: Int // 1-10
    let enjoymentRating: Int // 1-5
    let technicalExecution: Int // 1-5
    let physicalDemand: Int // 1-5
}

// MARK: - Recommendation & Feedback Schema

struct FirestoreRecommendationFeedback: Codable {
    let id: String
    let playerId: String
    let exerciseId: String
    let recommendationId: String
    let recommendationSource: String // "ML", "Rule-Based", "Manual"
    let feedbackType: String // "Positive", "Negative", "Neutral"
    let rating: Int // 1-5
    let wasCompleted: Bool
    let timeSpent: Double
    let difficultyRating: Int // 1-5
    let relevanceRating: Int // 1-5
    let notes: String
    let createdAt: Date
    
    // Context when recommendation was made
    let recommendationContext: RecommendationContext
    
    // Follow-up feedback
    let wouldRecommendToOthers: Bool?
    let improvementSuggestions: String?
}

struct RecommendationContext: Codable {
    let sessionGoals: [String]
    let recentPerformance: [String: Double]
    let timeOfDay: String
    let dayOfWeek: Int
    let lastTrainingDate: Date?
    let energyLevel: Int?
    let availableTime: Int // minutes
    let availableEquipment: [String]
}

// MARK: - ML Model Data Schema

struct FirestoreMLRecommendation: Codable {
    let id: String
    let playerId: String
    let exerciseId: String
    let modelVersion: String
    let recommendationType: String // "Collaborative", "Content-Based", "Hybrid"
    let confidenceScore: Double // 0.0 - 1.0
    let explanation: String
    let contextFactors: [String: Double]
    let isShown: Bool
    let isClicked: Bool
    let createdAt: Date
    let expiresAt: Date
    
    // A/B testing
    let experimentId: String?
    let treatmentGroup: String?
    
    // Similar user patterns
    let similarUserIds: [String]
    let baselineMetrics: [String: Double]
}

// MARK: - Aggregated Data for ML Training

struct FirestoreUserCluster: Codable {
    let clusterId: String
    let clusterName: String
    let description: String
    let userIds: [String]
    let centroidFeatures: [String: Double]
    let commonSkillGoals: [String]
    let averageExperienceLevel: Double
    let preferredExerciseTypes: [String]
    let createdAt: Date
    let updatedAt: Date
    
    // Cluster performance metrics
    let averageEngagement: Double
    let averageImprovement: Double
    let retentionRate: Double
}

struct FirestoreExerciseMetrics: Codable {
    let exerciseId: String
    let exerciseName: String
    let category: String
    let difficulty: Int
    let targetSkills: [String]
    
    // Aggregated user metrics
    let totalCompletions: Int
    let averageRating: Double
    let averageDifficulty: Double
    let averageDuration: Double
    let completionRate: Double
    
    // Skill improvement correlation
    let skillImprovementData: [String: SkillImprovementMetric]
    
    // User segmentation performance
    let performanceByExperience: [String: ExercisePerformanceMetric]
    let performanceByPosition: [String: ExercisePerformanceMetric]
    
    let lastUpdated: Date
}

struct SkillImprovementMetric: Codable {
    let skillName: String
    let averageImprovement: Double
    let improvementVariance: Double
    let sampleSize: Int
    let timeToImprovement: Double // average weeks
}

struct ExercisePerformanceMetric: Codable {
    let segment: String
    let averageRating: Double
    let completionRate: Double
    let averageDifficulty: Double
    let recommendationScore: Double
}

// MARK: - Real-time User Activity

struct FirestoreUserActivity: Codable {
    let userId: String
    let sessionId: String
    let timestamp: Date
    let eventType: String
    let exerciseId: String?
    let duration: Double?
    let rating: Int?
    let metadata: [String: String]
    
    // Device and context info
    let deviceType: String
    let appVersion: String
    let location: GeoPoint?
    let networkType: String?
}

// MARK: - Collaborative Filtering Data

struct FirestoreUserSimilarity: Codable {
    let userId1: String
    let userId2: String
    let similarityScore: Double // 0.0 - 1.0
    let sharedExercises: Int
    let sharedSkillGoals: Int
    let calculatedAt: Date
    
    // Similarity breakdown
    let skillGoalSimilarity: Double
    let experienceSimilarity: Double
    let preferenceSimilarity: Double
    let performanceSimilarity: Double
}

struct FirestoreExerciseAffinity: Codable {
    let exerciseId1: String
    let exerciseId2: String
    let affinityScore: Double // how often completed together
    let coOccurrenceCount: Int
    let sharedUsers: Int
    let calculatedAt: Date
    
    // Context patterns
    let temporalAffinity: Double // how often done in sequence
    let skillTransferScore: Double // skill development correlation
}

// MARK: - Content-Based Filtering Data

struct FirestoreExerciseFeatures: Codable {
    let exerciseId: String
    let category: String
    let difficulty: Int
    let duration: Double
    let equipment: [String]
    let targetSkills: [String]
    let physicalDemands: [String]
    
    // Derived features for ML
    let skillVector: [Double] // one-hot encoded skills
    let difficultyVector: [Double] // normalized difficulty across dimensions
    let contextVector: [Double] // equipment, location, etc.
    
    // Content similarity cache
    let similarExercises: [String: Double] // exerciseId -> similarity score
    let lastFeaturesUpdate: Date
}

// MARK: - Model Performance Tracking

struct FirestoreModelMetrics: Codable {
    let modelId: String
    let modelType: String // "Collaborative", "Content", "Hybrid"
    let version: String
    let deployedAt: Date
    
    // Performance metrics
    let accuracy: Double
    let precision: Double
    let recall: Double
    let f1Score: Double
    let ndcg: Double // Normalized Discounted Cumulative Gain
    
    // User engagement metrics
    let clickThroughRate: Double
    let completionRate: Double
    let averageRating: Double
    
    // A/B test results
    let experimentResults: [String: Double]
    
    let evaluatedAt: Date
}

// MARK: - Firestore Collection Names

struct FirestoreCollections {
    static let users = "users"
    static let playerProfiles = "playerProfiles"
    static let playerGoals = "playerGoals"
    static let trainingSessions = "trainingSessions"
    static let exercises = "exercises"
    static let recommendationFeedback = "recommendationFeedback"
    static let mlRecommendations = "mlRecommendations"
    static let userClusters = "userClusters"
    static let exerciseMetrics = "exerciseMetrics"
    static let userActivity = "userActivity"
    static let userSimilarity = "userSimilarity"
    static let exerciseAffinity = "exerciseAffinity"
    static let exerciseFeatures = "exerciseFeatures"
    static let modelMetrics = "modelMetrics"
    
    // Analytics collections
    static let mlAnalytics = "mlAnalytics"
    static let userEngagement = "userEngagement"
    static let performanceTracking = "performanceTracking"
}

// MARK: - Firestore Query Helpers

extension CloudDataService {
    
    // Get recommendations for user
    func getRecommendationsQuery(for playerId: String, limit: Int = 10) -> Query {
        return db.collection(FirestoreCollections.mlRecommendations)
            .whereField("playerId", isEqualTo: playerId)
            .whereField("expiresAt", isGreaterThan: Date())
            .order(by: "confidenceScore", descending: true)
            .limit(to: limit)
    }
    
    // Get similar users query
    func getSimilarUsersQuery(for playerId: String, threshold: Double = 0.7) -> Query {
        return db.collection(FirestoreCollections.userSimilarity)
            .whereField("userId1", isEqualTo: playerId)
            .whereField("similarityScore", isGreaterThanOrEqualTo: threshold)
            .order(by: "similarityScore", descending: true)
    }
    
    // Get user training history
    func getTrainingHistoryQuery(for playerId: String, limit: Int = 50) -> Query {
        return db.collection(FirestoreCollections.trainingSessions)
            .whereField("playerId", isEqualTo: playerId)
            .order(by: "date", descending: true)
            .limit(to: limit)
    }
    
    // Get exercise metrics for recommendations
    func getExerciseMetricsQuery(for skillGoals: [String]) -> Query {
        return db.collection(FirestoreCollections.exerciseMetrics)
            .whereField("targetSkills", arrayContainsAny: skillGoals)
            .order(by: "averageRating", descending: true)
    }
}