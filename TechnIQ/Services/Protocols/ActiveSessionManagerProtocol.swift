import Foundation
import CoreData

@MainActor
protocol ActiveSessionManagerProtocol: AnyObject {
    var phase: TrainingPhase { get }
    var currentExerciseIndex: Int { get }
    var exerciseRatings: [Int] { get }
    var exerciseNotes: [String] { get }
    var exercises: [Exercise] { get }
    var currentExercise: Exercise? { get }
    var upNextExercise: Exercise? { get }
    var isLastExercise: Bool { get }

    func start()
    func completeExercise()
    func rateExercise(_ rating: Int, notes: String)
    func nextExercise()
    func endSessionEarly()
    func finishSession(player: Player, context: NSManagedObjectContext) -> (xpBreakdown: SessionXPBreakdown?, newLevel: Int?, achievements: [Achievement])
    func averageRating() -> Int
}
