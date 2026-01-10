import Foundation

/// Mascot emotion states for "Kicko" - the TechnIQ mascot character
/// These states are used to display contextually appropriate mascot expressions
/// throughout the app to create emotional connection with users.
enum MascotState: String, CaseIterable, Identifiable {
    case happy
    case excited
    case proud
    case encouraging
    case thinking
    case celebrating
    case tired
    case disappointed
    case surprised
    case coaching
    case sleeping
    case waving

    var id: String { rawValue }

    // MARK: - Display Properties

    /// Human-readable name for the state
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .excited: return "Excited"
        case .proud: return "Proud"
        case .encouraging: return "Encouraging"
        case .thinking: return "Thinking"
        case .celebrating: return "Celebrating"
        case .tired: return "Tired"
        case .disappointed: return "Disappointed"
        case .surprised: return "Surprised"
        case .coaching: return "Coaching"
        case .sleeping: return "Sleeping"
        case .waving: return "Waving"
        }
    }

    /// Description of when this state is typically used
    var usageDescription: String {
        switch self {
        case .happy: return "Default cheerful state"
        case .excited: return "Achievements, milestones, rewards"
        case .proud: return "Level ups, skill improvements"
        case .encouraging: return "Motivation, nudges, tips"
        case .thinking: return "Loading states, processing"
        case .celebrating: return "Streaks, major accomplishments"
        case .tired: return "Rest days, break reminders"
        case .disappointed: return "Streak lost (empathetic, not judgmental)"
        case .surprised: return "Unexpected rewards, bonuses"
        case .coaching: return "Tips, tutorials, guidance"
        case .sleeping: return "Inactive user nudge"
        case .waving: return "Welcome, greetings, app launch"
        }
    }

    /// SF Symbol fallback when mascot images aren't available
    var sfSymbolFallback: String {
        switch self {
        case .happy: return "face.smiling.fill"
        case .excited: return "star.fill"
        case .proud: return "medal.fill"
        case .encouraging: return "hand.thumbsup.fill"
        case .thinking: return "brain.head.profile"
        case .celebrating: return "party.popper.fill"
        case .tired: return "moon.zzz.fill"
        case .disappointed: return "cloud.rain.fill"
        case .surprised: return "exclamationmark.circle.fill"
        case .coaching: return "figure.soccer"
        case .sleeping: return "zzz"
        case .waving: return "hand.wave.fill"
        }
    }

    /// Primary color associated with this state
    var accentColorName: String {
        switch self {
        case .happy, .encouraging, .waving: return "primaryGreen"
        case .excited, .celebrating, .surprised: return "accentYellow"
        case .proud: return "accentPurple"
        case .thinking, .coaching: return "secondaryBlue"
        case .tired, .sleeping: return "accentLavender"
        case .disappointed: return "accentOrange"
        }
    }

    // MARK: - Context-Based State Selection

    /// Get the appropriate mascot state for achievement unlocks
    static func forAchievement() -> MascotState {
        return .excited
    }

    /// Get the appropriate mascot state for level ups
    static func forLevelUp() -> MascotState {
        return .proud
    }

    /// Get the appropriate mascot state for streak milestones
    static func forStreakMilestone() -> MascotState {
        return .celebrating
    }

    /// Get the appropriate mascot state when streak is lost
    static func forStreakLost() -> MascotState {
        return .disappointed
    }

    /// Get the appropriate mascot state for session completion
    static func forSessionComplete(isFirstOfDay: Bool = false) -> MascotState {
        return isFirstOfDay ? .excited : .happy
    }

    /// Get the appropriate mascot state for onboarding
    static func forOnboarding(screenIndex: Int) -> MascotState {
        switch screenIndex {
        case 0: return .waving
        case 1: return .coaching
        case 2...4: return .encouraging
        case 5: return .proud
        default: return .happy
        }
    }

    /// Get the appropriate mascot state for empty states
    static func forEmptyState(context: EmptyStateContext) -> MascotState {
        switch context {
        case .noSessions: return .coaching
        case .noFavorites: return .encouraging
        case .noAchievements: return .excited
        case .noProgress: return .encouraging
        case .noPlans: return .thinking
        }
    }

    /// Get the appropriate mascot state based on time of day
    static func forTimeOfDay() -> MascotState {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<9: return .waving
        case 9..<12: return .happy
        case 12..<14: return .encouraging
        case 14..<18: return .coaching
        case 18..<21: return .happy
        case 21..<24, 0..<5: return .tired
        default: return .happy
        }
    }

    /// Get the appropriate mascot state for loading screens
    static func forLoading() -> MascotState {
        return .thinking
    }

    /// Get the appropriate mascot state for welcome back after inactivity
    static func forWelcomeBack(daysInactive: Int) -> MascotState {
        if daysInactive >= 7 {
            return .sleeping
        } else if daysInactive >= 3 {
            return .tired
        } else {
            return .waving
        }
    }
}

// MARK: - Supporting Types

/// Context types for empty state mascot selection
enum EmptyStateContext {
    case noSessions
    case noFavorites
    case noAchievements
    case noProgress
    case noPlans
}
