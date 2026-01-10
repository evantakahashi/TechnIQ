import Foundation
import CoreData

/// Service responsible for XP calculations, level progression, and streak management
final class XPService {
    static let shared = XPService()

    private init() {}

    // MARK: - XP Constants

    struct XPRewards {
        static let sessionBase: Int32 = 50
        static let intensityBonus: Int32 = 10  // Per intensity level
        static let firstSessionOfDay: Int32 = 25
        static let allExercisesCompleted: Int32 = 20
        static let sessionRated: Int32 = 5
        static let sessionNotes: Int32 = 5
        static let weeklyGoalCompleted: Int32 = 100
        static let streak7Day: Int32 = 150
        static let streak14Day: Int32 = 200
        static let streak30Day: Int32 = 500
        static let streak60Day: Int32 = 750
        static let streak100Day: Int32 = 1000
        static let streak365Day: Int32 = 5000
    }

    // MARK: - Level System

    struct LevelTier: Identifiable {
        let id = UUID()
        let minLevel: Int
        let maxLevel: Int
        let title: String
        let description: String
    }

    static let levelTiers: [LevelTier] = [
        LevelTier(minLevel: 1, maxLevel: 5, title: "Youth Academy", description: "Starting your journey"),
        LevelTier(minLevel: 6, maxLevel: 10, title: "Reserve Team", description: "Building fundamentals"),
        LevelTier(minLevel: 11, maxLevel: 20, title: "First Team", description: "Established player"),
        LevelTier(minLevel: 21, maxLevel: 30, title: "Club Captain", description: "Leading by example"),
        LevelTier(minLevel: 31, maxLevel: 40, title: "National Team", description: "Elite performer"),
        LevelTier(minLevel: 41, maxLevel: 50, title: "World Class Legend", description: "Mastery achieved")
    ]

    /// Calculate XP required for a specific level using exponential curve
    func xpRequiredForLevel(_ level: Int) -> Int64 {
        guard level > 1 else { return 0 }

        // Exponential curve: baseXP * (multiplier ^ (level - 1))
        // Level 2: 100, Level 3: 250, Level 4: 500, etc.
        let baseXP: Double = 100
        let multiplier: Double = 1.5

        var totalXP: Double = 0
        for l in 2...level {
            totalXP += baseXP * pow(multiplier, Double(l - 2))
        }

        return Int64(totalXP)
    }

    /// Get the level for a given total XP
    func levelForXP(_ xp: Int64) -> Int {
        var level = 1
        while level < 50 && xp >= xpRequiredForLevel(level + 1) {
            level += 1
        }
        return level
    }

    /// Get progress percentage toward next level
    func progressToNextLevel(totalXP: Int64, currentLevel: Int) -> Double {
        guard currentLevel < 50 else { return 1.0 }

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

    // MARK: - XP Calculation for Sessions

    struct SessionXPBreakdown {
        let baseXP: Int32
        let intensityBonus: Int32
        let firstSessionBonus: Int32
        let completionBonus: Int32
        let ratingBonus: Int32
        let notesBonus: Int32
        let streakBonus: Int32

        var total: Int32 {
            baseXP + intensityBonus + firstSessionBonus + completionBonus + ratingBonus + notesBonus + streakBonus
        }
    }

    /// Calculate XP earned from a training session
    func calculateSessionXP(
        intensity: Int16,
        exerciseCount: Int,
        allExercisesCompleted: Bool,
        hasRating: Bool,
        hasNotes: Bool,
        isFirstSessionOfDay: Bool,
        currentStreak: Int16
    ) -> SessionXPBreakdown {

        var intensityBonus: Int32 = 0
        if intensity > 0 {
            intensityBonus = XPRewards.intensityBonus * Int32(intensity)
        }

        let firstSessionBonus = isFirstSessionOfDay ? XPRewards.firstSessionOfDay : 0
        let completionBonus = allExercisesCompleted && exerciseCount > 0 ? XPRewards.allExercisesCompleted : 0
        let ratingBonus = hasRating ? XPRewards.sessionRated : 0
        let notesBonus = hasNotes ? XPRewards.sessionNotes : 0

        // Streak bonuses
        var streakBonus: Int32 = 0
        if currentStreak == 7 { streakBonus = XPRewards.streak7Day }
        else if currentStreak == 14 { streakBonus = XPRewards.streak14Day }
        else if currentStreak == 30 { streakBonus = XPRewards.streak30Day }
        else if currentStreak == 60 { streakBonus = XPRewards.streak60Day }
        else if currentStreak == 100 { streakBonus = XPRewards.streak100Day }
        else if currentStreak == 365 { streakBonus = XPRewards.streak365Day }

        return SessionXPBreakdown(
            baseXP: XPRewards.sessionBase,
            intensityBonus: intensityBonus,
            firstSessionBonus: firstSessionBonus,
            completionBonus: completionBonus,
            ratingBonus: ratingBonus,
            notesBonus: notesBonus,
            streakBonus: streakBonus
        )
    }

    // MARK: - Streak Management

    /// Check if it's the first session of the day for a player
    func isFirstSessionOfDay(for player: Player) -> Bool {
        guard let lastDate = player.lastTrainingDate else { return true }
        return !Calendar.current.isDateInToday(lastDate)
    }

    /// Update streak based on session completion
    func updateStreak(for player: Player, sessionDate: Date = Date()) {
        let calendar = Calendar.current

        if let lastDate = player.lastTrainingDate {
            let daysSinceLastSession = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastDate), to: calendar.startOfDay(for: sessionDate)).day ?? 0

            if daysSinceLastSession == 0 {
                // Same day - no streak change
            } else if daysSinceLastSession == 1 {
                // Consecutive day - increment streak
                player.currentStreak += 1
                if player.currentStreak > player.longestStreak {
                    player.longestStreak = player.currentStreak
                }
            } else {
                // Streak broken - check for streak freeze
                if player.streakFreezes > 0 && daysSinceLastSession == 2 {
                    // Use streak freeze
                    player.streakFreezes -= 1
                    player.currentStreak += 1
                    #if DEBUG
                    print("Used streak freeze. Remaining: \(player.streakFreezes)")
                    #endif
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
    }

    /// Calculate actual streak from session history (for fixing bugs)
    func calculateStreakFromHistory(for player: Player, in context: NSManagedObjectContext) -> Int16 {
        let request: NSFetchRequest<TrainingSession> = TrainingSession.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)]

        do {
            let sessions = try context.fetch(request)
            guard !sessions.isEmpty else { return 0 }

            let calendar = Calendar.current
            var streak: Int16 = 0
            var previousDate: Date?
            var uniqueDates: Set<String> = []

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"

            for session in sessions {
                guard let sessionDate = session.date else { continue }

                let dateString = dateFormatter.string(from: sessionDate)

                // Skip if we already counted this day
                if uniqueDates.contains(dateString) { continue }
                uniqueDates.insert(dateString)

                let sessionDay = calendar.startOfDay(for: sessionDate)

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
            #if DEBUG
            print("Error calculating streak from history: \(error)")
            #endif
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
            #if DEBUG
            print("Level up! \(oldLevel) -> \(newLevel)")
            #endif
            return newLevel
        }

        return nil
    }

    /// Process session completion - calculates XP, updates streak, and awards XP
    func processSessionCompletion(
        session: TrainingSession,
        player: Player,
        context: NSManagedObjectContext
    ) -> (xp: SessionXPBreakdown, levelUp: Int?) {

        // Check if first session of day
        let isFirstSession = isFirstSessionOfDay(for: player)

        // Update streak
        updateStreak(for: player, sessionDate: session.date ?? Date())

        // Calculate XP
        let exerciseCount = session.exercises?.count ?? 0
        let breakdown = calculateSessionXP(
            intensity: session.intensity,
            exerciseCount: exerciseCount,
            allExercisesCompleted: exerciseCount > 0,
            hasRating: session.overallRating > 0,
            hasNotes: !(session.notes?.isEmpty ?? true),
            isFirstSessionOfDay: isFirstSession,
            currentStreak: player.currentStreak
        )

        // Store XP on session
        session.xpEarned = breakdown.total

        // Award XP to player
        let levelUp = awardXP(to: player, amount: breakdown.total)

        // Save context
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving XP: \(error)")
            #endif
        }

        return (breakdown, levelUp)
    }

    // MARK: - Streak Freezes

    /// Purchase a streak freeze with XP
    func purchaseStreakFreeze(for player: Player, context: NSManagedObjectContext) -> Bool {
        let cost: Int64 = 500

        guard player.totalXP >= cost else { return false }

        player.totalXP -= cost
        player.streakFreezes += 1

        do {
            try context.save()
            return true
        } catch {
            #if DEBUG
            print("Error purchasing streak freeze: \(error)")
            #endif
            return false
        }
    }
}
