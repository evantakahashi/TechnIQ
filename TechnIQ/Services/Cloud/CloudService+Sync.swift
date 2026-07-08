import Foundation
import CoreData
import FirebaseAuth
import FirebaseFirestore
import UIKit

// MARK: - CloudService Sync (formerly CloudSyncManager)

extension CloudService {

    // MARK: - Manual Sync Operations

    func performFullSync() async {
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil
        let syncStart = Date()

        do {
            try await pushAllScoped()

            lastSyncDate = syncStart
            #if DEBUG
            print("Full cloud sync completed successfully")
            #endif
        } catch {
            syncError = error.localizedDescription
            #if DEBUG
            print("Full sync failed: \(error)")
            #endif
        }

        isSyncing = false
    }

    func performIncrementalSync() async {
        guard !isSyncing else { return }
        guard Auth.auth().currentUser != nil else { return }

        if let lastRequest = lastSyncRequest,
           Date().timeIntervalSince(lastRequest) < minSyncInterval {
            #if DEBUG
            print("⏰ Sync request throttled - too soon since last sync")
            #endif
            return
        }

        lastSyncRequest = Date()
        isSyncing = true
        let syncStart = Date()

        do {
            try await syncRecentChanges()
            // Advance the watermark to when the sync started so edits made mid-sync are caught next cycle.
            lastSyncDate = syncStart
            syncError = nil
        } catch {
            syncError = error.localizedDescription
            #if DEBUG
            print("Incremental sync failed: \(error)")
            #endif
        }

        isSyncing = false
    }

    // MARK: - Account Scoping

    /// The single Player owned by the currently-authenticated user. Every sync fetch scopes to this
    /// player so a different account's local rows never upload under this uid (cross-account leak).
    func currentSyncPlayer(in context: NSManagedObjectContext) -> Player? {
        guard let uid = auth.currentUser?.uid, !uid.isEmpty else { return nil }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", uid)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Pushes every synced collection for the current account's player. Used by the full sync and by
    /// the first incremental sync of a launch (when there is no watermark yet).
    private func pushAllScoped() async throws {
        try await syncPlayerData()
        try await syncTrainingHistory()
        try await syncPlayerStatsData()
        try await syncMatchData()
        try await syncAvatarData()
        try await syncCustomExercises()
        try await syncTrainingPlans()
        try await syncRecommendationFeedback()
    }

    // MARK: - Player Data Sync

    private func syncPlayerData() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }

        if let profile = player.playerProfile {
            try await syncPlayerProfile(player, with: profile)
        }
        if let goals = player.playerGoals?.allObjects as? [PlayerGoal], !goals.isEmpty {
            try await syncPlayerGoals(goals, for: player)
        }
    }

    private func syncTrainingHistory() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        let sessions = (player.sessions?.allObjects as? [TrainingSession]) ?? []
        for session in sessions {
            try await syncTrainingSession(session)
        }
    }

    private func syncPlayerStatsData() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        if let stats = player.stats?.allObjects as? [PlayerStats], !stats.isEmpty {
            try await syncPlayerStats(stats, for: player)
        }
    }

    private func syncMatchData() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        if let seasons = player.seasons?.allObjects as? [Season], !seasons.isEmpty {
            try await syncSeasons(seasons, for: player)
        }
        if let matches = player.matches?.allObjects as? [Match], !matches.isEmpty {
            try await syncMatches(matches, for: player)
        }
    }

    // MARK: - Avatar Sync

    private func syncAvatarData() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        if let avatar = player.avatarConfiguration {
            try await syncAvatarConfiguration(avatar, for: player)
        }
        if let ownedItems = player.ownedAvatarItems?.allObjects as? [OwnedAvatarItem], !ownedItems.isEmpty {
            try await syncOwnedAvatarItems(ownedItems, for: player)
        }
    }

    // MARK: - Custom Exercises Sync

    private func syncCustomExercises() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        if let exercises = player.exercises?.allObjects as? [Exercise], !exercises.isEmpty {
            try await syncCustomExercises(exercises, for: player)
        }
    }

    // MARK: - Training Plans Sync

    private func syncTrainingPlans() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        let plans = (player.trainingPlans?.allObjects as? [TrainingPlan]) ?? []
        for plan in plans {
            try await syncTrainingPlan(plan)
        }
    }

    private func syncRecommendationFeedback() async throws {
        guard let player = currentSyncPlayer(in: coreDataManager.context) else { return }
        if let feedback = player.recommendationFeedback?.allObjects as? [RecommendationFeedback], !feedback.isEmpty {
            try await syncRecommendationFeedback(feedback)
        }
    }

    /// Incremental sync: uploads only this account's rows whose `updatedAt` is newer than the last
    /// successful sync. Covers every synced collection (previously only profile + sessions), which is
    /// why matches/plans/drills/avatar/stats/goals no longer stop syncing after onboarding.
    private func syncRecentChanges() async throws {
        let context = coreDataManager.context
        guard let player = currentSyncPlayer(in: context) else { return }

        // No watermark yet this launch: push everything once (scoped); later cycles filter by updatedAt.
        guard let lastSync = lastSyncDate else {
            try await pushAllScoped()
            return
        }

        if let profile = player.playerProfile,
           (profile.updatedAt ?? .distantPast) > lastSync {
            try await syncPlayerProfile(player, with: profile)
        }

        let goals = (player.playerGoals?.allObjects as? [PlayerGoal])?
            .filter { ($0.updatedAt ?? .distantPast) > lastSync } ?? []
        if !goals.isEmpty { try await syncPlayerGoals(goals, for: player) }

        // updatedAt falls back to date/createdAt for rows saved before the field existed.
        let sessions = (player.sessions?.allObjects as? [TrainingSession])?
            .filter { ($0.updatedAt ?? $0.date ?? .distantPast) > lastSync } ?? []
        for session in sessions { try await syncTrainingSession(session) }

        let stats = (player.stats?.allObjects as? [PlayerStats])?
            .filter { ($0.updatedAt ?? $0.date ?? .distantPast) > lastSync } ?? []
        if !stats.isEmpty { try await syncPlayerStats(stats, for: player) }

        let seasons = (player.seasons?.allObjects as? [Season])?
            .filter { ($0.updatedAt ?? $0.createdAt ?? .distantPast) > lastSync } ?? []
        if !seasons.isEmpty { try await syncSeasons(seasons, for: player) }

        let matches = (player.matches?.allObjects as? [Match])?
            .filter { ($0.updatedAt ?? $0.createdAt ?? .distantPast) > lastSync } ?? []
        if !matches.isEmpty { try await syncMatches(matches, for: player) }

        let exercises = (player.exercises?.allObjects as? [Exercise])?
            .filter { ($0.updatedAt ?? .distantPast) > lastSync } ?? []
        if !exercises.isEmpty { try await syncCustomExercises(exercises, for: player) }

        let plans = (player.trainingPlans?.allObjects as? [TrainingPlan])?
            .filter { ($0.updatedAt ?? .distantPast) > lastSync } ?? []
        for plan in plans { try await syncTrainingPlan(plan) }

        if let avatar = player.avatarConfiguration,
           (avatar.updatedAt ?? avatar.lastModified ?? .distantPast) > lastSync {
            try await syncAvatarConfiguration(avatar, for: player)
        }
    }

    // MARK: - ML Analytics Integration

    func trackUserEvent(
        _ eventType: MLAnalyticsData.MLEventType,
        exerciseId: String? = nil,
        contextData: [String: Any] = [:]
    ) async {

        guard Auth.auth().currentUser != nil,
              let playerId = getCurrentPlayerId() else { return }

        let analyticsData = MLAnalyticsData(
            sessionId: UUID().uuidString,
            playerId: playerId,
            timestamp: Date(),
            eventType: eventType,
            exerciseId: exerciseId,
            userAction: eventType.rawValue,
            contextData: contextData,
            deviceInfo: getDeviceInfo()
        )

        do {
            try await submitMLAnalyticsData(analyticsData)
        } catch {
            #if DEBUG
            print("Failed to track user event: \(error)")
            #endif
        }
    }

    func getSimilarPlayerProfiles(for player: Player) async -> [CloudPlayerProfile] {
        guard let profile = player.playerProfile else { return [] }

        do {
            return try await fetchSimilarPlayerProfiles(for: profile, limit: 10)
        } catch {
            #if DEBUG
            print("Failed to fetch similar players: \(error)")
            #endif
            return []
        }
    }

    // MARK: - Enhanced ML Data Collection

    func createPlayerProfileForML(from player: Player, profile: PlayerProfile) -> FirestorePlayerProfile? {
        guard let playerId = player.id?.uuidString,
              let firebaseUID = player.firebaseUID else { return nil }

        let skillLevels = calculateCurrentSkillLevels(for: player)
        let trainingFrequency = calculateTrainingFrequency(for: player)
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
        guard let stats = player.stats?.allObjects as? [PlayerStats],
              let latestStats = stats.max(by: { $0.date ?? Date.distantPast < $1.date ?? Date.distantPast }),
              let skillRatings = latestStats.skillRatings else {
            return [:]
        }

        return skillRatings
    }

    private func calculateTrainingFrequency(for player: Player) -> Int {
        guard let sessions = player.sessions?.allObjects as? [TrainingSession] else { return 0 }

        let fourWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -4, to: Date()) ?? Date()
        let recentSessions = sessions.filter { session in
            guard let date = session.date else { return false }
            return date >= fourWeeksAgo
        }

        return recentSessions.count / 4
    }

    private func calculateProfileCompleteness(player: Player, profile: PlayerProfile) -> Double {
        var completedFields = 0
        let totalFields = 15

        if !(player.name?.isEmpty ?? true) { completedFields += 1 }
        if player.age > 0 { completedFields += 1 }
        if !(player.position?.isEmpty ?? true) { completedFields += 1 }
        if !(player.experienceLevel?.isEmpty ?? true) { completedFields += 1 }
        if !(player.competitiveLevel?.isEmpty ?? true) { completedFields += 1 }
        if !(player.playerRoleModel?.isEmpty ?? true) { completedFields += 1 }

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

    // MARK: - Helpers

    func getCurrentPlayerId() -> String? {
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

    private func getDeviceInfo() -> [String: String] {
        return [
            "platform": "iOS",
            "version": UIDevice.current.systemVersion,
            "model": UIDevice.current.model,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
    }
}

// MARK: - Notification Observers

extension CloudService {
    func setupSyncNotifications() {
        Task { [weak self] in
            let notifications = NotificationCenter.default.notifications(named: .NSManagedObjectContextDidSave)
            for await _ in notifications {
                await self?.performIncrementalSync()
            }
        }
    }
}
