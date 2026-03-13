import SwiftUI
import CoreData

struct QuickDrillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var drillService = CustomDrillService.shared

    let player: Player
    let onGenerated: (Exercise) -> Void
    var prefilledWeakness: SelectedWeakness? = nil

    @State private var skillDescription: String = ""
    @State private var errorMessage: String?

    private var isValid: Bool {
        skillDescription.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 || prefilledWeakness != nil
    }

    private var difficulty: DifficultyLevel {
        switch player.experienceLevel?.lowercased() {
        case "beginner": return .beginner
        case "advanced": return .advanced
        default: return .intermediate
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Description
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("What do you want to work on?")
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)

                            TextField("e.g. Quick passing under pressure", text: $skillDescription)
                                .modernTextFieldStyle()

                            let charCount = skillDescription.trimmingCharacters(in: .whitespacesAndNewlines).count
                            if charCount > 0 && charCount < 10 {
                                Text("\(10 - charCount) more characters needed")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.accentOrange)
                            }
                        }

                        // Generation progress
                        if drillService.isGenerating {
                            VStack(spacing: DesignSystem.Spacing.md) {
                                ProgressView(value: drillService.generationProgress)
                                    .tint(DesignSystem.Colors.primaryGreen)

                                Text(drillService.generationMessage)
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .padding(.vertical, DesignSystem.Spacing.md)
                        }

                        // Error
                        if let error = errorMessage {
                            Text(error)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                                .multilineTextAlignment(.center)
                        }

                        // Generate button
                        ModernButton("Generate Drill", icon: "bolt.fill", style: .primary) {
                            generateDrill()
                        }
                        .disabled(!isValid || drillService.isGenerating)
                        .opacity(!isValid || drillService.isGenerating ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Quick Drill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func generateDrill() {
        errorMessage = nil

        // Auto-map category from weakness if available
        let category: DrillCategory = {
            guard let weakness = prefilledWeakness else { return .technical }
            switch weakness.category {
            case "Defending": return .tactical
            case "Speed & Agility", "Stamina": return .physical
            case "Positioning": return .tactical
            default: return .technical
            }
        }()

        let request = CustomDrillRequest(
            skillDescription: skillDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            difficulty: difficulty,
            equipment: [.ball],
            numberOfPlayers: 1,
            fieldSize: .medium,
            selectedWeaknesses: prefilledWeakness.map { [$0] } ?? []
        )

        Task {
            do {
                let exercise = try await drillService.generateCustomDrill(request: request, for: player)
                await MainActor.run {
                    SubscriptionManager.shared.markQuickDrillUsed()
                    onGenerated(exercise)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
