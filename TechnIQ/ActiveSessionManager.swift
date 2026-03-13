import Foundation
import CoreData

// MARK: - Training Phase

enum TrainingPhase: Equatable {
    case exercise        // viewing drill instructions
    case rating          // rating the completed drill
    case sessionComplete // done
}

// MARK: - Active Session Manager

class ActiveSessionManager: ObservableObject {

    // MARK: State

    @Published var phase: TrainingPhase = .exercise
    @Published var currentExerciseIndex: Int = 0

    // Per-exercise tracking
    @Published var exerciseRatings: [Int] = []     // 1-5 per exercise
    @Published var exerciseNotes: [String] = []

    // MARK: Exercises

    let exercises: [Exercise]

    // MARK: Computed properties

    var currentExercise: Exercise? {
        guard currentExerciseIndex < exercises.count else { return nil }
        return exercises[currentExerciseIndex]
    }

    var upNextExercise: Exercise? {
        let next = currentExerciseIndex + 1
        guard next < exercises.count else { return nil }
        return exercises[next]
    }

    var isLastExercise: Bool {
        currentExerciseIndex >= exercises.count - 1
    }

    // MARK: Init

    init(exercises: [Exercise]) {
        self.exercises = exercises
        self.exerciseRatings = Array(repeating: 0, count: exercises.count)
        self.exerciseNotes = Array(repeating: "", count: exercises.count)
    }

    // MARK: - Session lifecycle

    func start() {
        phase = .exercise
    }

    // MARK: - Exercise flow

    func completeExercise() {
        guard phase == .exercise else { return }
        phase = .rating
        HapticManager.shared.exerciseComplete()
    }

    func rateExercise(_ rating: Int, notes: String) {
        guard currentExerciseIndex < exerciseRatings.count,
              currentExerciseIndex < exerciseNotes.count else { return }
        exerciseRatings[currentExerciseIndex] = rating
        exerciseNotes[currentExerciseIndex] = notes
    }

    func nextExercise() {
        if isLastExercise {
            phase = .sessionComplete
            HapticManager.shared.sessionComplete()
        } else {
            currentExerciseIndex += 1
            phase = .exercise
        }
    }

    // MARK: - Session completion

    func endSessionEarly() {
        phase = .sessionComplete
        HapticManager.shared.sessionComplete()
    }

    // MARK: - Save & XP

    func finishSession(
        player: Player,
        context: NSManagedObjectContext
    ) -> (xpBreakdown: XPService.SessionXPBreakdown?, newLevel: Int?, achievements: [Achievement]) {

        let completedCount = exerciseRatings.filter { $0 > 0 }.count
        let isFullCompletion = completedCount == exercises.count

        // Create TrainingSession
        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = Date()
        session.sessionType = "Training"
        session.duration = 0
        session.intensity = Int16(averageRating())

        // Average notes
        let allNotes = exerciseNotes.filter { !$0.isEmpty }.joined(separator: "; ")
        session.notes = allNotes.isEmpty ? nil : allNotes
        session.overallRating = Int16(averageRating())

        // Create SessionExercise entities
        for (i, exercise) in exercises.enumerated() {
            guard exerciseRatings[i] > 0 else { continue }
            let se = SessionExercise(context: context)
            se.id = UUID()
            se.session = session
            se.exercise = exercise
            se.duration = 0
            se.performanceRating = Int16(exerciseRatings[i])
            se.notes = exerciseNotes[i].isEmpty ? nil : exerciseNotes[i]
        }

        // Save
        CoreDataManager.shared.save()

        // Process XP
        let (breakdown, levelUp) = XPService.shared.processSessionCompletion(
            session: session,
            player: player,
            context: context
        )

        // For partial sessions, create modified breakdown without completion bonus
        var finalBreakdown = breakdown
        if !isFullCompletion {
            finalBreakdown = XPService.SessionXPBreakdown(
                baseXP: breakdown.baseXP,
                intensityBonus: breakdown.intensityBonus,
                firstSessionBonus: breakdown.firstSessionBonus,
                completionBonus: 0,
                ratingBonus: breakdown.ratingBonus,
                notesBonus: breakdown.notesBonus,
                streakBonus: breakdown.streakBonus
            )
        }

        // Check achievements
        let achievements = AchievementService.shared.checkAndUnlockAchievements(
            for: player,
            in: context
        )

        return (finalBreakdown, levelUp, achievements)
    }

    // MARK: - Helpers

    func averageRating() -> Int {
        let rated = exerciseRatings.filter { $0 > 0 }
        guard !rated.isEmpty else { return 3 }
        return rated.reduce(0, +) / rated.count
    }
}
