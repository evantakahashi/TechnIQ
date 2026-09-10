import Foundation
import CoreData

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
                    _ = TrainingPlanService.shared.addSessionToDay(day, sessionType: .technical, duration: 15, intensity: 3, notes: nil, exercises: sessionExercises)
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
#endif
