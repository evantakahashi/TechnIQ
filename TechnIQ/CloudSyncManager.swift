import Foundation
import CoreData
import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - Cloud Sync Manager
// Handles synchronization between Core Data and Firebase Firestore for ML features

class CloudSyncManager: ObservableObject {
    static let shared = CloudSyncManager()
    
    private let cloudDataService = CloudDataService.shared
    private let coreDataManager = CoreDataManager.shared
    
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: String?
    
    // Sync configuration
    private let autoSyncInterval: TimeInterval = 300 // 5 minutes
    private var syncTimer: Timer?
    
    // Throttling to prevent excessive sync calls
    private var lastSyncRequest: Date?
    private let minSyncInterval: TimeInterval = 30 // 30 seconds minimum between syncs
    
    private init() {
        startAutoSync()
        setupSyncNotifications()
    }
    
    deinit {
        syncTimer?.invalidate()
    }
    
    // MARK: - Auto Sync Management
    
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
    
    // MARK: - Manual Sync Operations
    
    func performFullSync() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        do {
            // Sync player profiles and goals
            try await syncPlayerData()
            
            // Sync training sessions
            try await syncTrainingHistory()
            
            // Sync recommendation feedback
            try await syncRecommendationFeedback()
            
            lastSyncDate = Date()
            print("✅ Full cloud sync completed successfully")
            
        } catch {
            syncError = error.localizedDescription
            print("❌ Full sync failed: \(error)")
        }
        
        isSyncing = false
    }
    
    func performIncrementalSync() async {
        guard !isSyncing else { return }
        guard Auth.auth().currentUser != nil else { return }
        
        // Throttle sync requests to prevent excessive network calls
        if let lastRequest = lastSyncRequest,
           Date().timeIntervalSince(lastRequest) < minSyncInterval {
            print("⏰ Sync request throttled - too soon since last sync")
            return
        }
        
        lastSyncRequest = Date()
        isSyncing = true
        
        do {
            // Only sync data that has changed since last sync
            try await syncRecentChanges()
            lastSyncDate = Date()
            
        } catch {
            print("⚠️ Incremental sync failed: \(error)")
            // Don't set error for incremental sync failures
        }
        
        isSyncing = false
    }
    
    // MARK: - Player Data Sync
    
    private func syncPlayerData() async throws {
        let context = coreDataManager.context
        
        // Fetch all players with profiles
        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.predicate = NSPredicate(format: "playerProfile != nil")
        
        do {
            let players = try context.fetch(playerRequest)
            
            for player in players {
                if let profile = player.playerProfile {
                    try await cloudDataService.syncPlayerProfile(player, with: profile)
                }
                
                // Sync player goals
                if let goals = player.playerGoals?.allObjects as? [PlayerGoal] {
                    try await cloudDataService.syncPlayerGoals(goals, for: player)
                }
            }
            
        } catch {
            throw error
        }
    }
    
    private func syncTrainingHistory() async throws {
        let context = coreDataManager.context
        
        // Fetch training sessions from last 30 days
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let sessionRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        sessionRequest.predicate = NSPredicate(format: "date >= %@", thirtyDaysAgo as NSDate)
        sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]
        
        do {
            let sessions = try context.fetch(sessionRequest)
            
            for session in sessions {
                try await cloudDataService.syncTrainingSession(session)
            }
            
        } catch {
            throw error
        }
    }
    
    private func syncRecommendationFeedback() async throws {
        let context = coreDataManager.context
        
        // Fetch unsynced recommendation feedback
        let feedbackRequest: NSFetchRequest<RecommendationFeedback> = RecommendationFeedback.fetchRequest()
        
        do {
            let feedback = try context.fetch(feedbackRequest)
            try await cloudDataService.syncRecommendationFeedback(feedback)
            
        } catch {
            throw error
        }
    }
    
    private func syncRecentChanges() async throws {
        // Sync only items modified since last sync
        guard let lastSync = lastSyncDate else {
            // First sync - do full sync without recursion
            try await syncPlayerData()
            try await syncTrainingHistory() 
            try await syncRecommendationFeedback()
            return
        }
        
        let context = coreDataManager.context
        
        do {
            // Sync recent player profile changes
            let profileRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
            profileRequest.predicate = NSPredicate(format: "updatedAt > %@", lastSync as NSDate)
            
            let recentProfiles = try context.fetch(profileRequest)
            for profile in recentProfiles {
                if let player = profile.player {
                    try await cloudDataService.syncPlayerProfile(player, with: profile)
                }
            }
            
            // Sync recent training sessions
            let sessionRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
            sessionRequest.predicate = NSPredicate(format: "date > %@", lastSync as NSDate)
            
            let recentSessions = try context.fetch(sessionRequest)
            for session in recentSessions {
                try await cloudDataService.syncTrainingSession(session)
            }
            
        } catch {
            throw error
        }
    }
    
    // MARK: - ML Analytics Integration
    
    func trackUserEvent(_ eventType: MLAnalyticsData.MLEventType, 
                       exerciseId: String? = nil,
                       contextData: [String: Any] = [:]) async {
        
        guard Auth.auth().currentUser != nil,
              let playerId = getCurrentPlayerId() else { return }
        
        let analyticsData = MLAnalyticsData(
            sessionId: generateSessionId(),
            playerId: playerId,
            timestamp: Date(),
            eventType: eventType,
            exerciseId: exerciseId,
            userAction: eventType.rawValue,
            contextData: contextData,
            deviceInfo: getDeviceInfo()
        )
        
        do {
            try await cloudDataService.submitMLAnalyticsData(analyticsData)
        } catch {
            print("⚠️ Failed to track user event: \(error)")
        }
    }
    
    func getSimilarPlayerProfiles(for player: Player) async -> [CloudPlayerProfile] {
        guard let profile = player.playerProfile else { return [] }
        
        do {
            return try await cloudDataService.fetchSimilarPlayerProfiles(for: profile, limit: 10)
        } catch {
            print("⚠️ Failed to fetch similar players: \(error)")
            return []
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentPlayerId() -> String? {
        let context = coreDataManager.context
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let players = try context.fetch(request)
            return players.first?.id?.uuidString
        } catch {
            return nil
        }
    }
    
    private func generateSessionId() -> String {
        return UUID().uuidString
    }
    
    private func getDeviceInfo() -> [String: String] {
        return [
            "platform": "iOS",
            "version": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
    }
    
    // MARK: - Enhanced ML Data Collection
    
    func createPlayerProfileForML(from player: Player, profile: PlayerProfile) -> FirestorePlayerProfile? {
        guard let playerId = player.id?.uuidString,
              let firebaseUID = player.firebaseUID else { return nil }
        
        // Calculate skill levels from training history
        let skillLevels = calculateCurrentSkillLevels(for: player)
        
        // Calculate training frequency
        let trainingFrequency = calculateTrainingFrequency(for: player)
        
        // Calculate profile completeness
        let completeness = calculateProfileCompleteness(player: player, profile: profile)
        
        return FirestorePlayerProfile(
            id: playerId,
            firebaseUID: firebaseUID,
            name: player.name ?? "",
            age: Int(player.age),
            position: player.position ?? "",
            experienceLevel: player.experienceLevel ?? "",
            competitiveLevel: player.competitiveLevel ?? "",
            playerRoleModel: player.playerRoleModel,
            skillGoals: profile.skillGoals ?? [],
            physicalFocusAreas: profile.physicalFocusAreas ?? [],
            selfIdentifiedWeaknesses: profile.selfIdentifiedWeaknesses ?? [],
            preferredIntensity: Int(profile.preferredIntensity),
            preferredSessionDuration: Int(profile.preferredSessionDuration),
            preferredDrillComplexity: profile.preferredDrillComplexity ?? "",
            yearsPlaying: Int(profile.yearsPlaying),
            trainingBackground: profile.trainingBackground ?? "",
            createdAt: profile.createdAt ?? Date(),
            updatedAt: Date(),
            isActive: true,
            skillLevels: skillLevels,
            trainingFrequency: trainingFrequency,
            lastActiveDate: Date(),
            profileCompleteness: completeness
        )
    }
    
    private func calculateCurrentSkillLevels(for player: Player) -> [String: Double] {
        // Get the most recent skill ratings from PlayerStats
        guard let stats = player.stats?.allObjects as? [PlayerStats],
              let latestStats = stats.max(by: { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }),
              let skillRatings = latestStats.skillRatings else {
            return [:]
        }
        
        return skillRatings
    }
    
    private func calculateTrainingFrequency(for player: Player) -> Int {
        guard let sessions = player.sessions?.allObjects as? [TrainingSession] else { return 0 }
        
        // Calculate average sessions per week over last 4 weeks
        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let recentSessions = sessions.filter { session in
            guard let date = session.date else { return false }
            return date >= fourWeeksAgo
        }
        
        return recentSessions.count / 4 // average per week
    }
    
    private func calculateProfileCompleteness(player: Player, profile: PlayerProfile) -> Double {
        var completedFields = 0
        let totalFields = 15
        
        // Check player fields
        if !(player.name?.isEmpty ?? true) { completedFields += 1 }
        if player.age > 0 { completedFields += 1 }
        if !(player.position?.isEmpty ?? true) { completedFields += 1 }
        if !(player.experienceLevel?.isEmpty ?? true) { completedFields += 1 }
        if !(player.competitiveLevel?.isEmpty ?? true) { completedFields += 1 }
        if !(player.playerRoleModel?.isEmpty ?? true) { completedFields += 1 }
        
        // Check profile fields
        if !(profile.skillGoals?.isEmpty ?? true) { completedFields += 1 }
        if !(profile.physicalFocusAreas?.isEmpty ?? true) { completedFields += 1 }
        if !(profile.selfIdentifiedWeaknesses?.isEmpty ?? true) { completedFields += 1 }
        if profile.preferredIntensity > 0 { completedFields += 1 }
        if profile.preferredSessionDuration > 0 { completedFields += 1 }
        if !(profile.preferredDrillComplexity?.isEmpty ?? true) { completedFields += 1 }
        if profile.yearsPlaying > 0 { completedFields += 1 }
        if !(profile.trainingBackground?.isEmpty ?? true) { completedFields += 1 }
        if !(player.playerGoals?.allObjects.isEmpty ?? true) { completedFields += 1 }
        
        return Double(completedFields) / Double(totalFields)
    }
}

// MARK: - Notification Extensions

extension CloudSyncManager {
    func setupSyncNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCoreDataChange),
            name: .NSManagedObjectContextDidSave,
            object: coreDataManager.context
        )
    }
    
    @objc private func handleCoreDataChange(_ notification: Notification) {
        // Trigger sync when Core Data changes occur
        Task {
            await performIncrementalSync()
        }
    }
}

// MARK: - Extensions for UI Integration

extension CloudSyncManager {
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