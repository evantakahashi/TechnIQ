import Foundation
import CoreData

extension Exercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }

    @NSManaged public var category: String?
    @NSManaged public var difficulty: Int16
    @NSManaged public var exerciseDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var instructions: String?
    @NSManaged public var name: String?
    @NSManaged public var targetSkills: [String]?
    @NSManaged public var sessionExercises: NSSet?

}

// MARK: Generated accessors for sessionExercises
extension Exercise {

    @objc(addSessionExercisesObject:)
    @NSManaged public func addToSessionExercises(_ value: SessionExercise)

    @objc(removeSessionExercisesObject:)
    @NSManaged public func removeFromSessionExercises(_ value: SessionExercise)

    @objc(addSessionExercises:)
    @NSManaged public func addToSessionExercises(_ values: NSSet)

    @objc(removeSessionExercises:)
    @NSManaged public func removeFromSessionExercises(_ values: NSSet)

}

extension Exercise : Identifiable {

}