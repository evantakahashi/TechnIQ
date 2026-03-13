import SwiftUI

// MARK: - Feature Icon Content

enum FeatureIconContent {
    case sfSymbol(name: String, color: Color)
    case multiIcon(icons: [(name: String, color: Color)])
}

// MARK: - Feature Highlight Model

struct FeatureHighlight: Identifiable {
    let id = UUID()
    let headline: String
    let body: String
    let mascotState: MascotState
    let speechText: String
    let iconContent: FeatureIconContent
}

// MARK: - Onboarding Highlights Data

extension FeatureHighlight {
    static let onboardingHighlights: [FeatureHighlight] = [
        FeatureHighlight(
            headline: "Smart Drills, Built for You",
            body: "AI generates personalized drills based on your position, skill level, and weaknesses",
            mascotState: .coaching,
            speechText: "Let's train smarter!",
            iconContent: .sfSymbol(
                name: "brain.head.profile",
                color: DesignSystem.Colors.primaryGreen
            )
        ),
        FeatureHighlight(
            headline: "Level Up Your Game",
            body: "Earn XP, build streaks, unlock achievements. 50 levels from Grassroots to Living Legend",
            mascotState: .excited,
            speechText: "Every session counts!",
            iconContent: .multiIcon(icons: [
                ("star.fill", DesignSystem.Colors.xpGold),
                ("flame.fill", DesignSystem.Colors.streakOrange),
                ("trophy.fill", DesignSystem.Colors.accentGold)
            ])
        ),
        FeatureHighlight(
            headline: "Make It Yours",
            body: "Customize your player avatar. Earn coins from training to unlock gear",
            mascotState: .happy,
            speechText: "Looking good!",
            iconContent: .multiIcon(icons: [
                ("person.crop.circle.fill", DesignSystem.Colors.primaryGreen),
                ("tshirt.fill", DesignSystem.Colors.secondaryBlue),
                ("shoe.fill", DesignSystem.Colors.accentOrange)
            ])
        )
    ]
}

// MARK: - Feature Highlight Page View

struct FeatureHighlightPage: View {
    let highlight: FeatureHighlight

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()

            // Mascot
            MascotView(
                state: highlight.mascotState,
                size: .large,
                showSpeechBubble: true,
                speechText: highlight.speechText
            )

            // Icon visual
            iconView
                .padding(.vertical, DesignSystem.Spacing.md)

            // Headline
            Text(highlight.headline)
                .font(DesignSystem.Typography.displaySmall)
                .bold()
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            // Body
            Text(highlight.body)
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    // MARK: - Icon View

    @ViewBuilder
    private var iconView: some View {
        switch highlight.iconContent {
        case .sfSymbol(let name, let color):
            Image(systemName: name)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(color)
                .frame(width: 80, height: 80)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(color.opacity(0.15))
                )

        case .multiIcon(let icons):
            HStack(spacing: DesignSystem.Spacing.md) {
                ForEach(Array(icons.enumerated()), id: \.offset) { _, icon in
                    Image(systemName: icon.name)
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(icon.color)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(icon.color.opacity(0.15))
                        )
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    FeatureHighlightPage(highlight: FeatureHighlight.onboardingHighlights[0])
}
