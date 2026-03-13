import Foundation
import CoreData

extension SessionExercise {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<SessionExercise> {
        return NSFetchRequest<SessionExercise>(entityName: "SessionExercise")
    }

    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var notes: String?
    @NSManaged public var performanceRating: Int16
    @NSManaged public var reps: Int16
    @NSManaged public var sets: Int16
    @NSManaged public var exercise: Exercise?
    @NSManaged public var session: TrainingSession?

}

extension SessionExercise : Identifiable {

}