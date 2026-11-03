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
        self.reps = Array(repeating: 0, count: exercises.count)
        self.exerciseDurations = Array(repeating: 0, count: exercises.count)
    }

    // MARK: - Touchline session mechanics (clock, reps)

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

    /// Counters restored from a snapshot (see +Resume). The clock stays paused.
    func restoreClock(reps: [Int], durations: [Int], elapsed: Int) {
        let count = exercises.count
        self.reps = Array(reps.prefix(count)) + Array(repeating: 0, count: max(0, count - reps.count))
        self.exerciseDurations = Array(durations.prefix(count)) + Array(repeating: 0, count: max(0, count - durations.count))
        self.elapsedSeconds = max(0, elapsed)
        self.isRunning = false
    }

    func startClock() {
        guard !isRunning, phase == .exercise else { return }
        isRunning = true
        persistSnapshot()
        clockTimer?.invalidate()
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    func pauseClock() {
        isRunning = false
        clockTimer?.invalidate()
        clockTimer = nil
        persistSnapshot()
    }

    func toggleClock() {
        if isRunning { pauseClock() } else { startClock() }
    }

    /// Advances the clock by one second. Called by the timer; tests call it directly.
    func tick() {
        guard isRunning, phase == .exercise else { return }
        elapsedSeconds += 1
        if elapsedSeconds % 5 == 0 { persistSnapshot() }
        if isTimeUp {
            pauseClock()
            HapticManager.shared.exerciseComplete()
        }
    }

    func addReps(_ count: Int = 10) {
        guard currentExerciseIndex < reps.count else { return }
        reps[currentExerciseIndex] += count
        HapticManager.shared.lightTap()
        persistSnapshot()
    }

    /// Touchline "next": completes the current drill with a provisional rating (the session-level
    /// feel refines it on Session Complete) and moves on, or finishes the session on the last drill.
    func advance(provisionalRating: Int = SessionFeel.right.rating) {
        guard phase == .exercise else { return }
        pauseClock()
        if currentExerciseIndex < exerciseDurations.count {
            exerciseDurations[currentExerciseIndex] = elapsedSeconds
        }
        completeExercise()
        rateExercise(provisionalRating, notes: "")
        nextExercise()
        elapsedSeconds = 0
        if phase == .exercise { startClock() } else { clearSnapshot() }
    }

    /// Applies the session-level "How did it feel?" answer: stores it on the saved session
    /// (`TrainingSession.feel`), writes its rating to every completed drill and the session, then
    /// re-derives the player's skill ratings from the pre-session snapshot.
    func applyFeel(_ feel: SessionFeel, to session: TrainingSession?, player: Player, context: NSManagedObjectContext) {
        for index in exerciseRatings.indices where exerciseRatings[index] > 0 {
            exerciseRatings[index] = feel.rating
        }
        guard let session else { return }
        session.feel = feel.rawValue
        session.overallRating = Int16(feel.rating)
        session.updatedAt = Date()
        for case let se as SessionExercise in session.exercises ?? [] {
            se.performanceRating = Int16(feel.rating)
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
    /// Player skill ratings before this session merged its samples, so feel changes don't drift.
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
        clearSnapshot()
        HapticManager.shared.sessionComplete()
    }

    /// Active (unpaused) seconds across drills, from the clock. Feeds XP and the streak rule.
    var activeSeconds: Int {
        exerciseDurations.reduce(0, +) + (phase == .exercise ? elapsedSeconds : 0)
    }

    /// Total minutes across drills (from the clock), at least 1 when anything was done.
    var totalMinutes: Int {
        let seconds = activeSeconds
        return seconds > 0 ? max(1, Int((Double(seconds) / 60).rounded())) : 0
    }

    // MARK: - Save & XP

    func finishSession(
        player: Player,
        context: NSManagedObjectContext
    ) -> (xpBreakdown: SessionXPBreakdown?, newLevel: Int?, achievements: [Achievement]) {
        clearSnapshot()

        let completedCount = exerciseRatings.filter { $0 > 0 }.count
        let isFullCompletion = completedCount == exercises.count

        // Ending before any drill is completed keeps nothing: no session row, no XP, no streak.
        guard completedCount > 0 else {
            completedSession = nil
            return (nil, nil, [])
        }

        // Create TrainingSession
        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = Date()
        session.sessionType = "Training"
        session.duration = Double(totalMinutes)
        session.activeSeconds = Double(activeSeconds)
        // Reps tapped on the pitch are self-reported; only camera-counted touches are verified.
        session.verifiedTouches = 0
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

        // Snapshot skill ratings so a later feel change can re-derive them, then merge this session
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

        // XP (XPFormula over active seconds + verified touches) and streak (StreakRule)
        let (breakdown, newLevel) = XPService.shared.processSessionCompletion(
            session: session,
            player: player,
            context: context,
            allExercisesCompleted: isFullCompletion
        )

        // Achievements unlock as badges; they pay no XP
        let achievements = AchievementService.shared.checkAndUnlockAchievements(
            for: player,
            in: context
        )

        // They trained today: the streak nudge goes, the next training day's reminder stays
        NotificationManager.shared.refresh(for: player)

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

    // MARK: - Helpers

    func averageRating() -> Int {
        let rated = exerciseRatings.filter { $0 > 0 }
        guard !rated.isEmpty else { return 3 }
        return rated.reduce(0, +) / rated.count
    }
}
