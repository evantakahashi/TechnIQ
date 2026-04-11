import SwiftUI

/// Reusable empty state component with bold SF Symbol + compressed display typography.
struct EmptyStateView: View {
    let context: EmptyStateContext
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        context: EmptyStateContext,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.context = context
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: symbolName)
                .font(.system(size: 96, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite.opacity(0.85))

            PitchDivider(horizontalPadding: 48)

            Text(title)
                .font(DesignSystem.Typography.displayMedium)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .multilineTextAlignment(.center)

            Text(description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if let title = actionTitle, let action = action {
                ModernButton(title, icon: actionIcon, style: .primary, action: action)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Content Properties

    private var symbolName: String {
        switch context {
        case .noSessions: return "soccerball"
        case .noFavorites: return "heart"
        case .noAchievements: return "trophy"
        case .noProgress: return "chart.line.uptrend.xyaxis"
        case .noPlans: return "calendar"
        case .noPosts: return "bubble.left.and.bubble.right"
        }
    }

    private var title: String {
        switch context {
        case .noSessions:
            return "Ready to Train?"
        case .noFavorites:
            return "No Favorites Yet"
        case .noAchievements:
            return "Achievements Await!"
        case .noProgress:
            return "Start Your Journey"
        case .noPlans:
            return "No Training Plans"
        case .noPosts:
            return "No Posts Yet"
        }
    }

    private var description: String {
        switch context {
        case .noSessions:
            return "Complete your first training session to start tracking your progress and earning XP!"
        case .noFavorites:
            return "Tap the heart icon on any exercise to save it here for quick access."
        case .noAchievements:
            return "Train regularly to unlock achievements and show off your dedication!"
        case .noProgress:
            return "Complete training sessions to see your skill improvements over time."
        case .noPlans:
            return "Create a personalized training plan to structure your practice."
        case .noPosts:
            return "Be the first to share something with the community!"
        }
    }

    private var actionIcon: String {
        switch context {
        case .noSessions:
            return "play.fill"
        case .noFavorites:
            return "book.fill"
        case .noAchievements:
            return "trophy.fill"
        case .noProgress:
            return "chart.line.uptrend.xyaxis"
        case .noPlans:
            return "calendar.badge.plus"
        case .noPosts:
            return "square.and.pencil"
        }
    }
}

// MARK: - Compact Empty State

/// A more compact empty state for use in cards or smaller areas
struct CompactEmptyStateView: View {
    let context: EmptyStateContext

    init(context: EmptyStateContext) {
        self.context = context
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: symbolName)
                .font(.system(size: 32, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite.opacity(0.7))
                .frame(width: 40)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.labelLarge)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)

                Text(subtitle)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.mutedIvory)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
    }

    private var symbolName: String {
        switch context {
        case .noSessions: return "soccerball"
        case .noFavorites: return "heart"
        case .noAchievements: return "trophy"
        case .noProgress: return "chart.line.uptrend.xyaxis"
        case .noPlans: return "calendar"
        case .noPosts: return "bubble.left.and.bubble.right"
        }
    }

    private var title: String {
        switch context {
        case .noSessions:
            return "No sessions yet"
        case .noFavorites:
            return "No favorites"
        case .noAchievements:
            return "No achievements"
        case .noProgress:
            return "No data yet"
        case .noPlans:
            return "No plans"
        case .noPosts:
            return "No posts yet"
        }
    }

    private var subtitle: String {
        switch context {
        case .noSessions:
            return "Start training to see data here"
        case .noFavorites:
            return "Heart your favorite exercises"
        case .noAchievements:
            return "Keep training to unlock"
        case .noProgress:
            return "Complete sessions to track"
        case .noPlans:
            return "Create a training plan"
        case .noPosts:
            return "Share with the community"
        }
    }
}

// MARK: - Loading State

/// Loading state view with a rotating soccer ball icon.
struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            SoccerBallSpinner()
                .scaleEffect(2.0)

            Text(message)
                .font(DesignSystem.Typography.displaySmall)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Error State

/// Error state view with warning icon and retry action.
struct ErrorStateView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?

    init(
        title: String = "Something went wrong",
        message: String = "We couldn't load the data. Please try again.",
        retryAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 96, weight: .regular))
                .foregroundColor(DesignSystem.Colors.bloodOrange)

            PitchDivider(horizontalPadding: 48)

            Text(title)
                .font(DesignSystem.Typography.displayMedium)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .multilineTextAlignment(.center)

            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if let retry = retryAction {
                ModernButton("Try Again", icon: "arrow.clockwise", style: .primary, action: retry)
                    .padding(.top, DesignSystem.Spacing.sm)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Welcome Back State

/// Welcome back state for returning users after inactivity
struct WelcomeBackView: View {
    let daysInactive: Int
    let onStartTraining: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "figure.soccer")
                .font(.system(size: 120, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite)

            PitchDivider(horizontalPadding: 48)

            Text("WELCOME BACK")
                .font(DesignSystem.Typography.displayLarge)
                .foregroundColor(DesignSystem.Colors.chalkWhite)

            Text(motivationalMessage)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            ModernButton("Start Training", icon: "play.fill", style: .primary, action: onStartTraining)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private var motivationalMessage: String {
        if daysInactive >= 7 {
            return "It's been a while! No worries - every champion takes breaks. Let's pick up where we left off!"
        } else if daysInactive >= 3 {
            return "A few days off is normal. Ready to get back into the rhythm?"
        } else {
            return "Good to see you again! Let's keep building on your progress."
        }
    }
}

// MARK: - Previews

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 40) {
            EmptyStateView(
                context: .noSessions,
                actionTitle: "Start Training",
                action: {}
            )

            Divider()

            EmptyStateView(
                context: .noFavorites,
                actionTitle: "Browse Exercises",
                action: {}
            )

            Divider()

            EmptyStateView(context: .noAchievements)
        }
    }
}

#Preview("Compact Empty States") {
    VStack(spacing: 20) {
        ModernCard {
            CompactEmptyStateView(context: .noSessions)
        }

        ModernCard {
            CompactEmptyStateView(context: .noFavorites)
        }

        ModernCard {
            CompactEmptyStateView(context: .noProgress)
        }
    }
    .padding()
}

#Preview("Loading & Error") {
    VStack(spacing: 40) {
        LoadingStateView(message: "Fetching your data...")

        Divider()

        ErrorStateView(retryAction: {})
    }
}

#Preview("Welcome Back") {
    WelcomeBackView(daysInactive: 7, onStartTraining: {})
}
