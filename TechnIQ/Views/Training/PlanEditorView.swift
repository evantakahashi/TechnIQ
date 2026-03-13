import SwiftUI
import CoreData

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let plan: TrainingPlanModel
    let player: Player
    let onSave: () -> Void

    // Editable fields
    @State private var editedName: String = ""
    @State private var editedDescription: String = ""
    @State private var hasChanges = false
    @State private var showingDiscardAlert = false
    @State private var showingSaveSuccess = false

    // Week editing
    @State private var selectedWeek: PlanWeekModel?
    @State private var showingWeekEditor = false

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Plan Info Card
                        planInfoCard

                        // Weeks List
                        weeksListCard

                        // Save Button
                        if hasChanges {
                            ModernButton("Save Changes", icon: "checkmark.circle", style: .primary) {
                                saveChanges()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardAlert = true
                        } else {
                            dismiss()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        if hasChanges {
                            saveChanges()
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Discard Changes?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("You have unsaved changes. Are you sure you want to discard them?")
            }
            .sheet(isPresented: $showingWeekEditor) {
                if let week = selectedWeek {
                    WeekEditorView(week: week, planId: plan.id) {
                        // Refresh after week edit
                        onSave()
                    }
                }
            }
            .onAppear {
                editedName = plan.name
                editedDescription = plan.description
            }
        }
    }

    // MARK: - Plan Info Card

    private var planInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "doc.text")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("Plan Details")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Plan Name
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Plan Name")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Enter plan name", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: editedName) { _ in
                            hasChanges = true
                        }
                }

                // Description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Description")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Enter description", text: $editedDescription, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .onChange(of: editedDescription) { _ in
                            hasChanges = true
                        }
                }

                // Read-only info
                Divider()

                HStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Duration")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text("\(plan.durationWeeks) weeks")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Difficulty")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(plan.difficulty.displayName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Category")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Text(plan.category.displayName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
            }
        }
    }

    // MARK: - Weeks List Card

    private var weeksListCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    Text("Weekly Schedule")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("Tap to edit")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                if plan.weeks.isEmpty {
                    emptyWeeksView
                } else {
                    ForEach(plan.weeks) { week in
                        WeekEditorRow(week: week) {
                            selectedWeek = week
                            showingWeekEditor = true
                        }

                        if week.id != plan.weeks.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var emptyWeeksView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

            Text("No weeks to edit")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Actions

    private func saveChanges() {
        TrainingPlanService.shared.updatePlan(
            planId: plan.id,
            name: editedName,
            description: editedDescription
        )
        hasChanges = false
        onSave()
    }
}

// MARK: - Week Editor Row

struct WeekEditorRow: View {
    let week: PlanWeekModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Week \(week.weekNumber)")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    if let focusArea = week.focusArea {
                        Text(focusArea)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(week.days.count) days")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("\(week.totalSessions) sessions")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PlanEditorView(
        plan: TrainingPlanModel(
            id: UUID(),
            name: "Technical Mastery",
            description: "8-week program focused on ball control",
            durationWeeks: 8,
            difficulty: .intermediate,
            category: .technical,
            targetRole: "Midfielder",
            isPrebuilt: false,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        ),
        player: Player(),
        onSave: {}
    )
}
