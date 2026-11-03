import Foundation
import CoreData

/// Service responsible for XP, level progression, and streak management.
/// XP comes from training only (`XPFormula`); the streak counts sessions that pass `StreakRule`.
@MainActor
final class XPService: ObservableObject, XPServiceProtocol {
    static let shared = XPService()

    @Published private(set) var lastError: ServiceError?

    init() {}

    // MARK: - Level System

    /// Soccer Career Path - 10 tiers representing the journey from grassroots to legend
    static let levelTiers: [LevelTier] = [
        LevelTier(minLevel: 1, maxLevel: 5, title: "Grassroots", description: "Starting your journey", icon: "leaf.fill"),
        LevelTier(minLevel: 6, maxLevel: 10, title: "Rising Star", description: "Building fundamentals", icon: "sparkles"),
        LevelTier(minLevel: 11, maxLevel: 15, title: "Squad Player", description: "Part of the team", icon: "person.fill"),
        LevelTier(minLevel: 16, maxLevel: 20, title: "Key Player", description: "Making an impact", icon: "star.fill"),
        LevelTier(minLevel: 21, maxLevel: 25, title: "Fan Favorite", description: "Crowd loves you", icon: "heart.fill"),
        LevelTier(minLevel: 26, maxLevel: 30, title: "Club Icon", description: "Leading by example", icon: "crown.fill"),
        LevelTier(minLevel: 31, maxLevel: 35, title: "International", description: "Representing your nation", icon: "globe.americas.fill"),
        LevelTier(minLevel: 36, maxLevel: 40, title: "Elite", description: "Among the best", icon: "bolt.fill"),
        LevelTier(minLevel: 41, maxLevel: 45, title: "World Class", description: "Top of the game", icon: "trophy.fill"),
        LevelTier(minLevel: 46, maxLevel: 50, title: "Living Legend", description: "Mastery achieved", icon: "laurel.leading")
    ]

    /// Total XP needed to reach `level` (`XPFormula.xpRequired(forLevel:)`).
    func xpRequiredForLevel(_ level: Int) -> Int64 {
        XPFormula.xpRequired(forLevel: level)
    }

    /// Get the level for a given total XP
    func levelForXP(_ xp: Int64) -> Int {
        XPFormula.level(forXP: xp)
    }

    /// Get progress percentage toward next level
    func progressToNextLevel(totalXP: Int64, currentLevel: Int) -> Double {
        guard currentLevel < XPFormula.maxLevel else { return 1.0 }

        let currentLevelXP = xpRequiredForLevel(currentLevel)
        let nextLevelXP = xpRequiredForLevel(currentLevel + 1)
        let xpInCurrentLevel = totalXP - currentLevelXP
        let xpNeededForNextLevel = nextLevelXP - currentLevelXP

        guard xpNeededForNextLevel > 0 else { return 1.0 }

        return min(1.0, max(0.0, Double(xpInCurrentLevel) / Double(xpNeededForNextLevel)))
    }

    /// Get the tier title for a level
    func tierForLevel(_ level: Int) -> LevelTier? {
        return Self.levelTiers.first { level >= $0.minLevel && level <= $0.maxLevel }
    }

    // MARK: - Streak Management

    /// Update streak for a session that counts toward it (`TrainingSession.countsTowardStreak`).
    func updateStreak(for player: Player, sessionDate: Date = Date()) {
        let calendar = Calendar.current
        let previousStreak = player.currentStreak

        if let lastDate = player.lastTrainingDate {
            let daysSinceLastSession = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: sessionDate)).day ?? 0

            if daysSinceLastSession == 0 {
                // Same day - no streak change
            } else if daysSinceLastSession == 1 {
                // Consecutive day - increment streak
                player.currentStreak += 1
            } else {
                // Streak broken - check for streak freeze
                if player.streakFreezes > 0 && daysSinceLastSession == 2 {
                    // Use streak freeze
                    player.streakFreezes -= 1
                    player.currentStreak += 1
                    AppLogger.shared.info("Used streak freeze. Remaining: \(player.streakFreezes)")
                } else {
                    // Reset streak
                    player.currentStreak = 1
                }
            }
        } else {
            // First session ever
            player.currentStreak = 1
        }

        player.lastTrainingDate = sessionDate

        // Update longest streak if needed
        if player.currentStreak > player.longestStreak {
            player.longestStreak = player.currentStreak
        }

        // Only react when the streak actually advanced this update (not on repeat same-day sessions)
        if player.currentStreak != previousStreak {
            handleStreakMilestone(for: player)
        }
    }

    /// Grant a streak freeze (cap 3) and fire celebratory haptics when a weekly milestone is first reached.
    /// Milestones pay no XP.
    private func handleStreakMilestone(for player: Player) {
        let milestones: Set<Int16> = [7, 14, 30]
        guard milestones.contains(player.currentStreak) else { return }
        if player.streakFreezes < 3 {
            player.streakFreezes += 1
            AppLogger.shared.info("Granted streak freeze at \(player.currentStreak)-day milestone. Remaining: \(player.streakFreezes)")
        }
        HapticManager.shared.streakMilestone()
    }

    /// Calculate actual streak from session history (for fixing bugs). Only sessions that pass
    /// `StreakRule` count.
    func calculateStreakFromHistory(for player: Player, in context: NSManagedObjectContext) -> Int16 {
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]

        do {
            let sessions = try context.fetch(request).filter(\.countsTowardStreak)
            guard !sessions.isEmpty else { return 0 }

            let calendar = Calendar.current
            var streak: Int16 = 0
            var previousDate: Date?
            var countedDays: Set<Date> = []

            for session in sessions {
                guard let sessionDate = session.date else { continue }
                let sessionDay = calendar.startOfDay(for: sessionDate)

                // Skip if we already counted this day
                guard countedDays.insert(sessionDay).inserted else { continue }

                if let prevDate = previousDate {
                    let daysDiff = calendar.dateComponents([.day], from: sessionDay, to: prevDate).day ?? 0

                    if daysDiff == 1 {
                        streak += 1
                        previousDate = sessionDay
                    } else {
                        break // Streak broken
                    }
                } else {
                    // First session (most recent)
                    let today = calendar.startOfDay(for: Date())
                    let daysSinceSession = calendar.dateComponents([.day], from: sessionDay, to: today).day ?? 0

                    if daysSinceSession <= 1 {
                        streak = 1
                        previousDate = sessionDay
                    } else {
                        break // No active streak
                    }
                }
            }

            return streak
        } catch {
            AppLogger.shared.error("Error calculating streak from history: \(error)")
            lastError = .coreData(error.localizedDescription)
            return 0
        }
    }

    // MARK: - Award XP

    /// Award XP to player and handle level ups
    /// Returns the new level if a level up occurred
    @discardableResult
    func awardXP(to player: Player, amount: Int32) -> Int? {
        let oldLevel = Int(player.currentLevel)
        player.totalXP += Int64(amount)

        let newLevel = levelForXP(player.totalXP)
        player.currentLevel = Int16(newLevel)

        if newLevel > oldLevel {
            AppLogger.shared.info("Level up! \(oldLevel) -> \(newLevel)")
            return newLevel
        }

        return nil
    }

    /// Process session completion: XP from `XPFormula` over the session's `verifiedTouches` and
    /// `activeSeconds` (set both before calling), streak update when the session passes `StreakRule`.
    /// `allExercisesCompleted` no longer changes XP; it is kept for callers.
    func processSessionCompletion(
        session: TrainingSession,
        player: Player,
        context: NSManagedObjectContext,
        allExercisesCompleted: Bool = true
    ) -> (xp: SessionXPBreakdown, levelUp: Int?) {

        if session.countsTowardStreak {
            updateStreak(for: player, sessionDate: session.date ?? Date())
        }

        let breakdown = XPFormula.session(verifiedTouches: Int(session.verifiedTouches),
                                          activeSeconds: session.activeSeconds)
        session.xpEarned = breakdown.total
        let levelUp = breakdown.total > 0 ? awardXP(to: player, amount: breakdown.total) : nil

        do {
            try context.save()
        } catch {
            AppLogger.shared.error("Error saving XP: \(error)")
            lastError = .coreData(error.localizedDescription)
        }

        return (breakdown, levelUp)
    }
}
