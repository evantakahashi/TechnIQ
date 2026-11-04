import Foundation

/// The camera-counted drills. Raw values are persisted on `CameraRun.drill` and synced — never rename.
enum CameraDrill: String, CaseIterable, Identifiable {
    case juggling
    case weakFootJuggling
    case alternatingJuggling
    case feetOnlyJuggling
    case belowWaistJuggling
    case toeTaps
    case wallPasses

    enum Mode: Equatable {
        /// Longest run until the ball drops.
        case streak
        /// Most touches inside a fixed window.
        case timed(seconds: Double)
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .juggling: return "Juggling"
        case .weakFootJuggling: return "Weak-foot juggling"
        case .alternatingJuggling: return "Alternating juggling"
        case .feetOnlyJuggling: return "Feet only"
        case .belowWaistJuggling: return "Below the waist"
        case .toeTaps: return "Toe taps"
        case .wallPasses: return "Wall passes"
        }
    }

    var rules: String {
        switch self {
        case .juggling: return "Feet, thighs, chest, head. Hands or the ground end it."
        case .weakFootJuggling: return "Weak foot only. A strong-foot touch ends it."
        case .alternatingJuggling: return "Left, right, left. The same foot twice ends it."
        case .feetOnlyJuggling: return "Feet only. A thigh, chest or head touch ends it."
        case .belowWaistJuggling: return "Keep it below your waist. Higher ends it."
        case .toeTaps: return "Alternate soles on top of the ball for 30 seconds."
        case .wallPasses: return "Wall to your side. Pass, receive, repeat for 30 seconds."
        }
    }

    /// Positioning prompt detail: where the ball should be while the player gets in the outline.
    var setupHint: String {
        switch self {
        case .juggling, .weakFootJuggling, .alternatingJuggling, .feetOnlyJuggling, .belowWaistJuggling:
            return "Whole body in frame, ball in your hands"
        case .toeTaps: return "Whole body in frame, ball on the ground in front of you"
        case .wallPasses: return "Whole body in frame, wall to your side, ball at your feet"
        }
    }

    /// Result-panel hint when a run counted nothing.
    var noTouchesHint: String {
        switch self {
        case .juggling: return "Drop it from your hands and keep it up"
        case .weakFootJuggling: return "Keep it up with your weaker foot only"
        case .alternatingJuggling: return "Keep it up, left foot then right"
        case .feetOnlyJuggling: return "Keep it up with your feet only"
        case .belowWaistJuggling: return "Small touches: keep it below your waist"
        case .toeTaps: return "Tap the top of the ball, left sole then right"
        case .wallPasses: return "Pass it off the wall and control it back at your feet"
        }
    }

    /// Counting not yet checked against real footage.
    var isBeta: Bool { self != .juggling }

    /// The ball rests on the ground for the whole drill, so it mustn't be filtered out as scenery.
    var ballRests: Bool { self == .toeTaps }

    var mode: Mode {
        switch self {
        case .juggling, .weakFootJuggling, .alternatingJuggling, .feetOnlyJuggling, .belowWaistJuggling: return .streak
        case .toeTaps, .wallPasses: return .timed(seconds: 30)
        }
    }

    /// Drills with a counter.
    var isAvailable: Bool { makeCounter() != nil }

    /// - Parameter dominantFoot: `Player.dominantFoot` ("Left" / "Right" / …); weak-foot juggling counts the
    ///   other foot (right-footed when unknown).
    func makeCounter(dominantFoot: String? = nil) -> DrillCounter? {
        switch self {
        case .juggling: return JuggleCounter()
        case .weakFootJuggling: return juggleCounter(.only(dominantFoot == "Left" ? .right : .left))
        case .alternatingJuggling: return juggleCounter(.alternate)
        case .feetOnlyJuggling:
            var config = JuggleCounter.Config()
            config.partRule = .feetOnly
            return JuggleCounter(config: config)
        case .belowWaistJuggling:
            var config = JuggleCounter.Config()
            config.heightLimit = .waist
            return JuggleCounter(config: config)
        case .toeTaps: return ToeTapCounter()
        case .wallPasses: return WallPassCounter()
        }
    }

    private func juggleCounter(_ rule: JuggleCounter.FootRule) -> JuggleCounter {
        var config = JuggleCounter.Config()
        config.footRule = rule
        return JuggleCounter(config: config)
    }
}
