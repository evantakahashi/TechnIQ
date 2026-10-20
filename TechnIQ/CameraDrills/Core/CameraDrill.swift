import Foundation

/// The camera-counted drills. Raw values are persisted on `CameraRun.drill` and synced — never rename.
enum CameraDrill: String, CaseIterable, Identifiable {
    case juggling
    case weakFootJuggling
    case alternatingJuggling
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
        case .toeTaps: return "Toe taps"
        case .wallPasses: return "Wall passes"
        }
    }

    var rules: String {
        switch self {
        case .juggling: return "Feet, thighs, chest, head. Hands or the ground end it."
        case .weakFootJuggling: return "Weak foot only. A strong-foot touch ends it."
        case .alternatingJuggling: return "Left, right, left. The same foot twice ends it."
        case .toeTaps: return "Alternate soles on top of the ball for 30 seconds."
        case .wallPasses: return "Pass, receive, repeat against a wall for 30 seconds."
        }
    }

    var mode: Mode {
        switch self {
        case .juggling, .weakFootJuggling, .alternatingJuggling: return .streak
        case .toeTaps, .wallPasses: return .timed(seconds: 30)
        }
    }

    /// Drills with a counter today; the rest arrive in phase 5.
    var isAvailable: Bool { makeCounter() != nil }

    func makeCounter() -> DrillCounter? {
        switch self {
        case .juggling: return JuggleCounter()
        default: return nil
        }
    }
}
