import Foundation
import CoreData
import SwiftUI

#if DEBUG
// MARK: - TQDemoSeed
//
// Debug-only fixture so the Touchline screens can be compared against the handoff mocks on a
// simulator. Launch with `-TQSeedDemo`: gives the current player kit #9, a 5-day streak, 2,450 XP,
// an active 8-week "Striker Development" schedule with two weeks done, completed sessions earlier
// this week, and a logged win. Idempotent per launch; never compiled into release builds.

enum TQDemoSeed {
    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-TQSeedDemo")
    }

    /// Creates the demo player for `uid` when none exists (fresh simulator / CI), with the default
    /// exercise library so Train and the Home hero have content.
    @MainActor
    @discardableResult
    static func ensurePlayer(uid: String, context: NSManagedObjectContext) -> Player? {
        guard isRequested, !uid.isEmpty else { return nil }
        let request = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", uid)
        if let existing = try? context.fetch(request).first { return existing }

        let player = Player(context: context)
        player.id = UUID()
        player.firebaseUID = uid
        player.name = "Player"
        player.age = 14
        player.position = "Forward"
        player.dominantFoot = "Right"
        player.experienceLevel = "Intermediate"
        player.playingStyle = "Balanced"
        player.createdAt = Date()
        CoreDataManager.shared.createDefaultExercises(for: player)
        try? context.save()
        return player
    }

    @MainActor
    static func apply(to player: Player, context: NSManagedObjectContext) {
        guard isRequested else { return }
        let calendar = Calendar.current
        let now = Date()

        player.kitNumber = 9
        player.currentStreak = 5
        player.longestStreak = max(player.longestStreak, 5)
        player.totalXP = max(player.totalXP, 2450)
        player.currentLevel = Int16(XPService.shared.levelForXP(player.totalXP))
        if player.position == nil || player.position?.isEmpty == true { player.position = "Forward" }
        if player.dominantFoot == nil { player.dominantFoot = "Right" }

        seedPlan(for: player, context: context, now: now)
        seedSessions(for: player, context: context, calendar: calendar, now: now)
        seedMatch(for: player, calendar: calendar, now: now)

        // Coach marks would cover the hero in screenshots.
        for id in ["dashboard", "train", "plans", "progress", "avatar"] { CoachMarkManager.shared.markSeen(id) }

        try? context.save()
    }

    /// Community drills for the Drills tab: a "drill of the week" plus a handful of rows.
    static func sharedDrills(category: String? = nil) -> [SharedDrill] {
        let now = Date()
        func drill(_ id: String, _ title: String, by author: String, level: Int, category cat: String, difficulty: Int,
                   minutes: Int, saves: Int, daysAgo: Int, saved: Bool = false) -> SharedDrill {
            SharedDrill(
                id: id, authorID: "demo-\(id)", authorName: author, authorLevel: level, title: title,
                description: "Shared by the community.", category: cat, difficulty: difficulty,
                targetSkills: [cat], duration: minutes, equipment: ["Ball", "Cones"],
                steps: ["Set up the cones five metres apart.", "Work through the pattern at pace.", "Switch feet halfway."],
                sets: 3, reps: 10, timestamp: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                saveCount: saves, isSavedByCurrentUser: saved, reportCount: 0
            )
        }
        let all = [
            drill("d1", "Wall pass finishing", by: "Marco T.", level: 14, category: "technical", difficulty: 3, minutes: 15, saves: 1240, daysAgo: 3),
            drill("d2", "Box-to-box shuttles", by: "Kai R.", level: 9, category: "physical", difficulty: 2, minutes: 12, saves: 412, daysAgo: 1),
            drill("d3", "Third-man runs", by: "Leah P.", level: 21, category: "tactical", difficulty: 4, minutes: 20, saves: 388, daysAgo: 5),
            drill("d4", "Cone weave turns", by: "Sam O.", level: 6, category: "technical", difficulty: 1, minutes: 10, saves: 251, daysAgo: 12),
            drill("d5", "Pressing triggers", by: "Ana V.", level: 17, category: "tactical", difficulty: 3, minutes: 18, saves: 197, daysAgo: 2),
            drill("d6", "Sprint ladder", by: "Dev K.", level: 11, category: "physical", difficulty: 2, minutes: 8, saves: 143, daysAgo: 20)
        ]
        guard let category else { return all }
        return all.filter { $0.category == category }
    }

    /// 8-week schedule mirroring the mock (Mon/Wed/Thu/Sat, two sessions on odd-week Saturdays);
    /// weeks 1–2 done, week 3 day 1 done.
    @MainActor
    private static func seedPlan(for player: Player, context: NSManagedObjectContext, now: Date) {
        // Replace an empty prebuilt shell (no weeks) so the schedule below becomes the active plan.
        if let active = TrainingPlanService.shared.fetchActivePlan(for: player), active.weeks.isEmpty {
            TrainingPlanService.shared.deletePlan(active)
        }
        guard TrainingPlanService.shared.fetchActivePlan(for: player) == nil,
              let plan = TrainingPlanService.shared.createCustomPlan(
                name: "Striker Development",
                description: "8 weeks on finishing, positioning and movement in the attacking third.",
                durationWeeks: 8,
                difficulty: .intermediate,
                category: .position,
                targetRole: "Striker",
                for: player
              ) else { return }

        let focus = ["Finishing fundamentals", "Movement off the ball", "Weak-foot finishing", "Aerial and first-time finishes",
                     "Pressure finishing", "Combination play", "Match-speed repetition", "Taper and test"]
        let exercises = seedExercises(for: player, context: context)
        let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }

        for weekNumber in 1...8 {
            guard let week = TrainingPlanService.shared.addWeekToPlan(plan, weekNumber: weekNumber, focusArea: focus[weekNumber - 1], notes: nil) else { continue }
            let pattern = weekNumber % 2 == 1 ? [1, 0, 1, 1, 0, 2, 0] : [1, 1, 0, 1, 0, 1, 0]
            for (index, count) in pattern.enumerated() {
                guard let day = TrainingPlanService.shared.addDayToWeek(week, dayNumber: index + 1, dayOfWeek: weekdays[index], isRestDay: count == 0, notes: nil) else { continue }
                for sessionIndex in 0..<count {
                    let sessionExercises = Array(exercises.dropFirst(sessionIndex).prefix(1))
                    _ = TrainingPlanService.shared.addSessionToDay(
                        day,
                        sessionType: .technical,
                        duration: 15,
                        intensity: 3,
                        notes: nil,
                        exercises: sessionExercises
                    )
                }
                let done = weekNumber <= 2 || (weekNumber == 3 && index == 0)
                if done {
                    day.isCompleted = true
                    day.completedAt = now
                    for session in (day.sessions?.allObjects as? [PlanSession]) ?? [] {
                        session.isCompleted = true
                        session.completedAt = now
                    }
                }
            }
            if weekNumber <= 2 {
                week.isCompleted = true
                week.completedAt = now
            }
        }
        plan.currentWeek = 3
        plan.progressPercentage = 31
        try? context.save()
        TrainingPlanService.shared.activatePlan(plan.toModel(), for: player)
    }

    /// Completed sessions on the training days earlier this week.
    @MainActor
    private static func seedSessions(for player: Player, context: NSManagedObjectContext, calendar: Calendar, now: Date) {
        let todayIndex = HomeWeekModel.mondayIndex(of: now, calendar: calendar)
        let monday = calendar.date(byAdding: .day, value: -todayIndex, to: calendar.startOfDay(for: now)) ?? now
        let existingThisWeek = ((player.sessions as? Set<TrainingSession>) ?? []).filter { ($0.date ?? .distantPast) >= monday }
        guard existingThisWeek.isEmpty else { return }
        for offset in [0, 2, 3] where offset < todayIndex {
            let date = calendar.date(byAdding: .day, value: offset, to: monday) ?? now
            let session = TrainingSession(context: context)
            session.id = UUID()
            session.player = player
            session.date = calendar.date(byAdding: .hour, value: 17, to: date)
            session.duration = 42
            session.intensity = 3
            session.overallRating = 4
            session.sessionType = "Training"
            session.xpEarned = 180
        }
    }

    @MainActor
    private static func seedMatch(for player: Player, calendar: Calendar, now: Date) {
        let matches = (player.matches as? Set<Match>) ?? []
        guard !matches.contains(where: { $0.opponent == "Northside" }) else { return }
        _ = MatchService.shared.createMatch(
            for: player,
            date: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
            opponent: "Northside",
            competition: "League",
            minutesPlayed: 80,
            goals: 2,
            assists: 1,
            positionPlayed: "Forward",
            isHomeGame: true,
            result: "W",
            notes: nil,
            rating: 4
        )
    }

    /// Two demo drills so today's plan session has something to start.
    @MainActor
    private static func seedExercises(for player: Player, context: NSManagedObjectContext) -> [Exercise] {
        let existing = (player.exercises as? Set<Exercise>) ?? []
        let wanted: [(String, String, Int16, [String])] = [
            ("Two-touch wall passing", "Pass with the left foot, receive the rebound with one touch, pass again on the second.", 2, ["Weak Foot", "Passing"]),
            ("First-touch directional", "Receive across the body and play the next pass in one movement.", 2, ["First Touch"])
        ]
        return wanted.map { name, description, difficulty, skills in
            if let found = existing.first(where: { $0.name == name }) { return found }
            let exercise = Exercise(context: context)
            exercise.id = UUID()
            exercise.name = name
            exercise.exerciseDescription = description
            exercise.category = "Technical"
            exercise.difficulty = difficulty
            exercise.targetSkills = skills
            exercise.estimatedDurationSeconds = 15 * 60
            exercise.instructions = "1. Stand 8 m from the wall between the two cones.\n2. \(description)\n3. Every 20 reps, shift to the other cone and change the angle."
            exercise.player = player
            return exercise
        }
    }
}

// MARK: - TQDebugScreen
//
// `-TQScreen signIn|onboarding` opens a pre-auth screen directly so it can be screenshotted
// without signing out of the simulator.

enum TQDebugScreen: String {
    case signIn, onboarding

    static var requested: TQDebugScreen? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-TQScreen"), index + 1 < args.count else { return nil }
        return TQDebugScreen(rawValue: args[index + 1])
    }
}

struct TQDebugScreenHost: View {
    let screen: TQDebugScreen
    @State private var onboardingComplete = false

    var body: some View {
        switch screen {
        case .signIn:
            AuthenticationView()
        case .onboarding:
            UnifiedOnboardingView(isOnboardingComplete: $onboardingComplete)
        }
    }
}
#endif
