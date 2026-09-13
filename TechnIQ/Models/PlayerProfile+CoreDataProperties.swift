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
    // Training profile (editable after onboarding): the goal chosen and the weekdays the player trains,
    // comma-separated DayOfWeek raw values.
    @NSManaged public var trainingGoal: String?
    @NSManaged public var trainingDays: String?
    @NSManaged public var yearsPlaying: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension PlayerProfile : Identifiable {

}