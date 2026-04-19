import CoreData
@testable import TechnIQ

/// In-memory Core Data stack for testing. Each test gets a fresh context.
class TestCoreDataStack: CoreDataManagerProtocol {
    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    init() {
        container = NSPersistentContainer(name: "DataModel")
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { fatalError("Test store failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Entity Factories

    @discardableResult
    func makePlayer(
        name: String = "Test Player",
        level: Int16 = 1,
        xp: Int64 = 0,
        coins: Int64 = 100,
        streak: Int16 = 0,
        longestStreak: Int16 = 0,
        streakFreezes: Int16 = 0
    ) -> Player {
        let player = Player(context: context)
        player.id = UUID()
        player.name = name
        player.currentLevel = level
        player.totalXP = xp
        player.coins = coins
        player.currentStreak = streak
        player.longestStreak = longestStreak
        player.streakFreezes = streakFreezes
        player.createdAt = Date()
        try? context.save()
        return player
    }

    @discardableResult
    func makeSession(
        player: Player,
        date: Date = Date(),
        duration: Double = 30,
        intensity: Int16 = 3,
        exerciseCount: Int = 3,
        rating: Int16 = 0,
        notes: String? = nil
    ) -> TrainingSession {
        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = date
        session.duration = duration
        session.intensity = intensity
        session.overallRating = rating
        session.notes = notes

        for i in 0..<exerciseCount {
            let exercise = makeExercise(player: player, name: "Exercise \(i)")
            let se = SessionExercise(context: context)
            se.id = UUID()
            se.session = session
            se.exercise = exercise
            se.duration = 10
        }

        try? context.save()
        return session
    }

    @discardableResult
    func makeExercise(
        player: Player,
        name: String = "Test Exercise",
        category: String = "Technical"
    ) -> Exercise {
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = name
        exercise.category = category
        exercise.player = player
        return exercise
    }

    @discardableResult
    func makeMatch(
        player: Player,
        date: Date = Date(),
        goals: Int16 = 0,
        assists: Int16 = 0,
        minutesPlayed: Int16 = 90,
        result: String? = nil,
        season: Season? = nil
    ) -> Match {
        let match = Match(context: context)
        match.id = UUID()
        match.player = player
        match.date = date
        match.goals = goals
        match.assists = assists
        match.minutesPlayed = minutesPlayed
        match.result = result
        match.rating = 3
        match.season = season
        match.createdAt = Date()
        try? context.save()
        return match
    }

    // MARK: - CoreDataManagerProtocol

    func save() { try? context.save() }

    func getCurrentPlayer() -> Player? {
        try? context.fetch(Player.fetchRequest()).first
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

    // MARK: - Entity Factories

    @discardableResult
    func makeTrainingPlan(
        player: Player,
        name: String = "Test Plan",
        isActive: Bool = false,
        durationWeeks: Int16 = 4
    ) -> TrainingPlan {
        let plan = TrainingPlan(context: context)
        plan.id = UUID()
        plan.name = name
        plan.player = player
        plan.isActive = isActive
        plan.durationWeeks = durationWeeks
        plan.createdAt = Date()
        try? context.save()
        return plan
    }

    @discardableResult
    func makePlanWeek(
        plan: TrainingPlan,
        weekNumber: Int16 = 1,
        focusArea: String = "Technical"
    ) -> PlanWeek {
        let week = PlanWeek(context: context)
        week.id = UUID()
        week.weekNumber = weekNumber
        week.focusArea = focusArea
        week.plan = plan
        try? context.save()
        return week
    }

    @discardableResult
    func makePlanDay(
        week: PlanWeek,
        dayNumber: Int16 = 1,
        isRestDay: Bool = false
    ) -> PlanDay {
        let day = PlanDay(context: context)
        day.id = UUID()
        day.dayNumber = dayNumber
        day.isRestDay = isRestDay
        day.week = week
        try? context.save()
        return day
    }

    @discardableResult
    func makePlanSession(
        day: PlanDay,
        exercises: [Exercise] = [],
        sessionType: String = "training"
    ) -> PlanSession {
        let session = PlanSession(context: context)
        session.id = UUID()
        session.sessionType = sessionType
        session.duration = 30
        session.day = day
        if !exercises.isEmpty {
            session.exercises = NSSet(array: exercises)
        }
        try? context.save()
        return session
    }

    @discardableResult
    func makeSeason(
        player: Player,
        name: String = "2025-26",
        isActive: Bool = false
    ) -> Season {
        let season = Season(context: context)
        season.id = UUID()
        season.name = name
        season.player = player
        season.isActive = isActive
        season.startDate = Date()
        season.endDate = Calendar.current.date(byAdding: .month, value: 10, to: Date())
        season.createdAt = Date()
        try? context.save()
        return season
    }

    @discardableResult
    func makePlayerStats(
        player: Player,
        date: Date = Date(),
        skillRatings: [String: Double] = ["passing": 4.0, "shooting": 3.5],
        totalHours: Double = 12.5,
        totalSessions: Int32 = 8
    ) -> PlayerStats {
        let stats = PlayerStats(context: context)
        stats.id = UUID()
        stats.player = player
        stats.date = date
        stats.skillRatings = skillRatings
        stats.totalTrainingHours = totalHours
        stats.totalSessions = totalSessions
        try? context.save()
        return stats
    }
}
