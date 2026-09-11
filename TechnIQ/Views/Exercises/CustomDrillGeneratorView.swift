import SwiftUI

// MARK: - AI drill generator (Touchline 9f / 9g)
//
// Form → generating (pitch card with spinner, pipeline step rows, Cancel) → created (open the drill)
// or failed (error banner above Try again / Edit the request, close matches from the library).
// Offline disables Try again; a quota error turns it into Upgrade; a moderation block leaves Edit only.

struct CustomDrillGeneratorView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drillService = CustomDrillService.shared
    @ObservedObject private var cloudService = CloudService.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var request = CustomDrillRequest.empty
    @State private var phase: Phase = .form
    @State private var showingDrillDetail = false
    @State private var showingPaywall = false
    @State private var closeMatch: Exercise?

    enum Phase: Equatable {
        case form
        case generating
        case created(Exercise, warnings: [String])
        case failed(Failure)
    }

    /// Why generation failed, mapped from CustomDrillError so the same layout serves every case.
    struct Failure: Equatable {
        enum Kind: Equatable { case generic, offline, quota, moderation }
        let kind: Kind
        let title: String
        let message: String
    }

    var body: some View {
        NavigationStack {
            TQScreen {
                VStack(spacing: DesignSystem.Spacing.section) {
                    TQNavBar("New drill · AI", tone: .grass) {
                        TQNavAction("Cancel") { cancel() }
                    } trailing: {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .padding(.top, 8)

                    switch phase {
                    case .form:
                        mainContent
                    case .generating:
                        generatingContent
                    case .created(let exercise, let warnings):
                        createdContent(exercise, warnings: warnings)
                    case .failed(let failure):
                        failedContent(failure)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .interactiveDismissDisabled(phase == .generating)
        .sheet(isPresented: $showingDrillDetail, onDismiss: { dismiss() }) {
            if case .created(let exercise, _) = phase {
                ExerciseDetailView(exercise: exercise)
            }
        }
        .sheet(item: $closeMatch) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: .customDrill)
        }
        .onAppear { applyDebugPhase() }
    }

    /// `-TQDrillPhase generating|failed` (DEBUG) opens the sheet in a given state for screenshots.
    private func applyDebugPhase() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-TQDrillPhase"), index + 1 < args.count else { return }
        request.skillDescription = "Left-foot passing under pressure, 15 minutes, I have a wall and four cones."
        switch args[index + 1] {
        case "generating":
            phase = .generating
            drillService.generationProgress = 0.6
        case "failed":
            phase = .failed(Failure(kind: .generic, title: "Couldn't generate this one", message: "The drill came back with a layout that didn't pass our checks. Nothing was saved and your quota wasn't used."))
        default:
            break
        }
        #endif
    }

    // MARK: - Request summary ("You asked for")

    private var requestSummary: String {
        let description = request.skillDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !description.isEmpty { return description }
        let weaknesses = request.selectedWeaknesses.map { $0.specific }
        return weaknesses.isEmpty ? "A drill for \(request.category.displayName.lowercased()) work" : weaknesses.joined(separator: ", ")
    }

    private var youAskedFor: some View {
        VStack(alignment: .leading, spacing: 6) {
            TQEyebrow("You asked for", tone: .muted, size: 11)
            Text(requestSummary)
                .font(Font.system(size: 15, weight: .regular))
                .lineSpacing(15 * 0.45)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous).fill(DesignSystem.Colors.surfaceRaised))
    }

    // MARK: - Generating (9f)

    private var pipelineSteps: [(String, TQStepRow.State)] {
        let progress = drillService.generationProgress
        func state(_ threshold: Double, _ next: Double) -> TQStepRow.State {
            if progress >= next { return .done }
            if progress >= threshold { return .running }
            return .pending
        }
        return [
            ("Picked the archetype", state(0.0, 0.35)),
            ("Wrote the steps and coaching points", state(0.35, 0.55)),
            ("Laying out cones and the wall", state(0.55, 0.75)),
            ("Checking geometry", state(0.75, 0.9))
        ]
    }

    private var generatingContent: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            youAskedFor

            ZStack {
                VStack(spacing: 10) {
                    TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 3, size: 28)
                    Text("Drawing the setup")
                        .font(Font.system(size: 14, weight: .semibold).width(.condensed))
                        .textCase(.uppercase)
                        .tracking(1.1)
                        .foregroundColor(DesignSystem.Colors.textOnPitch)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .pitchSurface(.diagram, cornerRadius: DesignSystem.CornerRadius.pitchCardCompact)
            .accessibilityLabel("Drawing the setup")

            TQRowList {
                ForEach(Array(pipelineSteps.enumerated()), id: \.offset) { _, step in
                    TQStepRow(text: step.0, state: step.1)
                }
            }

            Spacer()

            Text("Usually 15–25 s. Cancel keeps nothing.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(.bottom, DesignSystem.Spacing.lg)
        }
    }

    // MARK: - Created

    private func createdContent(_ exercise: Exercise, warnings: [String]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            if !warnings.isEmpty {
                TQBanner(.warning, lead: "Created with quality notes.", message: warnings.joined(separator: " "), layout: .block)
            }
            TQHeroCard(
                eyebrow: "Drill ready · \(exercise.category ?? "Technical")",
                title: exercise.name ?? "Your drill",
                figures: [("\(max(1, Int(exercise.estimatedDurationSeconds) / 60))", "min"), ("\(max(exercise.difficulty, 1))", "lvl")],
                body: "Saved to your library. Open it to see the diagram and steps, or start it from Train.",
                actionTitle: "Open drill",
                actionIcon: nil,
                markings: .heroSimple,
                action: { showingDrillDetail = true }
            )
            TQButton("Done", style: .ghost) { dismiss() }
            Spacer()
        }
    }

    // MARK: - Failed (9g)

    private var isOffline: Bool { !cloudService.isNetworkAvailable }

    private func failedContent(_ failure: Failure) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            youAskedFor
            TQBanner(.error, lead: failure.title, message: failure.message, layout: .block)

            VStack(spacing: 10) {
                switch failure.kind {
                case .moderation:
                    EmptyView()
                case .quota:
                    TQButton("Upgrade to Pro") { showingPaywall = true }
                case .offline, .generic:
                    TQButton("Try again") { generateDrill() }
                        .disabled(isOffline)
                }
                TQButton("Edit the request", style: .raised) { phase = .form }
            }

            let matches = closeMatches
            if !matches.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    TQGroupHeader("Close matches in your library")
                    TQRowList {
                        ForEach(matches, id: \.objectID) { exercise in
                            TQRow(exercise.name ?? "Drill",
                                  subtitle: "\(exercise.category ?? "Drill") · Lvl \(max(exercise.difficulty, 1))" + (exercise.estimatedDurationSeconds > 0 ? " · \(max(1, Int(exercise.estimatedDurationSeconds) / 60)) min" : ""),
                                  leading: .tile(TQTile.category(exercise.category, isAI: exercise.isAIGenerated, isVideo: exercise.isYouTubeExercise)),
                                  verticalPadding: DesignSystem.Spacing.rowVertical,
                                  action: { closeMatch = exercise })
                        }
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
        }
    }

    /// Up to three library drills sharing words with the request (or its weakness categories).
    private var closeMatches: [Exercise] {
        let words = Set((requestSummary + " " + request.selectedWeaknesses.map { $0.category }.joined(separator: " "))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 3 })
        guard !words.isEmpty else { return [] }
        let library = CoreDataManager.shared.fetchExercises(for: player)
        let scored = library.map { exercise -> (Exercise, Int) in
            let haystack = ((exercise.name ?? "") + " " + (exercise.targetSkills ?? []).joined(separator: " ") + " " + (exercise.weaknessCategories ?? "")).lowercased()
            return (exercise, words.filter { haystack.contains($0) }.count)
        }
        return scored.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(3).map { $0.0 }
    }

    private func failure(for error: Error) -> Failure {
        if let drillError = error as? CustomDrillError {
            switch drillError {
            case .networkError:
                return Failure(
                    kind: .offline,
                    title: "You're offline",
                    message: "The coach needs a connection to build a drill. Try again when you're back online."
                )
            case .dailyLimitReached, .quotaExceeded:
                return Failure(kind: .quota, title: "No AI drills left today", message: drillError.errorDescription ?? "")
            case .invalidRequest:
                return Failure(kind: .moderation, title: "Couldn't use that request", message: drillError.errorDescription ?? "")
            default:
                break
            }
        }
        if isOffline {
            return Failure(
                kind: .offline,
                title: "You're offline",
                message: "The coach needs a connection to build a drill. Try again when you're back online."
            )
        }
        return Failure(
            kind: .generic,
            title: "Couldn't generate this one",
            message: "The drill came back with a layout that didn't pass our checks. Nothing was saved and your quota wasn't used."
        )
    }

    private func cancel() {
        dismiss()
    }

    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                headerSection

                // Weakness suggestions (context-aware)
                WeaknessSuggestionsCard(player: player) { weakness in
                    if !request.selectedWeaknesses.contains(where: { $0.category == weakness.category && $0.specific == weakness.specific }) {
                        request.selectedWeaknesses.append(weakness)
                    }
                }

                // Two-tier weakness picker
                weaknessPickerSection

                skillDescriptionSection
                categorySection
                difficultySection
                equipmentSection
                numberOfPlayersSection
                fieldSizeSection
                generateButton
                DrillSafetyDisclaimer()
            }
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - Weakness Picker Section

    private var weaknessPickerSection: some View {
        WeaknessPickerView(selectedWeaknesses: $request.selectedWeaknesses)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQEyebrow("Describe what you want to fix")
            TQDisplayTitle("What should the coach build?", size: .medium)
            TQBody("Pick a weak spot or write a sentence. The coach turns it into a drill with a diagram in about 20 seconds.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Skill Description Section
    
    private var skillDescriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Anything else? (optional)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            ModernCard {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    TextField("e.g., improve first touch under pressure, better crossing accuracy...", text: $request.skillDescription, axis: .vertical)
                        .font(DesignSystem.Typography.bodyMedium)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                    
                    HStack {
                        Spacer()
                        Text("\(request.skillDescription.count)/500")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(request.skillDescription.isValidSkillDescription ? 
                                           DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
            
            if !request.skillDescription.isEmpty && !request.skillDescription.isValidSkillDescription {
                Text("Please provide at least 10 characters describing what you want to work on")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.error)
            }
        }
    }
    
    // MARK: - Category Section
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Category")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.sm) {
                ForEach(DrillCategory.allCases, id: \.self) { category in
                    CategorySelectionCard(
                        category: category,
                        isSelected: request.category == category
                    ) {
                        request.category = category
                    }
                }
            }
        }
    }
    
    // MARK: - Difficulty Section
    
    private var difficultySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Difficulty Level")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(DifficultyLevel.allCases, id: \.self) { difficulty in
                    DifficultySelectionCard(
                        difficulty: difficulty,
                        isSelected: request.difficulty == difficulty
                    ) {
                        request.difficulty = difficulty
                    }
                }
            }
        }
    }
    
    // MARK: - Equipment Section
    
    private var equipmentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Available Equipment")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    EquipmentSelectionCard(
                        equipment: equipment,
                        isSelected: request.equipment.contains(equipment)
                    ) {
                        if request.equipment.contains(equipment) {
                            request.equipment.remove(equipment)
                        } else {
                            request.equipment.insert(equipment)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Number of Players Section

    private var numberOfPlayersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Number of Players: \(request.numberOfPlayers)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            ModernCard {
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Slider(value: Binding(
                        get: { Double(request.numberOfPlayers) },
                        set: { request.numberOfPlayers = Int($0) }
                    ), in: 1...6, step: 1)
                    .tint(DesignSystem.Colors.primaryGreen)

                    HStack {
                        Text("1")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        Text("6")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
    }

    // MARK: - Field Size Section

    private var fieldSizeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Field Size")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(FieldSize.allCases, id: \.self) { size in
                    Button {
                        request.fieldSize = size
                    } label: {
                        ModernCard(padding: DesignSystem.Spacing.sm) {
                            VStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: size.icon)
                                    .font(.title3)
                                    .foregroundColor(request.fieldSize == size ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.primaryGreen)

                                Text(size.displayName)
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(request.fieldSize == size ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .background(
                            request.fieldSize == size ? DesignSystem.Colors.primaryGreen : Color.clear
                        )
                        .cornerRadius(DesignSystem.CornerRadius.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                                .stroke(
                                    request.fieldSize == size ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                                    lineWidth: request.fieldSize == size ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    // MARK: - Generate Button
    
    private var generateButton: some View {
        TQButton("Generate a drill") { generateDrill() }
            .disabled(!request.isValid)
    }
    
    // MARK: - Actions
    
    private func generateDrill() {
        phase = .generating
        Task {
            do {
                let exercise = try await drillService.generateCustomDrill(request: request, for: player)
                SubscriptionManager.shared.markCustomDrillUsed()
                var warnings: [String] = []
                if case .success(let response) = drillService.generationState {
                    warnings = response.validationWarnings ?? []
                }
                phase = .created(exercise, warnings: warnings)
            } catch {
                #if DEBUG
                print("Failed to generate drill: \(error)")
                #endif
                phase = .failed(failure(for: error))
            }
        }
    }
}

// MARK: - Selection Cards

struct CategorySelectionCard: View {
    let category: DrillCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: category.iconSystemName)
                        .font(.title3)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.primaryGreen)
                    Text(category.displayName)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DifficultySelectionCard: View {
    let difficulty: DifficultyLevel
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: difficulty.iconSystemName)
                        .font(.caption)
                        .foregroundColor(difficultyColor)
                    Text(difficulty.displayName)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var difficultyColor: Color {
        switch difficulty {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .red
        }
    }
}

struct EquipmentSelectionCard: View {
    let equipment: Equipment
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ModernCard(padding: DesignSystem.Spacing.xs) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: equipment.icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.primaryGreen)
                    
                    Text(equipment.displayName)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(isSelected ? DesignSystem.Colors.primaryDark : DesignSystem.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            }
            .background(
                isSelected ? DesignSystem.Colors.primaryGreen : Color.clear
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                    .stroke(
                        isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.neutral300,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Safety Disclaimer

/// Footer shown on drill surfaces. Not medical advice; encourages warm-up.
struct DrillSafetyDisclaimer: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "info.circle")
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .accessibilityHidden(true)
            Text("Warm up first. Stop if anything hurts. Not medical advice.")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"
    
    return CustomDrillGeneratorView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}