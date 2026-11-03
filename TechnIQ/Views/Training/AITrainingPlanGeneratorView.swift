import SwiftUI
import CoreData

// MARK: - New plan · AI (Touchline)
//
// Form → generating (pitch surface with spinner and phase rows, Cancel keeps nothing) → preview
// sheet (Save / Regenerate / Modify) → saved. Level, position, weak spots, training days and the
// next match start from the Training profile (PlanBuilderPrefill) and stay editable; the next
// match is one shared fact, so saving a plan writes it back to the profile.

struct AITrainingPlanGeneratorView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    let player: Player

    // Form inputs
    @State private var planName: String = ""
    @State private var duration: Int = 6
    @State private var difficultyIndex: Int = 1
    @State private var categoryIndex: Int = 0
    @State private var targetRole: String = ""
    @State private var focusAreas: [String] = []
    @State private var newFocusArea: String = ""
    @State private var preferredDays: Set<DayOfWeek> = []
    @State private var restDays: Set<DayOfWeek> = []
    @State private var position: String = ""
    @State private var weakSpots: [WeaknessCategory] = []
    @State private var nextMatch: Date?
    @State private var didPrefill = false

    // Generation state
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var generatedPlan: TrainingPlan?
    @State private var generatedStructure: GeneratedPlanStructure?
    @State private var showPreview = false
    @State private var regenerationCount = 0
    @State private var loadingPhase: LoadingPhase = .connecting
    @State private var generationTask: Task<Void, Never>?

    private let difficulties = PlanDifficulty.allCases
    private let categories = PlanCategory.allCases
    private let weekdays = DayOfWeek.allCases.sorted { $0.sortOrder < $1.sortOrder }

    private var difficulty: PlanDifficulty { difficulties[min(max(difficultyIndex, 0), difficulties.count - 1)] }
    private var category: PlanCategory { categories[min(max(categoryIndex, 0), categories.count - 1)] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("New plan · AI", tone: .grass) {
                    TQNavAction("Cancel") { cancelGeneration(); dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                if let plan = generatedPlan {
                    savedContent(plan)
                } else if isGenerating {
                    generatingContent
                } else {
                    form
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isGenerating)
        .alert("Couldn't build the plan", isPresented: $showError) {
            Button("Try again") { generatePlan() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showPreview) {
            if let structure = generatedStructure {
                AITrainingPlanPreviewView(
                    generatedPlan: structure,
                    player: player,
                    customName: planName,
                    onRegenerate: {
                        regenerationCount += 1
                        generatePlan()
                    },
                    onModifyParameters: {},
                    onSave: { savePlanFromStructure(structure) }
                )
            }
        }
        .onAppear { prefillFromPlayerProfile() }
        .onDisappear { cancelGeneration() }
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow("Built around you", size: 11)
                TQDisplayTitle("What should\nthe plan do?", size: .medium)
                TQBody("Filled in from your training profile. Change anything for this plan.")
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Shape")
                TQRule()
                // Every plan closes with a retest week on top of these (RetestWeek).
                TQValueStepper(label: "Weeks", value: $duration, range: 2...12) { "\($0) + retest" }
                TQRule()
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Level")
                TQSegment(options: difficulties.map(\.displayName), selectedIndex: $difficultyIndex)
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Position")
                TQChipRow {
                    ForEach(OnboardingMapping.positions, id: \.self) { item in
                        TQChip(item, isSelected: position == item) { position = item }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Weak spots · up to \(OnboardingMapping.maxWeakSpots)")
                TQChipRow {
                    ForEach(WeaknessCategory.allCases, id: \.self) { skill in
                        TQChip(skill.displayName, isSelected: weakSpots.contains(skill)) { toggleWeakSpot(skill) }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Focus")
                TQChipRow {
                    ForEach(Array(categories.enumerated()), id: \.offset) { index, item in
                        TQChip(item == .position ? "Position" : item.displayName, isSelected: categoryIndex == index) { categoryIndex = index }
                    }
                }
                if category == .position {
                    TQFormField("Position", text: $targetRole, placeholder: "Striker")
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Work on")
                HStack(spacing: 10) {
                    TQFormField("Skill or area", text: $newFocusArea, placeholder: "Weak-foot finishing")
                        .onSubmit { addFocusArea() }
                    TQIconButton("plus", style: .raised, shape: .square, size: 44, accessibilityLabel: "Add focus area") { addFocusArea() }
                        .disabled(newFocusArea.trimmingCharacters(in: .whitespaces).isEmpty)
                        .padding(.top, 18)
                }
                if !focusAreas.isEmpty {
                    TQChipRow {
                        ForEach(focusAreas, id: \.self) { area in
                            TQChip(area, isSelected: true, icon: "xmark") { removeFocusArea(area) }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                TQGroupHeader("Days you can train")
                TQChipRow {
                    ForEach(weekdays, id: \.self) { day in
                        TQChip(day.shortName, isSelected: preferredDays.contains(day)) { toggle(day, in: &preferredDays, removingFrom: &restDays) }
                    }
                }
                TQGroupHeader("Days you must rest")
                TQChipRow {
                    ForEach(weekdays, id: \.self) { day in
                        TQChip(day.shortName, isSelected: restDays.contains(day)) { toggle(day, in: &restDays, removingFrom: &preferredDays) }
                    }
                }
                TQBody("Leave both empty and the coach lays out the week.", tone: .muted, size: 13)
            }

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Next match")
                TQRule()
                TQDateRow("Next match", subtitle: "Light the day before, recovery the day after",
                          date: $nextMatch, range: NextMatchDefaults.range()) { NextMatchDefaults.suggested() }
                    .accessibilityIdentifier("planGenerator.nextMatch")
            }

            TQFormField("Plan name (optional)", text: $planName, placeholder: "The coach names it otherwise")

            TQButton("Build the plan", icon: "sparkles") { generatePlan() }
                .disabled(!isFormValid)
                .accessibilityIdentifier("planGenerator.build")
        }
    }

    private func toggle(_ day: DayOfWeek, in set: inout Set<DayOfWeek>, removingFrom other: inout Set<DayOfWeek>) {
        if set.contains(day) {
            set.remove(day)
        } else {
            set.insert(day)
            other.remove(day)
        }
    }

    // MARK: - Generating

    private var phaseRows: [(String, TQStepRow.State)] {
        let all: [LoadingPhase] = [.connecting, .analyzing, .generating, .structuring, .finalizing]
        let current = all.firstIndex(of: loadingPhase) ?? 0
        return all.enumerated().map { index, phase in
            (phase.title, index < current ? .done : (index == current ? .running : .pending))
        }
    }

    private var generatingContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 6) {
                TQEyebrow("You asked for", tone: .muted, size: 11)
                Text(requestSummary)
                    .font(Font.system(size: 15, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous).fill(DesignSystem.Colors.surfaceRaised))

            ZStack {
                VStack(spacing: 10) {
                    TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 3, size: 28)
                    Text(loadingPhase.description)
                        .font(Font.system(size: 14, weight: .semibold).width(.condensed))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundColor(DesignSystem.Colors.textOnPitch)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .pitchSurface(.diagram, cornerRadius: DesignSystem.CornerRadius.pitchCardCompact)

            TQRowList {
                ForEach(Array(phaseRows.enumerated()), id: \.offset) { _, row in
                    TQStepRow(text: row.0, state: row.1)
                }
            }

            if regenerationCount > 0 {
                TQBody("Attempt \(regenerationCount + 1).", tone: .muted, size: 13)
            }

            TQButton("Cancel", style: .ghost) { cancelGeneration() }

            Text("Usually 20–40 s. Cancel keeps nothing.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .frame(maxWidth: .infinity)
        }
        .onAppear { startPhaseProgression() }
    }

    private var requestSummary: String {
        var parts = ["\(duration) weeks + retest week", difficulty.displayName.lowercased(), category == .position ? (targetRole.isEmpty ? "position" : targetRole) : category.displayName.lowercased()]
        if !focusAreas.isEmpty { parts.append(focusAreas.joined(separator: ", ")) }
        if !preferredDays.isEmpty { parts.append(preferredDays.sorted().map(\.shortName).joined(separator: " ")) }
        return parts.joined(separator: " · ")
    }

    private func startPhaseProgression() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { if isGenerating { loadingPhase = .analyzing } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { if isGenerating { loadingPhase = .generating } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { if isGenerating { loadingPhase = .structuring } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { if isGenerating { loadingPhase = .finalizing } }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        loadingPhase = .connecting
    }

    // MARK: - Saved

    private func savedContent(_ plan: TrainingPlan) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQHeroCard(
                eyebrow: "Plan saved · \(plan.durationWeeks) weeks · \(plan.difficulty ?? "Intermediate")",
                title: plan.name ?? "Your plan",
                body: "It's in My plans. Open it and tap Start to make it your active plan.",
                actionTitle: "Done",
                actionIcon: nil,
                markings: .heroSimple,
                action: { dismiss() }
            )
        }
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        duration >= 2 && duration <= 12
    }

    /// Once per presentation: the preview sheet re-triggers onAppear and must not undo edits.
    private func prefillFromPlayerProfile() {
        guard !didPrefill else { return }
        didPrefill = true
        let prefill = PlanBuilderPrefill.from(player: player)
        difficultyIndex = difficulties.firstIndex(of: prefill.difficulty) ?? 1
        position = prefill.position ?? ""
        targetRole = prefill.position ?? ""
        weakSpots = prefill.weakSpots
        preferredDays = Set(prefill.trainingDays)
        restDays = []
        nextMatch = prefill.nextMatchDate
    }

    private func toggleWeakSpot(_ skill: WeaknessCategory) {
        if let index = weakSpots.firstIndex(of: skill) {
            weakSpots.remove(at: index)
        } else if weakSpots.count < OnboardingMapping.maxWeakSpots {
            weakSpots.append(skill)
        }
        HapticManager.shared.selectionChanged()
    }

    private func addFocusArea() {
        let trimmed = newFocusArea.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !focusAreas.contains(trimmed) else { return }
        focusAreas.append(trimmed)
        newFocusArea = ""
    }

    private func removeFocusArea(_ area: String) {
        focusAreas.removeAll { $0 == area }
    }

    private func generatePlan() {
        isGenerating = true
        loadingPhase = .connecting
        generationTask?.cancel()

        generationTask = Task {
            do {
                try Task.checkCancellation()
                let preferredDayStrings = preferredDays.sorted().map { $0.rawValue }
                let restDayStrings = restDays.sorted().map { $0.rawValue }
                let structure = try await AIRecommendationService.shared.generateTrainingPlan(
                    for: player,
                    duration: duration,
                    difficulty: difficulty.rawValue,
                    category: category.rawValue,
                    targetRole: category == .position ? targetRole : nil,
                    focusAreas: focusAreas,
                    preferredDays: preferredDayStrings,
                    restDays: restDayStrings,
                    extras: PlanRequestExtras(
                        weakSpots: weakSpots.map(\.displayName),
                        position: position.isEmpty ? nil : position,
                        nextMatchDate: nextMatch,
                        planStartDate: Date()
                    )
                )
                try Task.checkCancellation()
                await MainActor.run {
                    generatedStructure = structure
                    isGenerating = false
                    loadingPhase = .connecting
                    showPreview = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    isGenerating = false
                    loadingPhase = .connecting
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    loadingPhase = .connecting
                    errorMessage = "\(error.localizedDescription)\n\nCheck your connection and try again."
                    showError = true
                }
            }
        }
    }

    private func savePlanFromStructure(_ structure: GeneratedPlanStructure) {
        // The next match is the profile's; write it first so the new plan is shaped around it.
        TrainingPlanService.shared.setNextMatch(nextMatch, for: player)
        if let plan = TrainingPlanService.shared.createPlanFromAIGeneration(structure, for: player) {
            if !planName.trimmingCharacters(in: .whitespaces).isEmpty {
                plan.name = planName
                try? viewContext.save()
            }
            generatedPlan = plan
            showPreview = false
            HapticManager.shared.success()
        } else {
            showPreview = false
            errorMessage = "The plan came back but couldn't be saved. Please try again."
            showError = true
        }
    }
}

// MARK: - Loading Phase Enum

enum LoadingPhase: Equatable {
    case connecting
    case analyzing
    case generating
    case structuring
    case finalizing

    var title: String {
        switch self {
        case .connecting: return "Reaching the coach"
        case .analyzing: return "Reading your profile and history"
        case .generating: return "Writing the weeks"
        case .structuring: return "Laying out days and sessions"
        case .finalizing: return "Checking the schedule"
        }
    }

    var description: String {
        switch self {
        case .connecting: return "Connecting"
        case .analyzing: return "Reading your profile"
        case .generating: return "Writing the plan"
        case .structuring: return "Building the schedule"
        case .finalizing: return "Almost there"
        }
    }

    var progress: Double {
        switch self {
        case .connecting: return 0.1
        case .analyzing: return 0.3
        case .generating: return 0.6
        case .structuring: return 0.8
        case .finalizing: return 0.95
        }
    }
}
