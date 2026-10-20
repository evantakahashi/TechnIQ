import Foundation

/// The hands-free session flow for a player 3–4 m from the phone, driven only by their pose:
/// stand in the outline → spoken 3-2-1 → live → result → stay in the outline to go again.
/// Holding both arms up (outside a live run) finishes the session.
final class HandsFreeFlow {
    enum State: Equatable {
        case positioning
        case countdown(startedAt: Double)
        case live(startedAt: Double)
        case result(since: Double)
        case finished
    }

    /// Things to say or show at a transition.
    enum Cue: Equatable {
        case stepIn
        case ready
        case countdown(Int)
        case go
        case timeUp
        case finished
    }

    struct Config {
        /// Seconds in position before the countdown starts.
        var hold = 1.0
        var countdownSeconds = 3
        /// Result stays up at least this long before "go again" can start.
        var resultMinimum = 4.0
        /// In position this long after the result to go again.
        var goAgainHold = 1.5
        var armsUpHold = 0.8
    }

    let mode: CameraDrill.Mode
    let aspect: Double
    let config: Config
    private(set) var state: State = .positioning

    private var inPositionSince: Double?
    private var armsUpSince: Double?
    private var lastCountdownCue: Int?
    private var lastTime = 0.0

    init(mode: CameraDrill.Mode, aspect: Double, config: Config = Config()) {
        self.mode = mode
        self.aspect = aspect
        self.config = config
    }

    var isLive: Bool {
        if case .live = state { return true }
        return false
    }

    /// Seconds left in a live timed drill.
    var timeLeft: Double? {
        guard case let .live(startedAt) = state, case let .timed(seconds) = mode else { return nil }
        return max(0, seconds - (lastTime - startedAt))
    }

    func update(pose: BodyPose?, time: Double) -> [Cue] {
        lastTime = time
        let inPosition = pose.map { Self.isInPosition($0, aspect: aspect) } ?? false
        inPositionSince = inPosition ? (inPositionSince ?? time) : nil
        let armsUp = pose.map(Self.armsUp) ?? false
        armsUpSince = armsUp ? (armsUpSince ?? time) : nil

        if !isLive, state != .finished, let since = armsUpSince, time - since >= config.armsUpHold {
            state = .finished
            return [.finished]
        }

        switch state {
        case .positioning:
            if let since = inPositionSince, time - since >= config.hold, !armsUp {
                return startCountdown(at: time)
            }
        case let .countdown(startedAt):
            guard inPosition else {
                state = .positioning
                return [.stepIn]
            }
            let elapsed = time - startedAt
            if elapsed >= Double(config.countdownSeconds) {
                state = .live(startedAt: time)
                return [.go]
            }
            let remaining = config.countdownSeconds - Int(elapsed)
            if remaining != lastCountdownCue {
                lastCountdownCue = remaining
                return [.countdown(remaining)]
            }
        case let .live(startedAt):
            if case let .timed(seconds) = mode, time - startedAt >= seconds {
                state = .result(since: time)
                return [.timeUp]
            }
        case let .result(since):
            if time - since >= config.resultMinimum, let held = inPositionSince,
               time - held >= config.goAgainHold, !armsUp {
                return startCountdown(at: time)
            }
        case .finished:
            break
        }
        return []
    }

    /// A streak run ended (ball down, handball, lost) — show the result.
    func runEnded(at time: Double) {
        guard isLive else { return }
        state = .result(since: time)
    }

    private func startCountdown(at time: Double) -> [Cue] {
        state = .countdown(startedAt: time)
        lastCountdownCue = config.countdownSeconds
        return [.ready, .countdown(config.countdownSeconds)]
    }

    // MARK: - Pose checks

    /// Whole body visible, big enough to track (≥ 35% of frame height), roughly centred.
    static func isInPosition(_ pose: BodyPose, aspect: Double) -> Bool {
        guard let nose = pose[.nose] else { return false }
        let ankles = [pose[.leftAnkle], pose[.rightAnkle]].compactMap { $0 }
        guard let lowest = ankles.map(\.y).min() else { return false }
        return nose.y - lowest >= 0.35
            && nose.y <= 0.97 && lowest >= 0.02
            && nose.x >= 0.2 * aspect && nose.x <= 0.8 * aspect
    }

    /// Both wrists above the nose.
    static func armsUp(_ pose: BodyPose) -> Bool {
        guard let nose = pose[.nose], let left = pose[.leftWrist], let right = pose[.rightWrist] else { return false }
        return left.y > nose.y && right.y > nose.y
    }
}
