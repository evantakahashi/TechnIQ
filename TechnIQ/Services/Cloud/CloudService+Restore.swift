import Foundation
import CoreData
import FirebaseAuth
import FirebaseFirestore

// MARK: - CloudService Restore (formerly CloudRestoreService)

extension CloudService {

    // MARK: - Public Interface

    /// Check if cloud data exists for the current authenticated user
    func hasCloudDataForRestore() async -> Bool {
        do {
            return try await hasCloudData()
        } catch {
            #if DEBUG
            print("CloudService: Error checking cloud data - \(error)")
            #endif
            return false
        }
    }

    /// Restore all user data from cloud into Core Data
    func restoreFromCloud() async throws -> Player? {
        let context = CoreDataManager.shared.context
        guard Auth.auth().currentUser != nil else {
            throw CloudRestoreError.notAuthenticated
        }

        isRestoring = true
        restoreProgress = 0.0
        restoreError = nil

        defer {
            isRestoring = false
        }

        do {
            #if DEBUG
            print("CloudService: Starting cloud restore...")
            #endif

            restoreProgress = 0.1
            let cloudData = try await fetchAllUserData()

            guard let profileData = cloudData.playerProfiles.first else {
                throw CloudRestoreError.noDataFound
            }

            restoreProgress = 0.2
            let player = try createPlayer(from: profileData, in: context)

            restoreProgress = 0.3
            try restorePlayerProfile(from: profileData, for: player, in: context)

            restoreProgress = 0.4
            restoreGamificationData(from: profileData, to: player)

            restoreProgress = 0.5
            if let avatarData = cloudData.avatarConfiguration {
                try restoreAvatarConfiguration(from: avatarData, for: player, in: context)
            }

            restoreProgress = 0.55
            for itemData in cloudData.ownedAvatarItems {
                try restoreOwnedAvatarItem(from: itemData, for: player, in: context)
            }

            restoreProgress = 0.6
            for goalData in cloudData.playerGoals {
                try restorePlayerGoal(from: goalData, for: player, in: context)
            }

            restoreProgress = 0.7
            for exerciseData in cloudData.customExercises {
                try restoreCustomExercise(from: exerciseData, for: player, in: context)
            }

            restoreProgress = 0.75
            for statsData in cloudData.playerStats {
                try restorePlayerStats(from: statsData, for: player, in: context)
            }

            restoreProgress = 0.77
            for seasonData in cloudData.seasons {
                try restoreSeason(from: seasonData, for: player, in: context)
            }
            for matchData in cloudData.matches {
                try restoreMatch(from: matchData, for: player, in: context)
            }

            restoreProgress = 0.8
            for sessionData in cloudData.trainingSessions {
                try restoreTrainingSession(from: sessionData, for: player, in: context)
            }

            restoreProgress = 0.9
            for planData in cloudData.trainingPlans {
                try restoreTrainingPlan(from: planData, for: player, in: context)
            }

            restoreProgress = 1.0
            try context.save()

            #if DEBUG
            print("CloudService: Restore completed successfully")
            #endif

            return player

        } catch {
            restoreError = error.localizedDescription
            #if DEBUG
            print("CloudService: Restore failed - \(error)")
            #endif
            throw error
        }
    }

    // MARK: - Entity Creation Helpers

    private func createPlayer(from data: [String: Any], in context: NSManagedObjectContext) throws -> Player {
        let player = Player(context: context)
        player.id = UUID(uuidString: data["playerId"] as? String ?? "") ?? UUID()
        player.firebaseUID = data["firebaseUID"] as? String ?? Auth.auth().currentUser?.uid
        player.name = data["name"] as? String
        player.age = Int16(data["age"] as? Int ?? 0)
        player.position = data["position"] as? String
        player.experienceLevel = data["experienceLevel"] as? String
        player.competitiveLevel = data["competitiveLevel"] as? String
        player.playerRoleModel = data["playerRoleModel"] as? String
        player.playingStyle = data["playingStyle"] as? String
        player.dominantFoot = data["dominantFoot"] as? String
        player.height = data["height"] as? Double ?? 0
        player.weight = data["weight"] as? Double ?? 0
        player.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        player.lastCloudSync = Date()

        return player
    }

    private func restorePlayerProfile(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let profile = PlayerProfile(context: context)
        profile.id = UUID()
        profile.skillGoals = data["skillGoals"] as? [String]
        profile.physicalFocusAreas = data["physicalFocusAreas"] as? [String]
        profile.selfIdentifiedWeaknesses = data["selfIdentifiedWeaknesses"] as? [String]
        profile.preferredIntensity = Int16(data["preferredIntensity"] as? Int ?? 5)
        profile.preferredSessionDuration = Int16(data["preferredSessionDuration"] as? Int ?? 45)
        profile.preferredDrillComplexity = data["preferredDrillComplexity"] as? String
        profile.yearsPlaying = Int16(data["yearsPlaying"] as? Int ?? 0)
        profile.trainingBackground = data["trainingBackground"] as? String
        profile.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        profile.updatedAt = Date()
        profile.player = player
        player.playerProfile = profile
    }

    private func restoreGamificationData(from data: [String: Any], to player: Player) {
        player.totalXP = Int64(data["totalXP"] as? Int ?? 0)
        player.currentLevel = Int16(data["currentLevel"] as? Int ?? 1)
        player.currentStreak = Int16(data["currentStreak"] as? Int ?? 0)
        player.longestStreak = Int16(data["longestStreak"] as? Int ?? 0)
        player.coins = Int64(data["coins"] as? Int ?? 0)
        player.totalCoinsEarned = Int64(data["totalCoinsEarned"] as? Int ?? 0)
        player.streakFreezes = Int16(data["streakFreezes"] as? Int ?? 0)
        player.unlockedAchievements = data["unlockedAchievements"] as? [String]

        if let lastTrainingTimestamp = data["lastTrainingDate"] as? Timestamp {
            player.lastTrainingDate = lastTrainingTimestamp.dateValue()
        }
    }

    private func restoreAvatarConfiguration(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let avatar = AvatarConfiguration(context: context)
        avatar.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        avatar.skinTone = data["skinTone"] as? String
        avatar.hairStyle = data["hairStyle"] as? String
        avatar.hairColor = data["hairColor"] as? String
        avatar.faceStyle = data["faceStyle"] as? String
        avatar.jerseyId = data["jerseyId"] as? String
        avatar.shortsId = data["shortsId"] as? String
        avatar.socksId = data["socksId"] as? String
        avatar.cleatsId = data["cleatsId"] as? String
        avatar.accessoryIds = (data["accessoryIds"] as? [String]) as NSArray?
        avatar.lastModified = (data["lastModified"] as? Timestamp)?.dateValue() ?? Date()
        avatar.player = player
        player.avatarConfiguration = avatar
    }

    private func restoreOwnedAvatarItem(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let item = OwnedAvatarItem(context: context)
        item.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        item.itemId = data["itemId"] as? String
        item.purchasedAt = (data["purchasedAt"] as? Timestamp)?.dateValue() ?? Date()
        item.equippedSlot = data["equippedSlot"] as? String
        item.player = player
        player.addToOwnedAvatarItems(item)
    }

    private func restorePlayerGoal(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let goal = PlayerGoal(context: context)
        goal.id = UUID(uuidString: data["goalId"] as? String ?? "") ?? UUID()
        goal.skillName = data["skillName"] as? String
        goal.currentLevel = data["currentLevel"] as? Double ?? 0
        goal.targetLevel = data["targetLevel"] as? Double ?? 0
        goal.priority = data["priority"] as? String
        goal.status = data["status"] as? String
        goal.progressNotes = data["progressNotes"] as? String
        goal.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

        if let targetDateTimestamp = data["targetDate"] as? Timestamp {
            goal.targetDate = targetDateTimestamp.dateValue()
        }

        goal.player = player
        player.addToPlayerGoals(goal)
    }

    func restoreSeason(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let season = Season(context: context)
        season.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        season.name = data["name"] as? String
        season.team = data["team"] as? String
        season.startDate = (data["startDate"] as? Timestamp)?.dateValue() ?? (data["startDate"] as? Date) ?? Date()
        season.endDate = (data["endDate"] as? Timestamp)?.dateValue() ?? (data["endDate"] as? Date)
        season.isActive = data["isActive"] as? Bool ?? false
        season.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Date) ?? Date()
        season.player = player
        player.addToSeasons(season)
    }

    func restoreMatch(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let match = Match(context: context)
        match.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        match.date = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
        match.opponent = data["opponent"] as? String
        match.competition = data["competition"] as? String
        match.minutesPlayed = Self.int16Value(from: data["minutesPlayed"])
        match.goals = Self.int16Value(from: data["goals"])
        match.assists = Self.int16Value(from: data["assists"])
        match.positionPlayed = data["positionPlayed"] as? String
        match.isHomeGame = data["isHomeGame"] as? Bool ?? false
        match.result = data["result"] as? String
        match.notes = data["notes"] as? String
        match.rating = Self.int16Value(from: data["rating"])
        match.xpEarned = Self.int32Value(from: data["xpEarned"])
        match.strengths = data["strengths"] as? String
        match.weaknesses = data["weaknesses"] as? String
        match.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? (data["createdAt"] as? Date) ?? Date()
        match.player = player
        player.addToMatches(match)

        if let seasonIDString = data["seasonID"] as? String,
           !seasonIDString.isEmpty,
           let seasonID = UUID(uuidString: seasonIDString),
           let seasons = player.seasons?.allObjects as? [Season],
           let matchingSeason = seasons.first(where: { $0.id == seasonID }) {
            match.season = matchingSeason
        }
    }

    private static func int16Value(from value: Any?) -> Int16 {
        return int16Value(from: value, default: 0)
    }

    private static func int16Value(from value: Any?, default defaultValue: Int16) -> Int16 {
        if let v = value as? Int { return Int16(v) }
        if let v = value as? Int16 { return v }
        if let v = value as? Int32 { return Int16(v) }
        if let v = value as? Int64 { return Int16(v) }
        if let v = value as? NSNumber { return v.int16Value }
        return defaultValue
    }

    private static func int32Value(from value: Any?) -> Int32 {
        if let v = value as? Int { return Int32(v) }
        if let v = value as? Int16 { return Int32(v) }
        if let v = value as? Int32 { return v }
        if let v = value as? Int64 { return Int32(v) }
        if let v = value as? NSNumber { return v.int32Value }
        return 0
    }

    func restorePlayerStats(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let stats = PlayerStats(context: context)
        stats.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        stats.date = (data["date"] as? Timestamp)?.dateValue() ?? (data["date"] as? Date) ?? Date()
        stats.skillRatings = data["skillRatings"] as? [String: Double]
        stats.totalTrainingHours = data["totalTrainingHours"] as? Double ?? 0
        if let sessions = data["totalSessions"] as? Int {
            stats.totalSessions = Int32(sessions)
        } else if let sessions = data["totalSessions"] as? Int32 {
            stats.totalSessions = sessions
        } else if let sessions = data["totalSessions"] as? NSNumber {
            stats.totalSessions = sessions.int32Value
        }
        stats.player = player
        player.addToStats(stats)
    }

    func restoreCustomExercise(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let exercise = Exercise(context: context)
        exercise.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        exercise.name = data["name"] as? String
        exercise.category = data["category"] as? String
        exercise.difficulty = Int16(data["difficulty"] as? Int ?? 2)
        exercise.exerciseDescription = data["exerciseDescription"] as? String
        exercise.instructions = data["instructions"] as? String
        exercise.targetSkills = data["targetSkills"] as? [String]
        exercise.isYouTubeContent = data["isYouTubeContent"] as? Bool ?? false
        exercise.youtubeVideoID = data["youtubeVideoID"] as? String
        exercise.videoThumbnailURL = data["videoThumbnailURL"] as? String
        exercise.videoDuration = Int32(data["videoDuration"] as? Int ?? 0)
        exercise.videoDescription = data["videoDescription"] as? String
        exercise.isFavorite = data["isFavorite"] as? Bool ?? false
        exercise.personalNotes = data["personalNotes"] as? String
        exercise.diagramJSON = data["diagramJSON"] as? String
        exercise.metabolicLoad = Int16(data["metabolicLoad"] as? Int ?? 0)
        exercise.technicalComplexity = Int16(data["technicalComplexity"] as? Int ?? 0)

        if let lastUsedTimestamp = data["lastUsedAt"] as? Timestamp {
            exercise.lastUsedAt = lastUsedTimestamp.dateValue()
        }

        exercise.player = player
        player.addToExercises(exercise)
    }

    private func restoreTrainingSession(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let session = TrainingSession(context: context)
        session.id = UUID(uuidString: data["sessionId"] as? String ?? "") ?? UUID()
        session.date = (data["date"] as? Timestamp)?.dateValue() ?? Date()
        session.duration = Double(data["duration"] as? Int ?? 0)
        session.sessionType = data["sessionType"] as? String
        session.intensity = Int16(data["intensity"] as? Int ?? 5)
        session.location = data["location"] as? String
        session.overallRating = Int16(data["overallRating"] as? Int ?? 0)
        session.notes = data["notes"] as? String
        session.player = player
        player.addToSessions(session)

        if let exercisesData = data["exercises"] as? [[String: Any]] {
            for exerciseData in exercisesData {
                let sessionExercise = SessionExercise(context: context)
                sessionExercise.id = UUID()
                sessionExercise.duration = Double(exerciseData["duration"] as? Int ?? 0)
                sessionExercise.sets = Int16(exerciseData["sets"] as? Int ?? 0)
                sessionExercise.reps = Int16(exerciseData["reps"] as? Int ?? 0)
                sessionExercise.performanceRating = Int16(exerciseData["performanceRating"] as? Int ?? 0)
                sessionExercise.notes = exerciseData["notes"] as? String
                sessionExercise.session = session
            }
        }
    }

    func restoreTrainingPlan(from data: [String: Any], for player: Player, in context: NSManagedObjectContext) throws {
        let plan = TrainingPlan(context: context)
        plan.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        plan.name = data["name"] as? String
        plan.planDescription = data["planDescription"] as? String
        plan.durationWeeks = Int16(data["durationWeeks"] as? Int ?? 4)
        plan.difficulty = data["difficulty"] as? String
        plan.category = data["category"] as? String
        plan.targetRole = data["targetRole"] as? String
        plan.isPrebuilt = data["isPrebuilt"] as? Bool ?? false
        plan.isActive = data["isActive"] as? Bool ?? false
        plan.currentWeek = Int16(data["currentWeek"] as? Int ?? 1)
        plan.progressPercentage = data["progressPercentage"] as? Double ?? 0.0
        plan.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        plan.updatedAt = Date()

        if let startedAtTimestamp = data["startedAt"] as? Timestamp {
            plan.startedAt = startedAtTimestamp.dateValue()
        }
        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            plan.completedAt = completedAtTimestamp.dateValue()
        }

        plan.player = player
        player.addToTrainingPlans(plan)

        if let weeksData = data["weeks"] as? [[String: Any]] {
            for weekData in weeksData {
                try restorePlanWeek(from: weekData, for: plan, player: player, in: context)
            }
        }
    }

    func restorePlanWeek(from data: [String: Any], for plan: TrainingPlan, player: Player, in context: NSManagedObjectContext) throws {
        let week = PlanWeek(context: context)
        week.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        week.weekNumber = Int16(data["weekNumber"] as? Int ?? 1)
        week.focusArea = data["focusArea"] as? String
        week.notes = data["notes"] as? String
        week.isCompleted = data["isCompleted"] as? Bool ?? false

        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            week.completedAt = completedAtTimestamp.dateValue()
        }

        week.plan = plan
        plan.addToWeeks(week)

        if let daysData = data["days"] as? [[String: Any]] {
            for dayData in daysData {
                try restorePlanDay(from: dayData, for: week, player: player, in: context)
            }
        }
    }

    func restorePlanDay(from data: [String: Any], for week: PlanWeek, player: Player, in context: NSManagedObjectContext) throws {
        let day = PlanDay(context: context)
        day.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        day.dayNumber = Int16(data["dayNumber"] as? Int ?? 1)
        day.dayOfWeek = data["dayOfWeek"] as? String
        day.isRestDay = data["isRestDay"] as? Bool ?? false
        day.isSkipped = data["isSkipped"] as? Bool ?? false
        day.notes = data["notes"] as? String
        day.isCompleted = data["isCompleted"] as? Bool ?? false

        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            day.completedAt = completedAtTimestamp.dateValue()
        }

        day.week = week
        week.addToDays(day)

        if let sessionsData = data["sessions"] as? [[String: Any]] {
            for sessionData in sessionsData {
                try restorePlanSession(from: sessionData, for: day, player: player, in: context)
            }
        }
    }

    func restorePlanSession(from data: [String: Any], for day: PlanDay, player: Player, in context: NSManagedObjectContext) throws {
        let session = PlanSession(context: context)
        session.id = UUID(uuidString: data["id"] as? String ?? "") ?? UUID()
        session.sessionType = data["sessionType"] as? String
        session.duration = Self.int16Value(from: data["duration"], default: 30)
        session.intensity = Self.int16Value(from: data["intensity"], default: 5)
        session.orderIndex = Self.int16Value(from: data["orderIndex"])
        session.notes = data["notes"] as? String
        session.isCompleted = data["isCompleted"] as? Bool ?? false
        session.actualDuration = Self.int16Value(from: data["actualDuration"])
        session.actualIntensity = Self.int16Value(from: data["actualIntensity"])

        if let completedAtTimestamp = data["completedAt"] as? Timestamp {
            session.completedAt = completedAtTimestamp.dateValue()
        }

        session.day = day
        day.addToSessions(session)

        if let exerciseIDStrings = data["exerciseIDs"] as? [String], !exerciseIDStrings.isEmpty {
            let targetIDs = Set(exerciseIDStrings.compactMap { UUID(uuidString: $0) })
            let restoredExercises = (player.exercises?.allObjects as? [Exercise]) ?? []
            let matching = restoredExercises.filter { exercise in
                guard let id = exercise.id else { return false }
                return targetIDs.contains(id)
            }
            if !matching.isEmpty {
                session.exercises = NSSet(array: matching)
            }
        }
    }

    // MARK: - Conflict Resolution

    func mergeWithConflictResolution(local: Player, cloudData: [String: Any]) {
        let cloudXP = Int64(cloudData["totalXP"] as? Int ?? 0)
        if cloudXP > local.totalXP {
            local.totalXP = cloudXP
        }

        let cloudCoins = Int64(cloudData["coins"] as? Int ?? 0)
        if cloudCoins > local.coins {
            local.coins = cloudCoins
        }

        let cloudTotalCoins = Int64(cloudData["totalCoinsEarned"] as? Int ?? 0)
        if cloudTotalCoins > local.totalCoinsEarned {
            local.totalCoinsEarned = cloudTotalCoins
        }

        local.currentLevel = Int16(XPService.shared.levelForXP(local.totalXP))

        let cloudStreak = Int16(cloudData["currentStreak"] as? Int ?? 0)
        let cloudLongestStreak = Int16(cloudData["longestStreak"] as? Int ?? 0)

        if let cloudLastTraining = (cloudData["lastTrainingDate"] as? Timestamp)?.dateValue() {
            let daysSinceCloud = Calendar.current.dateComponents([.day], from: cloudLastTraining, to: Date()).day ?? 100
            if daysSinceCloud <= 1 && cloudStreak > local.currentStreak {
                local.currentStreak = cloudStreak
            }
        }

        if cloudLongestStreak > local.longestStreak {
            local.longestStreak = cloudLongestStreak
        }

        let localAchievements = Set(local.unlockedAchievements ?? [])
        let cloudAchievements = Set(cloudData["unlockedAchievements"] as? [String] ?? [])
        local.unlockedAchievements = Array(localAchievements.union(cloudAchievements))
    }
}
