import Foundation
import CoreData

/// Defines an achievement that can be unlocked
struct Achievement: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: AchievementCategory
    let requirement: AchievementRequirement
    let xpReward: Int32

    enum AchievementCategory: String, CaseIterable {
        case consistency = "Consistency"
        case volume = "Volume"
        case skills = "Skills"
    }
}

/// Defines the requirement for unlocking an achievement
enum AchievementRequirement {
    case sessionCount(Int)
    case streakDays(Int)
    case totalMinutes(Int)
    case uniqueExercises(Int)
    case categoryCompletion(String)
    case allTemplatesCompleted
    case customDrillsCreated(Int)
    case skillLevel(String, Double)
    case allSkillsAbove(Double)
    case skillImprovement(String, Double)
    case skillsImprovedInWeek(Int)
    case exerciseTypeCount(String, Int)
    case maxedSkills(Int)
    case earlyBirdSessions(Int)  // Before 8am
    case nightOwlSessions(Int)   // After 8pm
    case weekendSessions(Int)
    case monthsActive(Int)
    case comebackAfterBreak(Int) // Days of break before return
    case monthlySessionRecord(Int)
}

/// Service responsible for tracking and awarding achievements
final class AchievementService {
    static let shared = AchievementService()

    private init() {}

    // MARK: - All 30 Achievements

    static let allAchievements: [Achievement] = [
        // CONSISTENCY (10)
        Achievement(
            id: "first_training",
            name: "First Training",
            description: "Complete your first training session",
            icon: "figure.run",
            category: .consistency,
            requirement: .sessionCount(1),
            xpReward: 50
        ),
        Achievement(
            id: "week_warrior",
            name: "Week Warrior",
            description: "Maintain a 7-day training streak",
            icon: "flame.fill",
            category: .consistency,
            requirement: .streakDays(7),
            xpReward: 150
        ),
        Achievement(
            id: "monthly_master",
            name: "Monthly Master",
            description: "Maintain a 30-day training streak",
            icon: "calendar.badge.checkmark",
            category: .consistency,
            requirement: .streakDays(30),
            xpReward: 500
        ),
        Achievement(
            id: "century_club",
            name: "Century Club",
            description: "Maintain a 100-day training streak",
            icon: "100.circle.fill",
            category: .consistency,
            requirement: .streakDays(100),
            xpReward: 1000
        ),
        Achievement(
            id: "year_excellence",
            name: "Year of Excellence",
            description: "Maintain a 365-day training streak",
            icon: "star.circle.fill",
            category: .consistency,
            requirement: .streakDays(365),
            xpReward: 5000
        ),
        Achievement(
            id: "early_bird",
            name: "Early Bird",
            description: "Train before 8am (5 times)",
            icon: "sunrise.fill",
            category: .consistency,
            requirement: .earlyBirdSessions(5),
            xpReward: 100
        ),
        Achievement(
            id: "night_owl",
            name: "Night Owl",
            description: "Train after 8pm (5 times)",
            icon: "moon.stars.fill",
            category: .consistency,
            requirement: .nightOwlSessions(5),
            xpReward: 100
        ),
        Achievement(
            id: "weekend_warrior",
            name: "Weekend Warrior",
            description: "Train on 10 different weekends",
            icon: "sun.max.fill",
            category: .consistency,
            requirement: .weekendSessions(10),
            xpReward: 150
        ),
        Achievement(
            id: "all_weather",
            name: "All-Weather",
            description: "Train in every month of the year",
            icon: "cloud.sun.fill",
            category: .consistency,
            requirement: .monthsActive(12),
            xpReward: 300
        ),
        Achievement(
            id: "comeback_king",
            name: "Comeback King",
            description: "Return after a 7+ day break",
            icon: "arrow.counterclockwise.circle.fill",
            category: .consistency,
            requirement: .comebackAfterBreak(7),
            xpReward: 75
        ),

        // VOLUME (10)
        Achievement(
            id: "getting_started",
            name: "Getting Started",
            description: "Complete 10 training sessions",
            icon: "10.circle.fill",
            category: .volume,
            requirement: .sessionCount(10),
            xpReward: 100
        ),
        Achievement(
            id: "dedicated_player",
            name: "Dedicated Player",
            description: "Complete 50 training sessions",
            icon: "person.fill.checkmark",
            category: .volume,
            requirement: .sessionCount(50),
            xpReward: 250
        ),
        Achievement(
            id: "training_addict",
            name: "Training Addict",
            description: "Complete 100 training sessions",
            icon: "bolt.heart.fill",
            category: .volume,
            requirement: .sessionCount(100),
            xpReward: 500
        ),
        Achievement(
            id: "elite_athlete",
            name: "Elite Athlete",
            description: "Complete 500 training sessions",
            icon: "trophy.fill",
            category: .volume,
            requirement: .sessionCount(500),
            xpReward: 2500
        ),
        Achievement(
            id: "1000_hours",
            name: "1000 Hours",
            description: "Accumulate 60,000 minutes of training",
            icon: "clock.fill",
            category: .volume,
            requirement: .totalMinutes(60000),
            xpReward: 1000
        ),
        Achievement(
            id: "marathon_month",
            name: "Marathon Month",
            description: "Complete 20+ sessions in one month",
            icon: "calendar.badge.plus",
            category: .volume,
            requirement: .monthlySessionRecord(20),
            xpReward: 300
        ),
        Achievement(
            id: "exercise_explorer",
            name: "Exercise Explorer",
            description: "Try 25 different exercises",
            icon: "magnifyingglass",
            category: .volume,
            requirement: .uniqueExercises(25),
            xpReward: 150
        ),
        Achievement(
            id: "category_master",
            name: "Category Master",
            description: "Complete all exercises in Technical category",
            icon: "checkmark.seal.fill",
            category: .volume,
            requirement: .categoryCompletion("Technical"),
            xpReward: 200
        ),
        Achievement(
            id: "full_curriculum",
            name: "Full Curriculum",
            description: "Complete all template exercises",
            icon: "book.closed.fill",
            category: .volume,
            requirement: .allTemplatesCompleted,
            xpReward: 500
        ),
        Achievement(
            id: "custom_creator",
            name: "Custom Creator",
            description: "Create 10 custom drills",
            icon: "plus.square.fill",
            category: .volume,
            requirement: .customDrillsCreated(10),
            xpReward: 200
        ),

        // SKILLS (10)
        Achievement(
            id: "technical_ace",
            name: "Technical Ace",
            description: "Reach 80% proficiency in Technical skills",
            icon: "soccerball",
            category: .skills,
            requirement: .skillLevel("Technical", 80),
            xpReward: 300
        ),
        Achievement(
            id: "physical_peak",
            name: "Physical Peak",
            description: "Reach 80% proficiency in Physical skills",
            icon: "figure.strengthtraining.traditional",
            category: .skills,
            requirement: .skillLevel("Physical", 80),
            xpReward: 300
        ),
        Achievement(
            id: "tactical_genius",
            name: "Tactical Genius",
            description: "Reach 80% proficiency in Tactical skills",
            icon: "brain.head.profile",
            category: .skills,
            requirement: .skillLevel("Tactical", 80),
            xpReward: 300
        ),
        Achievement(
            id: "well_rounded",
            name: "Well-Rounded",
            description: "Reach 60% proficiency in all skill categories",
            icon: "circle.hexagonpath.fill",
            category: .skills,
            requirement: .allSkillsAbove(60),
            xpReward: 400
        ),
        Achievement(
            id: "mastery",
            name: "Mastery",
            description: "Reach 100% in any single skill",
            icon: "crown.fill",
            category: .skills,
            requirement: .skillLevel("any", 100),
            xpReward: 500
        ),
        Achievement(
            id: "improvement_arc",
            name: "Improvement Arc",
            description: "Improve any skill by 20 points",
            icon: "chart.line.uptrend.xyaxis",
            category: .skills,
            requirement: .skillImprovement("any", 20),
            xpReward: 200
        ),
        Achievement(
            id: "rapid_progress",
            name: "Rapid Progress",
            description: "Improve 3 skills in one week",
            icon: "hare.fill",
            category: .skills,
            requirement: .skillsImprovedInWeek(3),
            xpReward: 250
        ),
        Achievement(
            id: "specialist",
            name: "Specialist",
            description: "Complete 50 exercises of the same type",
            icon: "target",
            category: .skills,
            requirement: .exerciseTypeCount("any", 50),
            xpReward: 200
        ),
        Achievement(
            id: "skill_stacker",
            name: "Skill Stacker",
            description: "Max out 3 different skills",
            icon: "square.stack.3d.up.fill",
            category: .skills,
            requirement: .maxedSkills(3),
            xpReward: 750
        ),
        Achievement(
            id: "complete_player",
            name: "The Complete Player",
            description: "Reach 90%+ proficiency in all skill categories",
            icon: "medal.fill",
            category: .skills,
            requirement: .allSkillsAbove(90),
            xpReward: 1000
        )
    ]

    // MARK: - Achievement Checking

    /// Get all achievements a player has unlocked
    func getUnlockedAchievements(for player: Player) -> [Achievement] {
        let unlockedIds = player.unlockedAchievements ?? []
        return Self.allAchievements.filter { unlockedIds.contains($0.id) }
    }

    /// Get all achievements a player hasn't unlocked yet
    func getLockedAchievements(for player: Player) -> [Achievement] {
        let unlockedIds = player.unlockedAchievements ?? []
        return Self.allAchievements.filter { !unlockedIds.contains($0.id) }
    }

    /// Check if a specific achievement is unlocked
    func isUnlocked(_ achievementId: String, for player: Player) -> Bool {
        return (player.unlockedAchievements ?? []).contains(achievementId)
    }

    /// Check and unlock any achievements the player has earned
    /// Returns array of newly unlocked achievements
    func checkAndUnlockAchievements(
        for player: Player,
        in context: NSManagedObjectContext
    ) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []
        var currentUnlocked = player.unlockedAchievements ?? []

        for achievement in Self.allAchievements {
            // Skip if already unlocked
            if currentUnlocked.contains(achievement.id) { continue }

            // Check if requirement is met
            if checkRequirement(achievement.requirement, for: player, in: context) {
                currentUnlocked.append(achievement.id)
                newlyUnlocked.append(achievement)

                // Award XP for achievement
                XPService.shared.awardXP(to: player, amount: achievement.xpReward)

                #if DEBUG
                print("Achievement unlocked: \(achievement.name) (+\(achievement.xpReward) XP)")
                #endif
            }
        }

        // Update player's unlocked achievements
        if !newlyUnlocked.isEmpty {
            player.unlockedAchievements = currentUnlocked

            do {
                try context.save()
            } catch {
                #if DEBUG
                print("Error saving unlocked achievements: \(error)")
                #endif
            }
        }

        return newlyUnlocked
    }

    /// Check if a specific requirement is met
    private func checkRequirement(
        _ requirement: AchievementRequirement,
        for player: Player,
        in context: NSManagedObjectContext
    ) -> Bool {
        switch requirement {
        case .sessionCount(let count):
            return getSessionCount(for: player, in: context) >= count

        case .streakDays(let days):
            return player.currentStreak >= days || player.longestStreak >= days

        case .totalMinutes(let minutes):
            return getTotalTrainingMinutes(for: player, in: context) >= minutes

        case .uniqueExercises(let count):
            return getUniqueExerciseCount(for: player, in: context) >= count

        case .categoryCompletion(let category):
            return isCategoryCompleted(category, for: player, in: context)

        case .allTemplatesCompleted:
            return areAllTemplatesCompleted(for: player, in: context)

        case .customDrillsCreated(let count):
            return getCustomDrillCount(for: player, in: context) >= count

        case .skillLevel(let skill, let level):
            if skill == "any" {
                return hasAnySkillAtLevel(level, for: player, in: context)
            }
            return getSkillLevel(skill, for: player, in: context) >= level

        case .allSkillsAbove(let level):
            return areAllSkillsAbove(level, for: player, in: context)

        case .skillImprovement(_, let improvement):
            return hasImprovedSkillBy(improvement, for: player, in: context)

        case .skillsImprovedInWeek(let count):
            return getSkillsImprovedThisWeek(for: player, in: context) >= count

        case .exerciseTypeCount(_, let count):
            return getMaxExerciseTypeCount(for: player, in: context) >= count

        case .maxedSkills(let count):
            return getMaxedSkillsCount(for: player, in: context) >= count

        case .earlyBirdSessions(let count):
            return getEarlyBirdSessionCount(for: player, in: context) >= count

        case .nightOwlSessions(let count):
            return getNightOwlSessionCount(for: player, in: context) >= count

        case .weekendSessions(let count):
            return getWeekendSessionCount(for: player, in: context) >= count

        case .monthsActive(let months):
            return getActiveMonthsCount(for: player, in: context) >= months

        case .comebackAfterBreak(let days):
            return hasReturnedAfterBreak(days, for: player, in: context)

        case .monthlySessionRecord(let count):
            return getMaxMonthlySessionCount(for: player, in: context) >= count
        }
    }

    // MARK: - Helper Methods for Requirement Checking

    private func getSessionCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        return player.sessions?.count ?? 0
    }

    private func getTotalTrainingMinutes(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }
        return Int(sessions.reduce(0) { $0 + $1.duration })
    }

    private func getUniqueExerciseCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        var uniqueExerciseIds: Set<UUID> = []
        for session in sessions {
            guard let exercises = session.exercises as? Set<SessionExercise> else { continue }
            for sessionExercise in exercises {
                if let exerciseId = sessionExercise.exercise?.id {
                    uniqueExerciseIds.insert(exerciseId)
                }
            }
        }

        return uniqueExerciseIds.count
    }

    private func isCategoryCompleted(_ category: String, for player: Player, in context: NSManagedObjectContext) -> Bool {
        // Check if player has completed all exercises in a category
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@ AND player == %@", category, player)

        do {
            let exercises = try context.fetch(request)
            guard !exercises.isEmpty else { return false }

            for exercise in exercises {
                guard let sessionExercises = exercise.sessionExercises as? Set<SessionExercise>,
                      !sessionExercises.isEmpty else {
                    return false
                }
            }
            return true
        } catch {
            return false
        }
    }

    private func areAllTemplatesCompleted(for player: Player, in context: NSManagedObjectContext) -> Bool {
        // Simplified check - would need to compare against TemplateExerciseLibrary
        return false
    }

    private func getCustomDrillCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let exercises = player.exercises as? Set<Exercise> else { return 0 }
        return exercises.filter {
            $0.exerciseDescription?.contains("AI-Generated") == true ||
            $0.exerciseDescription?.contains("Custom") == true
        }.count
    }

    private func getSkillLevel(_ skill: String, for player: Player, in context: NSManagedObjectContext) -> Double {
        guard let stats = player.stats as? Set<PlayerStats>,
              let latestStats = stats.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }).first,
              let ratings = latestStats.skillRatings else { return 0 }

        return ratings[skill] ?? 0
    }

    private func hasAnySkillAtLevel(_ level: Double, for player: Player, in context: NSManagedObjectContext) -> Bool {
        guard let stats = player.stats as? Set<PlayerStats>,
              let latestStats = stats.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }).first,
              let ratings = latestStats.skillRatings else { return false }

        return ratings.values.contains { $0 >= level }
    }

    private func areAllSkillsAbove(_ level: Double, for player: Player, in context: NSManagedObjectContext) -> Bool {
        guard let stats = player.stats as? Set<PlayerStats>,
              let latestStats = stats.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }).first,
              let ratings = latestStats.skillRatings,
              !ratings.isEmpty else { return false }

        return ratings.values.allSatisfy { $0 >= level }
    }

    private func hasImprovedSkillBy(_ improvement: Double, for player: Player, in context: NSManagedObjectContext) -> Bool {
        guard let stats = player.stats as? Set<PlayerStats> else { return false }
        let sortedStats = stats.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }

        guard sortedStats.count >= 2,
              let firstRatings = sortedStats.first?.skillRatings,
              let lastRatings = sortedStats.last?.skillRatings else { return false }

        for (skill, latestValue) in lastRatings {
            if let earlierValue = firstRatings[skill], latestValue - earlierValue >= improvement {
                return true
            }
        }

        return false
    }

    private func getSkillsImprovedThisWeek(for player: Player, in context: NSManagedObjectContext) -> Int {
        // Simplified - would need historical skill tracking
        return 0
    }

    private func getMaxExerciseTypeCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        var typeCounts: [String: Int] = [:]
        for session in sessions {
            guard let exercises = session.exercises as? Set<SessionExercise> else { continue }
            for sessionExercise in exercises {
                let category = sessionExercise.exercise?.category ?? "Unknown"
                typeCounts[category, default: 0] += 1
            }
        }

        return typeCounts.values.max() ?? 0
    }

    private func getMaxedSkillsCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let stats = player.stats as? Set<PlayerStats>,
              let latestStats = stats.sorted(by: { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }).first,
              let ratings = latestStats.skillRatings else { return 0 }

        return ratings.values.filter { $0 >= 100 }.count
    }

    private func getEarlyBirdSessionCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        let calendar = Calendar.current
        return sessions.filter { session in
            guard let date = session.date else { return false }
            let hour = calendar.component(.hour, from: date)
            return hour < 8
        }.count
    }

    private func getNightOwlSessionCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        let calendar = Calendar.current
        return sessions.filter { session in
            guard let date = session.date else { return false }
            let hour = calendar.component(.hour, from: date)
            return hour >= 20
        }.count
    }

    private func getWeekendSessionCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        let calendar = Calendar.current
        var weekendDates: Set<String> = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for session in sessions {
            guard let date = session.date else { continue }
            let weekday = calendar.component(.weekday, from: date)
            if weekday == 1 || weekday == 7 { // Sunday or Saturday
                weekendDates.insert(formatter.string(from: date))
            }
        }

        return weekendDates.count
    }

    private func getActiveMonthsCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        var activeMonths: Set<String> = []
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for session in sessions {
            guard let date = session.date else { continue }
            activeMonths.insert(formatter.string(from: date))
        }

        return activeMonths.count
    }

    private func hasReturnedAfterBreak(_ days: Int, for player: Player, in context: NSManagedObjectContext) -> Bool {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return false }

        let sortedDates = sessions.compactMap { $0.date }.sorted()
        guard sortedDates.count >= 2 else { return false }

        let calendar = Calendar.current
        for i in 1..<sortedDates.count {
            let daysBetween = calendar.dateComponents([.day], from: sortedDates[i-1], to: sortedDates[i]).day ?? 0
            if daysBetween >= days {
                return true
            }
        }

        return false
    }

    private func getMaxMonthlySessionCount(for player: Player, in context: NSManagedObjectContext) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }

        var monthlyCounts: [String: Int] = [:]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"

        for session in sessions {
            guard let date = session.date else { continue }
            let monthKey = formatter.string(from: date)
            monthlyCounts[monthKey, default: 0] += 1
        }

        return monthlyCounts.values.max() ?? 0
    }

    // MARK: - Progress Toward Achievement

    /// Get progress percentage toward an achievement (0.0 to 1.0)
    func getProgress(
        for achievement: Achievement,
        player: Player,
        in context: NSManagedObjectContext
    ) -> Double {
        switch achievement.requirement {
        case .sessionCount(let target):
            let current = getSessionCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .streakDays(let target):
            let current = max(player.currentStreak, player.longestStreak)
            return min(1.0, Double(current) / Double(target))

        case .totalMinutes(let target):
            let current = getTotalTrainingMinutes(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .uniqueExercises(let target):
            let current = getUniqueExerciseCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .customDrillsCreated(let target):
            let current = getCustomDrillCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .earlyBirdSessions(let target):
            let current = getEarlyBirdSessionCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .nightOwlSessions(let target):
            let current = getNightOwlSessionCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .weekendSessions(let target):
            let current = getWeekendSessionCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .monthsActive(let target):
            let current = getActiveMonthsCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        case .monthlySessionRecord(let target):
            let current = getMaxMonthlySessionCount(for: player, in: context)
            return min(1.0, Double(current) / Double(target))

        default:
            // Binary achievements - either 0 or 1
            return isUnlocked(achievement.id, for: player) ? 1.0 : 0.0
        }
    }
}
