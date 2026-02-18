import SwiftUI

struct ProLockedCardView: View {
    let feature: PaywallFeature
    @State private var showingPaywall = false

    var body: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: feature.icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(feature.title)
                            .font(DesignSystem.Typography.labelLarge)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text(feature.description)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.accentGold)
                }

                Button {
                    showingPaywall = true
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Unlock with Pro")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accentGold.opacity(0.15))
                    .foregroundColor(DesignSystem.Colors.accentGold)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: feature)
        }
    }
}
