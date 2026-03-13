import Foundation
import CoreData

extension PlanDay {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanDay> {
        return NSFetchRequest<PlanDay>(entityName: "PlanDay")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var dayNumber: Int16
    @NSManaged public var dayOfWeek: String?
    @NSManaged public var isRestDay: Bool
    @NSManaged public var isSkipped: Bool
    @NSManaged public var notes: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var week: PlanWeek?
    @NSManaged public var sessions: NSSet?

}

// MARK: Generated accessors for sessions
extension PlanDay {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: PlanSession)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: PlanSession)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

extension PlanDay : Identifiable {

}
