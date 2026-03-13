import Foundation
import CoreData

extension PlanWeek {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanWeek> {
        return NSFetchRequest<PlanWeek>(entityName: "PlanWeek")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weekNumber: Int16
    @NSManaged public var focusArea: String?
    @NSManaged public var notes: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var plan: TrainingPlan?
    @NSManaged public var days: NSSet?

}

// MARK: Generated accessors for days
extension PlanWeek {

    @objc(addDaysObject:)
    @NSManaged public func addToDays(_ value: PlanDay)

    @objc(removeDaysObject:)
    @NSManaged public func removeFromDays(_ value: PlanDay)

    @objc(addDays:)
    @NSManaged public func addToDays(_ values: NSSet)

    @objc(removeDays:)
    @NSManaged public func removeFromDays(_ values: NSSet)

}

extension PlanWeek : Identifiable {

}
