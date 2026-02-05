import SwiftUI

struct RestCountdownView: View {
    @ObservedObject var manager: ActiveSessionManager

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Circular countdown ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 8)
                    .frame(width: 200, height: 200)

                // Progress ring
                Circle()
                    .trim(from: 0, to: manager.restProgress)
                    .stroke(
                        DesignSystem.Colors.primaryGreen,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: manager.restProgress)

                // Countdown number
                VStack(spacing: 4) {
                    Text(manager.formattedTime(manager.restTimeRemaining))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Rest")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            // Adjust buttons
            HStack(spacing: DesignSystem.Spacing.xl) {
                adjustButton(label: "-10s", delta: -10)
                adjustButton(label: "+10s", delta: 10)
            }

            // Up Next preview
            if let next = manager.upNextExercise {
                upNextPreview(next)
            }

            Spacer()

            // Skip Rest button
            Button {
                manager.skipRest()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "forward.fill")
                    Text("Skip Rest")
                        .fontWeight(.semibold)
                }
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button)
                        .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2)
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Adjust Button

    private func adjustButton(label: String, delta: TimeInterval) -> some View {
        Button {
            manager.adjustRest(delta)
            HapticManager.shared.lightTap()
        } label: {
            Text(label)
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 80, height: 44)
                .background(DesignSystem.Colors.backgroundSecondary)
                .cornerRadius(DesignSystem.CornerRadius.button)
        }
    }

    // MARK: - Up Next Preview

    private func upNextPreview(_ exercise: Exercise) -> some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Up Next")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(exercise.name ?? "Exercise")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Spacer()

                if let category = exercise.category {
                    CategoryBadge(category: category)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }
}
