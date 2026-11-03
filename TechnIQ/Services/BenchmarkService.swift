import Foundation
import CoreData

/// The three benchmark numbers (`BenchmarkType`): records them (typed or camera-counted), summarises
/// last vs best, and saves a finished assessment as one session. Syncs through
/// `CloudService.syncBenchmarks`.
@MainActor
final class BenchmarkService {
    static let shared = BenchmarkService()

    private let context: NSManagedObjectContext

    private init() {
        context = CoreDataManager.shared.context
    }

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    struct Value {
        let type: BenchmarkType
        let value: Int
        let cameraVerified: Bool
    }

    // MARK: Reading

    func entries(for player: Player) -> [BenchmarkEntry] {
        let request: NSFetchRequest<Benchmark> = Benchmark.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return ((try? context.fetch(request)) ?? []).compactMap(Self.entry)
    }

    func summaries(for player: Player) -> [BenchmarkType: BenchmarkSummary] {
        BenchmarkSummary.summarize(entries(for: player))
    }

    func hasBenchmarks(_ player: Player) -> Bool {
        let request: NSFetchRequest<Benchmark> = Benchmark.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        return ((try? context.count(for: request)) ?? 0) > 0
    }

    nonisolated static func entry(_ benchmark: Benchmark) -> BenchmarkEntry? {
        guard let raw = benchmark.type, let type = BenchmarkType(rawValue: raw) else { return nil }
        return BenchmarkEntry(type: type, value: Int(benchmark.value), date: benchmark.date ?? benchmark.createdAt ?? .distantPast,
                              cameraVerified: benchmark.cameraVerified)
    }

    // MARK: Writing

    /// Records one value. 0 is a legitimate result (a beginner's first juggle); negatives are not.
    @discardableResult
    func record(type: BenchmarkType, value: Int, cameraVerified: Bool, player: Player, date: Date = Date()) -> Benchmark? {
        record([Value(type: type, value: value, cameraVerified: cameraVerified)], player: player, date: date).first
    }

    /// Records several values in one save and one sync.
    @discardableResult
    func record(_ values: [Value], player: Player, date: Date = Date()) -> [Benchmark] {
        let benchmarks = values.filter { $0.value >= 0 }.map { insert($0, player: player, date: date) }
        guard !benchmarks.isEmpty else { return [] }
        do {
            try context.save()
        } catch {
            AppLogger.shared.error("[BenchmarkService] Save failed: \(error.localizedDescription)")
            context.rollback()
            return []
        }
        sync(benchmarks, for: player)
        return benchmarks
    }

    /// A finished camera run of a benchmark drill: juggling counts its run, the timed drills their
    /// count in the 30-s window (a run stopped early isn't a fair 30 s, so it isn't recorded).
    /// Runs of 0 aren't recorded either: a 0 from the camera is usually a false start.
    @discardableResult
    func recordCameraRun(drill: CameraDrill, count: Int, duration: Double, player: Player, date: Date = Date()) -> Benchmark? {
        guard let type = Self.benchmarkType(forCameraRunOf: drill, count: count, duration: duration) else { return nil }
        return record(type: type, value: count, cameraVerified: true, player: player, date: date)
    }

    /// The benchmark a camera run counts toward, or nil when it doesn't (see `recordCameraRun`).
    nonisolated static func benchmarkType(forCameraRunOf drill: CameraDrill, count: Int, duration: Double) -> BenchmarkType? {
        guard count > 0, let type = BenchmarkType.forCameraDrill(drill) else { return nil }
        if let window = type.windowSeconds, duration < Double(window) - 1 { return nil }
        return type
    }

    private func insert(_ value: Value, player: Player, date: Date) -> Benchmark {
        let benchmark = Benchmark(context: context)
        benchmark.id = UUID()
        benchmark.type = value.type.rawValue
        benchmark.value = Int32(clamping: value.value)
        benchmark.cameraVerified = value.cameraVerified
        benchmark.date = date
        benchmark.createdAt = date
        benchmark.updatedAt = date
        benchmark.player = player
        player.addToBenchmarks(benchmark)
        return benchmark
    }

    private func sync(_ benchmarks: [Benchmark], for player: Player) {
        guard !CloudService.isRunningUnitTests else { return }
        Task { @MainActor in try? await CloudService.shared.syncBenchmarks(benchmarks, for: player) }
    }

    // MARK: Assessment

    struct AssessmentOutcome {
        let session: TrainingSession
        let xp: SessionXPBreakdown
        let newLevel: Int?
        let achievements: [Achievement]
    }

    /// Saves a finished assessment: its three benchmarks, and a TrainingSession ("Assessment") carrying
    /// the active seconds and camera-counted touches, paid through the one XP path. A plan's
    /// assessment session is fulfilled. Returns nil when the flow isn't finished.
    @discardableResult
    func finishAssessment(_ flow: AssessmentFlow, player: Player, planSession: PlanSession?, startedAt: Date,
                          now: Date = Date()) -> AssessmentOutcome? {
        guard flow.isFinished else { return nil }
        let values = BenchmarkType.allCases.compactMap { type in
            flow.results[type].map { Value(type: type, value: $0.value, cameraVerified: $0.cameraVerified) }
        }
        let startingLevel = Int(player.currentLevel)
        let benchmarks = values.map { insert($0, player: player, date: now) }

        let session = TrainingSession(context: context)
        session.id = UUID()
        session.player = player
        session.date = now
        session.sessionType = SessionType.assessment.rawValue
        session.duration = max(1, (now.timeIntervalSince(startedAt) / 60).rounded())
        session.activeSeconds = Double(flow.activeSeconds)
        session.verifiedTouches = Int32(flow.verifiedTouches)
        session.intensity = Int16(RetestWeek.assessmentIntensity)
        session.notes = values.map { "\($0.type.title) \($0.value)" }.joined(separator: " · ")
        if let planSession { session.planSession = planSession }

        do {
            try context.save()
        } catch {
            AppLogger.shared.error("[BenchmarkService] Assessment save failed: \(error.localizedDescription)")
            context.rollback()
            return nil
        }
        sync(benchmarks, for: player)

        if let planSession {
            TrainingPlanService.shared.markSessionCompleted(planSession.toModel(), actualDuration: Int(session.duration),
                                                            actualIntensity: Int(session.intensity))
        }
        let (xp, _) = XPService.shared.processSessionCompletion(session: session, player: player, context: context,
                                                                allExercisesCompleted: true)
        let achievements = AchievementService.shared.checkAndUnlockAchievements(for: player, in: context)
        let newLevel = XPService.shared.syncLevel(for: player, previousLevel: startingLevel)
        try? context.save()
        if !CloudService.isRunningUnitTests { NotificationManager.shared.refresh(for: player) }
        return AssessmentOutcome(session: session, xp: xp, newLevel: newLevel, achievements: achievements)
    }
}
