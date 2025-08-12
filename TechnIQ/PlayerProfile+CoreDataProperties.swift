import Foundation
import CoreData

extension PlayerProfile {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerProfile> {
        return NSFetchRequest<PlayerProfile>(entityName: "PlayerProfile")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var skillGoals: [String]?
    @NSManaged public var physicalFocusAreas: [String]?
    @NSManaged public var selfIdentifiedWeaknesses: [String]?
    @NSManaged public var preferredIntensity: Int16
    @NSManaged public var preferredSessionDuration: Int16
    @NSManaged public var preferredDrillComplexity: String?
    @NSManaged public var trainingBackground: String?
    @NSManaged public var yearsPlaying: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension PlayerProfile : Identifiable {

}