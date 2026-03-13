import CoreData
import Foundation

enum TimeoutError: Error {
    case timeout
}

enum APIError: Error {
    case apiKeyNotConfigured
    case networkError
}

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()

    /// Published error state so UI can react to Core Data failures
    @Published var persistentStoreError: Error?

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DataModel")

        // Enable lightweight migration
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // If there's a migration error, delete the store and recreate
                #if DEBUG
                print("⚠️ Core Data error: \(error.localizedDescription)")
                #endif
                #if DEBUG
                print("🔄 Attempting to reset Core Data store...")

                #endif
                if let storeURL = storeDescription.url {
                    do {
                        try FileManager.default.removeItem(at: storeURL)
                        #if DEBUG
                        print("✅ Deleted corrupted store, will recreate")

                        #endif
                        // Try loading again
                        container.loadPersistentStores { [weak self] _, retryError in
                            if let retryError = retryError {
                                #if DEBUG
                                print("❌ Failed to recreate Core Data store: \(retryError.localizedDescription)")
                                #endif
                                self?.persistentStoreError = retryError
                            } else {
                                #if DEBUG
                                print("Successfully recreated Core Data store")
                                #endif
                            }
                        }
                    } catch {
                        #if DEBUG
                        print("❌ Failed to delete corrupted Core Data store: \(error.localizedDescription)")
                        #endif
                        self.persistentStoreError = error
                    }
                }
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                #if DEBUG
                print("Save error: \(error.localizedDescription)")
                #endif
            }
        }
    }
}

extension CoreDataManager {
    // MARK: - User-aware data fetching

    /// Convenience method to get current player using AuthenticationManager
    func getCurrentPlayer() -> Player? {
        let userUID = AuthenticationManager.shared.userUID
        guard !userUID.isEmpty else { return nil }
        return getCurrentPlayer(for: userUID)
    }

    func getCurrentPlayer(for firebaseUID: String) -> Player? {
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            #if DEBUG
            print("❌ Failed to fetch current player: \(error)")
            #endif
            return nil
        }
    }

    func fetchTrainingSessions(for firebaseUID: String) -> [TrainingSession] {
        guard let player = getCurrentPlayer(for: firebaseUID) else {
            #if DEBUG
            print("⚠️ No player found for Firebase UID: \(firebaseUID)")
            #endif
            return []
        }

        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]

        do {
            let sessions = try context.fetch(request)
            #if DEBUG
            print("📊 Found \(sessions.count) training sessions for user \(firebaseUID)")
            #endif
            return sessions
        } catch {
            #if DEBUG
            print("❌ Failed to fetch training sessions: \(error)")
            #endif
            return []
        }
    }

    func fetchExercises(for firebaseUID: String) -> [Exercise] {
        guard let player = getCurrentPlayer(for: firebaseUID) else {
            #if DEBUG
            print("⚠️ No player found for Firebase UID: \(firebaseUID)")
            #endif
            return []
        }

        return fetchExercises(for: player)
    }

    func createDefaultExercises(for player: Player) {
        // Check if exercises already exist for this player to prevent duplicates
        let existingExercises = fetchExercises(for: player)
        if !existingExercises.isEmpty {
            #if DEBUG
            print("📚 Exercises already exist for player \(player.name ?? "Unknown"), skipping default creation")
            #endif
            return
        }

        let exercises = [
            ("Ball Control", "Technical", 1, "Basic ball touches and control", ["Ball Control", "First Touch"]),
            ("Juggling", "Technical", 2, "Keep the ball in the air using different body parts", ["Ball Control", "Coordination"]),
            ("Dribbling Cones", "Technical", 2, "Dribble through a series of cones", ["Dribbling", "Agility"]),
            ("Shooting Practice", "Technical", 3, "Practice shooting accuracy and power", ["Shooting", "Accuracy"]),
            ("Passing Accuracy", "Technical", 2, "Short and long passing practice", ["Passing", "Vision"]),
            ("Sprint Training", "Physical", 2, "Short distance sprint intervals", ["Speed", "Acceleration"]),
            ("Agility Ladder", "Physical", 2, "Footwork and agility drills", ["Agility", "Coordination"]),
            ("Endurance Run", "Physical", 1, "Continuous running for stamina", ["Endurance", "Fitness"]),
            ("1v1 Practice", "Tactical", 3, "One-on-one attacking and defending", ["Defending", "Attacking"]),
            ("Small-Sided Games", "Tactical", 3, "3v3 or 4v4 mini games", ["Teamwork", "Decision Making"])
        ]

        for (name, category, difficulty, description, skills) in exercises {
            // Check if exercise with this name already exists for this player
            if !exerciseExists(name: name, for: player) {
                let exercise = Exercise(context: context)
                exercise.id = UUID()
                exercise.name = name
                exercise.category = category
                exercise.difficulty = Int16(difficulty)
                exercise.exerciseDescription = description
                exercise.targetSkills = skills
                exercise.instructions = "Follow standard \(name.lowercased()) protocol"
                exercise.setValue(player, forKey: "player")
            }
        }

        save()
    }

    private func exerciseExists(name: String, for player: Player) -> Bool {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND player == %@", name, player)

        do {
            let count = try context.count(for: request)
            return count > 0
        } catch {
            #if DEBUG
            print("❌ Failed to check exercise existence: \(error)")
            #endif
            return false
        }
    }

    func fetchExercises(for player: Player) -> [Exercise] {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("❌ Failed to fetch exercises for player: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Exercise Favorites & Recent

    /// Toggle favorite status for an exercise
    func toggleFavorite(exercise: Exercise) {
        exercise.isFavorite.toggle()
        save()
        #if DEBUG
        print("⭐ Exercise '\(exercise.name ?? "Unknown")' favorite status: \(exercise.isFavorite)")
        #endif
    }

    /// Fetch all favorite exercises for a player
    func fetchFavoriteExercises(for player: Player) -> [Exercise] {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND isFavorite == YES", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.name, ascending: true)]

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("❌ Failed to fetch favorite exercises: \(error)")
            #endif
            return []
        }
    }

    /// Fetch recently used exercises for a player
    func fetchRecentlyUsedExercises(for player: Player, limit: Int = 5) -> [Exercise] {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND lastUsedAt != nil", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Exercise.lastUsedAt, ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("❌ Failed to fetch recently used exercises: \(error)")
            #endif
            return []
        }
    }

    /// Record that an exercise was used (updates lastUsedAt timestamp)
    func recordExerciseUsage(exercise: Exercise) {
        exercise.lastUsedAt = Date()
        save()
    }

    /// Update exercise with new values
    func updateExercise(
        exercise: Exercise,
        name: String? = nil,
        description: String? = nil,
        category: String? = nil,
        difficulty: Int16? = nil,
        instructions: String? = nil,
        targetSkills: [String]? = nil,
        personalNotes: String? = nil
    ) {
        if let name = name { exercise.name = name }
        if let description = description { exercise.exerciseDescription = description }
        if let category = category { exercise.category = category }
        if let difficulty = difficulty { exercise.difficulty = difficulty }
        if let instructions = instructions { exercise.instructions = instructions }
        if let targetSkills = targetSkills { exercise.targetSkills = targetSkills }
        if let personalNotes = personalNotes { exercise.personalNotes = personalNotes }

        save()
        #if DEBUG
        print("✏️ Updated exercise: \(exercise.name ?? "Unknown")")
        #endif
    }

    /// Delete an exercise
    func deleteExercise(_ exercise: Exercise) {
        let exerciseName = exercise.name ?? "Unknown"
        context.delete(exercise)
        save()
        #if DEBUG
        print("🗑️ Deleted exercise: \(exerciseName)")
        #endif
    }

    // MARK: - Drill Feedback

    func saveDrillFeedback(
        for exercise: Exercise,
        player: Player,
        rating: Int,
        difficultyFeedback: String,
        notes: String
    ) {
        let feedback = RecommendationFeedback(context: context)
        feedback.id = UUID()
        feedback.createdAt = Date()
        feedback.exerciseID = exercise.id?.uuidString
        feedback.rating = Int16(rating)
        feedback.recommendationSource = "AI-Generated"
        feedback.feedbackType = rating >= 4 ? "Positive" : rating <= 2 ? "Negative" : "Neutral"
        feedback.notes = notes.isEmpty ? nil : notes
        feedback.player = player

        // Map difficulty feedback to rating
        switch difficultyFeedback {
        case "easy":
            feedback.difficultyRating = 1
        case "right":
            feedback.difficultyRating = 3
        case "hard":
            feedback.difficultyRating = 5
        default:
            feedback.difficultyRating = 3
        }

        save()
        #if DEBUG
        print("✅ Saved drill feedback: rating=\(rating), difficulty=\(difficultyFeedback)")
        #endif
    }

    func fetchDrillFeedback(for player: Player, limit: Int = 10) -> [RecommendationFeedback] {
        let request: NSFetchRequest<RecommendationFeedback> = RecommendationFeedback.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND recommendationSource == %@", player, "AI-Generated")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RecommendationFeedback.createdAt, ascending: false)]
        request.fetchLimit = limit

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("❌ Failed to fetch drill feedback: \(error)")
            #endif
            return []
        }
    }

    func fetchFeedback(for exercise: Exercise, player: Player) -> RecommendationFeedback? {
        guard let exerciseID = exercise.id?.uuidString else { return nil }

        let request: NSFetchRequest<RecommendationFeedback> = RecommendationFeedback.fetchRequest()
        request.predicate = NSPredicate(
            format: "player == %@ AND exerciseID == %@ AND recommendationSource == %@",
            player, exerciseID, "AI-Generated"
        )
        request.fetchLimit = 1

        return try? context.fetch(request).first
    }

    func getCompletionCount(for exercise: Exercise) -> Int {
        return exercise.sessionExercises?.count ?? 0
    }

    func getAveragePerformanceRating(for exercise: Exercise) -> Double {
        guard let sessionExercises = exercise.sessionExercises?.allObjects as? [SessionExercise],
              !sessionExercises.isEmpty else {
            return 0
        }

        let totalRating = sessionExercises.reduce(0) { $0 + Int($1.performanceRating) }
        return Double(totalRating) / Double(sessionExercises.count)
    }
}
