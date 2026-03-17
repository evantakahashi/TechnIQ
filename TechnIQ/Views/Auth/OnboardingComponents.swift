import SwiftUI

// MARK: - Helper Views

/// Feature row for welcome screen
struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.15))
                .cornerRadius(DesignSystem.CornerRadius.sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

/// Option button for goal selection
struct OnboardingOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryGreen)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.primaryGreen.opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                Text(title)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primaryGreen : Color.clear, lineWidth: 2)
            )
        }
    }
}

/// Chip for frequency/style selection
struct FrequencyChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.labelMedium)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isSelected ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.pill)
        }
    }
}

/// Position button with icon
struct PositionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryGreen)

                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(isSelected ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
}

/// Summary row for ready screen
struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}
