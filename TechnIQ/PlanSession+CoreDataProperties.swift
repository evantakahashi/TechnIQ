import Foundation
import CoreData

extension PlanSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlanSession> {
        return NSFetchRequest<PlanSession>(entityName: "PlanSession")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var sessionType: String?
    @NSManaged public var duration: Int16
    @NSManaged public var intensity: Int16
    @NSManaged public var notes: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var completedAt: Date?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var actualDuration: Int16
    @NSManaged public var actualIntensity: Int16
    @NSManaged public var day: PlanDay?
    @NSManaged public var exercises: NSSet?
    @NSManaged public var completedSession: TrainingSession?

}

// MARK: Generated accessors for exercises
extension PlanSession {

    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: Exercise)

    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: Exercise)

    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)

    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)

}

extension PlanSession : Identifiable {

}
