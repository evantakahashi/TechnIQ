import Foundation

// MARK: - Assessment flow
//
// The 10-minute assessment as a pure step machine (the view owns the clocks and the camera):
// intro → 2-min warm-up (skippable) → juggling, best of up to 3 attempts → wall passes 30 s →
// toe taps 30 s → results. Every step only moves forward; invalid calls are ignored, so the view
// can't put it in a state the recorder doesn't expect.

struct AssessmentFlow: Equatable {
    enum Step: Equatable {
        case intro, warmup, juggling, wallPasses, toeTaps, results
    }

    /// A timed test: start the clock, it runs, then the count is entered.
    enum TimedPhase: Equatable { case ready, running, entry }

    struct Measurement: Equatable {
        let value: Int
        let cameraVerified: Bool
    }

    static let warmupSeconds = 120
    static let maxJugglingAttempts = 3
    /// Juggling has no clock; the time spent on it counts as active, up to this much.
    static let maxJugglingSeconds = 300

    private(set) var step: Step = .intro
    private(set) var timedPhase: TimedPhase = .ready
    private(set) var jugglingAttempts: [Measurement] = []
    private(set) var results: [BenchmarkType: Measurement] = [:]
    /// Seconds the warm-up and test clocks actually ran (plus juggling time, capped).
    private(set) var activeSeconds = 0

    // MARK: Derived

    /// The benchmark the current step measures.
    var currentType: BenchmarkType? {
        switch step {
        case .juggling: return .juggling
        case .wallPasses: return .wallPasses30
        case .toeTaps: return .toeTaps30
        case .intro, .warmup, .results: return nil
        }
    }

    var remainingJugglingAttempts: Int { max(0, Self.maxJugglingAttempts - jugglingAttempts.count) }

    /// Best attempt (ties: a camera-counted one).
    var jugglingBest: Measurement? {
        jugglingAttempts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : (!lhs.cameraVerified && rhs.cameraVerified)
        }
    }

    /// Touches the camera counted: every camera juggling attempt, plus camera-counted timed tests.
    var verifiedTouches: Int {
        jugglingAttempts.filter(\.cameraVerified).reduce(0) { $0 + $1.value }
            + [BenchmarkType.wallPasses30, .toeTaps30].compactMap { results[$0] }.filter(\.cameraVerified).reduce(0) { $0 + $1.value }
    }

    /// 1-based position among the four parts (warm-up, juggling, wall passes, toe taps); 0 on intro.
    var stepNumber: Int {
        switch step {
        case .intro: return 0
        case .warmup: return 1
        case .juggling: return 2
        case .wallPasses: return 3
        case .toeTaps: return 4
        case .results: return 4
        }
    }

    static let stepCount = 4

    var isFinished: Bool { step == .results }

    // MARK: Transitions

    mutating func begin() {
        guard step == .intro else { return }
        step = .warmup
    }

    /// Warm-up over: its clock ran out or the player skipped it after `ranSeconds`.
    mutating func finishWarmup(ranSeconds: Int) {
        guard step == .warmup else { return }
        activeSeconds += min(max(ranSeconds, 0), Self.warmupSeconds)
        step = .juggling
    }

    mutating func addJugglingAttempt(_ value: Int, cameraVerified: Bool) {
        guard step == .juggling, value >= 0, remainingJugglingAttempts > 0 else { return }
        jugglingAttempts.append(Measurement(value: value, cameraVerified: cameraVerified))
    }

    /// Juggling done (needs one attempt): the best goes in, on to wall passes.
    mutating func finishJuggling(elapsedSeconds: Int) {
        guard step == .juggling, let best = jugglingBest else { return }
        results[.juggling] = best
        activeSeconds += min(max(elapsedSeconds, 0), Self.maxJugglingSeconds)
        step = .wallPasses
        timedPhase = .ready
    }

    mutating func startClock() {
        guard isTimedStep, timedPhase == .ready else { return }
        timedPhase = .running
    }

    /// The 30-s clock ran out (or was stopped early after `ranSeconds`).
    mutating func clockEnded(ranSeconds: Int) {
        guard isTimedStep, timedPhase == .running, let window = currentType?.windowSeconds else { return }
        activeSeconds += min(max(ranSeconds, 0), window)
        timedPhase = .entry
    }

    /// Run the clock again (a fumbled start); the time already run still counted.
    mutating func redoClock() {
        guard isTimedStep, timedPhase == .entry else { return }
        timedPhase = .ready
    }

    /// The count for the current timed test; moves to the next test or the results.
    mutating func enterCount(_ value: Int, cameraVerified: Bool = false) {
        guard isTimedStep, timedPhase == .entry, value >= 0, let type = currentType else { return }
        results[type] = Measurement(value: value, cameraVerified: cameraVerified)
        step = step == .wallPasses ? .toeTaps : .results
        timedPhase = .ready
    }

    private var isTimedStep: Bool { step == .wallPasses || step == .toeTaps }
}
