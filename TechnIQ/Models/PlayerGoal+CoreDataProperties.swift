import Foundation
import CoreData

extension PlayerGoal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerGoal> {
        return NSFetchRequest<PlayerGoal>(entityName: "PlayerGoal")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var skillName: String?
    @NSManaged public var currentLevel: Double
    @NSManaged public var targetLevel: Double
    @NSManaged public var targetDate: Date?
    @NSManaged public var priority: String?
    @NSManaged public var status: String?
    @NSManaged public var progressNotes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?

}

extension PlayerGoal : Identifiable {

}