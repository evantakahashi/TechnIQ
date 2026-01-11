import Foundation
import CoreData

extension Player {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        return NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var age: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var dominantFoot: String?
    @NSManaged public var firebaseUID: String?
    @NSManaged public var height: Double
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var playingStyle: String?
    @NSManaged public var position: String?
    @NSManaged public var weight: Double
    @NSManaged public var experienceLevel: String?
    @NSManaged public var competitiveLevel: String?
    @NSManaged public var playerRoleModel: String?
    @NSManaged public var lastCloudSync: Date?
    @NSManaged public var totalXP: Int64
    @NSManaged public var currentLevel: Int16
    @NSManaged public var currentStreak: Int16
    @NSManaged public var longestStreak: Int16
    @NSManaged public var lastTrainingDate: Date?
    @NSManaged public var unlockedAchievements: [String]?
    @NSManaged public var streakFreezes: Int16
    @NSManaged public var coins: Int64
    @NSManaged public var totalCoinsEarned: Int64
    @NSManaged public var sessions: NSSet?
    @NSManaged public var avatarConfiguration: AvatarConfiguration?
    @NSManaged public var ownedAvatarItems: NSSet?
    @NSManaged public var stats: NSSet?
    @NSManaged public var exercises: NSSet?
    @NSManaged public var playerProfile: PlayerProfile?
    @NSManaged public var playerGoals: NSSet?
    @NSManaged public var recommendationFeedback: NSSet?
    @NSManaged public var trainingPlans: NSSet?

}

// MARK: Generated accessors for sessions
extension Player {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: TrainingSession)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: TrainingSession)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

// MARK: Generated accessors for stats
extension Player {

    @objc(addStatsObject:)
    @NSManaged public func addToStats(_ value: PlayerStats)

    @objc(removeStatsObject:)
    @NSManaged public func removeFromStats(_ value: PlayerStats)

    @objc(addStats:)
    @NSManaged public func addToStats(_ values: NSSet)

    @objc(removeStats:)
    @NSManaged public func removeFromStats(_ values: NSSet)

}

// MARK: Generated accessors for exercises
extension Player {

    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: Exercise)

    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: Exercise)

    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)

    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)

}

// MARK: Generated accessors for playerGoals
extension Player {

    @objc(addPlayerGoalsObject:)
    @NSManaged public func addToPlayerGoals(_ value: PlayerGoal)

    @objc(removePlayerGoalsObject:)
    @NSManaged public func removeFromPlayerGoals(_ value: PlayerGoal)

    @objc(addPlayerGoals:)
    @NSManaged public func addToPlayerGoals(_ values: NSSet)

    @objc(removePlayerGoals:)
    @NSManaged public func removeFromPlayerGoals(_ values: NSSet)

}

// MARK: Generated accessors for recommendationFeedback
extension Player {

    @objc(addRecommendationFeedbackObject:)
    @NSManaged public func addToRecommendationFeedback(_ value: RecommendationFeedback)

    @objc(removeRecommendationFeedbackObject:)
    @NSManaged public func removeFromRecommendationFeedback(_ value: RecommendationFeedback)

    @objc(addRecommendationFeedback:)
    @NSManaged public func addToRecommendationFeedback(_ values: NSSet)

    @objc(removeRecommendationFeedback:)
    @NSManaged public func removeFromRecommendationFeedback(_ values: NSSet)

}

// MARK: Generated accessors for trainingPlans
extension Player {

    @objc(addTrainingPlansObject:)
    @NSManaged public func addToTrainingPlans(_ value: TrainingPlan)

    @objc(removeTrainingPlansObject:)
    @NSManaged public func removeFromTrainingPlans(_ value: TrainingPlan)

    @objc(addTrainingPlans:)
    @NSManaged public func addToTrainingPlans(_ values: NSSet)

    @objc(removeTrainingPlans:)
    @NSManaged public func removeFromTrainingPlans(_ values: NSSet)

}

// MARK: Generated accessors for ownedAvatarItems
extension Player {

    @objc(addOwnedAvatarItemsObject:)
    @NSManaged public func addToOwnedAvatarItems(_ value: OwnedAvatarItem)

    @objc(removeOwnedAvatarItemsObject:)
    @NSManaged public func removeFromOwnedAvatarItems(_ value: OwnedAvatarItem)

    @objc(addOwnedAvatarItems:)
    @NSManaged public func addToOwnedAvatarItems(_ values: NSSet)

    @objc(removeOwnedAvatarItems:)
    @NSManaged public func removeFromOwnedAvatarItems(_ values: NSSet)

}

extension Player : Identifiable {

}