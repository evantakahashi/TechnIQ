import SwiftUI
import CoreData

struct SessionEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let session: PlanSessionModel
    let dayId: UUID
    let onSave: () -> Void

    // Editable fields
    @State private var selectedSessionType: SessionType = .technical
    @State private var duration: Int = 30
    @State private var intensity: Int = 5
    @State private var editedNotes: String = ""
    @State private var hasChanges = false

    // Exercise management
    @State private var exerciseNames: [String] = []
    @State private var showingExercisePicker = false

    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Session Type Card
                        sessionTypeCard

                        // Duration & Intensity Card
                        durationIntensityCard

                        // Notes Card
                        notesCard

                        // Exercises Card
                        exercisesCard

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
            .navigationTitle("Edit Session")
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
            .onAppear {
                selectedSessionType = session.sessionType
                duration = session.duration
                intensity = session.intensity
                editedNotes = session.notes ?? ""
                loadExerciseNames()
            }
        }
    }

    // MARK: - Session Type Card

    private var sessionTypeCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: selectedSessionType.icon)
                        .font(.title2)
                        .foregroundColor(sessionTypeColor)

                    Text("Session Type")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Session Type Selector
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                    ForEach(SessionType.allCases, id: \.self) { type in
                        SessionTypeButton(
                            type: type,
                            isSelected: selectedSessionType == type
                        ) {
                            selectedSessionType = type
                            hasChanges = true
                        }
                    }
                }
            }
        }
    }

    private var sessionTypeColor: Color {
        switch selectedSessionType {
        case .technical: return DesignSystem.Colors.primaryGreen
        case .physical: return DesignSystem.Colors.accentOrange
        case .tactical: return DesignSystem.Colors.secondaryBlue
        case .recovery: return DesignSystem.Colors.accentYellow
        case .match: return DesignSystem.Colors.textPrimary
        }
    }

    // MARK: - Duration & Intensity Card

    private var durationIntensityCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)

                    Text("Duration & Intensity")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                // Duration Slider
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text("Duration")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Text("\(duration) minutes")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }

                    Slider(value: Binding(
                        get: { Double(duration) },
                        set: { duration = Int($0); hasChanges = true }
                    ), in: 10...120, step: 5)
                    .tint(DesignSystem.Colors.primaryGreen)

                    HStack {
                        Text("10 min")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("2 hours")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Divider()

                // Intensity Slider
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text("Intensity")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Spacer()

                        Text("\(intensity)/10")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(intensityColor)
                    }

                    Slider(value: Binding(
                        get: { Double(intensity) },
                        set: { intensity = Int($0); hasChanges = true }
                    ), in: 1...10, step: 1)
                    .tint(intensityColor)

                    HStack {
                        Text("Light")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.success)
                        Spacer()
                        Text("Moderate")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                        Spacer()
                        Text("Intense")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                    }
                }

                // Intensity Description
                Text(intensityDescription)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }

    private var intensityColor: Color {
        if intensity <= 3 {
            return DesignSystem.Colors.success
        } else if intensity <= 6 {
            return DesignSystem.Colors.accentYellow
        } else {
            return DesignSystem.Colors.accentOrange
        }
    }

    private var intensityDescription: String {
        switch intensity {
        case 1...3:
            return "Light intensity - good for recovery and technique work"
        case 4...6:
            return "Moderate intensity - balanced effort for skill development"
        case 7...8:
            return "High intensity - challenging workout for fitness gains"
        case 9...10:
            return "Maximum intensity - game-like conditions, full effort"
        default:
            return ""
        }
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.accentYellow)

                    Text("Session Notes")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                TextField("Add notes, goals, or reminders...", text: $editedNotes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
                    .onChange(of: editedNotes) { _ in
                        hasChanges = true
                    }
            }
        }
    }

    // MARK: - Exercises Card

    private var exercisesCard: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "figure.run")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("Exercises")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Spacer()

                    Text("\(exerciseNames.count) exercises")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                if exerciseNames.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "figure.run.circle")
                            .font(.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

                        Text("No exercises assigned")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                } else {
                    ForEach(exerciseNames, id: \.self) { name in
                        HStack {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundColor(DesignSystem.Colors.primaryGreen)

                            Text(name)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Note about exercise editing
                Text("Exercise assignments are currently read-only. Full exercise editing will be available in a future update.")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }

    // MARK: - Helper Methods

    private func loadExerciseNames() {
        // Fetch exercise names from Core Data based on exercise IDs
        let context = CoreDataManager.shared.context
        let exerciseIDs = session.exerciseIDs

        // Use perform block for thread safety
        context.perform {
            var names: [String] = []

            for exerciseId in exerciseIDs {
                let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", exerciseId as CVarArg)
                request.fetchLimit = 1

                do {
                    if let exercise = try context.fetch(request).first {
                        names.append(exercise.name ?? "Unknown Exercise")
                    }
                } catch {
                    #if DEBUG
                    print("Failed to fetch exercise: \(error)")
                    #endif
                }
            }

            // Update UI on main thread
            DispatchQueue.main.async {
                self.exerciseNames = names
            }
        }
    }

    private func saveChanges() {
        TrainingPlanService.shared.updateSession(
            sessionId: session.id,
            sessionType: selectedSessionType,
            duration: duration,
            intensity: intensity,
            notes: editedNotes.isEmpty ? nil : editedNotes
        )
        hasChanges = false
        onSave()
    }
}

// MARK: - Session Type Button

struct SessionTypeButton: View {
    let type: SessionType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: type.icon)
                    .font(.title3)

                Text(type.displayName)
                    .font(DesignSystem.Typography.labelSmall)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? typeColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? typeColor : DesignSystem.Colors.textSecondary)
            .cornerRadius(DesignSystem.CornerRadius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .stroke(isSelected ? typeColor : DesignSystem.Colors.textSecondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var typeColor: Color {
        switch type {
        case .technical: return DesignSystem.Colors.primaryGreen
        case .physical: return DesignSystem.Colors.accentOrange
        case .tactical: return DesignSystem.Colors.secondaryBlue
        case .recovery: return DesignSystem.Colors.accentYellow
        case .match: return DesignSystem.Colors.textPrimary
        }
    }
}

#Preview {
    SessionEditorView(
        session: PlanSessionModel(
            id: UUID(),
            sessionType: .technical,
            duration: 45,
            intensity: 6,
            notes: "Focus on first touch",
            isCompleted: false,
            completedAt: nil,
            actualDuration: nil,
            actualIntensity: nil,
            exerciseIDs: []
        ),
        dayId: UUID(),
        onSave: {}
    )
}
