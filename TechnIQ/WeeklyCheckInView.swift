import SwiftUI

struct WeeklyCheckInView: View {
    let weekNumber: Int
    let player: Player
    @StateObject private var aiCoachService = AICoachService.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        if aiCoachService.isLoadingAdaptation {
                            loadingState
                        } else if let response = aiCoachService.adaptationResponse {
                            reviewContent(response)
                        } else if aiCoachService.adaptationError != nil {
                            errorState
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("Week \(weekNumber) Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
                Task {
                    await aiCoachService.fetchPlanAdaptation(for: player, plan: plan, weekNumber: weekNumber)
                }
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing your week...")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.top, 80)
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Couldn't reach AI coach")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("You can retry or keep your current plan.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                ModernButton("Retry", icon: "arrow.clockwise", style: .secondary) {
                    if let plan = TrainingPlanService.shared.fetchActivePlan(for: player) {
                        Task {
                            await aiCoachService.fetchPlanAdaptation(for: player, plan: plan, weekNumber: weekNumber)
                        }
                    }
                }

                ModernButton("Keep Plan", style: .ghost) {
                    aiCoachService.dismissWeeklyCheckIn()
                    dismiss()
                }
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Review Content

    private func reviewContent(_ response: PlanAdaptationResponse) -> some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Week summary
            ModernCard(accentEdge: .leading, accentColor: DesignSystem.Colors.accentYellow) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Text("WEEK \(weekNumber) REVIEW")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                            .fontWeight(.bold)
                    }

                    Text(response.summary)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Proposed changes
            if !response.adaptations.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Proposed Changes for Week \(weekNumber + 1)")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.bold)

                    ForEach(Array(response.adaptations.enumerated()), id: \.offset) { _, adaptation in
                        adaptationRow(adaptation)
                    }
                }
            }

            // Action buttons
            VStack(spacing: DesignSystem.Spacing.sm) {
                ModernButton("Apply Changes", icon: "checkmark.circle", style: .primary) {
                    applyAdaptations(response.adaptations)
                }

                ModernButton("Keep Original Plan", icon: "xmark.circle", style: .ghost) {
                    aiCoachService.dismissWeeklyCheckIn()
                    dismiss()
                }
            }
        }
    }

    private func adaptationRow(_ adaptation: PlanAdaptation) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: iconForAdaptationType(adaptation.type))
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(colorForAdaptationType(adaptation.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(adaptation.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Day \(adaptation.day)")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceRaised)
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    private func iconForAdaptationType(_ type: String) -> String {
        switch type {
        case "add_session": return "plus.circle.fill"
        case "modify_difficulty": return "arrow.up.circle.fill"
        case "remove_session": return "minus.circle.fill"
        case "swap_exercise": return "arrow.triangle.swap"
        default: return "circle.fill"
        }
    }

    private func colorForAdaptationType(_ type: String) -> Color {
        switch type {
        case "add_session": return DesignSystem.Colors.primaryGreen
        case "modify_difficulty": return DesignSystem.Colors.accentOrange
        case "remove_session": return DesignSystem.Colors.error
        case "swap_exercise": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.textSecondary
        }
    }

    // MARK: - Apply Adaptations

    private func applyAdaptations(_ adaptations: [PlanAdaptation]) {
        guard let plan = TrainingPlanService.shared.fetchActivePlan(for: player) else { return }

        for adaptation in adaptations {
            TrainingPlanService.shared.applyAdaptation(adaptation, to: plan, targetWeek: weekNumber + 1)
        }

        aiCoachService.dismissWeeklyCheckIn()
        HapticManager.shared.success()
        dismiss()
    }
}
