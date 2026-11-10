import SwiftUI
import CoreData

// MARK: - New drill, written by hand (Train → New drill → Write your own)
//
// One form: name, then either a quick note or step-by-step sections, then category, level,
// duration and skills. Saved drills are stamped `.manual` and land in "My drills".

struct ManualDrillCreatorView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @State private var drillName = ""
    @State private var drillDescription = ""
    @State private var selectedCategory: DrillCategory = .technical
    @State private var selectedDifficulty: DifficultyLevel = .beginner
    @State private var duration = 30
    @State private var selectedSkills: Set<String> = []
    @State private var saveFailed = false

    // Step-by-step sections
    @State private var useStructuredMode = false
    @State private var setupRequirements = ""
    @State private var instructionSteps: [String] = [""]
    @State private var coachingPoints: [String] = [""]
    @State private var progressions: [String] = [""]
    @State private var selectedEquipment: Set<Equipment> = []

    private let availableSkills = [
        "Ball Control", "Dribbling", "Passing", "Shooting", "First Touch",
        "Speed", "Agility", "Endurance", "Strength", "Coordination",
        "Positioning", "Vision", "Decision Making", "Game Awareness", "Teamwork"
    ]

    private var isValid: Bool {
        if useStructuredMode {
            return !drillName.isEmpty && drillName.count >= 3 &&
                   !setupRequirements.isEmpty &&
                   instructionSteps.contains(where: { !$0.isEmpty })
        } else {
            return !drillName.isEmpty && drillName.count >= 3 &&
                   !drillDescription.isEmpty && drillDescription.count >= 10
        }
    }

    /// What is still missing, shown above the save button.
    private var validationHint: String? {
        if drillName.count < 3 { return "Give the drill a name (3 characters or more)." }
        if useStructuredMode {
            if setupRequirements.isEmpty { return "Describe the set-up." }
            if !instructionSteps.contains(where: { !$0.isEmpty }) { return "Add at least one step." }
        } else if drillDescription.count < 10 {
            return "Describe the drill in a sentence or two."
        }
        return nil
    }

    // Generate formatted instructions from structured sections
    private var formattedInstructions: String {
        var output = ""

        if !setupRequirements.isEmpty {
            output += "**Setup:**\n\(setupRequirements)\n"
            if !selectedEquipment.isEmpty {
                let equipmentNames = selectedEquipment.map { $0.displayName }.sorted()
                output += "Equipment: \(equipmentNames.joined(separator: ", "))\n"
            }
            output += "\n"
        }

        let validSteps = instructionSteps.filter { !$0.isEmpty }
        if !validSteps.isEmpty {
            output += "**Instructions:**\n"
            for (index, step) in validSteps.enumerated() {
                output += "\(index + 1). \(step)\n"
            }
            output += "\n"
        }

        let validPoints = coachingPoints.filter { !$0.isEmpty }
        if !validPoints.isEmpty {
            output += "**Coaching Points:**\n"
            for point in validPoints {
                output += "• \(point)\n"
            }
            output += "\n"
        }

        let validProgressions = progressions.filter { !$0.isEmpty }
        if !validProgressions.isEmpty {
            output += "**Progressions:**\n"
            for progression in validProgressions {
                output += "• \(progression)\n"
            }
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TQNavBar("New drill") {
                    TQNavAction("Cancel") { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                headerSection

                TQFormField("Name", text: $drillName, placeholder: "Cone dribbling circuit")
                    .onChange(of: drillName) { _, newValue in
                        if newValue.count > 50 { drillName = String(newValue.prefix(50)) }
                    }

                modeSection

                if useStructuredMode {
                    structuredSections
                } else {
                    DrillFormTextArea(label: "Description", text: $drillDescription,
                                      placeholder: "Set-up, what you do, what to focus on", lines: 4...8, limit: 500)
                }

                categorySection
                levelSection
                durationSection
                skillsSection
                saveSection
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQEyebrow("Your own drill")
            TQDisplayTitle("Write it\nyour way", size: .medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modeSection: some View {
        TQSegment(
            options: ["Quick note", "Step by step"],
            selectedIndex: Binding(
                get: { useStructuredMode ? 1 : 0 },
                set: { useStructuredMode = $0 == 1 }
            )
        )
    }

    @ViewBuilder
    private var structuredSections: some View {
        DrillFormTextArea(label: "Set-up", text: $setupRequirements,
                          placeholder: "Area, cone placement, where you start", lines: 3...6)

        DrillFormGroup("Equipment") {
            DrillFormChips(
                options: Equipment.allCases.filter { $0 != .none }.map(\.displayName),
                isSelected: { name in selectedEquipment.contains { $0.displayName == name } },
                onTap: { name in
                    guard let item = Equipment.allCases.first(where: { $0.displayName == name }) else { return }
                    if selectedEquipment.contains(item) {
                        selectedEquipment.remove(item)
                    } else {
                        selectedEquipment.insert(item)
                    }
                }
            )
        }

        DrillFormLineList(title: "Steps", lines: $instructionSteps, numbered: true,
                          placeholder: "What happens next", addTitle: "Add step")
        DrillFormLineList(title: "Coaching points", lines: $coachingPoints, numbered: false,
                          placeholder: "One thing to get right", addTitle: "Add point")
        DrillFormLineList(title: "Make it harder or easier", lines: $progressions, numbered: false,
                          placeholder: "Harder: add a defender", addTitle: "Add variation")
    }

    private var categorySection: some View {
        DrillFormGroup("Category") {
            DrillFormChips(
                options: DrillCategory.allCases.map(\.displayName),
                isSelected: { $0 == selectedCategory.displayName },
                onTap: { name in
                    if let match = DrillCategory.allCases.first(where: { $0.displayName == name }) {
                        selectedCategory = match
                    }
                }
            )
        }
    }

    private var levelSection: some View {
        DrillFormGroup("Level") {
            TQSegment(
                options: DifficultyLevel.allCases.map(\.displayName),
                selectedIndex: Binding(
                    get: { DifficultyLevel.allCases.firstIndex(of: selectedDifficulty) ?? 0 },
                    set: { index in
                        let levels = DifficultyLevel.allCases
                        if levels.indices.contains(index) { selectedDifficulty = levels[index] }
                    }
                )
            )
        }
    }

    private var durationSection: some View {
        VStack(spacing: 0) {
            TQRule()
            TQValueStepper(label: "Duration", value: $duration, range: 10...120, step: 5) { "\($0) min" }
            TQRule()
        }
    }

    private var skillsSection: some View {
        DrillFormGroup("Skills") {
            DrillFormChips(options: availableSkills, isSelected: { selectedSkills.contains($0) }) { skill in
                if selectedSkills.contains(skill) {
                    selectedSkills.remove(skill)
                } else {
                    selectedSkills.insert(skill)
                }
            }
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if saveFailed {
                TQBanner(.error, lead: "Couldn't save.", message: "Try again.")
            } else if let validationHint {
                TQBody(validationHint, tone: .muted, size: 13)
            }
            TQButton("Save drill") { saveDrill() }
                .disabled(!isValid)
                .opacity(isValid ? 1 : 0.4)
                .accessibilityIdentifier("manualDrill.save")
        }
        .padding(.top, DesignSystem.Spacing.sm)
    }

    // MARK: - Actions

    private func saveDrill() {
        guard isValid else { return }
        let exercise = Exercise(context: viewContext)
        exercise.id = UUID()
        exercise.source = TrainDrill.Source.manual.rawValue
        exercise.name = drillName
        exercise.category = selectedCategory.rawValue
        exercise.difficulty = Int16(selectedDifficulty.numericValue)
        exercise.targetSkills = Array(selectedSkills)
        exercise.isYouTubeContent = false
        exercise.estimatedDurationSeconds = Int16(clamping: max(duration, 1) * 60)

        if useStructuredMode {
            exercise.exerciseDescription = "Manual Drill"
            exercise.instructions = formattedInstructions
            exercise.equipment = Exercise.equipmentText(selectedEquipment.filter { $0 != .none }.map { $0.displayName }.sorted())
            exercise.cue = coachingPoints
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        } else {
            exercise.exerciseDescription = drillDescription
            exercise.instructions = nil
        }

        exercise.player = player

        do {
            try viewContext.save()
            HapticManager.shared.success()
            dismiss()
        } catch {
            viewContext.delete(exercise)
            saveFailed = true
            HapticManager.shared.error()
            #if DEBUG
            print("Failed to save drill: \(error)")
            #endif
        }
    }
}

// MARK: - Editable line list (steps, points, variations)

/// A growing list of one-line fields: "01 …" when numbered, a grass dash otherwise.
struct DrillFormLineList: View {
    let title: String
    @Binding var lines: [String]
    let numbered: Bool
    let placeholder: String
    let addTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader(title)
            TQRule()
            ForEach(Array(lines.indices), id: \.self) { index in
                row(index)
            }
            TQTextLink(addTitle, arrow: false) { lines.append("") }
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func binding(_ index: Int) -> Binding<String> {
        Binding(
            get: { lines.indices.contains(index) ? lines[index] : "" },
            set: { if lines.indices.contains(index) { lines[index] = $0 } }
        )
    }

    private func row(_ index: Int) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(numbered ? String(format: "%02d", index + 1) : "–")
                .font(Font.system(size: 14, weight: .bold).width(.condensed))
                .tracking(0.6)
                .foregroundColor(DesignSystem.Colors.grass)
                .frame(width: 22, alignment: .leading)
            TextField(placeholder, text: binding(index), axis: .vertical)
                .lineLimit(1...4)
                .font(Font.system(size: 15, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("\(title) \(index + 1)")
            if lines.count > 1 {
                Button {
                    if lines.indices.contains(index) { lines.remove(at: index) }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(title.lowercased()) \(index + 1)")
            }
        }
        .padding(.vertical, 10)
        .frame(minHeight: DesignSystem.Spacing.hitTarget)
        .overlay(alignment: .bottom) { TQRule() }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return ManualDrillCreatorView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}
#endif
