import Foundation
import CoreData

extension TrainingPlan {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrainingPlan> {
        return NSFetchRequest<TrainingPlan>(entityName: "TrainingPlan")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var planDescription: String?
    @NSManaged public var durationWeeks: Int16
    @NSManaged public var difficulty: String?
    @NSManaged public var category: String?
    @NSManaged public var targetRole: String?
    @NSManaged public var isPrebuilt: Bool
    @NSManaged public var isActive: Bool
    @NSManaged public var currentWeek: Int16
    @NSManaged public var progressPercentage: Double
    @NSManaged public var startedAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var player: Player?
    @NSManaged public var weeks: NSSet?

}

// MARK: Generated accessors for weeks
extension TrainingPlan {

    @objc(addWeeksObject:)
    @NSManaged public func addToWeeks(_ value: PlanWeek)

    @objc(removeWeeksObject:)
    @NSManaged public func removeFromWeeks(_ value: PlanWeek)

    @objc(addWeeks:)
    @NSManaged public func addToWeeks(_ values: NSSet)

    @objc(removeWeeks:)
    @NSManaged public func removeFromWeeks(_ values: NSSet)

}

extension TrainingPlan : Identifiable {

}
