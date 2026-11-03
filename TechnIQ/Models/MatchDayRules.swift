import Foundation

// MARK: - MatchDayRules
//
// Deterministic match-day shaping of a dated plan (dates from PlanSchedule). For every plan day
// from today on that is not done:
//   match day      → rest day, note "Match day" (its sessions stay attached, so moving the match
//                    hands the day back)
//   day after      → recovery: intensity 1, ≤ 30 min
//   day before     → light technical: intensity ≤ 2, ≤ 30 min
// So intensity ≥ 4 only lands on days at least two days from a match. Assessment sessions keep
// their type; one on a match day or the day after moves to the next free training day of its week
// (else an earlier one; else it stays), and a day left empty by the move rests. Softening is
// one-way; only the match-day rest is undone when the match moves. Returns the adjusted plan plus the changes for the service to persist.

enum MatchDayRules {
    static let matchDayNote = "Match day"
    static let dayBeforeNote = "Light technical: match tomorrow"
    static let dayAfterNote = "Recovery: the day after the match"

    static let lightMaxIntensity = 2
    static let lightMaxMinutes = 30
    static let recoveryIntensity = 1
    static let recoveryMaxMinutes = 30
    /// Sessions at or above this intensity need two clear days from a match.
    static let hardIntensity = 4

    enum Role: Equatable {
        case matchDay
        case dayBefore
        case dayAfter
        case none
    }

    struct DayChange: Equatable {
        let dayID: UUID
        let isRestDay: Bool
        let notes: String?
    }

    struct SessionChange: Equatable {
        let sessionID: UUID
        let sessionType: SessionType
        let duration: Int
        let intensity: Int
        let notes: String?
    }

    struct SessionMove: Equatable {
        let sessionID: UUID
        let toDayID: UUID
        let orderIndex: Int
    }

    struct Changes: Equatable {
        var days: [DayChange] = []
        var sessions: [SessionChange] = []
        var moves: [SessionMove] = []

        var isEmpty: Bool { days.isEmpty && sessions.isEmpty && moves.isEmpty }
    }

    struct Outcome {
        let plan: TrainingPlanModel
        let changes: Changes
    }

    // MARK: Match dates

    /// The dates the rules work from: the profile's next match plus any match logged from yesterday
    /// on (a match played and logged still protects today and the day after it). Older dates drop.
    static func relevantMatchDates(nextMatch: Date?, logged: [Date], now: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: now)
        let cutoff = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var days = Set<Date>()
        for date in ([nextMatch].compactMap { $0 } + logged) {
            let day = calendar.startOfDay(for: date)
            if day >= cutoff { days.insert(day) }
        }
        return days.sorted()
    }

    /// A day's role relative to the matches; match day wins over the day after, which wins over the day before.
    static func role(of date: Date, matchDates: [Date], calendar: Calendar) -> Role {
        let day = calendar.startOfDay(for: date)
        var offsets = Set<Int>()
        for match in matchDates {
            let start = calendar.startOfDay(for: match)
            if let diff = calendar.dateComponents([.day], from: start, to: day).day { offsets.insert(diff) }
        }
        if offsets.contains(0) { return .matchDay }
        if offsets.contains(1) { return .dayAfter }
        if offsets.contains(-1) { return .dayBefore }
        return .none
    }

    // MARK: Apply

    static func apply(to plan: TrainingPlanModel, startDate: Date, matchDates: [Date], now: Date, calendar: Calendar) -> Outcome {
        let today = calendar.startOfDay(for: now)
        var weeks = plan.weeks
        var changes = Changes()

        func dateOf(_ weekIndex: Int, _ dayIndex: Int) -> Date {
            PlanSchedule.date(of: weeks[weekIndex].days[dayIndex], in: weeks[weekIndex], startDate: startDate, calendar: calendar)
        }
        func isOpen(_ day: PlanDayModel, on date: Date) -> Bool {
            date >= today && !day.isCompleted && !day.isSkipped && !day.sessions.contains { $0.isCompleted }
        }
        func roleOf(_ date: Date) -> Role {
            role(of: date, matchDates: matchDates, calendar: calendar)
        }

        // 1. Move assessments off the match day and the day after.
        for wi in weeks.indices {
            for di in weeks[wi].days.indices {
                let day = weeks[wi].days[di]
                let dayDate = dateOf(wi, di)
                let dayRole = roleOf(dayDate)
                // A plain rest day's sessions are not in play; a rules-made match day's still are.
                guard dayRole == .matchDay || dayRole == .dayAfter, isOpen(day, on: dayDate),
                      !day.isRestDay || day.isMatchDay else { continue }
                for session in day.sessions where session.sessionType == .assessment {
                    let candidates = weeks[wi].days.indices.filter { index in
                        guard index != di else { return false }
                        let other = weeks[wi].days[index]
                        let otherDate = dateOf(wi, index)
                        let otherRole = roleOf(otherDate)
                        return !other.isRestDay && isOpen(other, on: otherDate) && otherRole != .matchDay && otherRole != .dayAfter
                    }
                    let later = candidates.filter { dateOf(wi, $0) > dayDate }.min { dateOf(wi, $0) < dateOf(wi, $1) }
                    let earlier = candidates.filter { dateOf(wi, $0) < dayDate }.max { dateOf(wi, $0) < dateOf(wi, $1) }
                    guard let target = later ?? earlier else { continue }
                    weeks[wi].days[di].sessions.removeAll { $0.id == session.id }
                    let orderIndex = weeks[wi].days[target].sessions.count
                    weeks[wi].days[target].sessions.append(session.with(orderIndex: orderIndex))
                    changes.moves.append(SessionMove(sessionID: session.id, toDayID: weeks[wi].days[target].id, orderIndex: orderIndex))
                }
                // A training day left with nothing on it becomes a rest day.
                let source = weeks[wi].days[di]
                if source.sessions.isEmpty && !source.isRestDay {
                    weeks[wi].days[di] = source.with(isRestDay: true, notes: source.notes)
                    changes.days.append(DayChange(dayID: source.id, isRestDay: true, notes: source.notes))
                }
            }
        }

        // 2. Shape each open day by its role.
        for wi in weeks.indices {
            for di in weeks[wi].days.indices {
                let dayDate = dateOf(wi, di)
                var day = weeks[wi].days[di]
                guard isOpen(day, on: dayDate) else { continue }
                let dayRole = roleOf(dayDate)

                if dayRole == .matchDay {
                    if !day.isMatchDay {
                        day = day.with(isRestDay: true, notes: matchDayNote)
                        changes.days.append(DayChange(dayID: day.id, isRestDay: true, notes: matchDayNote))
                    }
                    weeks[wi].days[di] = day
                    continue
                }

                // A day the rules once made a match day, whose match has moved: hand it back.
                if day.isMatchDay {
                    let rest = day.sessions.isEmpty
                    day = day.with(isRestDay: rest, notes: nil)
                    changes.days.append(DayChange(dayID: day.id, isRestDay: rest, notes: nil))
                }

                if !day.isRestDay, dayRole == .dayBefore || dayRole == .dayAfter {
                    for si in day.sessions.indices {
                        let session = day.sessions[si]
                        guard !session.isCompleted, let shaped = shape(session, role: dayRole), shaped != session else { continue }
                        day.sessions[si] = shaped
                        changes.sessions.append(SessionChange(sessionID: shaped.id, sessionType: shaped.sessionType,
                                                              duration: shaped.duration, intensity: shaped.intensity, notes: shaped.notes))
                    }
                }
                weeks[wi].days[di] = day
            }
        }

        var adjusted = plan
        adjusted.weeks = weeks
        return Outcome(plan: adjusted, changes: changes)
    }

    /// The light / recovery version of a session, or nil when it is left alone.
    static func shape(_ session: PlanSessionModel, role: Role) -> PlanSessionModel? {
        switch role {
        case .dayBefore:
            if session.sessionType == .assessment {
                let intensity = min(session.intensity, lightMaxIntensity)
                return intensity == session.intensity ? nil : session.with(intensity: intensity)
            }
            let intensity = max(1, min(session.intensity, lightMaxIntensity))
            let duration = min(session.duration, lightMaxMinutes)
            guard session.sessionType != .technical || intensity != session.intensity || duration != session.duration else { return nil }
            return session.with(type: .technical, duration: duration, intensity: intensity, notes: .some(dayBeforeNote))
        case .dayAfter:
            // An assessment that could not move stays as it is.
            if session.sessionType == .assessment { return nil }
            let duration = min(session.duration, recoveryMaxMinutes)
            guard session.sessionType != .recovery || session.intensity != recoveryIntensity || duration != session.duration else { return nil }
            return session.with(type: .recovery, duration: duration, intensity: recoveryIntensity, notes: .some(dayAfterNote))
        case .matchDay, .none:
            return nil
        }
    }
}

// MARK: - Value copies

extension PlanDayModel {
    func with(isRestDay: Bool, notes: String?) -> PlanDayModel {
        PlanDayModel(id: id, dayNumber: dayNumber, dayOfWeek: dayOfWeek, isRestDay: isRestDay, isSkipped: isSkipped,
                     notes: notes, isCompleted: isCompleted, completedAt: completedAt, sessions: sessions)
    }

    /// The rules turned this day into a match day (rest, "Match day" note).
    var isMatchDay: Bool { isRestDay && notes == MatchDayRules.matchDayNote }
}

extension PlanSessionModel {
    /// A copy with some fields replaced; `notes: .some(nil)` clears the note.
    func with(type: SessionType? = nil, duration: Int? = nil, intensity: Int? = nil, notes: String?? = nil, orderIndex: Int? = nil) -> PlanSessionModel {
        PlanSessionModel(id: id, sessionType: type ?? sessionType, duration: duration ?? self.duration,
                         intensity: intensity ?? self.intensity, orderIndex: orderIndex ?? self.orderIndex,
                         notes: notes ?? self.notes, isCompleted: isCompleted, completedAt: completedAt,
                         actualDuration: actualDuration, actualIntensity: actualIntensity, exerciseIDs: exerciseIDs)
    }
}
