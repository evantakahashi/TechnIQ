import Foundation
import CoreData

// MARK: - Training Plan Service
// Handles business logic for creating, managing, and generating training plans

class TrainingPlanService: ObservableObject {
    static let shared = TrainingPlanService()

    private let coreDataManager = CoreDataManager.shared
    private var context: NSManagedObjectContext {
        coreDataManager.context
    }

    @Published var activePlan: TrainingPlanModel?
    @Published var availablePlans: [TrainingPlanModel] = []

    private init() {
        loadPrebuiltPlans()
    }

    // MARK: - Fetch Plans

    func fetchAllPlans(for player: Player) -> [TrainingPlanModel] {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrainingPlan.createdAt, ascending: false)]

        do {
            let plans = try context.fetch(request)
            return plans.map { $0.toModel() }
        } catch {
            #if DEBUG
            print("Failed to fetch training plans: \(error)")
            #endif
            return []
        }
    }

    func fetchActivePlan(for player: Player) -> TrainingPlanModel? {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND isActive == YES", player)
        request.fetchLimit = 1

        do {
            let plans = try context.fetch(request)
            return plans.first?.toModel()
        } catch {
            #if DEBUG
            print("Failed to fetch active plan: \(error)")
            #endif
            return nil
        }
    }

    /// Fetches a single plan by ID (for refreshing after edits)
    func fetchPlan(byId planId: UUID) -> TrainingPlanModel? {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planId as CVarArg)
        request.fetchLimit = 1

        do {
            let plan = try context.fetch(request).first
            return plan?.toModel()
        } catch {
            #if DEBUG
            print("Failed to fetch plan by ID: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Create Plans

    func createCustomPlan(
        name: String,
        description: String,
        durationWeeks: Int,
        difficulty: PlanDifficulty,
        category: PlanCategory,
        targetRole: String?,
        for player: Player
    ) -> TrainingPlan? {
        let plan = TrainingPlan(context: context)
        plan.id = UUID()
        plan.name = name
        plan.planDescription = description
        plan.durationWeeks = Int16(durationWeeks)
        plan.difficulty = difficulty.rawValue
        plan.category = category.rawValue
        plan.targetRole = targetRole
        plan.isPrebuilt = false
        plan.isActive = false
        plan.currentWeek = 1
        plan.progressPercentage = 0.0
        plan.createdAt = Date()
        plan.updatedAt = Date()
        plan.player = player

        do {
            try context.save()
            return plan
        } catch {
            #if DEBUG
            print("Failed to create custom plan: \(error)")
            #endif
            return nil
        }
    }

    /// Creates a training plan from AI-generated structure
    func createPlanFromAIGeneration(_ generated: GeneratedPlanStructure, for player: Player) -> TrainingPlan? {
        #if DEBUG
        print("🤖 TrainingPlanService: Creating plan from AI generation: \(generated.name)")
        #endif

        // Create the base plan
        guard let plan = createCustomPlan(
            name: generated.name,
            description: generated.description,
            durationWeeks: generated.weeks.count,
            difficulty: generated.parsedDifficulty,
            category: generated.parsedCategory,
            targetRole: generated.targetRole,
            for: player
        ) else {
            return nil
        }

        // Mark as AI-generated (using isPrebuilt = false to distinguish from templates)
        plan.isPrebuilt = false

        // Build out the complete structure
        for generatedWeek in generated.weeks {
            guard let week = addWeekToPlan(
                plan,
                weekNumber: generatedWeek.weekNumber,
                focusArea: generatedWeek.focusArea,
                notes: generatedWeek.notes
            ) else {
                continue
            }

            for generatedDay in generatedWeek.days {
                guard let day = addDayToWeek(
                    week,
                    dayNumber: generatedDay.dayNumber,
                    dayOfWeek: generatedDay.parsedDayOfWeek,
                    isRestDay: generatedDay.isRestDay,
                    notes: generatedDay.notes
                ) else {
                    continue
                }

                for generatedSession in generatedDay.sessions {
                    // Match AI-suggested exercises to actual Exercise entities
                    let matchedExercises = matchExercisesFromLibrary(
                        suggestedNames: generatedSession.suggestedExerciseNames,
                        sessionType: generatedSession.parsedSessionType,
                        for: player
                    )

                    _ = addSessionToDay(
                        day,
                        sessionType: generatedSession.parsedSessionType,
                        duration: generatedSession.duration,
                        intensity: generatedSession.intensity,
                        notes: generatedSession.notes,
                        exercises: matchedExercises
                    )
                }
            }
        }

        do {
            try context.save()
            #if DEBUG
            print("✅ TrainingPlanService: Successfully created AI-generated plan with \(generated.weeks.count) weeks")
            #endif
            return plan
        } catch {
            #if DEBUG
            print("❌ TrainingPlanService: Failed to save AI-generated plan: \(error)")
            #endif
            return nil
        }
    }

    /// Matches AI-suggested exercise names to actual Exercise entities in Core Data
    private func matchExercisesFromLibrary(suggestedNames: [String], sessionType: SessionType, for player: Player) -> [Exercise] {
        var matchedExercises: [Exercise] = []

        for suggestedName in suggestedNames {
            // Try to find exact match in Core Data
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "name CONTAINS[cd] %@ AND player == %@", suggestedName, player)
            request.fetchLimit = 1

            do {
                if let existingExercise = try context.fetch(request).first {
                    matchedExercises.append(existingExercise)
                    continue
                }
            } catch {
                #if DEBUG
                print("⚠️ Error searching for exercise '\(suggestedName)': \(error)")
                #endif
            }

            // If no match found, try template library
            if let templateExercise = TemplateExerciseLibrary.shared.findExercise(byName: suggestedName) {
                // Create new exercise from template
                if let newExercise = createExerciseFromTemplate(templateExercise, for: player) {
                    matchedExercises.append(newExercise)
                }
            } else {
                #if DEBUG
                print("⚠️ No match found for exercise: '\(suggestedName)', using fallback")
                #endif

                // Fallback: Get random exercises from template library matching session type
                let fallbackExercises = TemplateExerciseLibrary.shared.randomExercises(
                    for: sessionType.rawValue,
                    count: 1
                )

                if let fallbackTemplate = fallbackExercises.first,
                   let newExercise = createExerciseFromTemplate(fallbackTemplate, for: player) {
                    matchedExercises.append(newExercise)
                }
            }
        }

        return matchedExercises
    }

    /// Creates an Exercise entity from a template
    private func createExerciseFromTemplate(_ template: TemplateExercise, for player: Player) -> Exercise? {
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = template.name
        exercise.category = template.category
        exercise.exerciseDescription = template.description
        exercise.difficulty = Int16(mapDifficultyToNumber(template.difficulty))
        exercise.player = player
        exercise.isYouTubeContent = false

        do {
            try context.save()
            return exercise
        } catch {
            #if DEBUG
            print("Failed to create exercise from template: \(error)")
            #endif
            return nil
        }
    }

    private func mapDifficultyToNumber(_ difficulty: String) -> Int {
        switch difficulty.lowercased() {
        case "beginner": return 1
        case "intermediate": return 3
        case "advanced": return 4
        case "elite": return 5
        default: return 2
        }
    }

    func addWeekToPlan(_ plan: TrainingPlan, weekNumber: Int, focusArea: String?, notes: String?) -> PlanWeek? {
        let week = PlanWeek(context: context)
        week.id = UUID()
        week.weekNumber = Int16(weekNumber)
        week.focusArea = focusArea
        week.notes = notes
        week.isCompleted = false
        week.plan = plan

        do {
            try context.save()
            return week
        } catch {
            #if DEBUG
            print("Failed to add week to plan: \(error)")
            #endif
            return nil
        }
    }

    func addDayToWeek(_ week: PlanWeek, dayNumber: Int, dayOfWeek: DayOfWeek?, isRestDay: Bool, notes: String?) -> PlanDay? {
        let day = PlanDay(context: context)
        day.id = UUID()
        day.dayNumber = Int16(dayNumber)
        day.dayOfWeek = dayOfWeek?.rawValue
        day.isRestDay = isRestDay
        day.notes = notes
        day.isCompleted = false
        day.week = week

        do {
            try context.save()
            return day
        } catch {
            #if DEBUG
            print("Failed to add day to week: \(error)")
            #endif
            return nil
        }
    }

    func addSessionToDay(_ day: PlanDay, sessionType: SessionType, duration: Int, intensity: Int, notes: String?, exercises: [Exercise]) -> PlanSession? {
        let session = PlanSession(context: context)
        session.id = UUID()
        session.sessionType = sessionType.rawValue
        session.duration = Int16(duration)
        session.intensity = Int16(intensity)
        session.notes = notes
        session.isCompleted = false
        session.day = day
        session.exercises = NSSet(array: exercises)

        do {
            try context.save()
            return session
        } catch {
            #if DEBUG
            print("Failed to add session to day: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Activate/Deactivate Plans

    func activatePlan(_ planModel: TrainingPlanModel, for player: Player) {
        // Deactivate any currently active plans
        deactivateAllPlans(for: player)

        // Find and activate the selected plan
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planModel.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let plan = try context.fetch(request).first {
                plan.isActive = true
                plan.startedAt = Date()
                plan.updatedAt = Date()
                try context.save()
                activePlan = plan.toModel()
            }
        } catch {
            #if DEBUG
            print("Failed to activate plan: \(error)")
            #endif
        }
    }

    func deactivateAllPlans(for player: Player) {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND isActive == YES", player)

        do {
            let activePlans = try context.fetch(request)
            for plan in activePlans {
                plan.isActive = false
                plan.updatedAt = Date()
            }
            try context.save()
        } catch {
            #if DEBUG
            print("Failed to deactivate plans: \(error)")
            #endif
        }
    }

    // MARK: - Progress Tracking

    func markSessionCompleted(_ sessionModel: PlanSessionModel, actualDuration: Int, actualIntensity: Int) {
        let request: NSFetchRequest<PlanSession> = PlanSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionModel.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let session = try context.fetch(request).first {
                session.isCompleted = true
                session.completedAt = Date()
                session.actualDuration = Int16(actualDuration)
                session.actualIntensity = Int16(actualIntensity)

                // Check if all sessions in the day are complete
                if let day = session.day {
                    checkAndMarkDayCompleted(day)
                }

                try context.save()
            }
        } catch {
            #if DEBUG
            print("Failed to mark session completed: \(error)")
            #endif
        }
    }

    private func checkAndMarkDayCompleted(_ day: PlanDay) {
        let sessions = (day.sessions?.allObjects as? [PlanSession]) ?? []
        let allCompleted = !sessions.isEmpty && sessions.allSatisfy { $0.isCompleted }

        if allCompleted {
            day.isCompleted = true
            day.completedAt = Date()

            // Check if all days in the week are complete
            if let week = day.week {
                checkAndMarkWeekCompleted(week)
            }
        }
    }

    private func checkAndMarkWeekCompleted(_ week: PlanWeek) {
        let days = (week.days?.allObjects as? [PlanDay]) ?? []
        let allCompleted = !days.isEmpty && days.allSatisfy { $0.isCompleted }

        if allCompleted {
            week.isCompleted = true
            week.completedAt = Date()

            // Check if all weeks in the plan are complete
            if let plan = week.plan {
                checkAndMarkPlanCompleted(plan)
            }
        }
    }

    private func checkAndMarkPlanCompleted(_ plan: TrainingPlan) {
        let weeks = (plan.weeks?.allObjects as? [PlanWeek]) ?? []
        let allCompleted = !weeks.isEmpty && weeks.allSatisfy { $0.isCompleted }

        if allCompleted {
            plan.completedAt = Date()
            plan.progressPercentage = 100.0
            plan.isActive = false
        } else {
            // Update progress percentage
            updatePlanProgress(plan)
        }

        plan.updatedAt = Date()
    }

    private func updatePlanProgress(_ plan: TrainingPlan) {
        let weeks = (plan.weeks?.allObjects as? [PlanWeek]) ?? []
        guard !weeks.isEmpty else { return }

        let totalSessions = weeks.reduce(0) { weekTotal, week in
            let days = (week.days?.allObjects as? [PlanDay]) ?? []
            return weekTotal + days.reduce(0) { dayTotal, day in
                let sessions = (day.sessions?.allObjects as? [PlanSession]) ?? []
                return dayTotal + sessions.count
            }
        }

        let completedSessions = weeks.reduce(0) { weekTotal, week in
            let days = (week.days?.allObjects as? [PlanDay]) ?? []
            return weekTotal + days.reduce(0) { dayTotal, day in
                let sessions = (day.sessions?.allObjects as? [PlanSession]) ?? []
                return dayTotal + sessions.filter { $0.isCompleted }.count
            }
        }

        plan.progressPercentage = totalSessions > 0 ? Double(completedSessions) / Double(totalSessions) * 100.0 : 0.0
    }

    // MARK: - Delete Plans

    func deletePlan(_ planModel: TrainingPlanModel) {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planModel.id as CVarArg)
        request.fetchLimit = 1

        do {
            if let plan = try context.fetch(request).first {
                context.delete(plan)
                try context.save()
            }
        } catch {
            #if DEBUG
            print("Failed to delete plan: \(error)")
            #endif
        }
    }

    // MARK: - Update Methods (Phase 3 - Plan Editing)

    /// Updates a training plan's basic information
    /// - Returns: true if update succeeded, false otherwise
    @discardableResult
    func updatePlan(planId: UUID, name: String, description: String) -> Bool {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planId as CVarArg)
        request.fetchLimit = 1

        do {
            guard let plan = try context.fetch(request).first else {
                #if DEBUG
                print("Failed to find plan with ID: \(planId)")
                #endif
                return false
            }
            plan.name = name
            plan.planDescription = description
            plan.updatedAt = Date()
            try context.save()
            #if DEBUG
            print("Updated plan: \(name)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("Failed to update plan: \(error)")
            #endif
            return false
        }
    }

    /// Updates a week's focus area and notes
    /// - Returns: true if update succeeded, false otherwise
    @discardableResult
    func updateWeek(weekId: UUID, focusArea: String?, notes: String?) -> Bool {
        let request: NSFetchRequest<PlanWeek> = PlanWeek.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", weekId as CVarArg)
        request.fetchLimit = 1

        do {
            guard let week = try context.fetch(request).first else {
                #if DEBUG
                print("Failed to find week with ID: \(weekId)")
                #endif
                return false
            }
            week.focusArea = focusArea
            week.notes = notes

            // Also update the parent plan's timestamp
            week.plan?.updatedAt = Date()

            try context.save()
            #if DEBUG
            print("Updated week \(week.weekNumber): \(focusArea ?? "no focus")")
            #endif
            return true
        } catch {
            #if DEBUG
            print("Failed to update week: \(error)")
            #endif
            return false
        }
    }

    /// Updates a day's rest status and notes
    /// - Returns: true if update succeeded, false otherwise
    @discardableResult
    func updateDay(dayId: UUID, isRestDay: Bool, notes: String?) -> Bool {
        let request: NSFetchRequest<PlanDay> = PlanDay.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", dayId as CVarArg)
        request.fetchLimit = 1

        do {
            guard let day = try context.fetch(request).first else {
                #if DEBUG
                print("Failed to find day with ID: \(dayId)")
                #endif
                return false
            }
            day.isRestDay = isRestDay
            day.notes = notes

            // Update parent plan's timestamp
            day.week?.plan?.updatedAt = Date()

            try context.save()
            #if DEBUG
            print("Updated day \(day.dayNumber): isRestDay=\(isRestDay)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("Failed to update day: \(error)")
            #endif
            return false
        }
    }

    /// Updates a session's type, duration, intensity, and notes
    /// - Returns: true if update succeeded, false otherwise
    @discardableResult
    func updateSession(sessionId: UUID, sessionType: SessionType, duration: Int, intensity: Int, notes: String?) -> Bool {
        let request: NSFetchRequest<PlanSession> = PlanSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", sessionId as CVarArg)
        request.fetchLimit = 1

        do {
            guard let session = try context.fetch(request).first else {
                #if DEBUG
                print("Failed to find session with ID: \(sessionId)")
                #endif
                return false
            }
            session.sessionType = sessionType.rawValue
            session.duration = Int16(duration)
            session.intensity = Int16(intensity)
            session.notes = notes

            // Update parent plan's timestamp
            session.day?.week?.plan?.updatedAt = Date()

            try context.save()
            #if DEBUG
            print("Updated session: \(sessionType.displayName) - \(duration)min")
            #endif
            return true
        } catch {
            #if DEBUG
            print("Failed to update session: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Clone/Duplicate Plans (Phase 4)

    /// Creates a complete copy of an existing training plan
    /// - Parameters:
    ///   - planModel: The plan to clone
    ///   - player: The player who will own the cloned plan
    ///   - newName: Optional new name for the clone (defaults to "Copy of [original name]")
    /// - Returns: The cloned TrainingPlan entity, or nil if cloning failed
    func clonePlan(_ planModel: TrainingPlanModel, for player: Player, newName: String? = nil) -> TrainingPlan? {
        // Create the base plan
        let clonedPlan = TrainingPlan(context: context)
        clonedPlan.id = UUID()
        clonedPlan.name = newName ?? "Copy of \(planModel.name)"
        clonedPlan.planDescription = planModel.description
        clonedPlan.durationWeeks = Int16(planModel.durationWeeks)
        clonedPlan.difficulty = planModel.difficulty.rawValue
        clonedPlan.category = planModel.category.rawValue
        clonedPlan.targetRole = planModel.targetRole
        clonedPlan.isPrebuilt = false // Clones are never prebuilt
        clonedPlan.isActive = false
        clonedPlan.currentWeek = 1
        clonedPlan.progressPercentage = 0.0
        clonedPlan.createdAt = Date()
        clonedPlan.updatedAt = Date()
        clonedPlan.player = player

        // Clone all weeks
        for weekModel in planModel.weeks {
            let clonedWeek = PlanWeek(context: context)
            clonedWeek.id = UUID()
            clonedWeek.weekNumber = Int16(weekModel.weekNumber)
            clonedWeek.focusArea = weekModel.focusArea
            clonedWeek.notes = weekModel.notes
            clonedWeek.isCompleted = false
            clonedWeek.plan = clonedPlan

            // Clone all days in the week
            for dayModel in weekModel.days {
                let clonedDay = PlanDay(context: context)
                clonedDay.id = UUID()
                clonedDay.dayNumber = Int16(dayModel.dayNumber)
                clonedDay.dayOfWeek = dayModel.dayOfWeek?.rawValue
                clonedDay.isRestDay = dayModel.isRestDay
                clonedDay.notes = dayModel.notes
                clonedDay.isCompleted = false
                clonedDay.week = clonedWeek

                // Clone all sessions in the day
                for sessionModel in dayModel.sessions {
                    let clonedSession = PlanSession(context: context)
                    clonedSession.id = UUID()
                    clonedSession.sessionType = sessionModel.sessionType.rawValue
                    clonedSession.duration = Int16(sessionModel.duration)
                    clonedSession.intensity = Int16(sessionModel.intensity)
                    clonedSession.notes = sessionModel.notes
                    clonedSession.isCompleted = false
                    clonedSession.day = clonedDay

                    // Clone exercise references
                    if !sessionModel.exerciseIDs.isEmpty {
                        var exercises: [Exercise] = []
                        for exerciseID in sessionModel.exerciseIDs {
                            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                            request.predicate = NSPredicate(format: "id == %@", exerciseID as CVarArg)
                            request.fetchLimit = 1
                            if let exercise = try? context.fetch(request).first {
                                exercises.append(exercise)
                            }
                        }
                        clonedSession.exercises = NSSet(array: exercises)
                    }
                }
            }
        }

        do {
            try context.save()
            #if DEBUG
            print("Successfully cloned plan: \(planModel.name) -> \(clonedPlan.name ?? "")")
            #endif
            return clonedPlan
        } catch {
            #if DEBUG
            print("Failed to clone plan: \(error)")
            #endif
            context.rollback()
            return nil
        }
    }

    // MARK: - Today's Training Helpers

    /// Gets today's planned sessions for the active plan
    func getTodaysSessions(for planModel: TrainingPlanModel) -> [PlanSession] {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planModel.id as CVarArg)
        request.fetchLimit = 1

        do {
            guard let plan = try context.fetch(request).first else { return [] }

            // Get current week and day
            guard let (weekNumber, dayNumber) = getCurrentWeekAndDay(for: planModel) else { return [] }

            // Find the specific week and day
            let weeks = (plan.weeks?.allObjects as? [PlanWeek]) ?? []
            guard let currentWeek = weeks.first(where: { $0.weekNumber == Int16(weekNumber) }) else { return [] }

            let days = (currentWeek.days?.allObjects as? [PlanDay]) ?? []
            guard let currentDay = days.first(where: { $0.dayNumber == Int16(dayNumber) }) else { return [] }

            // Return sessions for today
            return (currentDay.sessions?.allObjects as? [PlanSession]) ?? []
        } catch {
            #if DEBUG
            print("Failed to get today's sessions: \(error)")
            #endif
            return []
        }
    }

    /// Calculates current week and day based on plan start date
    func getCurrentWeekAndDay(for planModel: TrainingPlanModel) -> (week: Int, day: Int)? {
        guard let startDate = planModel.startedAt else { return nil }

        let calendar = Calendar.current
        let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: Date()).day ?? 0

        // Calculate week number (1-indexed)
        let weekNumber = (daysSinceStart / 7) + 1

        // Calculate day number within the week (1-7)
        let dayNumber = (daysSinceStart % 7) + 1

        // Ensure we don't exceed plan duration
        guard weekNumber <= planModel.durationWeeks else { return nil }

        return (week: weekNumber, day: dayNumber)
    }

    // MARK: - Pre-built Plans

    private func loadPrebuiltPlans() {
        // Pre-built plans will be created when a player selects them
        // This just initializes the available templates
        availablePlans = [
            createStrikerDevelopmentTemplate(),
            createMidfielderMasteryTemplate(),
            createDefenderFoundationTemplate(),
            createSpeedAndAgilityTemplate(),
            createTechnicalExcellenceTemplate(),
            createYouthDevelopmentTemplate()
        ]
    }

    func instantiatePrebuiltPlan(_ template: TrainingPlanModel, for player: Player) -> TrainingPlan? {
        // Create the plan based on template
        guard let plan = createCustomPlan(
            name: template.name,
            description: template.description,
            durationWeeks: template.durationWeeks,
            difficulty: template.difficulty,
            category: template.category,
            targetRole: template.targetRole,
            for: player
        ) else {
            return nil
        }

        plan.isPrebuilt = true

        // Create weeks based on template
        for weekTemplate in template.weeks {
            guard let week = addWeekToPlan(plan, weekNumber: weekTemplate.weekNumber, focusArea: weekTemplate.focusArea, notes: weekTemplate.notes) else {
                continue
            }

            // Create days based on template
            for dayTemplate in weekTemplate.days {
                guard let day = addDayToWeek(week, dayNumber: dayTemplate.dayNumber, dayOfWeek: dayTemplate.dayOfWeek, isRestDay: dayTemplate.isRestDay, notes: dayTemplate.notes) else {
                    continue
                }

                // Create sessions based on template (exercises will be added later)
                for sessionTemplate in dayTemplate.sessions {
                    _ = addSessionToDay(day, sessionType: sessionTemplate.sessionType, duration: sessionTemplate.duration, intensity: sessionTemplate.intensity, notes: sessionTemplate.notes, exercises: [])
                }
            }
        }

        do {
            try context.save()
            return plan
        } catch {
            #if DEBUG
            print("Failed to save instantiated plan: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Template Generators

    private func createStrikerDevelopmentTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Striker Development",
            description: "8-week program focused on finishing, positioning, and movement in the attacking third",
            durationWeeks: 8,
            difficulty: .intermediate,
            category: .position,
            targetRole: "Striker",
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }

    private func createMidfielderMasteryTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Midfielder Mastery",
            description: "6-week program developing vision, passing range, and box-to-box capabilities",
            durationWeeks: 6,
            difficulty: .intermediate,
            category: .position,
            targetRole: "Midfielder",
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }

    private func createDefenderFoundationTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Defender Foundation",
            description: "6-week program building defensive awareness, tackling, and aerial dominance",
            durationWeeks: 6,
            difficulty: .intermediate,
            category: .position,
            targetRole: "Defender",
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }

    private func createSpeedAndAgilityTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Speed & Agility",
            description: "4-week high-intensity program for explosive acceleration and quick direction changes",
            durationWeeks: 4,
            difficulty: .advanced,
            category: .physical,
            targetRole: nil,
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }

    private func createTechnicalExcellenceTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Technical Excellence",
            description: "8-week comprehensive program mastering ball control, dribbling, and first touch",
            durationWeeks: 8,
            difficulty: .intermediate,
            category: .technical,
            targetRole: nil,
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }

    private func createYouthDevelopmentTemplate() -> TrainingPlanModel {
        TrainingPlanModel(
            id: UUID(),
            name: "Youth Development",
            description: "12-week foundational program for young players (U12-U16) building fundamental skills",
            durationWeeks: 12,
            difficulty: .beginner,
            category: .general,
            targetRole: nil,
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        )
    }
}
