import Foundation
import CoreData

protocol CoreDataManagerProtocol: AnyObject {
    var context: NSManagedObjectContext { get }
    func save()
    func getCurrentPlayer() -> Player?
    func getCurrentPlayer(for firebaseUID: String) -> Player?
    func fetchExercises(for player: Player) -> [Exercise]
    func fetchExercises(for firebaseUID: String) -> [Exercise]
    func fetchTrainingSessions(for firebaseUID: String) -> [TrainingSession]
    func createDefaultExercises(for player: Player)
    func toggleFavorite(exercise: Exercise)
    func fetchFavoriteExercises(for player: Player) -> [Exercise]
    func fetchRecentlyUsedExercises(for player: Player, limit: Int) -> [Exercise]
    func recordExerciseUsage(exercise: Exercise)
    func updateExercise(exercise: Exercise, name: String?, description: String?, category: String?, difficulty: Int16?, instructions: String?, targetSkills: [String]?, personalNotes: String?)
    func deleteExercise(_ exercise: Exercise)
    func saveDrillFeedback(for exercise: Exercise, player: Player, rating: Int, difficultyFeedback: String, notes: String)
    func fetchDrillFeedback(for player: Player, limit: Int) -> [RecommendationFeedback]
    func fetchFeedback(for exercise: Exercise, player: Player) -> RecommendationFeedback?
    func getCompletionCount(for exercise: Exercise) -> Int
    func getAveragePerformanceRating(for exercise: Exercise) -> Double
}
