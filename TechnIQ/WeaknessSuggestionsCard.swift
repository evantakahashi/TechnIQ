import SwiftUI

// MARK: - Context-Aware Weakness Suggestions Card

struct WeaknessSuggestionsCard: View {
    let player: Player
    var onWeaknessSelected: ((SelectedWeakness) -> Void)?

    @State private var profile: WeaknessProfile?
    @State private var isLoaded = false

    var body: some View {
        Group {
            if let profile = profile, !profile.suggestedWeaknesses.isEmpty {
                suggestionContent(profile)
            } else if isLoaded {
                placeholderContent
            }
        }
        .onAppear {
            loadProfile()
        }
    }

    private func suggestionContent(_ profile: WeaknessProfile) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                Text("Suggested for You")
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()
            }

            if !profile.dataSources.isEmpty {
                Text("Based on your \(profile.dataSources.joined(separator: " and "))")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            FlowLayout(spacing: DesignSystem.Spacing.sm) {
                ForEach(profile.suggestedWeaknesses, id: \.specific) { weakness in
                    Button {
                        onWeaknessSelected?(weakness)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: iconForCategory(weakness.category))
                                .font(.system(size: 11))
                            Text(weakness.specific)
                                .font(DesignSystem.Typography.labelMedium)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.pill)
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(DesignSystem.Colors.primaryGreen.opacity(0.15), lineWidth: 1)
        )
    }

    private var placeholderContent: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("Complete a few matches or sessions to get personalized suggestions")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func loadProfile() {
        // Try cached first
        if let cached = WeaknessAnalysisService.shared.getCachedProfile(for: player) {
            profile = cached
            isLoaded = true
            return
        }
        // Analyze fresh
        let result = WeaknessAnalysisService.shared.analyzeWeaknesses(for: player)
        profile = result
        isLoaded = true
    }

    private func iconForCategory(_ categoryName: String) -> String {
        for cat in WeaknessCategory.allCases where cat.displayName == categoryName {
            return cat.icon
        }
        return "circle"
    }
}
