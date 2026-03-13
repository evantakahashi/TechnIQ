import Foundation

// MARK: - CloudDataService Protocol

@MainActor
protocol CloudDataServiceProtocol: AnyObject {
    var isNetworkAvailable: Bool { get }
    func syncPlayerProfile(_ player: Player, with profile: PlayerProfile) async throws
    func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws
    func syncTrainingSession(_ session: TrainingSession) async throws
    func syncRecommendationFeedback(_ feedback: [RecommendationFeedback]) async throws
    func hasCloudData() async throws -> Bool
    func fetchAllUserData() async throws -> CloudUserData
}

// MARK: - CloudSyncManager Protocol

@MainActor
protocol CloudSyncManagerProtocol: AnyObject {
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var syncError: String? { get }
    func performFullSync() async
    func performIncrementalSync() async
    func stopAutoSync()
}

// MARK: - CloudRestoreService Protocol

@MainActor
protocol CloudRestoreServiceProtocol: AnyObject {
    var isRestoring: Bool { get }
    var restoreProgress: Double { get }
    var restoreError: String? { get }
    func hasCloudData() async -> Bool
    func restoreFromCloud() async throws -> Player?
}
