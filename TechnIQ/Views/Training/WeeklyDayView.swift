import SwiftUI
import CoreData

// MARK: - Weekly Day View Component

struct WeeklyDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let sessions: [TrainingSession]

    @State private var isPressed = false
    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text("\(calendar.component(.day, from: date))")
                .font(isToday ? DesignSystem.Typography.titleMedium : DesignSystem.Typography.titleSmall)
                .fontWeight(isToday ? .bold : .semibold)
                .foregroundColor(textColor)

            // Enhanced session indicator for weekly view
            weeklySessionIndicator
        }
        .frame(width: 48, height: 72) // Larger for weekly view
        .background(premiumBackground)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .overlay(premiumOverlay)
        .customShadow(shadowStyle)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(DesignSystem.Animation.spring, value: isPressed)
    }

    @ViewBuilder
    private var weeklySessionIndicator: some View {
        if sessions.isEmpty {
            Circle()
                .fill(DesignSystem.Colors.neutral300)
                .frame(width: 8, height: 8)
                .opacity(0.4)
        } else if sessions.count == 1, let first = sessions.first {
            // Single session with larger icon for weekly view
            sessionTypeIcon(for: first)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(colorForSession(first))
                .cornerRadius(10)
                .customShadow(DesignSystem.Shadow.small)
        } else {
            // Multiple sessions with enhanced styling
            VStack(spacing: 2) {
                Text("\(sessions.count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(sessionIntensityGradient)
                    )
                    .customShadow(DesignSystem.Shadow.small)

                // Progress bar showing total duration
                sessionDurationBar
            }
        }
    }

    @ViewBuilder
    private var sessionDurationBar: some View {
        let totalMinutes = sessions.reduce(0) { $0 + Int($1.duration) }
        let barWidth: CGFloat = min(CGFloat(totalMinutes) / 120.0 * 32, 32) // Max 120min = full width

        Capsule()
            .fill(sessionIntensityGradient)
            .frame(width: barWidth, height: 3)
            .opacity(0.8)
    }

    private var textColor: Color {
        if isToday {
            return isSelected ? .white : DesignSystem.Colors.primaryGreen
        } else {
            return isSelected ? .white : DesignSystem.Colors.textPrimary
        }
    }

    @ViewBuilder
    private var premiumBackground: some View {
        Group {
            if isSelected {
                DesignSystem.Colors.primaryGradient
            } else if isToday {
                LinearGradient(
                    colors: [DesignSystem.Colors.primaryGreen.opacity(0.2), DesignSystem.Colors.primaryGreenLight.opacity(0.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if !sessions.isEmpty {
                DesignSystem.Colors.neutral100
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.4), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                DesignSystem.Colors.backgroundSecondary
            }
        }
    }

    @ViewBuilder
    private var premiumOverlay: some View {
        Group {
            if isSelected {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 3)
                    .opacity(0.8)
            } else if isToday {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
                    .opacity(0.7)
            } else if !sessions.isEmpty {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1.5)
                    .opacity(0.6)
            }
        }
    }

    private var shadowStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        if isSelected {
            return (DesignSystem.Colors.primaryGreen.opacity(0.4), 10, 0, 5)
        } else if isToday || !sessions.isEmpty {
            return DesignSystem.Shadow.medium
        } else {
            return (Color.clear, 0, 0, 0)
        }
    }

    private var sessionIntensityGradient: LinearGradient {
        let avgIntensity = sessions.reduce(0.0) { $0 + Double($1.intensity) } / Double(sessions.count)

        switch avgIntensity {
        case 0..<2:
            return LinearGradient(colors: [DesignSystem.Colors.success, DesignSystem.Colors.primaryGreenLight],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2..<3:
            return LinearGradient(colors: [DesignSystem.Colors.accentYellow, DesignSystem.Colors.warning],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3..<4:
            return LinearGradient(colors: [DesignSystem.Colors.warning, DesignSystem.Colors.accentOrange],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [DesignSystem.Colors.error, Color.red],
                                 startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func sessionTypeIcon(for session: TrainingSession) -> Image {
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

    private func colorForSession(_ session: TrainingSession) -> Color {
        switch session.intensity {
        case 1...2:
            return DesignSystem.Colors.success
        case 3:
            return DesignSystem.Colors.accentYellow
        case 4:
            return DesignSystem.Colors.warning
        default:
            return DesignSystem.Colors.error
        }
    }
}
