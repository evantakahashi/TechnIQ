import SwiftUI
import CoreData

struct WeekEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let week: PlanWeekModel
    let planId: UUID
    let onSave: () -> Void

    // Editable fields
    @State private var editedFocusArea: String = ""
    @State private var editedNotes: String = ""
    @State private var hasChanges = false

    // Day/Session editing
    @State private var selectedDay: PlanDayModel?
    @State private var showingDayEditor = false

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Week Info Card
                        weekInfoCard

                        // Days List
                        daysListCard

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
            .navigationTitle("Week \(week.weekNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        if hasChanges {
                            saveChanges()
                        }
                        dismiss()
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
            .sheet(isPresented: $showingDayEditor) {
                if let day = selectedDay {
                    DayEditorView(day: day, weekId: week.id) {
                        onSave()
                    }
                }
            }
            .onAppear {
                editedFocusArea = week.focusArea ?? ""
                editedNotes = week.notes ?? ""
            }
        }
    }

    // MARK: - Week Info Card

    private var weekInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "target")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("Week Details")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Focus Area
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Focus Area")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("e.g., Ball Control Fundamentals", text: $editedFocusArea)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: editedFocusArea) { _ in
                            hasChanges = true
                        }
                }

                // Notes
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Week Notes")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Optional notes for this week", text: $editedNotes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                        .onChange(of: editedNotes) { _ in
                            hasChanges = true
                        }
                }

                // Week Stats
                Divider()

                HStack(spacing: DesignSystem.Spacing.lg) {
                    StatBadge(
                        icon: "calendar",
                        value: "\(week.days.count)",
                        label: "Days",
                        color: DesignSystem.Colors.secondaryBlue
                    )

                    StatBadge(
                        icon: "figure.run",
                        value: "\(week.totalSessions)",
                        label: "Sessions",
                        color: DesignSystem.Colors.primaryGreen
                    )

                    StatBadge(
                        icon: "bed.double",
                        value: "\(restDaysCount)",
                        label: "Rest Days",
                        color: DesignSystem.Colors.accentYellow
                    )
                }
            }
        }
    }

    private var restDaysCount: Int {
        week.days.filter { $0.isRestDay }.count
    }

    // MARK: - Days List Card

    private var daysListCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    Text("Daily Schedule")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("Tap to edit")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                ForEach(week.days) { day in
                    DayEditorRow(day: day) {
                        selectedDay = day
                        showingDayEditor = true
                    }

                    if day.id != week.days.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        TrainingPlanService.shared.updateWeek(
            weekId: week.id,
            focusArea: editedFocusArea.isEmpty ? nil : editedFocusArea,
            notes: editedNotes.isEmpty ? nil : editedNotes
        )
        hasChanges = false
        onSave()
    }
}

// MARK: - Day Editor Row

struct DayEditorRow: View {
    let day: PlanDayModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Day indicator
                Circle()
                    .fill(day.isRestDay ? DesignSystem.Colors.accentYellow : DesignSystem.Colors.primaryGreen)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    if let dayOfWeek = day.dayOfWeek {
                        Text(dayOfWeek.displayName)
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    } else {
                        Text("Day \(day.dayNumber)")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    if day.isRestDay {
                        Text("Rest Day")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    } else {
                        Text("\(day.sessions.count) session\(day.sessions.count == 1 ? "" : "s") • \(day.totalDuration) min")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)

            Text(value)
                .font(DesignSystem.Typography.numberSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WeekEditorView(
        week: PlanWeekModel(
            id: UUID(),
            weekNumber: 1,
            focusArea: "Ball Control Fundamentals",
            notes: "Focus on first touch",
            isCompleted: false,
            completedAt: nil,
            days: []
        ),
        planId: UUID(),
        onSave: {}
    )
}
