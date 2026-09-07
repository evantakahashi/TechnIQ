import SwiftUI
import CoreData

struct QuickDrillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drillService = CustomDrillService.shared

    let player: Player
    let onGenerated: (Exercise) -> Void
    var prefilledWeakness: SelectedWeakness? = nil

    @State private var skillDescription: String = ""
    @State private var errorMessage: String?
    @State private var generationTask: Task<Void, Never>?
    @State private var generatedExercise: Exercise?

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
        NavigationStack {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        if let exercise = generatedExercise {
                            successCard(for: exercise)
                        } else {
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
            .onDisappear {
                generationTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private func successCard(for exercise: Exercise) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .a11yHidden()

            Text("Drill Ready!")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)

            Text(exercise.name ?? "Custom Drill")
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)

            Text("Saved to your exercise library")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ModernButton("Go to Drill", icon: "figure.run", style: .primary) {
                onGenerated(exercise)
            }

            Button("Done") { dismiss() }
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
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
            // Quick Drill is one-tap with no equipment picker, so authorize the
            // basics — ball-only meant shooting requests could never get a goal
            // element and the AI improvised nonsense like "shoots at B5" (a ball).
            equipment: [.ball, .cones, .goals],
            numberOfPlayers: 1,
            fieldSize: .medium,
            selectedWeaknesses: prefilledWeakness.map { [$0] } ?? []
        )

        generationTask = Task {
            do {
                let exercise = try await drillService.generateCustomDrill(request: request, for: player)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    SubscriptionManager.shared.markQuickDrillUsed()
                    // Show the success card; the kid taps "Go to Drill" to start.
                    generatedExercise = exercise
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
