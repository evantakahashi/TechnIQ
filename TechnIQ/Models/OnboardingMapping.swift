import Foundation

// MARK: - OnboardingMapping
//
// Pure mappings behind the onboarding answers (Touchline 7b): experience → plan difficulty,
// goal → plan category, frequency → training/rest days, and the numeric field validation for
// age and kit number. Kept out of the view so they are unit-testable.

enum OnboardingMapping {
    static let goals = ["Improve Skills", "Build Fitness", "Prepare for Tryouts", "Stay Active", "Become Pro"]
    static let frequencies = ["2-3x per week", "3-4x per week", "5-6x per week", "Daily"]
    static let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    static let feet = ["Left", "Right", "Both"]
    static let experienceLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]

    static let ageRange = 5...80
    static let kitNumberRange = 1...99
    static let maxWeakSpots = 3

    static func difficulty(forExperience experience: String) -> String {
        switch experience {
        case "Beginner": return PlanDifficulty.beginner.rawValue
        case "Intermediate": return PlanDifficulty.intermediate.rawValue
        case "Advanced": return PlanDifficulty.advanced.rawValue
        case "Professional": return PlanDifficulty.elite.rawValue
        default: return PlanDifficulty.intermediate.rawValue
        }
    }

    static func category(forGoal goal: String) -> String {
        switch goal {
        case "Improve Skills": return PlanCategory.technical.rawValue
        case "Build Fitness": return PlanCategory.physical.rawValue
        case "Prepare for Tryouts": return PlanCategory.general.rawValue
        case "Stay Active": return PlanCategory.general.rawValue
        case "Become Pro": return PlanCategory.technical.rawValue
        default: return PlanCategory.general.rawValue
        }
    }

    static func preferredDays(forFrequency frequency: String) -> [String] {
        switch frequency {
        case "2-3x per week": return ["Monday", "Wednesday", "Friday"]
        case "3-4x per week": return ["Monday", "Tuesday", "Thursday", "Friday"]
        case "5-6x per week": return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        case "Daily": return DayOfWeek.allCases.map(\.rawValue)
        default: return ["Monday", "Wednesday", "Friday"]
        }
    }

    /// Every weekday that is not a preferred training day.
    static func restDays(forFrequency frequency: String) -> [String] {
        let preferred = Set(preferredDays(forFrequency: frequency))
        return DayOfWeek.allCases.map(\.rawValue).filter { !preferred.contains($0) }
    }

    /// Keeps only digits, capped at `maxDigits` characters (number-pad fields).
    static func digits(_ text: String, maxDigits: Int) -> String {
        String(text.filter(\.isNumber).prefix(maxDigits))
    }

    static func age(from text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), ageRange.contains(value) else { return nil }
        return value
    }

    static func kitNumber(from text: String) -> Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespaces)), kitNumberRange.contains(value) else { return nil }
        return value
    }

    /// The name shown to other players: trimmed input, else the account display name, else "Player".
    static func resolvedName(entered: String, accountName: String) -> String {
        let trimmed = entered.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        let fallback = accountName.trimmingCharacters(in: .whitespaces)
        return fallback.isEmpty ? "Player" : fallback
    }
}
