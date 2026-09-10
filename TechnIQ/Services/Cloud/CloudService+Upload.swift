import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - CloudService Upload (formerly CloudDataService)

extension CloudService {

    // MARK: - Player Profile Sync

    func syncPlayerProfile(_ player: Player, with profile: PlayerProfile) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        guard let playerDocID = player.id?.uuidString else {
            AppLogger.shared.warning("[CloudService] Skipping player profile sync — player has nil id")
            return
        }

        syncStatus = .syncing

        do {
            // Read the existing cloud doc first and pull up any higher XP/coins/streak so a stale
            // device can't regress values written by a newer one (blind last-writer-wins otherwise).
            let existing = try? await db.collection("users").document(userUID)
                .collection("playerProfiles").document(playerDocID).getDocument()
            if let cloudData = existing?.data() {
                mergeWithConflictResolution(local: player, cloudData: cloudData)
            }

            let playerData = try createPlayerProfileDocument(player: player, profile: profile)

            try await db.collection("users").document(userUID)
                .collection("playerProfiles").document(playerDocID)
                .setData(playerData, merge: true)

            player.lastCloudSync = Date()

            syncStatus = .success
            lastSyncDate = Date()

        } catch {
            syncStatus = .error(error.localizedDescription)
            throw error
        }
    }

    func syncPlayerGoals(_ goals: [PlayerGoal], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(goals) { batch, goal in
            guard let goalDocID = goal.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping goal sync — goal has nil id")
                return
            }
            let goalData = try self.createPlayerGoalDocument(goal: goal)
            let docRef = self.db.collection("users").document(userUID)
                .collection("playerGoals").document(goalDocID)
            batch.setData(goalData, forDocument: docRef, merge: true)
        }
    }

    func syncPlayerStats(_ statsList: [PlayerStats], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(statsList) { batch, stats in
            guard let statsDocID = stats.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping stats sync — stats has nil id")
                return
            }
            let statsData = self.createPlayerStatsDocument(stats: stats)
            let docRef = self.db.collection("users").document(userUID)
                .collection("playerStats").document(statsDocID)
            batch.setData(statsData, forDocument: docRef, merge: true)
        }
    }

    func syncSeasons(_ seasons: [Season], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(seasons) { batch, season in
            guard let seasonDocID = season.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping season sync — season has nil id")
                return
            }
            let seasonData = self.createSeasonDocument(season: season)
            let docRef = self.db.collection("users").document(userUID)
                .collection("seasons").document(seasonDocID)
            batch.setData(seasonData, forDocument: docRef, merge: true)
        }
    }

    func syncMatches(_ matches: [Match], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(matches) { batch, match in
            guard let matchDocID = match.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping match sync — match has nil id")
                return
            }
            let matchData = self.createMatchDocument(match: match)
            let docRef = self.db.collection("users").document(userUID)
                .collection("matches").document(matchDocID)
            batch.setData(matchData, forDocument: docRef, merge: true)
        }
    }

    // MARK: - Training Session Sync

    func syncTrainingSession(_ session: TrainingSession) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        guard let sessionDocID = session.id?.uuidString else {
            AppLogger.shared.warning("[CloudService] Skipping training session sync — session has nil id")
            return
        }

        let sessionData = try createTrainingSessionDocument(session: session)

        try await db.collection("users").document(userUID)
            .collection("trainingSessions").document(sessionDocID)
            .setData(sessionData, merge: true)
    }

    // MARK: - Recommendation Feedback Sync

    func syncRecommendationFeedback(_ feedback: [RecommendationFeedback]) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(feedback) { batch, feedbackItem in
            guard let feedbackDocID = feedbackItem.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping feedback sync — feedback has nil id")
                return
            }
            let feedbackData = try self.createRecommendationFeedbackDocument(feedback: feedbackItem)
            let docRef = self.db.collection("users").document(userUID)
                .collection("recommendationFeedback").document(feedbackDocID)
            batch.setData(feedbackData, forDocument: docRef, merge: true)
        }
    }

    // MARK: - Avatar Configuration Sync

    func syncAvatarConfiguration(_ avatar: AvatarConfiguration, for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        let avatarData = createAvatarConfigurationDocument(avatar: avatar)

        try await db.collection("users").document(userUID)
            .collection("avatarConfiguration").document(player.id?.uuidString ?? "default")
            .setData(avatarData, merge: true)
    }

    func syncOwnedAvatarItems(_ items: [OwnedAvatarItem], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(items) { batch, item in
            guard let itemDocID = item.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping owned avatar item sync — item has nil id")
                return
            }
            let itemData = self.createOwnedAvatarItemDocument(item: item)
            let docRef = self.db.collection("users").document(userUID)
                .collection("ownedAvatarItems").document(itemDocID)
            batch.setData(itemData, forDocument: docRef, merge: true)
        }
    }

    // MARK: - Custom Exercises Sync

    func syncCustomExercises(_ exercises: [Exercise], for player: Player) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        try await commitInChunks(exercises) { batch, exercise in
            guard let exerciseDocID = exercise.id?.uuidString else {
                AppLogger.shared.warning("[CloudService] Skipping custom exercise sync — exercise has nil id")
                return
            }
            let exerciseData = self.createCustomExerciseDocument(exercise: exercise)
            let docRef = self.db.collection("users").document(userUID)
                .collection("customExercises").document(exerciseDocID)
            batch.setData(exerciseData, forDocument: docRef, merge: true)
        }
    }

    // MARK: - Training Plans Sync

    func syncTrainingPlan(_ plan: TrainingPlan) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        guard let planDocID = plan.id?.uuidString else {
            AppLogger.shared.warning("[CloudService] Skipping training plan sync — plan has nil id")
            return
        }

        let planData = createTrainingPlanDocument(plan: plan)

        try await db.collection("users").document(userUID)
            .collection("trainingPlans").document(planDocID)
            .setData(planData, merge: true)
    }

    // MARK: - Data Retrieval

    func fetchPlayerProfile(for playerID: String) async throws -> [String: Any]? {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        let document = try await db.collection("users").document(userUID)
            .collection("playerProfiles").document(playerID).getDocument()

        return document.data()
    }

    func fetchAllUserData() async throws -> CloudUserData {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        let userRef = db.collection("users").document(userUID)

        async let profilesSnapshot = userRef.collection("playerProfiles").getDocuments()
        async let goalsSnapshot = userRef.collection("playerGoals").getDocuments()
        async let sessionsSnapshot = userRef.collection("trainingSessions").getDocuments()
        async let feedbackSnapshot = userRef.collection("recommendationFeedback").getDocuments()
        async let avatarSnapshot = userRef.collection("avatarConfiguration").getDocuments()
        async let ownedItemsSnapshot = userRef.collection("ownedAvatarItems").getDocuments()
        async let customExercisesSnapshot = userRef.collection("customExercises").getDocuments()
        async let trainingPlansSnapshot = userRef.collection("trainingPlans").getDocuments()
        async let statsSnapshot = userRef.collection("playerStats").getDocuments()
        async let seasonsSnapshot = userRef.collection("seasons").getDocuments()
        async let matchesSnapshot = userRef.collection("matches").getDocuments()
        async let deletedItemsSnapshot = userRef.collection("deletedItems").getDocuments()

        let (profiles, goals, sessions, feedback, avatar, ownedItems, exercises, plans, stats, seasons, matches, deletedItems) = try await (
            profilesSnapshot, goalsSnapshot, sessionsSnapshot, feedbackSnapshot,
            avatarSnapshot, ownedItemsSnapshot, customExercisesSnapshot, trainingPlansSnapshot,
            statsSnapshot, seasonsSnapshot, matchesSnapshot, deletedItemsSnapshot
        )

        // Locally-deleted items are tombstoned by document id; drop them so restore never resurrects them.
        let deletedIds = Set(deletedItems.documents.map { $0.documentID })
        func live(_ documents: [QueryDocumentSnapshot]) -> [[String: Any]] {
            documents.filter { !deletedIds.contains($0.documentID) }.map { $0.data() }
        }

        return CloudUserData(
            playerProfiles: live(profiles.documents),
            playerGoals: live(goals.documents),
            trainingSessions: live(sessions.documents),
            recommendationFeedback: live(feedback.documents),
            avatarConfiguration: avatar.documents.first(where: { !deletedIds.contains($0.documentID) })?.data(),
            ownedAvatarItems: live(ownedItems.documents),
            customExercises: live(exercises.documents),
            trainingPlans: live(plans.documents),
            playerStats: live(stats.documents),
            seasons: live(seasons.documents),
            matches: live(matches.documents)
        )
    }

    /// Pure decision: does this cloud profile document represent a user who actually finished onboarding,
    /// or is it a partial upload that should NOT trigger a restore?
    /// We consider a profile "meaningful" only if both `position` and `experienceLevel` are set —
    /// both are mandatory fields in the onboarding flow, so a doc missing either was written by a
    /// crash or abandoned session.
    func hasMeaningfulCloudProfile(_ doc: [String: Any]) -> Bool {
        let position = (doc["position"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let experienceLevel = (doc["experienceLevel"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        return !position.isEmpty && !experienceLevel.isEmpty
    }

    /// Check if a restorable cloud profile exists for the current user.
    func hasCloudData() async throws -> Bool {
        guard let userUID = auth.currentUser?.uid else {
            return false
        }

        guard isNetworkAvailable else {
            return false
        }

        let snapshot = try await db.collection("users").document(userUID)
            .collection("playerProfiles").limit(to: 1).getDocuments()

        guard let doc = snapshot.documents.first?.data() else {
            return false
        }

        return hasMeaningfulCloudProfile(doc)
    }

    // MARK: - Analytics and ML Data Collection

    func submitMLAnalyticsData(_ data: MLAnalyticsData) async throws {
        let analyticsData = try createMLAnalyticsDocument(data: data)

        try await db.collection("mlAnalytics").document(data.sessionId).setData(analyticsData, merge: true)
    }

    func fetchSimilarPlayerProfiles(for playerProfile: PlayerProfile, limit: Int = 10) async throws -> [CloudPlayerProfile] {
        // arrayContainsAny throws NSInvalidArgumentException on an empty array (uncatchable in Swift).
        guard let skillGoals = playerProfile.skillGoals, !skillGoals.isEmpty else {
            return []
        }

        let skillGoalsQuery = db.collection("aggregatedProfiles")
            .whereField("skillGoals", arrayContainsAny: skillGoals)
            .limit(to: limit)

        let snapshot = try await skillGoalsQuery.getDocuments()
        return snapshot.documents.compactMap { document in
            try? createCloudPlayerProfile(from: document.data())
        }
    }

    // MARK: - Offline Queue Management

    func syncOfflineChanges() async throws {
        syncStatus = .syncing
        syncStatus = .success
        lastSyncDate = Date()
    }

    // MARK: - Deletion Propagation

    /// Removes a synced entity's cloud document and writes a tombstone under `deletedItems` so a
    /// restore on another device will not resurrect it. Fire-and-forget: failures are logged, not thrown.
    func propagateDeletion(collection: String, docId: String) async {
        guard let userUID = auth.currentUser?.uid, !docId.isEmpty else { return }
        let userRef = db.collection("users").document(userUID)
        do {
            try await userRef.collection(collection).document(docId).delete()
            try await userRef.collection("deletedItems").document(docId).setData([
                "collection": collection,
                "deletedAt": FieldValue.serverTimestamp()
            ], merge: true)
        } catch {
            AppLogger.shared.error("[CloudService] Failed to propagate deletion of \(collection)/\(docId): \(error.localizedDescription)")
        }
    }

    // MARK: - Community Training Plans

    func shareTrainingPlan(_ plan: TrainingPlanModel, message: String) async throws {
        guard let userUID = auth.currentUser?.uid else {
            throw CloudDataError.notAuthenticated
        }

        guard isNetworkAvailable else {
            throw CloudDataError.networkError
        }

        let planData = try createSharedPlanDocument(plan: plan, message: message, userUID: userUID)

        try await db.collection("communityPlans").document(plan.id.uuidString)
            .setData(planData, merge: false)

        #if DEBUG
        print("Successfully shared plan '\(plan.name)' to community")
        #endif
    }
}

// MARK: - Document Creation Helpers

extension CloudService {
    func createPlayerProfileDocument(player: Player, profile: PlayerProfile) throws -> [String: Any] {
        return [
            "playerId": player.id?.uuidString ?? "",
            "firebaseUID": player.firebaseUID ?? "",
            "name": player.name ?? "",
            "age": player.age,
            "position": player.position ?? "",
            "experienceLevel": player.experienceLevel ?? "",
            "competitiveLevel": player.competitiveLevel ?? "",
            "kitNumber": Int(player.kitNumber),
            "playerRoleModel": player.playerRoleModel ?? "",
            "playingStyle": player.playingStyle ?? "",
            "dominantFoot": player.dominantFoot ?? "",
            "height": player.height,
            "weight": player.weight,
            "weaknessProfileJSON": player.weaknessProfileJSON ?? "",
            "skillGoals": profile.skillGoals ?? [],
            "physicalFocusAreas": profile.physicalFocusAreas ?? [],
            "selfIdentifiedWeaknesses": profile.selfIdentifiedWeaknesses ?? [],
            "preferredIntensity": profile.preferredIntensity,
            "preferredSessionDuration": profile.preferredSessionDuration,
            "preferredDrillComplexity": profile.preferredDrillComplexity ?? "",
            "yearsPlaying": profile.yearsPlaying,
            "trainingBackground": profile.trainingBackground ?? "",
            "totalXP": player.totalXP,
            "currentLevel": player.currentLevel,
            "currentStreak": player.currentStreak,
            "longestStreak": player.longestStreak,
            "coins": player.coins,
            "totalCoinsEarned": player.totalCoinsEarned,
            "streakFreezes": player.streakFreezes,
            "unlockedAchievements": player.unlockedAchievements ?? [],
            "lastTrainingDate": player.lastTrainingDate as Any,
            "createdAt": profile.createdAt ?? Date(),
            "updatedAt": Date()
        ]
    }

    private func createPlayerGoalDocument(goal: PlayerGoal) throws -> [String: Any] {
        return [
            "goalId": goal.id?.uuidString ?? "",
            "playerId": goal.player?.id?.uuidString ?? "",
            "skillName": goal.skillName ?? "",
            "currentLevel": goal.currentLevel,
            "targetLevel": goal.targetLevel,
            "targetDate": goal.targetDate ?? NSNull(),
            "priority": goal.priority ?? "",
            "status": goal.status ?? "",
            "progressNotes": goal.progressNotes ?? "",
            "createdAt": goal.createdAt ?? Date(),
            "updatedAt": Date()
        ] as [String: Any]
    }

    func createTrainingSessionDocument(session: TrainingSession) throws -> [String: Any] {
        var exercisesData: [[String: Any]] = []
        if let exercises = session.exercises as? Set<SessionExercise> {
            exercisesData = exercises.map { exercise in
                [
                    "exerciseId": exercise.exercise?.id?.uuidString ?? "",
                    "exerciseName": exercise.exercise?.name ?? "",
                    "duration": exercise.duration,
                    "sets": exercise.sets,
                    "reps": exercise.reps,
                    "performanceRating": exercise.performanceRating,
                    "notes": exercise.notes ?? ""
                ]
            }
        }

        return [
            "sessionId": session.id?.uuidString ?? "",
            "playerId": session.player?.id?.uuidString ?? "",
            "date": session.date ?? Date(),
            "duration": session.duration,
            "sessionType": session.sessionType ?? "",
            "intensity": session.intensity,
            "location": session.location ?? "",
            "overallRating": session.overallRating,
            "xpEarned": session.xpEarned,
            "notes": session.notes ?? "",
            "updatedAt": session.updatedAt ?? Date(),
            "exercises": exercisesData
        ]
    }

    private func createRecommendationFeedbackDocument(feedback: RecommendationFeedback) throws -> [String: Any] {
        return [
            "feedbackId": feedback.id?.uuidString ?? "",
            "playerId": feedback.player?.id?.uuidString ?? "",
            "exerciseID": feedback.exerciseID ?? "",
            "recommendationSource": feedback.recommendationSource ?? "",
            "feedbackType": feedback.feedbackType ?? "",
            "rating": feedback.rating,
            "wasCompleted": feedback.wasCompleted,
            "timeSpent": feedback.timeSpent,
            "difficultyRating": feedback.difficultyRating,
            "relevanceRating": feedback.relevanceRating,
            "notes": feedback.notes ?? "",
            "createdAt": feedback.createdAt ?? Date()
        ]
    }

    private func createMLAnalyticsDocument(data: MLAnalyticsData) throws -> [String: Any] {
        return [
            "sessionId": data.sessionId,
            "playerId": data.playerId,
            "timestamp": data.timestamp,
            "eventType": data.eventType.rawValue,
            "exerciseId": data.exerciseId as Any,
            "userAction": data.userAction,
            "contextData": data.contextData,
            "deviceInfo": data.deviceInfo
        ]
    }

    private func createAvatarConfigurationDocument(avatar: AvatarConfiguration) -> [String: Any] {
        return [
            "id": avatar.id?.uuidString ?? "",
            "skinTone": avatar.skinTone ?? "",
            "hairStyle": avatar.hairStyle ?? "",
            "hairColor": avatar.hairColor ?? "",
            "faceStyle": avatar.faceStyle ?? "",
            "jerseyId": avatar.jerseyId ?? "",
            "shortsId": avatar.shortsId ?? "",
            "socksId": avatar.socksId ?? "",
            "cleatsId": avatar.cleatsId ?? "",
            "accessoryIds": (avatar.accessoryIds as? [String]) ?? [],
            "lastModified": avatar.lastModified ?? Date()
        ]
    }

    private func createOwnedAvatarItemDocument(item: OwnedAvatarItem) -> [String: Any] {
        return [
            "id": item.id?.uuidString ?? "",
            "itemId": item.itemId ?? "",
            "purchasedAt": item.purchasedAt ?? Date(),
            "equippedSlot": item.equippedSlot ?? ""
        ]
    }

    func createPlayerStatsDocument(stats: PlayerStats) -> [String: Any] {
        return [
            "id": stats.id?.uuidString ?? "",
            "playerId": stats.player?.id?.uuidString ?? "",
            "date": stats.date ?? Date(),
            "skillRatings": stats.skillRatings ?? [:],
            "totalTrainingHours": stats.totalTrainingHours,
            "totalSessions": stats.totalSessions,
            "updatedAt": stats.updatedAt ?? Date()
        ]
    }

    func createSeasonDocument(season: Season) -> [String: Any] {
        return [
            "id": season.id?.uuidString ?? "",
            "playerId": season.player?.id?.uuidString ?? "",
            "name": season.name ?? "",
            "team": season.team ?? "",
            "startDate": season.startDate ?? Date(),
            "endDate": season.endDate as Any,
            "isActive": season.isActive,
            "createdAt": season.createdAt ?? Date(),
            "updatedAt": season.updatedAt ?? Date()
        ]
    }

    func createMatchDocument(match: Match) -> [String: Any] {
        return [
            "id": match.id?.uuidString ?? "",
            "playerId": match.player?.id?.uuidString ?? "",
            "date": match.date ?? Date(),
            "opponent": match.opponent ?? "",
            "competition": match.competition ?? "",
            "minutesPlayed": match.minutesPlayed,
            "goals": match.goals,
            "assists": match.assists,
            "positionPlayed": match.positionPlayed ?? "",
            "isHomeGame": match.isHomeGame,
            "result": match.result ?? "",
            "notes": match.notes ?? "",
            "rating": match.rating,
            "xpEarned": match.xpEarned,
            "strengths": match.strengths ?? "",
            "weaknesses": match.weaknesses ?? "",
            "createdAt": match.createdAt ?? Date(),
            "updatedAt": match.updatedAt ?? Date(),
            "seasonID": match.season?.id?.uuidString ?? ""
        ]
    }

    func createCustomExerciseDocument(exercise: Exercise) -> [String: Any] {
        return [
            "id": exercise.id?.uuidString ?? "",
            "playerId": exercise.player?.id?.uuidString ?? "",
            "name": exercise.name ?? "",
            "category": exercise.category ?? "",
            "difficulty": exercise.difficulty,
            "exerciseDescription": exercise.exerciseDescription ?? "",
            "instructions": exercise.instructions ?? "",
            "targetSkills": exercise.targetSkills ?? [],
            "isYouTubeContent": exercise.isYouTubeContent,
            "youtubeVideoID": exercise.youtubeVideoID ?? "",
            "videoThumbnailURL": exercise.videoThumbnailURL ?? "",
            "videoDuration": exercise.videoDuration,
            "videoDescription": exercise.videoDescription ?? "",
            "isFavorite": exercise.isFavorite,
            "lastUsedAt": exercise.lastUsedAt as Any,
            "personalNotes": exercise.personalNotes ?? "",
            "diagramJSON": exercise.diagramJSON ?? "",
            "metabolicLoad": exercise.metabolicLoad,
            "technicalComplexity": exercise.technicalComplexity,
            "estimatedDurationSeconds": exercise.estimatedDurationSeconds,
            "variationsJSON": exercise.variationsJSON ?? "",
            "weaknessCategories": exercise.weaknessCategories ?? "",
            "communityAuthor": exercise.communityAuthor ?? "",
            "communityDrillID": exercise.communityDrillID ?? "",
            "updatedAt": exercise.updatedAt ?? Date()
        ]
    }

    func createTrainingPlanDocument(plan: TrainingPlan) -> [String: Any] {
        var weeksData: [[String: Any]] = []
        if let weeks = plan.weeks as? Set<PlanWeek> {
            weeksData = weeks.sorted { $0.weekNumber < $1.weekNumber }.map { week in
                var daysData: [[String: Any]] = []
                if let days = week.days as? Set<PlanDay> {
                    daysData = days.sorted { $0.dayNumber < $1.dayNumber }.map { day in
                        var sessionsData: [[String: Any]] = []
                        if let sessions = day.sessions as? Set<PlanSession> {
                            sessionsData = sessions.map { session in
                                let exerciseIDs = (session.exercises as? Set<Exercise>)?.compactMap { $0.id?.uuidString } ?? []
                                return [
                                    "id": session.id?.uuidString ?? "",
                                    "sessionType": session.sessionType ?? "",
                                    "duration": session.duration,
                                    "intensity": session.intensity,
                                    "notes": session.notes ?? "",
                                    "isCompleted": session.isCompleted,
                                    "completedAt": session.completedAt as Any,
                                    "orderIndex": session.orderIndex,
                                    "actualDuration": session.actualDuration,
                                    "actualIntensity": session.actualIntensity,
                                    "exerciseIDs": exerciseIDs
                                ] as [String: Any]
                            }
                        }
                        return [
                            "id": day.id?.uuidString ?? "",
                            "dayNumber": day.dayNumber,
                            "dayOfWeek": day.dayOfWeek ?? "",
                            "isRestDay": day.isRestDay,
                            "isSkipped": day.isSkipped,
                            "notes": day.notes ?? "",
                            "isCompleted": day.isCompleted,
                            "completedAt": day.completedAt as Any,
                            "sessions": sessionsData
                        ] as [String: Any]
                    }
                }
                return [
                    "id": week.id?.uuidString ?? "",
                    "weekNumber": week.weekNumber,
                    "focusArea": week.focusArea ?? "",
                    "notes": week.notes ?? "",
                    "isCompleted": week.isCompleted,
                    "completedAt": week.completedAt as Any,
                    "days": daysData
                ] as [String: Any]
            }
        }

        return [
            "id": plan.id?.uuidString ?? "",
            "playerId": plan.player?.id?.uuidString ?? "",
            "name": plan.name ?? "",
            "planDescription": plan.planDescription ?? "",
            "durationWeeks": plan.durationWeeks,
            "difficulty": plan.difficulty ?? "",
            "category": plan.category ?? "",
            "targetRole": plan.targetRole ?? "",
            "isPrebuilt": plan.isPrebuilt,
            "isActive": plan.isActive,
            "currentWeek": plan.currentWeek,
            "progressPercentage": plan.progressPercentage,
            "startedAt": plan.startedAt as Any,
            "completedAt": plan.completedAt as Any,
            "createdAt": plan.createdAt ?? Date(),
            "updatedAt": plan.updatedAt ?? Date(),
            "weeks": weeksData
        ] as [String: Any]
    }

    private func createCloudPlayerProfile(from data: [String: Any]) throws -> CloudPlayerProfile {
        return CloudPlayerProfile(
            playerId: data["playerId"] as? String ?? "",
            skillGoals: data["skillGoals"] as? [String] ?? [],
            experienceLevel: data["experienceLevel"] as? String ?? "",
            competitiveLevel: data["competitiveLevel"] as? String ?? "",
            position: data["position"] as? String ?? "",
            preferredIntensity: data["preferredIntensity"] as? Int ?? 5,
            physicalFocusAreas: data["physicalFocusAreas"] as? [String] ?? []
        )
    }

    private func createSharedPlanDocument(plan: TrainingPlanModel, message: String, userUID: String) throws -> [String: Any] {
        let weeksData = plan.weeks.map { week -> [String: Any] in
            let daysData = week.days.map { day -> [String: Any] in
                let sessionsData = day.sessions.map { session -> [String: Any] in
                    return [
                        "sessionType": session.sessionType.rawValue,
                        "duration": session.duration,
                        "intensity": session.intensity,
                        "notes": session.notes ?? "",
                        "exerciseIDs": session.exerciseIDs.map { $0.uuidString }
                    ]
                }

                return [
                    "dayNumber": day.dayNumber,
                    "dayOfWeek": day.dayOfWeek?.rawValue ?? "",
                    "isRestDay": day.isRestDay,
                    "notes": day.notes ?? "",
                    "sessions": sessionsData
                ]
            }

            return [
                "weekNumber": week.weekNumber,
                "focusArea": week.focusArea ?? "",
                "notes": week.notes ?? "",
                "days": daysData
            ]
        }

        return [
            "id": plan.id.uuidString,
            "name": plan.name,
            "description": plan.description,
            "durationWeeks": plan.durationWeeks,
            "difficulty": plan.difficulty.rawValue,
            "category": plan.category.rawValue,
            "targetRole": plan.targetRole ?? "",
            "estimatedTotalHours": plan.estimatedTotalHours,
            "weeks": weeksData,
            "contributorUID": userUID,
            "contributorMessage": message,
            "sharedAt": Date(),
            "upvotes": 0,
            "downloads": 0
        ] as [String: Any]
    }
}
