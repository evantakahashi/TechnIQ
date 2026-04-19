import Foundation
import CoreData
import FirebaseAuth
import FirebaseFirestore
import Network
import UIKit

// MARK: - CloudService
// Unified cloud service merging CloudDataService, CloudSyncManager, and CloudRestoreService.

@MainActor
class CloudService: ObservableObject, CloudServiceProtocol {
    static let shared = CloudService()

    let db = Firestore.firestore()
    let auth = Auth.auth()
    let coreDataManager = CoreDataManager.shared

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Published (merged from all 3 services)

    enum CloudSyncStatus {
        case idle
        case syncing
        case success
        case error(String)
    }

    @Published var syncStatus: CloudSyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var isNetworkAvailable = true

    // From CloudSyncManager
    @Published var isSyncing = false
    @Published var syncError: String?

    // From CloudRestoreService
    @Published var isRestoring = false
    @Published var restoreProgress: Double = 0.0
    @Published var restoreError: String?

    // MARK: - Sync Configuration

    let autoSyncInterval: TimeInterval = 300 // 5 minutes
    var syncTimer: Timer?
    var lastSyncRequest: Date?
    let minSyncInterval: TimeInterval = 30

    // MARK: - Init

    private init() {
        setupFirestore()
        startNetworkMonitoring()
        startAutoSync()
        setupSyncNotifications()
    }

    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }

    // MARK: - Firestore Configuration

    private func setupFirestore() {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
    }

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isNetworkAvailable = isAvailable
                if !isAvailable {
                    #if DEBUG
                    print("🌐 Network connection lost - will skip cloud sync operations")
                    #endif
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Auto Sync

    private func startAutoSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: autoSyncInterval, repeats: true) { _ in
            Task {
                await self.performIncrementalSync()
            }
        }
    }

    func stopAutoSync() {
        syncTimer?.invalidate()
        syncTimer = nil
    }

    // MARK: - Batch Chunking

    /// Commits items in batches of 450 to stay under Firestore's 500-operation limit.
    func commitInChunks<T>(
        _ items: [T],
        using buildBatch: (WriteBatch, T) throws -> Void
    ) async throws {
        let chunkSize = 450
        for startIndex in stride(from: 0, to: items.count, by: chunkSize) {
            let endIndex = min(startIndex + chunkSize, items.count)
            let chunk = Array(items[startIndex..<endIndex])
            let batch = db.batch()
            for item in chunk {
                try buildBatch(batch, item)
            }
            try await batch.commit()
        }
    }
}

// MARK: - Data Models

struct CloudUserData {
    let playerProfiles: [[String: Any]]
    let playerGoals: [[String: Any]]
    let trainingSessions: [[String: Any]]
    let recommendationFeedback: [[String: Any]]
    let avatarConfiguration: [String: Any]?
    let ownedAvatarItems: [[String: Any]]
    let customExercises: [[String: Any]]
    let trainingPlans: [[String: Any]]
    let playerStats: [[String: Any]]
    let seasons: [[String: Any]]
    let matches: [[String: Any]]
}

struct CloudPlayerProfile {
    let playerId: String
    let skillGoals: [String]
    let experienceLevel: String
    let competitiveLevel: String
    let position: String
    let preferredIntensity: Int
    let physicalFocusAreas: [String]
}

struct MLAnalyticsData {
    let sessionId: String
    let playerId: String
    let timestamp: Date
    let eventType: MLEventType
    let exerciseId: String?
    let userAction: String
    let contextData: [String: Any]
    let deviceInfo: [String: String]

    enum MLEventType: String, CaseIterable {
        case sessionStart = "session_start"
        case exerciseView = "exercise_view"
        case exerciseComplete = "exercise_complete"
        case feedbackSubmit = "feedback_submit"
        case recommendationView = "recommendation_view"
        case recommendationClick = "recommendation_click"
        case sessionComplete = "session_complete"
    }
}

// MARK: - Errors

enum CloudDataError: LocalizedError {
    case notAuthenticated
    case invalidData
    case networkError
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network connection error"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        }
    }
}

enum CloudRestoreError: LocalizedError {
    case notAuthenticated
    case noDataFound
    case restorationFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .noDataFound:
            return "No cloud data found for this account"
        case .restorationFailed(let message):
            return "Restoration failed: \(message)"
        }
    }
}

// MARK: - Sync Status UI Helpers

extension CloudService {
    var syncStatusText: String {
        if isSyncing {
            return "Syncing..."
        } else if let error = syncError {
            return "Sync Error: \(error)"
        } else if let lastSync = lastSyncDate {
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Not synced"
        }
    }

    var syncStatusColor: String {
        if isSyncing {
            return "blue"
        } else if syncError != nil {
            return "red"
        } else {
            return "green"
        }
    }
}
