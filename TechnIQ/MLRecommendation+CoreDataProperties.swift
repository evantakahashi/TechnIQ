import Foundation
import CoreData

extension MLRecommendation {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MLRecommendation> {
        return NSFetchRequest<MLRecommendation>(entityName: "MLRecommendation")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var playerID: String?
    @NSManaged public var exerciseID: String?
    @NSManaged public var recommendationType: String?
    @NSManaged public var confidenceScore: Double
    @NSManaged public var explanation: String?
    @NSManaged public var modelVersion: String?
    @NSManaged public var contextFactors: [String: Any]?
    @NSManaged public var isShown: Bool
    @NSManaged public var isClicked: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var expiresAt: Date?

}

extension MLRecommendation : Identifiable {

}