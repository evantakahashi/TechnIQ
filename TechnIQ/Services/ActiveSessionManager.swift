import Foundation
import CoreData

// MARK: - Training Phase

enum TrainingPhase: Equatable {
    case exercise        // viewing drill instructions
    case rating          // rating the completed drill
    case sessionComplete // done
}

// MARK: - Session effort ("How did it feel?")

/// Session-level answer on Session Complete. Maps onto the 1–5 performance scale that feeds skill
/// scores and the XP rating bonus: an easy session means the skill is mastered, a hard one that it
/// still needs work.
enum SessionEffort: String, CaseIterable, Identifiable {
    case easy, ok, good, hard

    var id: String { rawValue }

    var rating: Int {
        switch self {
        case .easy: return 5
        case .good: return 4
        case .ok: return 3
        case .hard: return 2
        }
    }

    var label: String {
        switch self {
        case .easy: return "Easy"
        case .ok: return "OK"
        case .good: return "Good"
        case .hard: return "Hard"
        }
    }

    static func from(rating: Int) -> SessionEffort {
        allCases.first { $0.rating == rating } ?? .good
    }
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
        self.reps = Array(repeating: 0, count: exercises.count)
        self.exerciseDurations = Array(repeating: 0, count: exercises.count)
    }

    // MARK: - Touchline session mechanics (clock, reps, effort)

    /// Seconds spent on the current drill (counts while running).
    @Published private(set) var elapsedSeconds: Int = 0
    @Published private(set) var isRunning: Bool = false
    /// Reps counted per drill ("+10 reps").
    @Published private(set) var reps: [Int] = []
    /// Seconds spent per drill, written when a drill is advanced.
    @Published private(set) var exerciseDurations: [Int] = []

    private var clockTimer: Timer?

    /// Countdown target for the current drill, nil when the drill has no estimated duration (count up).
    var targetSeconds: Int? {
        guard let exercise = currentExercise, exercise.estimatedDurationSeconds > 0 else { return nil }
        return Int(exercise.estimatedDurationSeconds)
    }

    /// What the clock shows: remaining time when there is a target, elapsed time otherwise.
    var clockSeconds: Int {
        if let targetSeconds { return max(0, targetSeconds - elapsedSeconds) }
        return elapsedSeconds
    }

    var isTimeUp: Bool {
        guard let targetSeconds else { return false }
        return elapsedSeconds >= targetSeconds
    }

    var currentReps: Int {
        guard currentExerciseIndex < reps.count else { return 0 }
        return reps[currentExerciseIndex]
    }

    /// Effort zone for the current drill: metabolic load 1–5 when known, else from difficulty.
    var currentEffortZone: Int {
        Self.effortZone(for: currentExercise)
    }

    static func effortZone(for exercise: Exercise?) -> Int {
        guard let exercise else { return 2 }
        if exercise.metabolicLoad > 0 { return Int(min(max(exercise.metabolicLoad, 1), 5)) }
        switch exercise.difficulty {
        case ..<1: return 2
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    func startClock() {
        guard !isRunning, phase == .exercise else { return }
        isRunning = true
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func pauseClock() {
        isRunning = false
        clockTimer?.invalidate()
        clockTimer = nil
    }

    func toggleClock() {
        if isRunning { pauseClock() } else { startClock() }
    }

    /// Advances the clock by one second. Called by the timer; tests call it directly.
    func tick() {
        guard isRunning, phase == .exercise else { return }
        elapsedSeconds += 1
        if isTimeUp {
            pauseClock()
            HapticManager.shared.exerciseComplete()
        }
    }

    func addReps(_ count: Int = 10) {
        guard currentExerciseIndex < reps.count else { return }
        reps[currentExerciseIndex] += count
        HapticManager.shared.lightTap()
    }

    /// Touchline "next": completes the current drill with a provisional rating (the session-level
    /// effort refines it on Session Complete) and moves on, or finishes the session on the last drill.
    func advance(provisionalRating: Int = SessionEffort.good.rating) {
        guard phase == .exercise else { return }
        pauseClock()
        if currentExerciseIndex < exerciseDurations.count {
            exerciseDurations[currentExerciseIndex] = elapsedSeconds
        }
        completeExercise()
        rateExercise(provisionalRating, notes: "")
        nextExercise()
        elapsedSeconds = 0
        if phase == .exercise { startClock() }
    }

    /// Applies the session-level "How did it feel?" answer to every completed drill and to the saved
    /// session, then re-derives the player's skill ratings from the pre-session snapshot.
    func applyEffort(_ effort: SessionEffort, to session: TrainingSession?, player: Player, context: NSManagedObjectContext) {
        for index in exerciseRatings.indices where exerciseRatings[index] > 0 {
            exerciseRatings[index] = effort.rating
        }
        guard let session else { return }
        session.overallRating = Int16(effort.rating)
        for case let se as SessionExercise in session.exercises ?? [] {
            se.performanceRating = Int16(effort.rating)
        }
        if let snapshot = skillRatingsSnapshot {
            let stats = Self.latestOrNewStats(for: player, context: context)
            stats.skillRatings = snapshot
            recordSkillRatings(for: player, context: context)
        }
        CoreDataManager.shared.save()
    }

    /// The saved session (set by finishSession) so Session Complete can refine it.
    private(set) var completedSession: TrainingSession?
    /// Player skill ratings before this session merged its samples, so effort changes don't drift.
    private var skillRatingsSnapshot: [String: Double]?

    // MARK: - Session lifecycle

    func start() {
        phase = .exercise
        startClock()
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
        pauseClock()
        if currentExerciseIndex < exerciseDurations.count, phase == .exercise {
            exerciseDurations[currentExerciseIndex] = elapsedSeconds
        }
        phase = .sessionComplete
        HapticManager.shared.sessionComplete()
    }

    /// Total minutes across drills (from the clock), at least 1 when anything was done.
    var totalMinutes: Int {
        let seconds = exerciseDurations.reduce(0, +) + (phase == .exercise ? elapsedSeconds : 0)
        return seconds > 0 ? max(1, Int((Double(seconds) / 60).rounded())) : 0
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
        session.duration = Double(totalMinutes)
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
            se.duration = i < exerciseDurations.count ? Double(exerciseDurations[i]) / 60.0 : 0
            se.reps = i < reps.count ? Int16(clamping: reps[i]) : 0
            se.performanceRating = Int16(exerciseRatings[i])
            se.notes = exerciseNotes[i].isEmpty ? nil : exerciseNotes[i]
        }

        // Snapshot skill ratings so a later effort change can re-derive them, then merge this session
        skillRatingsSnapshot = Self.latestOrNewStats(for: player, context: context).skillRatings ?? [:]
        recordSkillRatings(for: player, context: context)
        completedSession = session

        // Fulfil the plan session this workout came from (only when every drill was completed;
        // ending early keeps the plan session open)
        if let planSession, isFullCompletion {
            session.planSession = planSession
        }

        // Save
        CoreDataManager.shared.save()

        if let planSession, isFullCompletion {
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
