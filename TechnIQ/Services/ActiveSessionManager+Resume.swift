import Foundation
import CoreData

// MARK: - Resume an interrupted session
//
// The live pitch used to keep its clock, reps and drill index in memory only: a phone call ended
// the session. The manager now writes a small snapshot to UserDefaults on every change and Home
// offers "Continue" while one exists (for 12 hours). Finishing or ending a session clears it.

struct SessionSnapshot: Codable, Equatable {
    static let key = "activeSession.snapshot"
    static let maxAge: TimeInterval = 12 * 60 * 60

    var exerciseIDs: [String]
    var planSessionID: String?
    var currentExerciseIndex: Int
    var exerciseRatings: [Int]
    var exerciseNotes: [String]
    var reps: [Int]
    var exerciseDurations: [Int]
    var elapsedSeconds: Int
    var savedAt: Date

    var isFresh: Bool { Date().timeIntervalSince(savedAt) < Self.maxAge }

    /// Seconds spent so far across finished drills plus the current one.
    var totalSeconds: Int { exerciseDurations.reduce(0, +) + elapsedSeconds }

    static func load(from defaults: UserDefaults = .standard) -> SessionSnapshot? {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(SessionSnapshot.self, from: data) else { return nil }
        guard snapshot.isFresh else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return snapshot
    }

    func save(to defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

extension ActiveSessionManager {
    /// What Home needs to say "Session in progress · 12:40 · drill 2 of 3".
    var snapshot: SessionSnapshot {
        SessionSnapshot(
            exerciseIDs: exercises.map { $0.id?.uuidString ?? "" },
            planSessionID: planSession?.id?.uuidString,
            currentExerciseIndex: currentExerciseIndex,
            exerciseRatings: exerciseRatings,
            exerciseNotes: exerciseNotes,
            reps: reps,
            exerciseDurations: exerciseDurations,
            elapsedSeconds: elapsedSeconds,
            savedAt: Date()
        )
    }

    /// Persist unless the session is over. Cheap: a few hundred bytes of JSON.
    func persistSnapshot(to defaults: UserDefaults = .standard) {
        guard phase != .sessionComplete, !exercises.isEmpty, exercises.allSatisfy({ $0.id != nil }) else { return }
        snapshot.save(to: defaults)
    }

    func clearSnapshot(from defaults: UserDefaults = .standard) {
        SessionSnapshot.clear(from: defaults)
    }

    /// Rebuilds a manager from a snapshot, or nil when a drill no longer exists.
    static func restore(_ snapshot: SessionSnapshot, in context: NSManagedObjectContext) -> ActiveSessionManager? {
        var exercises: [Exercise] = []
        for idString in snapshot.exerciseIDs {
            guard let id = UUID(uuidString: idString) else { return nil }
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            guard let exercise = try? context.fetch(request).first else { return nil }
            exercises.append(exercise)
        }
        guard !exercises.isEmpty else { return nil }

        var planSession: PlanSession?
        if let planID = snapshot.planSessionID.flatMap(UUID.init(uuidString:)) {
            let request: NSFetchRequest<PlanSession> = PlanSession.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", planID as CVarArg)
            request.fetchLimit = 1
            planSession = try? context.fetch(request).first
        }

        let manager = ActiveSessionManager(exercises: exercises, planSession: planSession)
        manager.apply(snapshot)
        return manager
    }

    /// Restores counters; the clock stays paused until the player taps Resume.
    func apply(_ snapshot: SessionSnapshot) {
        let count = exercises.count
        currentExerciseIndex = min(max(snapshot.currentExerciseIndex, 0), max(count - 1, 0))
        exerciseRatings = Array(snapshot.exerciseRatings.prefix(count)) + Array(repeating: 0, count: max(0, count - snapshot.exerciseRatings.count))
        exerciseNotes = Array(snapshot.exerciseNotes.prefix(count)) + Array(repeating: "", count: max(0, count - snapshot.exerciseNotes.count))
        restoreClock(reps: snapshot.reps, durations: snapshot.exerciseDurations, elapsed: snapshot.elapsedSeconds)
        phase = .exercise
    }
}
