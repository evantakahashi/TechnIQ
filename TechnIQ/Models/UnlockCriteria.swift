import Foundation

/// What a player must do to master a drill (and unlock its harder version), e.g.
/// "20 consecutive juggles, 3 times". Stored JSON-encoded on `Exercise.unlockCriteriaJSON`;
/// drills without one get `UnlockCriteria.default`.
struct UnlockCriteria: Codable, Equatable {
    enum Kind: String, Codable {
        /// Finish the drill `times` times without it feeling too hard.
        case completions
        /// Hit `target` on `benchmark` `times` times (camera or typed-in benchmarks).
        case benchmark
        /// Log at least `target` reps in a completion, `times` times.
        case reps
    }

    var kind: Kind
    /// Per-attempt threshold (juggles in a row, reps). Ignored for `.completions`.
    var target: Int
    /// How many qualifying attempts are needed.
    var times: Int
    /// Which benchmark counts, for `.benchmark`.
    var benchmark: BenchmarkType?

    static let `default` = UnlockCriteria(kind: .completions, target: 0, times: 3, benchmark: nil)

    /// Player-facing sentence: "20 consecutive juggles, 3 times".
    var summary: String {
        let timesText = times == 1 ? "once" : "\(times) times"
        switch kind {
        case .completions:
            return times == 1 ? "Complete it once without it feeling too hard"
                : "Complete it \(times) times without it feeling too hard"
        case .benchmark:
            switch benchmark {
            case .juggling: return "\(target) consecutive juggles, \(timesText)"
            case .wallPasses30: return "\(target) wall passes in 30 s, \(timesText)"
            case .toeTaps30: return "\(target) toe taps in 30 s, \(timesText)"
            case nil: return "Complete it \(timesText)"
            }
        case .reps:
            return "\(target) reps in a session, \(timesText)"
        }
    }

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> UnlockCriteria? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(UnlockCriteria.self, from: data)
    }
}
