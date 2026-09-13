import Foundation
import CoreData

// MARK: - Plan editing
//
// Everything the one-screen editor needs beyond the create/update calls in the main file:
// structure (weeks, sessions), drills on a session, plan-level details, and a skeleton builder for
// custom plans so they never start as empty shells. All calls save and return whether they took.

extension TrainingPlanService {
    private var editingContext: NSManagedObjectContext { CoreDataManager.shared.context }

    private func fetch<T: NSManagedObject>(_ type: T.Type, id: UUID) -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? editingContext.fetch(request).first
    }

    private func saveEdit(_ plan: TrainingPlan?) -> Bool {
        plan?.updatedAt = Date()
        do {
            try editingContext.save()
            if let plan { Task { @MainActor in try? await CloudService.shared.syncTrainingPlan(plan) } }
            return true
        } catch {
            #if DEBUG
            print("Plan edit failed to save: \(error)")
            #endif
            editingContext.rollback()
            return false
        }
    }

    // MARK: Plan details

    @discardableResult
    func updatePlanDetails(planId: UUID, name: String, description: String, difficulty: PlanDifficulty) -> Bool {
        guard let plan = fetch(TrainingPlan.self, id: planId) else { return false }
        plan.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.planDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        plan.difficulty = difficulty.rawValue
        return saveEdit(plan)
    }

    // MARK: Weeks

    /// Appends a week that mirrors the last week's pattern (rest days, session types, lengths and
    /// drills) with nothing completed, so a plan can be extended without rebuilding it.
    @discardableResult
    func appendWeek(planId: UUID) -> Bool {
        guard let plan = fetch(TrainingPlan.self, id: planId) else { return false }
        let weeks = ((plan.weeks?.allObjects as? [PlanWeek]) ?? []).sorted { $0.weekNumber < $1.weekNumber }
        let template = weeks.last
        let week = PlanWeek(context: editingContext)
        week.id = UUID()
        week.weekNumber = Int16(weeks.count + 1)
        week.focusArea = template?.focusArea
        week.plan = plan

        let templateDays = ((template?.days?.allObjects as? [PlanDay]) ?? []).sorted { $0.dayNumber < $1.dayNumber }
        let dayCount = templateDays.isEmpty ? 7 : templateDays.count
        for index in 0..<dayCount {
            let source = index < templateDays.count ? templateDays[index] : nil
            let day = PlanDay(context: editingContext)
            day.id = UUID()
            day.dayNumber = Int16(index + 1)
            day.dayOfWeek = source?.dayOfWeek ?? DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }[index % 7].rawValue
            day.isRestDay = source?.isRestDay ?? true
            day.week = week
            for (order, sourceSession) in ((source?.sessions?.allObjects as? [PlanSession]) ?? []).sorted(by: { $0.orderIndex < $1.orderIndex }).enumerated() {
                let session = PlanSession(context: editingContext)
                session.id = UUID()
                session.sessionType = sourceSession.sessionType
                session.duration = sourceSession.duration
                session.intensity = sourceSession.intensity
                session.orderIndex = Int16(order)
                session.day = day
                session.exercises = sourceSession.exercises
            }
        }
        plan.durationWeeks = Int16(weeks.count + 1)
        plan.completedAt = nil
        return saveEdit(plan)
    }

    /// Removes the last week unless it is the only one or it has completed sessions.
    @discardableResult
    func removeLastWeek(planId: UUID) -> Bool {
        guard let plan = fetch(TrainingPlan.self, id: planId) else { return false }
        let weeks = ((plan.weeks?.allObjects as? [PlanWeek]) ?? []).sorted { $0.weekNumber < $1.weekNumber }
        guard weeks.count > 1, let last = weeks.last else { return false }
        let hasProgress = ((last.days?.allObjects as? [PlanDay]) ?? []).contains { day in
            ((day.sessions?.allObjects as? [PlanSession]) ?? []).contains { $0.isCompleted }
        }
        guard !hasProgress else { return false }
        editingContext.delete(last)
        plan.durationWeeks = Int16(weeks.count - 1)
        return saveEdit(plan)
    }

    // MARK: Days and sessions

    @discardableResult
    func setRestDay(dayId: UUID, isRestDay: Bool) -> Bool {
        guard let day = fetch(PlanDay.self, id: dayId) else { return false }
        day.isRestDay = isRestDay
        if isRestDay { day.isSkipped = false }
        return saveEdit(day.week?.plan)
    }

    @discardableResult
    func addSession(dayId: UUID, sessionType: SessionType, duration: Int, intensity: Int) -> PlanSession? {
        guard let day = fetch(PlanDay.self, id: dayId) else { return nil }
        day.isRestDay = false
        let session = addSessionToDay(day, sessionType: sessionType, duration: duration, intensity: intensity, notes: nil, exercises: [])
        _ = saveEdit(day.week?.plan)
        return session
    }

    @discardableResult
    func removeSession(sessionId: UUID) -> Bool {
        guard let session = fetch(PlanSession.self, id: sessionId), let day = session.day else { return false }
        editingContext.delete(session)
        let remaining = ((day.sessions?.allObjects as? [PlanSession]) ?? []).filter { $0 != session }.sorted { $0.orderIndex < $1.orderIndex }
        for (index, item) in remaining.enumerated() { item.orderIndex = Int16(index) }
        return saveEdit(day.week?.plan)
    }

    @discardableResult
    func setSessionExercises(sessionId: UUID, exerciseIDs: [UUID]) -> Bool {
        guard let session = fetch(PlanSession.self, id: sessionId) else { return false }
        let exercises = exerciseIDs.compactMap { fetch(Exercise.self, id: $0) }
        session.exercises = NSSet(array: exercises)
        return saveEdit(session.day?.week?.plan)
    }

    // MARK: Custom plan skeleton

    struct CustomPlanSpec {
        var name: String
        var description: String
        var weeks: Int
        var trainingDays: [DayOfWeek]
        var sessionType: SessionType
        var minutes: Int
        var intensity: Int
        var difficulty: PlanDifficulty
        var category: PlanCategory
    }

    /// A custom plan with a full week × day × session skeleton, so it can be followed and edited at once.
    func createCustomPlan(_ spec: CustomPlanSpec, for player: Player) -> TrainingPlan? {
        guard let plan = createCustomPlan(
            name: spec.name,
            description: spec.description,
            durationWeeks: max(spec.weeks, 1),
            difficulty: spec.difficulty,
            category: spec.category,
            targetRole: player.position,
            for: player
        ) else { return nil }
        let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }
        for weekNumber in 1...max(spec.weeks, 1) {
            guard let week = addWeekToPlan(plan, weekNumber: weekNumber, focusArea: nil, notes: nil) else { continue }
            for (index, weekday) in weekdays.enumerated() {
                let trains = spec.trainingDays.contains(weekday)
                guard let day = addDayToWeek(week, dayNumber: index + 1, dayOfWeek: weekday, isRestDay: !trains, notes: nil) else { continue }
                if trains {
                    _ = addSessionToDay(day, sessionType: spec.sessionType, duration: spec.minutes, intensity: spec.intensity, notes: nil, exercises: [])
                }
            }
        }
        _ = saveEdit(plan)
        return plan
    }
}
