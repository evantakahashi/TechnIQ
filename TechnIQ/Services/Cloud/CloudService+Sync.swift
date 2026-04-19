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

        do {
            try await syncPlayerData()
            try await syncTrainingHistory()
            try await syncPlayerStatsData()
            try await syncMatchData()
            try await syncAvatarData()
            try await syncCustomExercises()
            try await syncTrainingPlans()
            try await syncRecommendationFeedback()

            lastSyncDate = Date()
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

        do {
            try await syncRecentChanges()
            lastSyncDate = Date()
        } catch {
            #if DEBUG
            print("⚠️ Incremental sync failed: \(error)")
            #endif
        }

        isSyncing = false
    }

    // MARK: - Player Data Sync

    private func syncPlayerData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.predicate = NSPredicate(format: "playerProfile != nil")

        let players = try context.fetch(playerRequest)

        for player in players {
            if let profile = player.playerProfile {
                try await syncPlayerProfile(player, with: profile)
            }

            if let goals = player.playerGoals?.allObjects as? [PlayerGoal] {
                try await syncPlayerGoals(goals, for: player)
            }
        }
    }

    private func syncTrainingHistory() async throws {
        let context = coreDataManager.context

        let sessionRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        sessionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]

        let sessions = try context.fetch(sessionRequest)

        for session in sessions {
            try await syncTrainingSession(session)
        }
    }

    private func syncPlayerStatsData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try context.fetch(playerRequest)

        for player in players {
            if let stats = player.stats?.allObjects as? [PlayerStats], !stats.isEmpty {
                try await syncPlayerStats(stats, for: player)
            }
        }
    }

    private func syncMatchData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        let players = try context.fetch(playerRequest)

        for player in players {
            if let seasons = player.seasons?.allObjects as? [Season], !seasons.isEmpty {
                try await syncSeasons(seasons, for: player)
            }
            if let matches = player.matches?.allObjects as? [Match], !matches.isEmpty {
                try await syncMatches(matches, for: player)
            }
        }
    }

    // MARK: - Avatar Sync

    private func syncAvatarData() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()
        playerRequest.predicate = NSPredicate(format: "avatarConfiguration != nil")

        let players = try context.fetch(playerRequest)

        for player in players {
            if let avatar = player.avatarConfiguration {
                try await syncAvatarConfiguration(avatar, for: player)
            }

            if let ownedItems = player.ownedAvatarItems?.allObjects as? [OwnedAvatarItem], !ownedItems.isEmpty {
                try await syncOwnedAvatarItems(ownedItems, for: player)
            }
        }
    }

    // MARK: - Custom Exercises Sync

    private func syncCustomExercises() async throws {
        let context = coreDataManager.context

        let playerRequest: NSFetchRequest<Player> = Player.fetchRequest()

        let players = try context.fetch(playerRequest)

        for player in players {
            if let exercises = player.exercises?.allObjects as? [Exercise], !exercises.isEmpty {
                try await syncCustomExercises(exercises, for: player)
            }
        }
    }

    // MARK: - Training Plans Sync

    private func syncTrainingPlans() async throws {
        let context = coreDataManager.context

        let planRequest: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()

        let plans = try context.fetch(planRequest)

        for plan in plans {
            try await syncTrainingPlan(plan)
        }
    }

    private func syncRecommendationFeedback() async throws {
        let context = coreDataManager.context

        let feedbackRequest: NSFetchRequest<RecommendationFeedback> = RecommendationFeedback.fetchRequest()

        let feedback = try context.fetch(feedbackRequest)
        try await syncRecommendationFeedback(feedback)
    }

    private func syncRecentChanges() async throws {
        guard let lastSync = lastSyncDate else {
            try await syncPlayerData()
            try await syncTrainingHistory()
            try await syncRecommendationFeedback()
            return
        }

        let context = coreDataManager.context

        let profileRequest: NSFetchRequest<PlayerProfile> = PlayerProfile.fetchRequest()
        profileRequest.predicate = NSPredicate(format: "updatedAt > %@", lastSync as NSDate)

        let recentProfiles = try context.fetch(profileRequest)
        for profile in recentProfiles {
            if let player = profile.player {
                try await syncPlayerProfile(player, with: profile)
            }
        }

        let sessionRequest: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        sessionRequest.predicate = NSPredicate(format: "date > %@", lastSync as NSDate)

        let recentSessions = try context.fetch(sessionRequest)
        for session in recentSessions {
            try await syncTrainingSession(session)
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
            print("⚠️ Failed to track user event: \(error)")
            #endif
        }
    }

    func getSimilarPlayerProfiles(for player: Player) async -> [CloudPlayerProfile] {
        guard let profile = player.playerProfile else { return [] }

        do {
            return try await fetchSimilarPlayerProfiles(for: profile, limit: 10)
        } catch {
            #if DEBUG
            print("⚠️ Failed to fetch similar players: \(error)")
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
