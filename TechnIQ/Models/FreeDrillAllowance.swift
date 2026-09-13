import Foundation

/// The free tier's AI drill budget: three drills for life, then Pro. Counted per signed-in user in
/// UserDefaults; the server's daily LLM quota remains the hard backstop. Pure enough to unit test with
/// a throwaway `UserDefaults` suite.
struct FreeDrillAllowance {
    static let total = 3

    private let defaults: UserDefaults
    private let key: String

    init(userUID: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.key = "freeAIDrillsUsed.\(userUID.isEmpty ? "anonymous" : userUID)"
    }

    var used: Int {
        get { max(0, defaults.integer(forKey: key)) }
        nonmutating set { defaults.set(max(0, newValue), forKey: key) }
    }

    var remaining: Int { max(0, Self.total - used) }

    func canGenerate(isPro: Bool) -> Bool { isPro || remaining > 0 }

    /// Call once per drill that actually came back from the pipeline. Pro players are never counted,
    /// so a later downgrade still leaves them their three.
    func recordGeneration(isPro: Bool) {
        guard !isPro else { return }
        used += 1
    }

    /// "3 free drills left" / "1 free drill left" / "No free drills left".
    var label: String {
        switch remaining {
        case 0: return "No free drills left"
        case 1: return "1 free drill left"
        default: return "\(remaining) free drills left"
        }
    }
}
