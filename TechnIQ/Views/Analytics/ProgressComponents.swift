import SwiftUI

// MARK: - Supporting Views

struct SkillProgressRow: View {
    let skill: SkillProgress

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(skill.skillName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    if skill.change > 0 {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("+\(String(format: "%.1f", skill.change))")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    } else if skill.change < 0 {
                        Image(systemName: "arrow.down.right")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                        Text("\(String(format: "%.1f", skill.change))")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                    }

                    Text(String(format: "%.1f", skill.currentLevel))
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("/ 5.0")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(DesignSystem.Colors.neutral300)
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(progressColor(for: skill.currentLevel))
                        .frame(width: geometry.size.width * (skill.currentLevel / 5.0), height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .customShadow(DesignSystem.Shadow.small)
    }

    private func progressColor(for level: Double) -> Color {
        switch level {
        case 0..<2.0: return DesignSystem.Colors.accentOrange
        case 2.0..<3.5: return DesignSystem.Colors.accentYellow
        case 3.5...5.0: return DesignSystem.Colors.primaryGreen
        default: return DesignSystem.Colors.secondaryBlue
        }
    }
}

struct AchievementCard: View {
    let achievement: ProgressAchievement

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(achievement.color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.system(size: 20))
                    .foregroundColor(achievement.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(achievement.description)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .customShadow(DesignSystem.Shadow.small)
    }
}

struct CategoryBar: View {
    let category: String
    let percentage: Double
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: iconForCategory)
                    .font(.system(size: 16))
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(category)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(Int(percentage))%")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(color)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(DesignSystem.Colors.neutral300)
                            .frame(height: 6)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: geometry.size.width * (percentage / 100.0), height: 6)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .customShadow(DesignSystem.Shadow.small)
    }

    private var iconForCategory: String {
        switch category.lowercased() {
        case "technical": return "figure.soccer"
        case "physical": return "heart.fill"
        case "tactical": return "brain.head.profile"
        default: return "sportscourt"
        }
    }
}

// MARK: - Insight Card

struct InsightCard: View {
    let insight: TrainingInsight

    private var cardColor: Color {
        switch insight.color {
        case "primaryGreen":
            return DesignSystem.Colors.primaryGreen
        case "secondaryBlue":
            return DesignSystem.Colors.secondaryBlue
        case "accentOrange":
            return DesignSystem.Colors.accentOrange
        case "accentYellow":
            return DesignSystem.Colors.accentYellow
        case "error":
            return DesignSystem.Colors.error
        default:
            return DesignSystem.Colors.neutral400
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(cardColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: insight.icon)
                    .font(.system(size: 20))
                    .foregroundColor(cardColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    // Priority badge for high priority items
                    if insight.priority >= 8 {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(cardColor)
                    }
                }

                Text(insight.description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Actionable suggestion
                if let actionable = insight.actionable {
                    HStack(spacing: 4) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption2)
                            .foregroundColor(cardColor)

                        Text(actionable)
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(cardColor)
                            .fontWeight(.medium)
                    }
                    .padding(.top, 4)
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }
}
