import Foundation

struct CameraReward: Equatable {
    var xp: Int
    var coins: Int
    /// Whether this run used one of the day's capped base rewards.
    var countsTowardCap: Bool

    static let none = CameraReward(xp: 0, coins: 0, countsTowardCap: false)
}

/// XP and coins for camera-verified runs. Only the per-run base is capped: a personal best can't be
/// farmed (it has to beat the last one) and a challenge pays once, so those always pay.
enum CameraRewards {
    static let dailyCap = 10
    /// Runs shorter than this earn nothing (and can't be a personal best).
    static let minimumCount = 3
    static let base = (xp: 5, coins: 2)
    static let personalBest = (xp: 25, coins: 10)
    static let challenge = (xp: 100, coins: 50)

    static func reward(count: Int, isPersonalBest: Bool, beatChallenge: Bool, rewardedRunsToday: Int) -> CameraReward {
        guard count >= minimumCount else { return .none }
        var reward = CameraReward.none
        if rewardedRunsToday < dailyCap {
            reward = CameraReward(xp: base.xp, coins: base.coins, countsTowardCap: true)
        }
        if isPersonalBest {
            reward.xp += personalBest.xp
            reward.coins += personalBest.coins
        }
        if beatChallenge {
            reward.xp += challenge.xp
            reward.coins += challenge.coins
        }
        return reward
    }

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
