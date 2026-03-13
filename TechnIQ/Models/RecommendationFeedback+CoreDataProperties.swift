import Foundation
import CoreData

extension RecommendationFeedback {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RecommendationFeedback> {
        return NSFetchRequest<RecommendationFeedback>(entityName: "RecommendationFeedback")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var exerciseID: String?
    @NSManaged public var recommendationSource: String?
    @NSManaged public var feedbackType: String?
    @NSManaged public var rating: Int16
    @NSManaged public var wasCompleted: Bool
    @NSManaged public var timeSpent: Double
    @NSManaged public var difficultyRating: Int16
    @NSManaged public var relevanceRating: Int16
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var player: Player?

}

extension RecommendationFeedback : Identifiable {

}