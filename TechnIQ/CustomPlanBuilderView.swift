import SwiftUI
import CoreData

struct CustomPlanBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var planService = TrainingPlanService.shared

    let player: Player

    @State private var planName = ""
    @State private var planDescription = ""
    @State private var durationWeeks: Int = 4
    @State private var selectedDifficulty: PlanDifficulty = .intermediate
    @State private var selectedCategory: PlanCategory = .general
    @State private var targetRole = ""
    @State private var showingSuccess = false

    private let nameCharacterLimit = 50
    private let descriptionCharacterLimit = 200

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Info Card
                    infoCard

                    // Plan Name
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Plan Name")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        TextField("e.g., My Training Program", text: $planName)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.md)

                        Text("\(planName.count)/\(nameCharacterLimit)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(planName.count > nameCharacterLimit ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Description")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        TextEditor(text: $planDescription)
                            .frame(height: 100)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.md)

                        Text("\(planDescription.count)/\(descriptionCharacterLimit)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(planDescription.count > descriptionCharacterLimit ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // Duration Picker
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Duration: \(durationWeeks) weeks")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Slider(value: Binding(
                            get: { Double(durationWeeks) },
                            set: { durationWeeks = Int($0) }
                        ), in: 2...16, step: 1)
                        .tint(DesignSystem.Colors.primaryGreen)
                    }

                    // Difficulty Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Difficulty")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(PlanDifficulty.allCases, id: \.self) { difficulty in
                                DifficultySelectionButton(
                                    difficulty: difficulty,
                                    isSelected: selectedDifficulty == difficulty
                                ) {
                                    selectedDifficulty = difficulty
                                }
                            }
                        }
                    }

                    // Category Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Category")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        ForEach(PlanCategory.allCases, id: \.self) { category in
                            CategorySelectionButton(
                                category: category,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                            }
                        }
                    }

                    // Target Role (Optional)
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Target Position (Optional)")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        TextField("e.g., Midfielder", text: $targetRole)
                            .padding(DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.cardBackground)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }

                    // Create Button
                    ModernButton("Create Plan", icon: "plus.circle.fill", style: .primary) {
                        createPlan()
                    }
                    .disabled(!isFormValid)
                }
                .padding(DesignSystem.Spacing.md)
            }
            .navigationTitle("Create Custom Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Plan Created!", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your custom training plan \"\(planName)\" has been created successfully.")
            }
        }
    }

    // MARK: - Info Card

    private var infoCard: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)
                    .font(.title2)

                Text("Create a custom training plan tailored to your specific goals and schedule")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        !planName.isEmpty &&
        planName.count <= nameCharacterLimit &&
        !planDescription.isEmpty &&
        planDescription.count <= descriptionCharacterLimit
    }

    // MARK: - Create Plan

    private func createPlan() {
        guard isFormValid else { return }

        let _ = planService.createCustomPlan(
            name: planName,
            description: planDescription,
            durationWeeks: durationWeeks,
            difficulty: selectedDifficulty,
            category: selectedCategory,
            targetRole: targetRole.isEmpty ? nil : targetRole,
            for: player
        )

        showingSuccess = true
    }
}

// MARK: - Difficulty Selection Button

struct DifficultySelectionButton: View {
    let difficulty: PlanDifficulty
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(difficulty.displayName)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .frame(maxWidth: .infinity)
                .background(isSelected ? buttonColor : DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(isSelected ? buttonColor : DesignSystem.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var buttonColor: Color {
        switch difficulty {
        case .beginner: return DesignSystem.Colors.success
        case .intermediate: return DesignSystem.Colors.secondaryBlue
        case .advanced: return DesignSystem.Colors.warning
        case .elite: return DesignSystem.Colors.error
        }
    }
}

// MARK: - Category Selection Button

struct CategorySelectionButton: View {
    let category: PlanCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
                    .frame(width: 24)

                Text(category.displayName)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(isSelected ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textSecondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.1) : DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CustomPlanBuilderView(player: Player())
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
