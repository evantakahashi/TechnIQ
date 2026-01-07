import SwiftUI
import CoreData

struct TrainingPlanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var planService = TrainingPlanService.shared

    let initialPlan: TrainingPlanModel
    let player: Player

    @State private var currentPlan: TrainingPlanModel?
    @State private var showingConfirmStart = false
    @State private var expandedWeeks: Set<UUID> = []
    @State private var showingEditor = false

    /// The plan to display (current or initial)
    private var plan: TrainingPlanModel {
        currentPlan ?? initialPlan
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Header Card
                    headerCard

                    // Statistics Overview
                    statsOverview

                    // Weeks Breakdown
                    weeksBreakdown

                    // Action Button
                    actionButton
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
            .navigationTitle(plan.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Edit button (only for non-prebuilt plans)
                        if !plan.isPrebuilt {
                            Button {
                                showingEditor = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                        }

                        Button("Close") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditor) {
                PlanEditorView(plan: plan, player: player) {
                    // Refresh plan data from Core Data after editing
                    refreshPlanData()
                }
            }
            .confirmationDialog("Start Training Plan?", isPresented: $showingConfirmStart) {
                Button("Start Plan") {
                    startPlan()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will set \"\(plan.name)\" as your active training plan. Any currently active plan will be deactivated.")
            }
        }
    }

    /// Refreshes plan data from Core Data
    private func refreshPlanData() {
        if let freshPlan = TrainingPlanService.shared.fetchPlan(byId: initialPlan.id) {
            currentPlan = freshPlan
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: plan.category.icon)
                        .font(.largeTitle)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Spacer()

                    DifficultyBadge(difficulty: plan.difficulty)
                }

                if let targetRole = plan.targetRole {
                    Text(targetRole)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                Text(plan.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(.top, 4)

                if plan.isActive {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.success)

                        Text("Active Plan")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.success)
                    }
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }
        }
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            PlanStatCard(
                icon: "calendar",
                title: "Duration",
                value: "\(plan.durationWeeks)",
                subtitle: "weeks",
                color: DesignSystem.Colors.secondaryBlue
            )

            PlanStatCard(
                icon: "clock",
                title: "Total Time",
                value: String(format: "%.0f", plan.estimatedTotalHours),
                subtitle: "hours",
                color: DesignSystem.Colors.accentOrange
            )

            if plan.isActive {
                PlanStatCard(
                    icon: "chart.bar.fill",
                    title: "Progress",
                    value: "\(Int(plan.progressPercentage))",
                    subtitle: "percent",
                    color: DesignSystem.Colors.primaryGreen
                )
            } else {
                PlanStatCard(
                    icon: "figure.run",
                    title: "Sessions",
                    value: "\(plan.totalSessions)",
                    subtitle: "total",
                    color: DesignSystem.Colors.primaryGreen
                )
            }
        }
    }

    // MARK: - Weeks Breakdown

    private var weeksBreakdown: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Weekly Schedule")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if plan.weeks.isEmpty {
                emptyWeeksView
            } else {
                ForEach(plan.weeks) { week in
                    WeekCard(
                        week: week,
                        isExpanded: expandedWeeks.contains(week.id)
                    ) {
                        toggleWeekExpansion(week.id)
                    }
                }
            }
        }
    }

    private var emptyWeeksView: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.3))

                Text("No weekly schedule yet")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Text("This plan template will be populated with exercises when you start it")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Action Button

    private var actionButton: some View {
        ModernButton(
            plan.isActive ? "View Progress" : "Start This Plan",
            icon: plan.isActive ? "chart.line.uptrend.xyaxis" : "play.fill",
            style: .primary
        ) {
            if plan.isActive {
                // Navigate to active plan view
                dismiss()
            } else {
                showingConfirmStart = true
            }
        }
    }

    // MARK: - Helper Methods

    private func toggleWeekExpansion(_ weekId: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedWeeks.contains(weekId) {
                expandedWeeks.remove(weekId)
            } else {
                expandedWeeks.insert(weekId)
            }
        }
    }

    private func startPlan() {
        if plan.isPrebuilt {
            // Instantiate the prebuilt plan for the player
            if let newPlan = planService.instantiatePrebuiltPlan(plan, for: player) {
                let model = newPlan.toModel()
                planService.activatePlan(model, for: player)
            }
        } else {
            // Activate existing custom plan
            planService.activatePlan(plan, for: player)
        }

        dismiss()
    }
}

// MARK: - Plan Stat Card

struct PlanStatCard: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let color: Color

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.sm) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(value)
                    .font(DesignSystem.Typography.numberMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(subtitle)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Week Card

struct WeekCard: View {
    let week: PlanWeekModel
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Week Header
                Button(action: onTap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Week \(week.weekNumber)")
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            if let focusArea = week.focusArea {
                                Text(focusArea)
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }

                        Spacer()

                        if week.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(DesignSystem.Colors.success)
                        }

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Expanded Content
                if isExpanded {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    if let notes = week.notes {
                        Text(notes)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.bottom, DesignSystem.Spacing.xs)
                    }

                    // Days in Week
                    ForEach(week.days) { day in
                        DayRow(day: day)
                    }
                }
            }
        }
    }
}

// MARK: - Day Row

struct DayRow: View {
    let day: PlanDayModel

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(day.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textSecondary.opacity(0.3))
                .frame(width: 8, height: 8)

            if let dayOfWeek = day.dayOfWeek {
                Text(dayOfWeek.displayName)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 80, alignment: .leading)
            } else {
                Text("Day \(day.dayNumber)")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .frame(width: 80, alignment: .leading)
            }

            if day.isRestDay {
                Text("Rest Day")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.accentYellow)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(DesignSystem.Colors.accentYellow.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.xs)
            } else {
                Text("\(day.sessions.count) session\(day.sessions.count == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                Spacer()

                Text("\(day.totalDuration) min")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TrainingPlanDetailView(
        initialPlan: TrainingPlanModel(
            id: UUID(),
            name: "Striker Development",
            description: "8-week program focused on finishing, positioning, and movement in the attacking third",
            durationWeeks: 8,
            difficulty: .intermediate,
            category: .position,
            targetRole: "Striker",
            isPrebuilt: true,
            isActive: false,
            currentWeek: 1,
            progressPercentage: 0.0,
            startedAt: nil,
            completedAt: nil,
            createdAt: Date(),
            updatedAt: Date(),
            weeks: []
        ),
        player: Player()
    )
}
