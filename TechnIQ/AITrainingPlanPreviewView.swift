import SwiftUI

struct AITrainingPlanPreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let generatedPlan: GeneratedPlanStructure
    let player: Player
    let customName: String
    let onRegenerate: () -> Void
    let onModifyParameters: () -> Void
    let onSave: () -> Void

    @State private var expandedWeeks: Set<Int> = []
    @State private var isSaving = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Preview Banner
                        previewBanner

                        // Plan Header
                        headerCard

                        // Stats Overview
                        statsOverview

                        // Weeks Preview
                        weeksPreview

                        // Action Buttons
                        actionButtons
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
            }
            .navigationTitle("Plan Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    // MARK: - Preview Banner

    private var previewBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "eye.fill")
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.secondaryBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Preview Mode")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Review your AI-generated plan before saving")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.secondaryBlue.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.md)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: generatedPlan.parsedCategory.icon)
                        .font(.largeTitle)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Spacer()

                    DifficultyBadge(difficulty: generatedPlan.parsedDifficulty)
                }

                Text(displayName)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                if let targetRole = generatedPlan.targetRole, !targetRole.isEmpty {
                    Text(targetRole)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                Text(generatedPlan.description)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.top, 4)
            }
        }
    }

    private var displayName: String {
        if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
            return customName
        }
        return generatedPlan.name
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            PreviewStatCard(
                icon: "calendar",
                title: "Duration",
                value: "\(generatedPlan.weeks.count)",
                subtitle: "weeks",
                color: DesignSystem.Colors.secondaryBlue
            )

            PreviewStatCard(
                icon: "clock",
                title: "Total Time",
                value: String(format: "%.0f", estimatedTotalHours),
                subtitle: "hours",
                color: DesignSystem.Colors.accentOrange
            )

            PreviewStatCard(
                icon: "figure.run",
                title: "Sessions",
                value: "\(totalSessions)",
                subtitle: "total",
                color: DesignSystem.Colors.primaryGreen
            )
        }
    }

    private var estimatedTotalHours: Double {
        let totalMinutes = generatedPlan.weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.reduce(0) { dayTotal, day in
                dayTotal + day.sessions.reduce(0) { sessionTotal, session in
                    sessionTotal + session.duration
                }
            }
        }
        return Double(totalMinutes) / 60.0
    }

    private var totalSessions: Int {
        generatedPlan.weeks.reduce(0) { weekTotal, week in
            weekTotal + week.days.reduce(0) { dayTotal, day in
                dayTotal + day.sessions.count
            }
        }
    }

    // MARK: - Weeks Preview

    private var weeksPreview: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Weekly Schedule")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ForEach(generatedPlan.weeks, id: \.weekNumber) { week in
                PreviewWeekCard(
                    week: week,
                    isExpanded: expandedWeeks.contains(week.weekNumber)
                ) {
                    toggleWeekExpansion(week.weekNumber)
                }
            }
        }
    }

    private func toggleWeekExpansion(_ weekNumber: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedWeeks.contains(weekNumber) {
                expandedWeeks.remove(weekNumber)
            } else {
                expandedWeeks.insert(weekNumber)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Save Button (Primary)
            ModernButton("Save Plan", icon: "checkmark.circle", style: .primary) {
                isSaving = true
                onSave()
            }
            .disabled(isSaving)

            // Secondary Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Regenerate Button
                Button(action: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRegenerate()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Regenerate")
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.secondaryBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.secondaryBlue.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }

                // Modify Parameters Button
                Button(action: {
                    dismiss()
                    onModifyParameters()
                }) {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Modify")
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.accentOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.accentOrange.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }

            Text("Not satisfied? Regenerate with the same settings or modify your parameters.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, DesignSystem.Spacing.xs)
        }
    }
}

// MARK: - Preview Stat Card

struct PreviewStatCard: View {
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

// MARK: - Preview Week Card

struct PreviewWeekCard: View {
    let week: GeneratedWeek
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

                            Text(week.focusArea)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }

                        Spacer()

                        // Session count badge
                        Text("\(weekSessionCount) sessions")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                            .cornerRadius(DesignSystem.CornerRadius.xs)

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())

                // Expanded Content
                if isExpanded {
                    Divider()
                        .padding(.vertical, DesignSystem.Spacing.xs)

                    if let notes = week.notes, !notes.isEmpty {
                        Text(notes)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.bottom, DesignSystem.Spacing.xs)
                    }

                    // Days in Week
                    ForEach(week.days, id: \.dayNumber) { day in
                        PreviewDayRow(day: day)
                    }
                }
            }
        }
    }

    private var weekSessionCount: Int {
        week.days.reduce(0) { $0 + $1.sessions.count }
    }
}

// MARK: - Preview Day Row

struct PreviewDayRow: View {
    let day: GeneratedDay

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(day.isRestDay ? DesignSystem.Colors.accentYellow : DesignSystem.Colors.primaryGreen)
                .frame(width: 8, height: 8)

            Text(day.dayOfWeek)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .frame(width: 80, alignment: .leading)

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

                Text("\(dayTotalDuration) min")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var dayTotalDuration: Int {
        day.sessions.reduce(0) { $0 + $1.duration }
    }
}

#Preview {
    let samplePlan = GeneratedPlanStructure(
        name: "Technical Mastery Program",
        description: "An 8-week program focused on improving ball control, passing accuracy, and first touch",
        difficulty: "Intermediate",
        category: "Technical",
        targetRole: "Midfielder",
        weeks: [
            GeneratedWeek(
                weekNumber: 1,
                focusArea: "Foundation Building",
                notes: "Focus on basic techniques",
                days: [
                    GeneratedDay(dayNumber: 1, dayOfWeek: "Monday", isRestDay: false, notes: nil, sessions: [
                        GeneratedSession(sessionType: "Technical", duration: 45, intensity: 3, notes: nil, suggestedExerciseNames: ["Wall Passing", "Cone Dribbling"])
                    ]),
                    GeneratedDay(dayNumber: 2, dayOfWeek: "Tuesday", isRestDay: true, notes: "Active recovery", sessions: []),
                    GeneratedDay(dayNumber: 3, dayOfWeek: "Wednesday", isRestDay: false, notes: nil, sessions: [
                        GeneratedSession(sessionType: "Technical", duration: 60, intensity: 4, notes: nil, suggestedExerciseNames: ["Triangle Passing", "First Touch Drills"])
                    ])
                ]
            ),
            GeneratedWeek(
                weekNumber: 2,
                focusArea: "Skill Development",
                notes: nil,
                days: []
            )
        ]
    )

    return AITrainingPlanPreviewView(
        generatedPlan: samplePlan,
        player: Player(),
        customName: "",
        onRegenerate: {},
        onModifyParameters: {},
        onSave: {}
    )
}
