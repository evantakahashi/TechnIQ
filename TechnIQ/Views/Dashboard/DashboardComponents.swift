import SwiftUI
import CoreData

struct ModernActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(disabled ? 0.08 : 0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(disabled ? color.opacity(0.4) : color)
                }

                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(disabled ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(isPressed ? DesignSystem.Shadow.small : DesignSystem.Shadow.medium)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(disabled ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .allowsHitTesting(!disabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !disabled { isPressed = pressing }
        }, perform: {})
    }
}

struct ModernSessionRow: View {
    let session: TrainingSession

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Session Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: DesignSystem.Icons.training)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(session.sessionType ?? "Training")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)

                Text(formatDate(session.date ?? Date()))
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text("\(Int(session.duration))min")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)

                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < session.overallRating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct ModernRecommendationRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(color)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)

                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

struct SmartRecommendationRow: View {
    let recommendation: YouTubeService.DrillRecommendation
    @State private var showingPhysicalDetails = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.1))
                        .frame(width: 40, height: 40)

                    Image(systemName: categoryIcon)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(categoryColor)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(recommendation.exercise.name ?? "Drill")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .fontWeight(.medium)

                        Spacer()

                        if recommendation.priority == 1 {
                            Text("HIGH")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.error)
                                .cornerRadius(4)
                        }
                    }

                    Text(recommendation.reason)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    // Physical Indicators Row
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.intensity.displayName,
                            color: intensityColor,
                            icon: "gauge"
                        )

                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.duration.displayName,
                            color: DesignSystem.Colors.secondaryBlue,
                            icon: "clock"
                        )

                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.heartRateZone.shortName,
                            color: DesignSystem.Colors.accentOrange,
                            icon: "heart.fill"
                        )

                        Spacer()

                        Button(action: {
                            showingPhysicalDetails.toggle()
                        }) {
                            Image(systemName: showingPhysicalDetails ? "chevron.up" : "info.circle")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                    }

                    HStack {
                        Text("Level \(recommendation.exercise.difficulty)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Text(String(format: "%.0f%% match", recommendation.confidenceScore * 100))
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Expandable Physical Details
            if showingPhysicalDetails {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Physical Demands
                    if !recommendation.physicalIndicators.physicalDemands.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Physical Demands")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 4) {
                                ForEach(recommendation.physicalIndicators.physicalDemands.prefix(6), id: \.rawValue) { demand in
                                    HStack(spacing: 4) {
                                        Image(systemName: demand.icon)
                                            .font(.caption2)
                                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                                        Text(demand.rawValue)
                                            .font(DesignSystem.Typography.labelSmall)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                    }

                    // Recovery Information
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                            Text(recommendation.physicalIndicators.recoveryTime.displayName)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Heart Rate")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                            Text(recommendation.physicalIndicators.heartRateZone.percentageRange)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.neutral100.opacity(0.5))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .animation(DesignSystem.Animation.smooth, value: showingPhysicalDetails)
    }

    private var categoryColor: Color {
        switch recommendation.category {
        case .skillGap:
            return DesignSystem.Colors.error
        case .difficultyProgression:
            return DesignSystem.Colors.primaryGreen
        case .varietyBalance:
            return DesignSystem.Colors.accentOrange
        case .repeatSuccess:
            return DesignSystem.Colors.accentYellow
        case .complementarySkill:
            return DesignSystem.Colors.secondaryBlue
        }
    }

    private var categoryIcon: String {
        switch recommendation.category {
        case .skillGap:
            return "target"
        case .difficultyProgression:
            return "arrow.up.circle"
        case .varietyBalance:
            return "shuffle"
        case .repeatSuccess:
            return "star.circle"
        case .complementarySkill:
            return "link.circle"
        }
    }

    private var intensityColor: Color {
        switch recommendation.physicalIndicators.intensity.color {
        case "green":
            return DesignSystem.Colors.primaryGreen
        case "yellow":
            return DesignSystem.Colors.accentYellow
        case "orange":
            return DesignSystem.Colors.accentOrange
        case "red":
            return DesignSystem.Colors.error
        case "purple":
            return Color.purple
        default:
            return DesignSystem.Colors.primaryGreen
        }
    }
}

struct PhysicalIndicatorChip: View {
    let text: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Daily Goal Card

struct DailyGoalCard: View {
    let sessionsToday: Int
    let dailyGoal: Int
    let onStartSession: () -> Void

    private var progress: Double {
        min(1.0, Double(sessionsToday) / Double(dailyGoal))
    }

    private var isGoalComplete: Bool {
        sessionsToday >= dailyGoal
    }

    var body: some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Circular Progress Ring
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isGoalComplete ? DesignSystem.Colors.successGreen : DesignSystem.Colors.primaryGreen,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                    // Center content
                    VStack(spacing: 0) {
                        if isGoalComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.successGreen)
                        } else {
                            Text("\(sessionsToday)")
                                .font(DesignSystem.Typography.headlineMedium)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("/\(dailyGoal)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                // Goal Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(isGoalComplete ? "Goal Complete!" : "Today's Goal")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(isGoalComplete ? DesignSystem.Colors.successGreen : DesignSystem.Colors.textSecondary)

                    Text(isGoalComplete ? "Great work today!" : "Complete \(dailyGoal) session\(dailyGoal == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.semibold)

                    if !isGoalComplete {
                        Text("\(dailyGoal - sessionsToday) more to go")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Action button
                FloatingActionButton(
                    icon: isGoalComplete ? "plus" : "play.fill"
                ) {
                    onStartSession()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(
                    isGoalComplete ? DesignSystem.Colors.successGreen.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isGoalComplete)
    }
}

// MARK: - Enhanced Stats Row

struct StatsRowView: View {
    let player: Player
    let sessionsThisWeek: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Streak
            StatPill(
                icon: "flame.fill",
                value: "\(player.currentStreak)",
                label: "Streak",
                color: DesignSystem.Colors.streakOrange
            )

            // Week Sessions
            StatPill(
                icon: "calendar",
                value: "\(sessionsThisWeek)",
                label: "This Week",
                color: DesignSystem.Colors.secondaryBlue
            )

            // Total XP
            StatPill(
                icon: "star.fill",
                value: formatXP(player.totalXP),
                label: "Total XP",
                color: DesignSystem.Colors.xpGold
            )

            // Level
            StatPill(
                icon: "trophy.fill",
                value: "Lv.\(player.currentLevel)",
                label: "Level",
                color: DesignSystem.Colors.levelPurple
            )
        }
    }

    private func formatXP(_ xp: Int64) -> String {
        if xp >= 1000 {
            return String(format: "%.1fK", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Compact Player Stats (for header)

struct CompactPlayerStats: View {
    let player: Player
    @StateObject private var coinVM = CoinBalanceViewModel()

    private var tier: LevelTier? {
        XPService.shared.tierForLevel(Int(player.currentLevel))
    }

    var body: some View {
        // Minimal vertical stack - just icons with values
        VStack(alignment: .trailing, spacing: 6) {
            // Rank row
            HStack(spacing: 4) {
                Image(systemName: tier?.icon ?? "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.xpGold)
                Text(tier?.title ?? "Rookie")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            // Stats row
            HStack(spacing: 8) {
                // Level
                Text("Lv.\(player.currentLevel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Streak (if > 0)
                if player.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.streakOrange)
                        Text("\(player.currentStreak)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.streakOrange)
                    }
                    .fixedSize()
                }

                // Coins
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.coinGold)
                    Text("\(coinVM.balance)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fixedSize()
                }
                .fixedSize()
            }
            .fixedSize()
        }
        .fixedSize()
    }
}
