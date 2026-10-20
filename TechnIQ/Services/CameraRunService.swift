import Foundation
import CoreData

/// Saves camera-counted runs: personal bests, capped XP/coin rewards, cloud sync.
@MainActor
final class CameraRunService: ObservableObject {
    static let shared = CameraRunService()

    struct Outcome {
        let run: CameraRun
        let reward: CameraReward
        let isPersonalBest: Bool
        let previousBest: Int?
        let levelUp: Int?
    }

    private let context: NSManagedObjectContext
    private let defaults: UserDefaults
    private let coins: CoinService

    private init() {
        context = CoreDataManager.shared.context
        defaults = .standard
        coins = .shared
    }

    init(context: NSManagedObjectContext, defaults: UserDefaults, coins: CoinService) {
        self.context = context
        self.defaults = defaults
        self.coins = coins
    }

    /// Best count so far for `drill`, or nil if the player has no runs of it.
    func personalBest(for drill: CameraDrill, player: Player) -> Int? {
        let request: NSFetchRequest<CameraRun> = CameraRun.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND drill == %@", player, drill.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first.map { Int($0.count) }
    }

    /// Records a finished run and pays its reward. Runs of 0 touches are not stored.
    @discardableResult
    func record(drill: CameraDrill, count: Int, duration: Double, player: Player, now: Date = Date()) -> Outcome? {
        guard count > 0 else { return nil }
        let previousBest = personalBest(for: drill, player: player)
        let isBest = CameraRewards.isPersonalBest(count: count, previousBest: previousBest)
        let ledgerKey = Self.ledgerKey(player: player, day: now)
        let rewardedToday = defaults.integer(forKey: ledgerKey)
        let reward = CameraRewards.reward(count: count, isPersonalBest: isBest, beatChallenge: false,
                                          rewardedRunsToday: rewardedToday)

        let run = CameraRun(context: context)
        run.id = UUID()
        run.drill = drill.rawValue
        run.count = Int32(count)
        run.duration = duration
        run.isPersonalBest = isBest
        run.xpEarned = Int32(reward.xp)
        run.coinsEarned = Int32(reward.coins)
        run.createdAt = now
        run.updatedAt = now
        run.player = player
        player.addToCameraRuns(run)

        let levelUp = reward.xp > 0 ? XPService.shared.awardXP(to: player, amount: Int32(reward.xp)) : nil
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("[CameraRunService] Save failed: \(error.localizedDescription)")
            context.rollback()
            return nil
        }
        if reward.countsTowardCap { defaults.set(rewardedToday + 1, forKey: ledgerKey) }
        if reward.coins > 0 { coins.awardCoins(reward.coins, for: .cameraRun(coins: reward.coins), context: context) }
        if let levelUp { coins.awardLevelUpCoins(newLevel: levelUp, context: context) }

        Task { @MainActor in try? await CloudService.shared.syncCameraRuns([run], for: player) }
        return Outcome(run: run, reward: reward, isPersonalBest: isBest, previousBest: previousBest, levelUp: levelUp)
    }

    private static func ledgerKey(player: Player, day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return "cameraRewards.\(player.id?.uuidString ?? "none").\(formatter.string(from: day))"
    }
}
