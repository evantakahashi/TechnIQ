import Foundation
import Combine
import CoreData
import UIKit

// MARK: - Training Phase

enum TrainingPhase: Equatable {
    case preparing       // 3-2-1 countdown
    case exerciseActive  // doing the exercise
    case exerciseComplete // quick rate + notes
    case rest            // countdown to next
    case sessionComplete // done
}

// MARK: - Active Session Manager

class ActiveSessionManager: ObservableObject {

    // MARK: State

    @Published var phase: TrainingPhase = .preparing
    @Published var currentExerciseIndex: Int = 0
    @Published var isPaused: Bool = false
    @Published var preparingCountdown: Int = 3

    // Per-exercise tracking
    @Published var exerciseDurations: [TimeInterval] = []
    @Published var exerciseRatings: [Int] = []     // 1-5 per exercise
    @Published var exerciseNotes: [String] = []

    // Rest config
    @Published var restDuration: TimeInterval = 30

    // MARK: Exercises

    let exercises: [Exercise]

    // MARK: Date-based timers (background-safe)

    private var sessionStartTime: Date?
    private var exerciseStartTime: Date?
    private var restStartTime: Date?

    // Pause tracking
    private var accumulatedSessionPause: TimeInterval = 0
    private var accumulatedExercisePause: TimeInterval = 0
    private var pauseStartTime: Date?

    // Display timer (UI refresh only)
    private var displayTimer: AnyCancellable?
    private var preparingTimer: AnyCancellable?
    private var foregroundObserver: NSObjectProtocol?

    // MARK: Computed properties

    var totalElapsedTime: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        let pauseNow = isPaused ? Date().timeIntervalSince(pauseStartTime ?? Date()) : 0
        return Date().timeIntervalSince(start) - accumulatedSessionPause - pauseNow
    }

    var exerciseElapsedTime: TimeInterval {
        guard let start = exerciseStartTime else { return 0 }
        let pauseNow = isPaused ? Date().timeIntervalSince(pauseStartTime ?? Date()) : 0
        return Date().timeIntervalSince(start) - accumulatedExercisePause - pauseNow
    }

    var restTimeRemaining: TimeInterval {
        guard let start = restStartTime else { return restDuration }
        let elapsed = Date().timeIntervalSince(start)
        return max(0, restDuration - elapsed)
    }

    var restProgress: Double {
        guard restDuration > 0 else { return 1.0 }
        return 1.0 - (restTimeRemaining / restDuration)
    }

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

    var completedExerciseCount: Int {
        exerciseDurations.filter { $0 > 0 }.count
    }

    // MARK: Init

    init(exercises: [Exercise]) {
        self.exercises = exercises
        self.exerciseDurations = Array(repeating: 0, count: exercises.count)
        self.exerciseRatings = Array(repeating: 0, count: exercises.count)
        self.exerciseNotes = Array(repeating: "", count: exercises.count)

        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
            // Auto-advance rest if it expired while backgrounded
            if self?.phase == .rest, let remaining = self?.restTimeRemaining, remaining <= 0 {
                self?.restFinished()
            }
        }
    }

    deinit {
        displayTimer?.cancel()
        preparingTimer?.cancel()
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Timer management

    private func startDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, !self.isPaused else { return }
                self.objectWillChange.send()

                // Auto-advance rest when countdown reaches 0
                if self.phase == .rest && self.restTimeRemaining <= 0 {
                    self.restFinished()
                }
            }
    }

    private func stopDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    // MARK: - Session lifecycle

    func start() {
        sessionStartTime = Date()
        phase = .preparing
        preparingCountdown = 3
        startPreparingCountdown()
    }

    private func startPreparingCountdown() {
        preparingTimer?.cancel()
        preparingCountdown = 3
        HapticManager.shared.countdownTick()

        preparingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.preparingCountdown -= 1
                if self.preparingCountdown > 0 {
                    HapticManager.shared.countdownTick()
                } else {
                    self.preparingTimer?.cancel()
                    HapticManager.shared.countdownComplete()
                    self.beginExercise()
                }
            }
    }

    private func beginExercise() {
        phase = .exerciseActive
        exerciseStartTime = Date()
        accumulatedExercisePause = 0
        startDisplayTimer()
        HapticManager.shared.exerciseStart()
    }

    // MARK: - Exercise flow

    /// Freezes exercise duration immediately so rating time isn't counted
    func completeExercise() {
        guard phase == .exerciseActive else { return }
        guard currentExerciseIndex < exerciseDurations.count else { return }

        // Freeze duration
        let duration = exerciseElapsedTime
        exerciseDurations[currentExerciseIndex] = duration

        phase = .exerciseComplete
        HapticManager.shared.exerciseComplete()
    }

    func rateExercise(_ rating: Int, notes: String) {
        guard currentExerciseIndex < exerciseRatings.count,
              currentExerciseIndex < exerciseNotes.count else { return }
        exerciseRatings[currentExerciseIndex] = rating
        exerciseNotes[currentExerciseIndex] = notes
    }

    /// Move to rest or session complete
    func nextExercise() {
        if isLastExercise {
            finishAllExercises()
        } else {
            startRest()
        }
    }

    // MARK: - Rest flow

    private func startRest() {
        phase = .rest
        restStartTime = Date()
        HapticManager.shared.restStart()
    }

    func adjustRest(_ delta: TimeInterval) {
        let newDuration = restDuration + delta
        guard newDuration >= 5 else { return } // minimum 5s
        restDuration = newDuration
        // Adjust restStartTime to maintain the new remaining time correctly
        // If we added time, shift start earlier; if removed, shift later
        restStartTime = restStartTime?.addingTimeInterval(-delta)
    }

    func skipRest() {
        restFinished()
    }

    private func restFinished() {
        HapticManager.shared.restEnd()
        currentExerciseIndex += 1
        // Reset rest duration for next rest
        restDuration = 30
        beginExercise()
    }

    // MARK: - Pause

    func pause() {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
    }

    func resume() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        let pauseInterval = Date().timeIntervalSince(pauseStart)
        accumulatedSessionPause += pauseInterval
        if phase == .exerciseActive {
            accumulatedExercisePause += pauseInterval
        }
        isPaused = false
        pauseStartTime = nil
    }

    // MARK: - Session completion

    private func finishAllExercises() {
        stopDisplayTimer()
        phase = .sessionComplete
        HapticManager.shared.sessionComplete()
    }

    func endSessionEarly() {
        // Freeze current exercise if active
        if phase == .exerciseActive, currentExerciseIndex < exerciseDurations.count {
            exerciseDurations[currentExerciseIndex] = exerciseElapsedTime
        }
        stopDisplayTimer()
        phase = .sessionComplete
        HapticManager.shared.sessionComplete()
    }

    // MARK: - Save & XP

    func finishSession(
        player: Player,
        context: NSManagedObjectContext
    ) -> (xpBreakdown: XPService.SessionXPBreakdown?, newLevel: Int?, achievements: [Achievement]) {

        let completedCount = exerciseDurations.filter { $0 > 0 }.count
        let isFullCompletion = completedCount == exercises.count

        // Create TrainingSession
        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = Date()
        session.sessionType = "Training"
        session.duration = totalElapsedTime / 60.0 // minutes
        session.intensity = Int16(averageRating())

        // Average notes
        let allNotes = exerciseNotes.filter { !$0.isEmpty }.joined(separator: "; ")
        session.notes = allNotes.isEmpty ? nil : allNotes
        session.overallRating = Int16(averageRating())

        // Create SessionExercise entities
        for (i, exercise) in exercises.enumerated() {
            guard exerciseDurations[i] > 0 else { continue }
            let se = SessionExercise(context: context)
            se.id = UUID()
            se.session = session
            se.exercise = exercise
            se.duration = exerciseDurations[i] / 60.0 // minutes
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

    func formattedTime(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(max(0, interval))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
