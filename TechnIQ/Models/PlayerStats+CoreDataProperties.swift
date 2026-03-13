import Foundation
import CoreData

extension PlayerStats {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerStats> {
        return NSFetchRequest<PlayerStats>(entityName: "PlayerStats")
    }

    @NSManaged public var date: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var skillRatings: [String: Double]?
    @NSManaged public var totalTrainingHours: Double
    @NSManaged public var totalSessions: Int32
    @NSManaged public var player: Player?

}

extension PlayerStats : Identifiable {

}