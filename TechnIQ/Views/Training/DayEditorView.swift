import SwiftUI
import CoreData

struct DayEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let day: PlanDayModel
    let weekId: UUID
    let onSave: () -> Void

    // Editable fields
    @State private var isRestDay: Bool = false
    @State private var editedNotes: String = ""
    @State private var hasChanges = false

    // Session editing
    @State private var selectedSession: PlanSessionModel?
    @State private var showingSessionEditor = false

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Day Info Card
                        dayInfoCard

                        // Sessions List (only if not rest day)
                        if !isRestDay {
                            sessionsListCard
                        }

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
            .navigationTitle(dayTitle)
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
            .sheet(isPresented: $showingSessionEditor) {
                if let session = selectedSession {
                    SessionEditorView(session: session, dayId: day.id) {
                        onSave()
                    }
                }
            }
            .onAppear {
                isRestDay = day.isRestDay
                editedNotes = day.notes ?? ""
            }
        }
    }

    private var dayTitle: String {
        if let dayOfWeek = day.dayOfWeek {
            return dayOfWeek.displayName
        }
        return "Day \(day.dayNumber)"
    }

    // MARK: - Day Info Card

    private var dayInfoCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: isRestDay ? "bed.double" : "figure.run")
                        .font(.title2)
                        .foregroundColor(isRestDay ? DesignSystem.Colors.accentYellow : DesignSystem.Colors.primaryGreen)

                    Text("Day Details")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Rest Day Toggle
                Toggle(isOn: $isRestDay) {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Text("Rest Day")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .tint(DesignSystem.Colors.accentYellow)
                .onChange(of: isRestDay) { _ in
                    hasChanges = true
                }

                if isRestDay {
                    Text("Rest days help your body recover and adapt to training. Make sure to stay hydrated and get enough sleep!")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                }

                // Notes
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Notes")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    TextField("Optional notes for this day", text: $editedNotes, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(2...4)
                        .onChange(of: editedNotes) { _ in
                            hasChanges = true
                        }
                }

                // Day Stats
                if !isRestDay {
                    Divider()

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        DayStatBadge(
                            icon: "figure.run",
                            value: "\(day.sessions.count)",
                            label: "Sessions",
                            color: DesignSystem.Colors.primaryGreen
                        )

                        DayStatBadge(
                            icon: "clock",
                            value: "\(day.totalDuration)",
                            label: "Minutes",
                            color: DesignSystem.Colors.secondaryBlue
                        )

                        DayStatBadge(
                            icon: "checkmark.circle",
                            value: "\(completedSessionsCount)",
                            label: "Completed",
                            color: DesignSystem.Colors.success
                        )
                    }
                }
            }
        }
    }

    private var completedSessionsCount: Int {
        day.sessions.filter { $0.isCompleted }.count
    }

    // MARK: - Sessions List Card

    private var sessionsListCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    Text("Sessions")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("Tap to edit")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                if day.sessions.isEmpty {
                    emptySessionsView
                } else {
                    ForEach(day.sessions) { session in
                        SessionEditorRow(session: session) {
                            selectedSession = session
                            showingSessionEditor = true
                        }

                        if session.id != day.sessions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var emptySessionsView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "figure.run.circle")
                .font(.largeTitle)
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

            Text("No sessions scheduled")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Actions

    private func saveChanges() {
        TrainingPlanService.shared.updateDay(
            dayId: day.id,
            isRestDay: isRestDay,
            notes: editedNotes.isEmpty ? nil : editedNotes
        )
        hasChanges = false
        onSave()
    }
}

// MARK: - Session Editor Row

struct SessionEditorRow: View {
    let session: PlanSessionModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                // Session type indicator
                Image(systemName: session.sessionType.icon)
                    .font(.title3)
                    .foregroundColor(sessionColor)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.sessionType.displayName)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("\(session.duration) min")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("Intensity: \(session.intensity)/10")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(intensityColor)
                    }
                }

                Spacer()

                if session.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.success)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var sessionColor: Color {
        switch session.sessionType {
        case .technical: return DesignSystem.Colors.primaryGreen
        case .physical: return DesignSystem.Colors.accentOrange
        case .tactical: return DesignSystem.Colors.secondaryBlue
        case .recovery: return DesignSystem.Colors.accentYellow
        case .match: return DesignSystem.Colors.textPrimary
        case .warmup: return DesignSystem.Colors.accentOrange
        case .cooldown: return DesignSystem.Colors.secondaryBlue
        }
    }

    private var intensityColor: Color {
        if session.intensity <= 3 {
            return DesignSystem.Colors.success
        } else if session.intensity <= 6 {
            return DesignSystem.Colors.accentYellow
        } else {
            return DesignSystem.Colors.accentOrange
        }
    }
}

// MARK: - Day Stat Badge

struct DayStatBadge: View {
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
    DayEditorView(
        day: PlanDayModel(
            id: UUID(),
            dayNumber: 1,
            dayOfWeek: .monday,
            isRestDay: false,
            isSkipped: false,
            notes: "Focus on technique",
            isCompleted: false,
            completedAt: nil,
            sessions: []
        ),
        weekId: UUID(),
        onSave: {}
    )
}
