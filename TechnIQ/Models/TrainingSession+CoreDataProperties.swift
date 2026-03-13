import Foundation
import CoreData

extension TrainingSession {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TrainingSession> {
        return NSFetchRequest<TrainingSession>(entityName: "TrainingSession")
    }

    @NSManaged public var date: Date?
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var intensity: Int16
    @NSManaged public var location: String?
    @NSManaged public var notes: String?
    @NSManaged public var overallRating: Int16
    @NSManaged public var sessionType: String?
    @NSManaged public var xpEarned: Int32
    @NSManaged public var exercises: NSSet?
    @NSManaged public var player: Player?
    @NSManaged public var planSession: PlanSession?

}

// MARK: Generated accessors for exercises
extension TrainingSession {

    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: SessionExercise)

    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: SessionExercise)

    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)

    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)

}

extension TrainingSession : Identifiable {

}