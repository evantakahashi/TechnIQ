import SwiftUI
import CoreData

// MARK: - Calendar Day View

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let sessions: [TrainingSession]
    let onTap: () -> Void

    @State private var isPressed = false
    private let calendar = Calendar.current

    var body: some View {
        Button(action: {
            // Add haptic feedback for premium feel
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            onTap()
        }) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                // Day number with enhanced typography
                Text("\(calendar.component(.day, from: date))")
                    .font(isToday ? DesignSystem.Typography.titleMedium : DesignSystem.Typography.bodyMedium)
                    .fontWeight(isToday ? .bold : .semibold)
                    .foregroundColor(textColor)

                // Enhanced session indicators
                premiumSessionIndicators
            }
            .frame(width: 52, height: 64) // Larger touch targets
            .background(premiumBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(premiumOverlay)
            .customShadow(shadowStyle)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.spring, value: isPressed)
            .animation(DesignSystem.Animation.quick, value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    @ViewBuilder
    private var premiumSessionIndicators: some View {
        VStack(spacing: 2) {
            if sessions.isEmpty {
                // Empty state with subtle indicator
                Circle()
                    .fill(DesignSystem.Colors.neutral300)
                    .frame(width: 6, height: 6)
                    .opacity(0.3)
            } else if sessions.count == 1, let first = sessions.first {
                // Single session with icon
                sessionTypeIcon(for: first)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(colorForSession(first))
                    .cornerRadius(8)
            } else {
                // Multiple sessions - show count with heat intensity
                Text("\(sessions.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(sessionIntensityGradient)
                    )
                    .customShadow(DesignSystem.Shadow.small)
            }
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
        // Determine icon based on session type or default to soccer ball
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

    private var textColor: Color {
        if !isCurrentMonth {
            return DesignSystem.Colors.textTertiary
        } else if isToday {
            return isSelected ? .white : DesignSystem.Colors.primaryGreen
        } else {
            return isSelected ? .white : DesignSystem.Colors.textPrimary
        }
    }

    @ViewBuilder
    private var premiumBackground: some View {
        Group {
            if isSelected {
                // Selected state with premium gradient
                DesignSystem.Colors.primaryGradient
            } else if isToday {
                // Today with subtle gradient
                LinearGradient(
                    colors: [DesignSystem.Colors.primaryGreen.opacity(0.15), DesignSystem.Colors.primaryGreenLight.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else if !sessions.isEmpty {
                // Has sessions - subtle background with glassmorphism
                DesignSystem.Colors.neutral100
                    .overlay(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else {
                // Empty day
                DesignSystem.Colors.backgroundSecondary
            }
        }
    }

    @ViewBuilder
    private var premiumOverlay: some View {
        Group {
            if isSelected {
                // Bright selection border
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2.5)
                    .opacity(0.8)
            } else if isToday {
                // Today border with subtle glow
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 1.5)
                    .opacity(0.6)
            } else if !sessions.isEmpty {
                // Sessions border
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1)
                    .opacity(0.5)
            }
        }
    }

    private var shadowStyle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        if isSelected {
            return (DesignSystem.Colors.primaryGreen.opacity(0.3), 8, 0, 4)
        } else if isToday || !sessions.isEmpty {
            return DesignSystem.Shadow.small
        } else {
            return (Color.clear, 0, 0, 0)
        }
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
