import Foundation
import CoreData

/// Saves camera-counted runs: personal bests, sitting-capped XP (`CameraSitting`), cloud sync.
@MainActor
final class CameraRunService: ObservableObject {
    static let shared = CameraRunService()

    struct Outcome {
        let run: CameraRun
        let xp: Int
        let isPersonalBest: Bool
        let previousBest: Int?
        let levelUp: Int?
    }

    private let context: NSManagedObjectContext

    private init() {
        context = CoreDataManager.shared.context
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    /// Best count so far for `drill`, or nil if the player has no runs of it.
    func personalBest(for drill: CameraDrill, player: Player) -> Int? {
        let request: NSFetchRequest<CameraRun> = CameraRun.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND drill == %@", player, drill.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "count", ascending: false)]
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first.map { Int($0.count) }
    }

    /// Records a finished run and pays its share of the sitting's XP. Runs of 0 touches are not stored.
    /// `sitting` is the camera session the run belongs to; the default is a sitting of this run alone.
    /// A run of a benchmark drill also records a camera-verified Benchmark unless `recordsBenchmark`
    /// is false (the assessment records its own best-of-three).
    @discardableResult
    func record(drill: CameraDrill, count: Int, duration: Double, player: Player,
                sitting: CameraSitting = CameraSitting(), now: Date = Date(),
                recordsBenchmark: Bool = true) -> Outcome? {
        guard count > 0 else { return nil }
        let previousBest = personalBest(for: drill, player: player)
        let isBest = CameraRewards.isPersonalBest(count: count, previousBest: previousBest)
        let xp = sitting.xp(forRunWith: count, seconds: duration)

        let run = CameraRun(context: context)
        run.id = UUID()
        run.drill = drill.rawValue
        run.count = Int32(count)
        run.duration = duration
        run.isPersonalBest = isBest
        run.xpEarned = Int32(xp)
        run.createdAt = now
        run.updatedAt = now
        run.player = player
        player.addToCameraRuns(run)

        let levelUp = xp > 0 ? XPService.shared.awardXP(to: player, amount: Int32(xp)) : nil
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("[CameraRunService] Save failed: \(error.localizedDescription)")
            context.rollback()
            return nil
        }
        sitting.add(touches: count, seconds: duration, xp: xp)

        Task { @MainActor in try? await CloudService.shared.syncCameraRuns([run], for: player) }
        if recordsBenchmark {
            BenchmarkService(context: context).recordCameraRun(drill: drill, count: count, duration: duration, player: player, date: now)
        }
        return Outcome(run: run, xp: xp, isPersonalBest: isBest, previousBest: previousBest, levelUp: levelUp)
    }
}
