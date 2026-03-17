import Foundation

// MARK: - Unified CloudService Protocol

@MainActor
protocol CloudServiceProtocol: AnyObject {
    // Network
    var isNetworkAvailable: Bool { get }

    // Sync state (formerly CloudDataService)
    var syncStatus: CloudService.CloudSyncStatus { get }
    var lastSyncDate: Date? { get }

    // Sync management (formerly CloudSyncManager)
    var isSyncing: Bool { get }
    var syncError: String? { get }
    func performFullSync() async
    func performIncrementalSync() async
    func stopAutoSync()

    // Upload (formerly CloudDataService)
    func syncPlayerProfile(_ player: Player, with profile: PlayerProfile) async throws
    func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws
    func syncTrainingSession(_ session: TrainingSession) async throws
    func syncRecommendationFeedback(_ feedback: [RecommendationFeedback]) async throws
    func hasCloudData() async throws -> Bool
    func fetchAllUserData() async throws -> CloudUserData

    // Restore (formerly CloudRestoreService)
    var isRestoring: Bool { get }
    var restoreProgress: Double { get }
    var restoreError: String? { get }
    func hasCloudDataForRestore() async -> Bool
    func restoreFromCloud() async throws -> Player?
}

