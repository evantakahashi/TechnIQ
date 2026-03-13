import CoreData
@testable import TechnIQ

final class MockCoreDataManager: CoreDataManagerProtocol {
    let testStack = TestCoreDataStack()
    var context: NSManagedObjectContext { testStack.context }

    func save() { try? context.save() }

    var stubbedPlayer: Player?
    func getCurrentPlayer() -> Player? {
        stubbedPlayer ?? (try? context.fetch(Player.fetchRequest()).first)
    }

    func getCurrentPlayer(for firebaseUID: String) -> Player? {
        getCurrentPlayer()
    }

    func fetchExercises(for player: Player) -> [Exercise] {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        return (try? context.fetch(request)) ?? []
    }

    func fetchExercises(for firebaseUID: String) -> [Exercise] { [] }

    func fetchTrainingSessions(for firebaseUID: String) -> [TrainingSession] { [] }

    func createDefaultExercises(for player: Player) {}

    func toggleFavorite(exercise: Exercise) { exercise.isFavorite.toggle(); save() }

    func fetchFavoriteExercises(for player: Player) -> [Exercise] { [] }

    func fetchRecentlyUsedExercises(for player: Player, limit: Int) -> [Exercise] { [] }

    func recordExerciseUsage(exercise: Exercise) { exercise.lastUsedAt = Date(); save() }

    func updateExercise(exercise: Exercise, name: String?, description: String?, category: String?, difficulty: Int16?, instructions: String?, targetSkills: [String]?, personalNotes: String?) {}

    func deleteExercise(_ exercise: Exercise) { context.delete(exercise); save() }

    func saveDrillFeedback(for exercise: Exercise, player: Player, rating: Int, difficultyFeedback: String, notes: String) {}

    func fetchDrillFeedback(for player: Player, limit: Int) -> [RecommendationFeedback] { [] }

    func fetchFeedback(for exercise: Exercise, player: Player) -> RecommendationFeedback? { nil }

    func getCompletionCount(for exercise: Exercise) -> Int { 0 }

    func getAveragePerformanceRating(for exercise: Exercise) -> Double { 0 }
}
