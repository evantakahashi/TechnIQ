import Foundation

/// The three numbers the assessment measures and every plan retests.
/// Raw values are persisted on `Benchmark.type` and synced — never rename.
enum BenchmarkType: String, CaseIterable, Identifiable, Codable {
    /// Most consecutive juggles in one run.
    case juggling
    /// Clean wall passes in 30 seconds.
    case wallPasses30
    /// Alternating toe taps in 30 seconds.
    case toeTaps30

    var id: String { rawValue }

    var title: String {
        switch self {
        case .juggling: return "Juggling"
        case .wallPasses30: return "Wall passes"
        case .toeTaps30: return "Toe taps"
        }
    }

    /// Unit shown after the value ("14 in a row", "22 in 30 s").
    var unit: String {
        switch self {
        case .juggling: return "in a row"
        case .wallPasses30, .toeTaps30: return "in 30 s"
        }
    }

    /// Timed window in seconds, nil for a streak.
    var windowSeconds: Int? {
        switch self {
        case .juggling: return nil
        case .wallPasses30, .toeTaps30: return 30
        }
    }

    /// The camera drill that measures this benchmark.
    var cameraDrill: CameraDrill {
        switch self {
        case .juggling: return .juggling
        case .wallPasses30: return .wallPasses
        case .toeTaps30: return .toeTaps
        }
    }

    /// The benchmark a camera drill's run counts toward (nil for drills that aren't benchmarks).
    static func forCameraDrill(_ drill: CameraDrill) -> BenchmarkType? {
        allCases.first { $0.cameraDrill == drill }
    }
}
