import Foundation
import CoreData

// MARK: - Training Plan UI Models
// Lightweight Swift structs for UI layer, mapped from Core Data entities

struct TrainingPlanModel: Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String
    let durationWeeks: Int
    let difficulty: PlanDifficulty
    let category: PlanCategory
    let targetRole: String?
    let isPrebuilt: Bool
    let isActive: Bool
    let currentWeek: Int
    let progressPercentage: Double
    let startedAt: Date?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var weeks: [PlanWeekModel]

    // Computed properties
    var isCompleted: Bool {
        completedAt != nil
    }

    var totalDays: Int {
        weeks.reduce(0) { $0 + $1.days.count }
    }

    var completedDays: Int {
        weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.filter { $0.isCompleted }.count
        }
    }

    var totalSessions: Int {
        weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.reduce(0) { dayTotal, day in
                dayTotal + day.sessions.count
            }
        }
    }

    var completedSessions: Int {
        weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.reduce(0) { dayTotal, day in
                dayTotal + day.sessions.filter { $0.isCompleted }.count
            }
        }
    }

    var estimatedTotalHours: Double {
        let totalMinutes = weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.reduce(0) { dayTotal, day in
                dayTotal + day.sessions.reduce(0) { sessionTotal, session in
                    sessionTotal + Int(session.duration)
                }
            }
        }
        return Double(totalMinutes) / 60.0
    }
}

struct PlanWeekModel: Identifiable, Hashable {
    let id: UUID
    let weekNumber: Int
    let focusArea: String?
    let notes: String?
    let isCompleted: Bool
    let completedAt: Date?

    var days: [PlanDayModel]

    var totalSessions: Int {
        days.reduce(0) { $0 + $1.sessions.count }
    }

    var completedSessions: Int {
        days.reduce(0) { dayTotal, day in
            dayTotal + day.sessions.filter { $0.isCompleted }.count
        }
    }
}

struct PlanDayModel: Identifiable, Hashable {
    let id: UUID
    let dayNumber: Int
    let dayOfWeek: DayOfWeek?
    let isRestDay: Bool
    let isSkipped: Bool
    let notes: String?
    let isCompleted: Bool
    let completedAt: Date?

    var sessions: [PlanSessionModel]

    var totalDuration: Int {
        sessions.reduce(0) { $0 + Int($1.duration) }
    }

    /// Day is "done" for progression purposes (completed, skipped, or rest)
    var isDone: Bool {
        isCompleted || isSkipped || isRestDay
    }
}

struct PlanSessionModel: Identifiable, Hashable {
    let id: UUID
    let sessionType: SessionType
    let duration: Int
    let intensity: Int
    let orderIndex: Int
    let notes: String?
    let isCompleted: Bool
    let completedAt: Date?
    let actualDuration: Int?
    let actualIntensity: Int?

    var exerciseIDs: [UUID]
}

// MARK: - Enums

enum PlanDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case elite = "Elite"

    var displayName: String { rawValue }

    var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "orange"
        case .elite: return "red"
        }
    }
}

enum PlanCategory: String, CaseIterable {
    case technical = "Technical"
    case physical = "Physical"
    case tactical = "Tactical"
    case general = "General"
    case position = "Position-Specific"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .technical: return "soccerball"
        case .physical: return "figure.run"
        case .tactical: return "brain.head.profile"
        case .general: return "figure.soccer"
        case .position: return "sportscourt"
        }
    }
}

enum SessionType: String, CaseIterable {
    case technical = "Technical"
    case physical = "Physical"
    case tactical = "Tactical"
    case recovery = "Recovery"
    case match = "Match"
    case warmup = "Warmup"
    case cooldown = "Cooldown"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .technical: return "soccerball"
        case .physical: return "figure.run"
        case .tactical: return "brain.head.profile"
        case .recovery: return "bed.double.fill"
        case .match: return "sportscourt"
        case .warmup: return "flame.fill"
        case .cooldown: return "snowflake"
        }
    }
}

enum DayOfWeek: String, CaseIterable, Comparable {
    case monday = "Monday"
    case tuesday = "Tuesday"
    case wednesday = "Wednesday"
    case thursday = "Thursday"
    case friday = "Friday"
    case saturday = "Saturday"
    case sunday = "Sunday"

    var displayName: String { rawValue }
    var shortName: String {
        String(rawValue.prefix(3))
    }

    var sortOrder: Int {
        switch self {
        case .monday: return 0
        case .tuesday: return 1
        case .wednesday: return 2
        case .thursday: return 3
        case .friday: return 4
        case .saturday: return 5
        case .sunday: return 6
        }
    }

    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - Core Data Conversion Extensions

extension TrainingPlan {
    func toModel() -> TrainingPlanModel {
        let weeksArray = (weeks?.allObjects as? [PlanWeek])?.sorted { $0.weekNumber < $1.weekNumber } ?? []

        return TrainingPlanModel(
            id: id ?? UUID(),
            name: name ?? "",
            description: planDescription ?? "",
            durationWeeks: Int(durationWeeks),
            difficulty: PlanDifficulty(rawValue: difficulty ?? "Beginner") ?? .beginner,
            category: PlanCategory(rawValue: category ?? "General") ?? .general,
            targetRole: targetRole,
            isPrebuilt: isPrebuilt,
            isActive: isActive,
            currentWeek: Int(currentWeek),
            progressPercentage: progressPercentage,
            startedAt: startedAt,
            completedAt: completedAt,
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date(),
            weeks: weeksArray.map { $0.toModel() }
        )
    }
}

extension PlanWeek {
    func toModel() -> PlanWeekModel {
        let daysArray = (days?.allObjects as? [PlanDay])?.sorted { $0.dayNumber < $1.dayNumber } ?? []

        return PlanWeekModel(
            id: id ?? UUID(),
            weekNumber: Int(weekNumber),
            focusArea: focusArea,
            notes: notes,
            isCompleted: isCompleted,
            completedAt: completedAt,
            days: daysArray.map { $0.toModel() }
        )
    }
}

extension PlanDay {
    func toModel() -> PlanDayModel {
        let sessionsArray = (sessions?.allObjects as? [PlanSession])?
            .sorted { $0.orderIndex < $1.orderIndex } ?? []

        return PlanDayModel(
            id: id ?? UUID(),
            dayNumber: Int(dayNumber),
            dayOfWeek: dayOfWeek.flatMap { DayOfWeek(rawValue: $0) },
            isRestDay: isRestDay,
            isSkipped: isSkipped,
            notes: notes,
            isCompleted: isCompleted,
            completedAt: completedAt,
            sessions: sessionsArray.map { $0.toModel() }
        )
    }
}

extension PlanSession {
    func toModel() -> PlanSessionModel {
        let exercisesArray = (exercises?.allObjects as? [Exercise]) ?? []

        return PlanSessionModel(
            id: id ?? UUID(),
            sessionType: SessionType(rawValue: sessionType ?? "Technical") ?? .technical,
            duration: Int(duration),
            intensity: Int(intensity),
            orderIndex: Int(orderIndex),
            notes: notes,
            isCompleted: isCompleted,
            completedAt: completedAt,
            actualDuration: actualDuration > 0 ? Int(actualDuration) : nil,
            actualIntensity: actualIntensity > 0 ? Int(actualIntensity) : nil,
            exerciseIDs: exercisesArray.compactMap { $0.id }
        )
    }
}

// MARK: - AI-Generated Plan Models

struct GeneratedPlanStructure: Codable {
    let name: String
    let description: String
    let difficulty: String
    let category: String
    let targetRole: String?
    let weeks: [GeneratedWeek]

    var parsedDifficulty: PlanDifficulty {
        PlanDifficulty(rawValue: difficulty) ?? .intermediate
    }

    var parsedCategory: PlanCategory {
        PlanCategory(rawValue: category) ?? .general
    }
}

struct GeneratedWeek: Codable {
    let weekNumber: Int
    let focusArea: String
    let notes: String?
    let days: [GeneratedDay]
}

struct GeneratedDay: Codable {
    let dayNumber: Int
    let dayOfWeek: String
    let isRestDay: Bool
    let notes: String?
    let sessions: [GeneratedSession]

    var parsedDayOfWeek: DayOfWeek? {
        DayOfWeek(rawValue: dayOfWeek)
    }
}

struct GeneratedSession: Codable {
    let sessionType: String
    let duration: Int
    let intensity: Int
    let notes: String?
    let suggestedExerciseNames: [String]

    var parsedSessionType: SessionType {
        SessionType(rawValue: sessionType) ?? .technical
    }
}

// MARK: - Plan Update Models

struct PlanUpdates {
    var name: String?
    var description: String?
    var difficulty: PlanDifficulty?
    var category: PlanCategory?
    var targetRole: String?
    var weeksToAdd: [PlanWeekData]?
    var weeksToRemove: [UUID]?
    var daysToUpdate: [DayUpdate]?
    var sessionsToUpdate: [SessionUpdate]?
}

struct PlanWeekData {
    let weekNumber: Int
    let focusArea: String?
    let notes: String?
    let days: [PlanDayData]
}

struct PlanDayData {
    let dayNumber: Int
    let dayOfWeek: DayOfWeek?
    let isRestDay: Bool
    let notes: String?
    let sessions: [PlanSessionData]
}

struct PlanSessionData {
    let sessionType: SessionType
    let duration: Int
    let intensity: Int
    let notes: String?
    let exerciseIDs: [UUID]
}

struct DayUpdate {
    let dayID: UUID
    let isRestDay: Bool?
    let notes: String?
    let sessionsToAdd: [PlanSessionData]?
}

struct SessionUpdate {
    let sessionID: UUID
    let sessionType: SessionType?
    let duration: Int?
    let intensity: Int?
    let notes: String?
    let exerciseIDs: [UUID]?
}
