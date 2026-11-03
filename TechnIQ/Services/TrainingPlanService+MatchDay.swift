import Foundation
import CoreData

// MARK: - Match day
//
// Persists `MatchDayRules` on a stored plan and owns the one shared fact behind it: the profile's
// next match (`PlayerProfile.nextMatchDate`). The rules run after plan creation, on activation
// (dates move), after re-binding training days or an adaptation, and whenever the next match
// changes. Match dates = the next match plus matches logged from yesterday on.

extension TrainingPlanService {
    private var matchContext: NSManagedObjectContext { CoreDataManager.shared.context }

    /// The dates the rules use for this player.
    func matchDates(for player: Player, now: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let logged = ((player.matches as? Set<Match>) ?? []).compactMap(\.date)
        return MatchDayRules.relevantMatchDates(nextMatch: player.playerProfile?.nextMatchDate, logged: logged, now: now, calendar: calendar)
    }

    /// Applies the rules to one stored plan. Returns whether anything changed.
    @discardableResult
    func applyMatchDayRules(to planId: UUID, matchDates: [Date], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        let request: NSFetchRequest<TrainingPlan> = TrainingPlan.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", planId as CVarArg)
        request.fetchLimit = 1
        guard let plan = try? matchContext.fetch(request).first else { return false }

        let model = plan.toModel()
        let outcome = MatchDayRules.apply(to: model, startDate: PlanSchedule.startDate(of: model), matchDates: matchDates, now: now, calendar: calendar)
        guard !outcome.changes.isEmpty else { return false }

        var daysByID: [UUID: PlanDay] = [:]
        var sessionsByID: [UUID: PlanSession] = [:]
        for week in (plan.weeks?.allObjects as? [PlanWeek]) ?? [] {
            for day in (week.days?.allObjects as? [PlanDay]) ?? [] {
                if let id = day.id { daysByID[id] = day }
                for session in (day.sessions?.allObjects as? [PlanSession]) ?? [] {
                    if let id = session.id { sessionsByID[id] = session }
                }
            }
        }
        for move in outcome.changes.moves {
            guard let session = sessionsByID[move.sessionID], let day = daysByID[move.toDayID] else { continue }
            session.day = day
            session.orderIndex = Int16(move.orderIndex)
        }
        for change in outcome.changes.days {
            guard let day = daysByID[change.dayID] else { continue }
            day.isRestDay = change.isRestDay
            day.notes = change.notes
        }
        for change in outcome.changes.sessions {
            guard let session = sessionsByID[change.sessionID] else { continue }
            session.sessionType = change.sessionType.rawValue
            session.duration = Int16(change.duration)
            session.intensity = Int16(change.intensity)
            session.notes = change.notes
        }
        plan.updatedAt = Date()
        do {
            try matchContext.save()
            if plan.isActive { activePlan = plan.toModel() }
            Task { @MainActor in try? await CloudService.shared.syncTrainingPlan(plan) }
            return true
        } catch {
            AppLogger.shared.error("Match-day rules failed to save: \(error)")
            matchContext.rollback()
            return false
        }
    }

    /// Applies the rules to a plan with this player's match dates.
    @discardableResult
    func applyMatchDayRules(to planId: UUID, for player: Player) -> Bool {
        applyMatchDayRules(to: planId, matchDates: matchDates(for: player))
    }

    /// Re-applies the rules to the player's active plan and rebuilds reminders when days changed.
    @discardableResult
    func refreshMatchDayRules(for player: Player) -> Bool {
        guard let plan = fetchActivePlan(for: player) else { return false }
        let changed = applyMatchDayRules(to: plan.id, for: player)
        if changed { NotificationManager.shared.refresh(for: player) }
        return changed
    }

    // MARK: Next match (one shared fact)

    /// Sets or clears the profile's next match (stored as the start of that day), then re-shapes
    /// the active plan.
    func setNextMatch(_ date: Date?, for player: Player, calendar: Calendar = .current) {
        let newValue = date.map { calendar.startOfDay(for: $0) }
        let existing = player.playerProfile
        guard existing?.nextMatchDate != newValue else { return }
        let profile = existing ?? {
            let created = PlayerProfile(context: matchContext)
            created.id = UUID()
            created.createdAt = Date()
            created.player = player
            player.playerProfile = created
            return created
        }()
        profile.nextMatchDate = newValue
        profile.updatedAt = Date()
        CoreDataManager.shared.save()
        refreshMatchDayRules(for: player)
    }

    /// A logged match on or after the next match's day means it was played: clear it. Either way
    /// the active plan is re-checked (the logged match now counts as a match date).
    func matchLogged(on date: Date, for player: Player, calendar: Calendar = .current) {
        if MatchScheduleLink.clearsNextMatch(loggedOn: date, nextMatchDate: player.playerProfile?.nextMatchDate, calendar: calendar) {
            setNextMatch(nil, for: player, calendar: calendar)
        } else {
            refreshMatchDayRules(for: player)
        }
    }
}
