import SwiftUI

// MARK: - Smart Drill Recommendations (Dashboard Section)

struct SmartDrillRecommendationsView: View {
    let player: Player
    var onGenerateDrill: ((SelectedWeakness) -> Void)?

    @State private var suggestions: [DrillSuggestion] = []
    @State private var isLoaded = false

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    Text("Drills For You")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Spacer()
                }

                ForEach(suggestions) { suggestion in
                    DrillSuggestionCard(suggestion: suggestion) {
                        onGenerateDrill?(suggestion.weakness)
                    }
                }
            }
            .onAppear { loadSuggestions() }
        } else if !isLoaded {
            Color.clear
                .frame(height: 0)
                .onAppear { loadSuggestions() }
        }
    }

    private func loadSuggestions() {
        let profile = WeaknessAnalysisService.shared.getCachedProfile(for: player)
            ?? WeaknessAnalysisService.shared.analyzeWeaknesses(for: player)

        suggestions = profile.suggestedWeaknesses.prefix(3).map { weakness in
            DrillSuggestion(
                weakness: weakness,
                title: "Improve \(weakness.specific)",
                description: drillDescription(for: weakness),
                difficulty: difficultyForPlayer()
            )
        }
        isLoaded = true
    }

    private func drillDescription(for weakness: SelectedWeakness) -> String {
        let descriptions: [String: String] = [
            "Dribbling": "Targeted dribbling exercises to sharpen your ball control",
            "Passing": "Precision passing drills to improve your distribution",
            "Shooting": "Finishing exercises to boost your goal-scoring ability",
            "First Touch": "Touch and control drills for better ball reception",
            "Defending": "Defensive technique drills to strengthen your game",
            "Speed & Agility": "Speed and agility work to improve your movement",
            "Stamina": "Endurance-focused exercises for match fitness",
            "Positioning": "Tactical positioning drills for better awareness",
            "Weak Foot": "Non-dominant foot exercises for two-footed confidence",
            "Aerial Ability": "Aerial drills to improve your heading and jumping"
        ]
        return descriptions[weakness.category] ?? "AI-generated drill targeting your weakness"
    }

    private func difficultyForPlayer() -> DifficultyLevel {
        switch player.experienceLevel {
        case "Beginner": return .beginner
        case "Advanced", "Elite": return .advanced
        default: return .intermediate
        }
    }
}

// MARK: - Drill Suggestion Model

struct DrillSuggestion: Identifiable {
    let id = UUID()
    let weakness: SelectedWeakness
    let title: String
    let description: String
    let difficulty: DifficultyLevel
}

// MARK: - Drill Suggestion Card

private struct DrillSuggestionCard: View {
    let suggestion: DrillSuggestion
    let onGenerate: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: iconForCategory(suggestion.weakness.category))
                    .font(.system(size: 18))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.title)
                    .font(DesignSystem.Typography.labelLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(suggestion.description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .lineLimit(2)

                // Difficulty badge
                Text(suggestion.difficulty.displayName)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            Spacer()

            // Generate button
            Button {
                onGenerate()
            } label: {
                Text("Generate")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.lg)
    }

    private func iconForCategory(_ categoryName: String) -> String {
        for cat in WeaknessCategory.allCases where cat.displayName == categoryName {
            return cat.icon
        }
        return "circle"
    }
}
