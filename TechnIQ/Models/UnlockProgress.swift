import Foundation

// MARK: - Unlock progress
//
// How far a player is toward a drill's `UnlockCriteria`. A completion is one finished run of the
// drill (a SessionExercise) in a session that did not feel too hard; sessions with no feel count.
// Benchmark criteria count recorded benchmarks of that type at or above the target.

struct UnlockProgress: Equatable {
    struct Completion: Equatable {
        var reps: Int
        var feel: SessionFeel?
    }

    struct BenchmarkResult: Equatable {
        var type: BenchmarkType
        var value: Int
    }

    let done: Int
    let needed: Int

    var isUnlocked: Bool { done >= needed }
    var fraction: Double { needed > 0 ? min(1, Double(done) / Double(needed)) : 1 }
    /// "2 of 3"
    var countLabel: String { "\(min(done, needed)) of \(needed)" }

    static func compute(criteria: UnlockCriteria,
                        completions: [Completion],
                        benchmarks: [BenchmarkResult]) -> UnlockProgress {
        let needed = max(1, criteria.times)
        let counted = completions.filter { $0.feel != .tooHard }
        let done: Int
        switch criteria.kind {
        case .completions:
            done = counted.count
        case .reps:
            done = counted.filter { $0.reps >= criteria.target }.count
        case .benchmark:
            if let type = criteria.benchmark {
                done = benchmarks.filter { $0.type == type && $0.value >= criteria.target }.count
            } else {
                done = counted.count
            }
        }
        return UnlockProgress(done: done, needed: needed)
    }
}

extension Exercise {
    /// Live progress toward this drill's unlock criteria from the player's sessions and benchmarks.
    var unlockProgress: UnlockProgress {
        let completions = ((sessionExercises as? Set<SessionExercise>) ?? []).map {
            UnlockProgress.Completion(reps: Int($0.reps), feel: SessionFeel(raw: $0.session?.feel))
        }
        let benchmarks = ((player?.benchmarks as? Set<Benchmark>) ?? []).compactMap { row -> UnlockProgress.BenchmarkResult? in
            guard let type = row.type.flatMap(BenchmarkType.init(rawValue:)) else { return nil }
            return UnlockProgress.BenchmarkResult(type: type, value: Int(row.value))
        }
        return UnlockProgress.compute(criteria: unlockCriteria, completions: completions, benchmarks: benchmarks)
    }
}
