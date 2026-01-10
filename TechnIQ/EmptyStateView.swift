import SwiftUI

/// Reusable empty state component with mascot and encouraging messaging
/// Used throughout the app when there's no data to display
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
            // Mascot
            MascotView(
                state: MascotState.forEmptyState(context: context),
                size: .large,
                showSpeechBubble: true,
                speechText: speechBubbleText
            )

            // Title
            Text(title)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            // Action button (if provided)
            if let title = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: actionIcon)
                        Text(title)
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .padding(.top, DesignSystem.Spacing.sm)
            }
        }
        .padding(DesignSystem.Spacing.xl)
    }

    // MARK: - Content Properties

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
        }
    }

    private var speechBubbleText: String {
        switch context {
        case .noSessions:
            return "Let's go!"
        case .noFavorites:
            return "Find your favorites!"
        case .noAchievements:
            return "You can do it!"
        case .noProgress:
            return "Every pro started here!"
        case .noPlans:
            return "Plan to succeed!"
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
        }
    }
}

// MARK: - Compact Empty State

/// A more compact empty state for use in cards or smaller areas
struct CompactEmptyStateView: View {
    let context: EmptyStateContext
    let showMascot: Bool

    init(context: EmptyStateContext, showMascot: Bool = true) {
        self.context = context
        self.showMascot = showMascot
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if showMascot {
                MascotView(
                    state: MascotState.forEmptyState(context: context),
                    size: .small
                )
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
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
        }
    }
}

// MARK: - Loading State

/// Loading state view with thinking mascot
struct LoadingStateView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            MascotView(state: .thinking, size: .medium)

            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ProgressView()
                .tint(DesignSystem.Colors.primaryGreen)
        }
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Error State

/// Error state view with disappointed mascot
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
            MascotView(state: .disappointed, size: .large)

            Text(title)
                .font(DesignSystem.Typography.titleLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            if let retry = retryAction {
                Button(action: retry) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .padding(.top, DesignSystem.Spacing.sm)
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
            MascotView(
                state: MascotState.forWelcomeBack(daysInactive: daysInactive),
                size: .xlarge,
                showSpeechBubble: true,
                speechText: welcomeMessage
            )

            Text("Welcome Back!")
                .font(DesignSystem.Typography.headlineMedium)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(motivationalMessage)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Button(action: onStartTraining) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "play.fill")
                    Text("Start Training")
                }
                .font(DesignSystem.Typography.labelLarge)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, DesignSystem.Spacing.xl)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primaryGreen)
                .cornerRadius(DesignSystem.CornerRadius.button)
            }
            .padding(.top, DesignSystem.Spacing.md)
        }
        .padding(DesignSystem.Spacing.xl)
    }

    private var welcomeMessage: String {
        if daysInactive >= 7 {
            return "I missed you!"
        } else if daysInactive >= 3 {
            return "Ready to train?"
        } else {
            return "Hey there!"
        }
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
