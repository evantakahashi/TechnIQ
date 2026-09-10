import Foundation
import CoreData

// MARK: - Training Phase

enum TrainingPhase: Equatable {
    case exercise        // viewing drill instructions
    case rating          // rating the completed drill
    case sessionComplete // done
}

// MARK: - Active Session Manager

@MainActor
class ActiveSessionManager: ObservableObject, ActiveSessionManagerProtocol {

    // MARK: State

    @Published var phase: TrainingPhase = .exercise
    @Published var currentExerciseIndex: Int = 0

    // Per-exercise tracking
    @Published var exerciseRatings: [Int] = []     // 1-5 per exercise
    @Published var exerciseNotes: [String] = []

    // MARK: Exercises

    let exercises: [Exercise]

    /// Plan session this workout fulfils (Home "Start session"); completion is written back on finish.
    let planSession: PlanSession?

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

    init(exercises: [Exercise], planSession: PlanSession? = nil) {
        self.exercises = exercises
        self.planSession = planSession
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
    ) -> (xpBreakdown: SessionXPBreakdown?, newLevel: Int?, achievements: [Achievement]) {

        let completedCount = exerciseRatings.filter { $0 > 0 }.count
        let isFullCompletion = completedCount == exercises.count
        let startingLevel = Int(player.currentLevel)

        // Create TrainingSession
        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = Date()
        session.sessionType = "Training"
        session.duration = 0
        session.intensity = Int16(averageRating())
        session.focusWeakness = dominantFocusWeakness()

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

        // Update running skill ratings from this session's rated exercises
        recordSkillRatings(for: player, context: context)

        // Fulfil the plan session this workout came from
        if let planSession {
            session.planSession = planSession
        }

        // Save
        CoreDataManager.shared.save()

        if let planSession {
            TrainingPlanService.shared.markSessionCompleted(
                planSession.toModel(),
                actualDuration: Int(session.duration),
                actualIntensity: Int(session.intensity)
            )
        }

        // Process XP
        let (breakdown, _) = XPService.shared.processSessionCompletion(
            session: session,
            player: player,
            context: context,
            allExercisesCompleted: isFullCompletion
        )

        // Check achievements (may award additional XP)
        let achievements = AchievementService.shared.checkAndUnlockAchievements(
            for: player,
            in: context
        )

        // Recompute level after all XP (session + achievements) so achievement-triggered level-ups aren't silent
        let newLevel = XPService.shared.syncLevel(for: player, previousLevel: startingLevel)

        // They trained today: clear the streak-at-risk reminder and re-arm the daily nudge
        NotificationManager.shared.cancelStreakAtRiskForToday()
        NotificationManager.shared.scheduleDailyTrainingReminder()

        return (breakdown, newLevel, achievements)
    }

    // MARK: - Weakness & skill recording

    /// Most common weakness category across this session's exercises, used to tag the session's focus.
    private func dominantFocusWeakness() -> String? {
        var counts: [String: Int] = [:]
        for exercise in exercises {
            guard let raw = exercise.weaknessCategories, !raw.isEmpty else { continue }
            for name in Self.weaknessCategoryNames(from: raw) {
                counts[name, default: 0] += 1
            }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    /// Merge this session's per-exercise ratings into the player's running skillRatings (0-100 scale).
    private func recordSkillRatings(for player: Player, context: NSManagedObjectContext) {
        var samples: [String: [Double]] = [:]
        for (i, exercise) in exercises.enumerated() {
            guard exerciseRatings[i] > 0 else { continue }
            let scaled = Double(exerciseRatings[i]) * 20.0
            var skills = exercise.targetSkills ?? []
            if let raw = exercise.weaknessCategories, !raw.isEmpty {
                skills.append(contentsOf: Self.weaknessCategoryNames(from: raw))
            }
            for skill in skills where !skill.isEmpty {
                samples[skill, default: []].append(scaled)
            }
        }
        guard !samples.isEmpty else { return }

        let stats = Self.latestOrNewStats(for: player, context: context)
        var ratings = stats.skillRatings ?? [:]
        for (skill, values) in samples {
            let sample = values.reduce(0, +) / Double(values.count)
            if let existing = ratings[skill] {
                ratings[skill] = (existing + sample) / 2.0
            } else {
                ratings[skill] = sample
            }
        }
        stats.skillRatings = ratings
        stats.date = Date()
        stats.updatedAt = Date()
    }

    private static func latestOrNewStats(for player: Player, context: NSManagedObjectContext) -> PlayerStats {
        if let stats = player.stats as? Set<PlayerStats>,
           let latest = stats.sorted(by: { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }).first {
            return latest
        }
        let stats = PlayerStats(context: context)
        stats.id = UUID()
        stats.player = player
        player.addToStats(stats)
        return stats
    }

    /// Parse the "Category:Specific,Category:Specific" weaknessCategories string into category names.
    private static func weaknessCategoryNames(from raw: String) -> [String] {
        raw.split(separator: ",").compactMap { pair -> String? in
            let name = pair.split(separator: ":").first.map { String($0).trimmingCharacters(in: .whitespaces) }
            return (name?.isEmpty == false) ? name : nil
        }
    }

    /// Session-row variant used by manual logging (NewSessionView): same recording
    /// math as finishSession, sourced from persisted SessionExercise rows.
    static func recordCompletedSession(_ session: TrainingSession, player: Player, context: NSManagedObjectContext) {
        var counts: [String: Int] = [:]
        var samples: [String: [Double]] = [:]
        for sessionExercise in (session.exercises as? Set<SessionExercise>) ?? [] {
            guard let exercise = sessionExercise.exercise else { continue }
            var skills = exercise.targetSkills ?? []
            if let raw = exercise.weaknessCategories, !raw.isEmpty {
                let names = weaknessCategoryNames(from: raw)
                names.forEach { counts[$0, default: 0] += 1 }
                skills.append(contentsOf: names)
            }
            let rating = Int(sessionExercise.performanceRating)
            guard rating > 0 else { continue }
            let scaled = Double(rating) * 20.0
            for skill in skills where !skill.isEmpty {
                samples[skill, default: []].append(scaled)
            }
        }
        if session.focusWeakness == nil {
            session.focusWeakness = counts.max { $0.value < $1.value }?.key
        }
        guard !samples.isEmpty else { return }
        let stats = Self.latestOrNewStats(for: player, context: context)
        var ratings = stats.skillRatings ?? [:]
        for (skill, values) in samples {
            let sample = values.reduce(0, +) / Double(values.count)
            ratings[skill] = ratings[skill].map { ($0 + sample) / 2.0 } ?? sample
        }
        stats.skillRatings = ratings
        stats.date = Date()
        stats.updatedAt = Date()
    }

    // MARK: - Helpers

    func averageRating() -> Int {
        let rated = exerciseRatings.filter { $0 > 0 }
        guard !rated.isEmpty else { return 3 }
        return rated.reduce(0, +) / rated.count
    }
}
