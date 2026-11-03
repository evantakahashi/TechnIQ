import Foundation

/// XP for one camera sitting (one CameraDrillSession): `XPFormula` over the sitting's total
/// camera-counted touches and total live seconds, so a sitting earns 30 XP at most. Each run is paid
/// the increase it makes, so the runs add up to the sitting's total. No personal-best or daily bonuses.
final class CameraSitting {
    private(set) var touches = 0
    private(set) var liveSeconds: Double = 0
    private(set) var xpAwarded = 0

    init() {}

    /// XP a run of `touches` over `seconds` would earn on top of what the sitting has paid. Pure.
    func xp(forRunWith touches: Int, seconds: Double) -> Int {
        let total = XPFormula.session(verifiedTouches: self.touches + max(0, touches),
                                      activeSeconds: liveSeconds + Self.clean(seconds)).total
        return max(0, Int(total) - xpAwarded)
    }

    /// Adds a saved run and the XP it was paid.
    func add(touches: Int, seconds: Double, xp: Int) {
        self.touches += max(0, touches)
        liveSeconds += Self.clean(seconds)
        xpAwarded += max(0, xp)
    }

    private static func clean(_ seconds: Double) -> Double {
        seconds.isFinite ? max(0, seconds) : 0
    }
}

enum CameraRewards {
    /// Runs shorter than this can't be a personal best.
    static let minimumCount = 3

    static func isPersonalBest(count: Int, previousBest: Int?) -> Bool {
        count >= minimumCount && count > (previousBest ?? 0)
    }
}

/// Live tracking needs an A14 or newer (iPhone 12+) to hold ~30 fps.
enum CameraDrillSupport {
    /// `machine` is the hardware id, e.g. "iPhone13,2" (iPhone 12).
    static func isSupported(machine: String) -> Bool {
        guard machine.hasPrefix("iPhone"),
              let major = Int(machine.dropFirst("iPhone".count).split(separator: ",").first ?? "") else { return false }
        return major >= 13
    }

    /// This device's hardware id (the simulated model's id on the simulator).
    static var currentMachine: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] { return simulated }
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
    }

    static var isCurrentDeviceSupported: Bool { isSupported(machine: currentMachine) }
}
