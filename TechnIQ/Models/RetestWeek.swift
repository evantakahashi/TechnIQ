import Foundation

// MARK: - Retest week
//
// Every plan ends with a retest week: the first training day is the 10-minute assessment, the other
// training days are light technical work (the drills from the week before), rest days follow the
// plan's own pattern. Pure so templates and tests share the exact shape; `TrainingPlanService
// .appendRetestWeek(to:)` materialises it on stored plans. Appending is idempotent.

enum RetestWeek {
    static let focusArea = "Retest week"
    static let notes = "Ease off, then test again: same three numbers as your first session."
    static let assessmentMinutes = 10
    static let assessmentIntensity = 3
    static let lightMinutes = 20
    static let lightIntensity = 2
    static let assessmentNote = "Juggling, wall passes, toe taps. Beat your last numbers."
    static let lightNote = "Light touches to stay sharp for the retest."
    /// Light sessions reuse up to this many drills from the week before.
    static let drillsPerLightSession = 2

    /// Training days when the plan has no pattern to copy.
    static let defaultTrainingDays: [DayOfWeek] = [.monday, .wednesday, .friday]

    /// The plan already ends with a retest week.
    static func endsWithRetest(_ weeks: [PlanWeekModel]) -> Bool {
        weeks.max { $0.weekNumber < $1.weekNumber }?.isRetest ?? false
    }

    /// `weeks` with a retest week appended, unless the plan already ends with one.
    static func appending(to weeks: [PlanWeekModel]) -> [PlanWeekModel] {
        guard !endsWithRetest(weeks) else { return weeks }
        return weeks + [week(after: weeks)]
    }

    /// The retest week that follows `weeks`: numbered after the last, copying the last training
    /// week's rest pattern and drills.
    static func week(after weeks: [PlanWeekModel]) -> PlanWeekModel {
        let ordered = weeks.sorted { $0.weekNumber < $1.weekNumber }
        let source = ordered.last { !$0.isRetest && !$0.days.isEmpty }
        let slots = daySlots(from: source)
        let drillPool = (source?.days ?? [])
            .sorted { $0.dayNumber < $1.dayNumber }
            .filter { !$0.isRestDay }
            .flatMap { $0.sessions.sorted { $0.orderIndex < $1.orderIndex } }
            .filter { $0.sessionType != .assessment && !$0.exerciseIDs.isEmpty }
            .map(\.exerciseIDs)

        var trainingIndex = 0
        let days = slots.map { slot -> PlanDayModel in
            var sessions: [PlanSessionModel] = []
            if !slot.isRestDay {
                if trainingIndex == 0 {
                    sessions = [session(.assessment, minutes: assessmentMinutes, intensity: assessmentIntensity,
                                        notes: assessmentNote, exerciseIDs: [])]
                } else {
                    let drills = drillPool.isEmpty ? [] : Array(drillPool[(trainingIndex - 1) % drillPool.count].prefix(drillsPerLightSession))
                    sessions = [session(.technical, minutes: lightMinutes, intensity: lightIntensity,
                                        notes: lightNote, exerciseIDs: drills)]
                }
                trainingIndex += 1
            }
            return PlanDayModel(
                id: UUID(), dayNumber: slot.dayNumber, dayOfWeek: slot.dayOfWeek, isRestDay: slot.isRestDay,
                isSkipped: false, notes: nil, isCompleted: false, completedAt: nil, sessions: sessions
            )
        }
        return PlanWeekModel(
            id: UUID(), weekNumber: (ordered.last?.weekNumber ?? 0) + 1, focusArea: focusArea, notes: notes,
            isCompleted: false, completedAt: nil, days: days, isRetest: true
        )
    }

    struct DaySlot: Equatable {
        let dayNumber: Int
        let dayOfWeek: DayOfWeek?
        let isRestDay: Bool
    }

    /// The source week's days (rest or not), or Mon–Sun with the default training days. Always at
    /// least one training day so the assessment has a home.
    static func daySlots(from week: PlanWeekModel?) -> [DaySlot] {
        var slots: [DaySlot]
        if let days = week?.days, !days.isEmpty {
            slots = days.sorted { $0.dayNumber < $1.dayNumber }.map {
                DaySlot(dayNumber: $0.dayNumber, dayOfWeek: $0.dayOfWeek, isRestDay: $0.isRestDay || $0.sessions.isEmpty)
            }
        } else {
            slots = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }.enumerated().map { index, weekday in
                DaySlot(dayNumber: index + 1, dayOfWeek: weekday, isRestDay: !defaultTrainingDays.contains(weekday))
            }
        }
        if !slots.contains(where: { !$0.isRestDay }), let first = slots.first {
            slots[0] = DaySlot(dayNumber: first.dayNumber, dayOfWeek: first.dayOfWeek, isRestDay: false)
        }
        return slots
    }

    private static func session(_ type: SessionType, minutes: Int, intensity: Int, notes: String, exerciseIDs: [UUID]) -> PlanSessionModel {
        PlanSessionModel(
            id: UUID(), sessionType: type, duration: minutes, intensity: intensity, orderIndex: 0, notes: notes,
            isCompleted: false, completedAt: nil, actualDuration: nil, actualIntensity: nil, exerciseIDs: exerciseIDs
        )
    }
}
