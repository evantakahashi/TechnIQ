import SwiftUI

struct TodaysFocusCard: View {
    let coaching: DailyCoaching
    let isStale: Bool
    let onStartDrill: () -> Void
    let onBrowseLibrary: () -> Void

    var body: some View {
        ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.primaryGreen) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Header
                HStack {
                    Image(systemName: "scope")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("TODAY'S FOCUS")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .fontWeight(.bold)

                    Spacer()

                    if isStale {
                        Text("Updated yesterday")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }

                // AI Reasoning
                Text(coaching.reasoning)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Drill Preview Card
                drillPreview

                // Tips
                if let firstTip = coaching.additionalTips.first {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "lightbulb.fill")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Text(firstTip)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ModernButton("Start Drill", icon: "play.fill", style: .primary) {
                        onStartDrill()
                    }

                    ModernButton("Browse Library", icon: "books.vertical", style: .ghost) {
                        onBrowseLibrary()
                    }
                }
            }
        }
        .a11y(
            label: "Today's focus: \(coaching.focusArea). \(coaching.reasoning)",
            trait: .isStaticText
        )
    }

    private var drillPreview: some View {
        let drill = coaching.recommendedDrill

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(drill.name)
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.semibold)

            HStack(spacing: DesignSystem.Spacing.md) {
                Text(drill.category.capitalized)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { i in
                        Image(systemName: i < drill.difficulty ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    }
                }

                Text("\(drill.duration) min")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Skill tags
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(drill.targetSkills.prefix(3), id: \.self) { skill in
                    Text(skill)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceOverlay)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }
}

// MARK: - Loading Skeleton

struct TodaysFocusCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.primaryGreen) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(DesignSystem.Colors.surfaceHighlight)
                        .frame(width: 140, height: 16)
                    Spacer()
                }

                RoundedRectangle(cornerRadius: 4)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 40)

                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 80)

                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.surfaceHighlight)
                    .frame(height: 44)
            }
            .opacity(isAnimating ? 0.4 : 0.8)
            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
        }
    }
}
