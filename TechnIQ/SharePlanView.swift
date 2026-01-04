import SwiftUI

struct SharePlanView: View {
    let plan: TrainingPlanModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareMessage = ""
    @State private var isSharing = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        headerSection
                        planPreview
                        shareOptions
                        submitButton
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Share Plan")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .alert("Plan Shared!", isPresented: $showSuccessMessage) {
                Button("Done") {
                    dismiss()
                }
            } message: {
                Text("Thank you for contributing! Your plan will help other players improve their training.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: "person.3.fill")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Contribute to Community")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Share your custom training plan with other players worldwide")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()
                }
            }
        }
    }

    // MARK: - Plan Preview

    private var planPreview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Plan Details")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: plan.category.icon)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(DesignSystem.Typography.titleMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            if let targetRole = plan.targetRole {
                                Text(targetRole)
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        DifficultyBadge(difficulty: plan.difficulty)
                    }

                    Divider()

                    Text(plan.description)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    HStack(spacing: DesignSystem.Spacing.md) {
                        InfoChip(icon: "calendar", text: "\(plan.durationWeeks) weeks")
                        InfoChip(icon: "clock", text: String(format: "%.0f hrs", plan.estimatedTotalHours))
                        InfoChip(icon: "flame.fill", text: plan.difficulty.displayName)
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
    }

    // MARK: - Share Options

    private var shareOptions: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Add a Message (Optional)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("e.g., This plan helped me improve my finishing...", text: $shareMessage, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)

                    HStack {
                        Spacer()
                        Text("\(shareMessage.count)/200")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }

            // Sharing info
            ModernCard(padding: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("What gets shared:")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("• Plan structure and exercises\n• Duration and difficulty\n• Your optional message")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Your personal data and progress are not shared.")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .italic()
                    }

                    Spacer()
                }
            }
            .background(DesignSystem.Colors.secondaryBlue.opacity(0.1))
        }
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        ModernButton(
            isSharing ? "Sharing..." : "Share with Community",
            icon: "paperplane.fill",
            style: .primary
        ) {
            sharePlan()
        }
        .disabled(isSharing)
    }

    // MARK: - Actions

    private func sharePlan() {
        guard shareMessage.count <= 200 else {
            errorMessage = "Message must be 200 characters or less"
            return
        }

        isSharing = true

        Task {
            do {
                try await CloudDataService.shared.shareTrainingPlan(plan, message: shareMessage)

                await MainActor.run {
                    isSharing = false
                    showSuccessMessage = true
                }
            } catch CloudDataError.notAuthenticated {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Please sign in to share plans"
                }
            } catch CloudDataError.networkError {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "No internet connection. Please try again later."
                }
            } catch {
                await MainActor.run {
                    isSharing = false
                    errorMessage = "Failed to share plan. Please try again."
                }
            }
        }
    }
}

// MARK: - Info Chip Component

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.xs)
    }
}

// MARK: - Preview

#Preview {
    let mockPlan = TrainingPlanModel(
        id: UUID(),
        name: "Striker Development",
        description: "8-week program focused on finishing, positioning, and movement in the attacking third",
        durationWeeks: 8,
        difficulty: .intermediate,
        category: .position,
        targetRole: "Striker",
        isPrebuilt: false,
        isActive: false,
        currentWeek: 1,
        progressPercentage: 0,
        startedAt: nil,
        completedAt: nil,
        createdAt: Date(),
        updatedAt: Date(),
        weeks: []
    )

    return SharePlanView(plan: mockPlan)
}
