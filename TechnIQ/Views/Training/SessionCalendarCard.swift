import SwiftUI
import CoreData

// MARK: - Enhanced Session Calendar Card

struct SessionCalendarCard: View {
    let session: TrainingSession
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header with session type and intensity
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        // Session type with icon
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            sessionTypeIcon
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(sessionColor)

                            Text(session.sessionType ?? "Training")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineLimit(1)
                        }

                        // Session date/time
                        if let date = session.date {
                            Text(timeString(from: date))
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    Spacer()

                    // Intensity indicator with premium styling
                    intensityBadge
                }

                // Metrics row
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Duration with progress bar
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(sessionColor)

                            Text("\(Int(session.duration)) min")
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }

                        // Duration progress bar (relative to 2 hours max)
                        let progress = min(session.duration / 120.0, 1.0)

                        Capsule()
                            .fill(sessionColor.opacity(0.3))
                            .frame(height: 3)
                            .overlay(
                                HStack {
                                    Capsule()
                                        .fill(sessionColor)
                                        .frame(width: 40 * progress)

                                    Spacer()
                                }
                            )
                            .frame(width: 40)
                    }

                    Spacer()

                    // Exercise count
                    if let exercises = session.exercises, exercises.count > 0 {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 4) {
                                Text("\(exercises.count)")
                                    .font(DesignSystem.Typography.labelMedium)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)

                                Image(systemName: "list.bullet")
                                    .font(.system(size: 10))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            Text("exercises")
                                .font(.system(size: 10))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(width: 180, height: 100)
            .background(premiumCardBackground)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .overlay(premiumCardOverlay)
            .customShadow(cardShadow)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    private var sessionTypeIcon: Image {
        if let sessionType = session.sessionType?.lowercased() {
            switch sessionType {
            case "technical", "skill", "ball work":
                return Image(systemName: "soccerball")
            case "physical", "fitness", "conditioning":
                return Image(systemName: "figure.run")
            case "tactical", "strategy", "formation":
                return Image(systemName: "brain.head.profile")
            default:
                return Image(systemName: "soccerball")
            }
        }
        return Image(systemName: "soccerball")
    }

    private var sessionColor: Color {
        switch session.intensity {
        case 1...2: return DesignSystem.Colors.success
        case 3: return DesignSystem.Colors.accentYellow
        case 4: return DesignSystem.Colors.warning
        default: return DesignSystem.Colors.error
        }
    }

    @ViewBuilder
    private var intensityBadge: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= Int(session.intensity) ? sessionColor : DesignSystem.Colors.neutral300)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.xs)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.backgroundSecondary)
                .overlay(
                    Capsule()
                        .stroke(sessionColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var premiumCardBackground: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
            .fill(DesignSystem.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    @ViewBuilder
    private var premiumCardOverlay: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
            .stroke(
                LinearGradient(
                    colors: [sessionColor.opacity(0.3), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }

    private var cardShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        return (sessionColor.opacity(0.15), 6, 0, 3)
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
