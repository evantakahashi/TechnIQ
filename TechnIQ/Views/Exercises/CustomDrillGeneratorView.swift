import SwiftUI

// MARK: - AI drill generator (Touchline 9f / 9g)
//
// The one generator behind every entry point (Train's + New drill, the Home hero, the coach's
// suggestions, a drill's "Make it harder"). Quick by default: pick a weak spot or write a sentence
// and go; category, level, equipment, players and pitch size sit behind "More options" with sane
// defaults. Form → generating (pitch card with spinner, pipeline step rows, Cancel) → created
// (open the drill, or hand it straight to `onCreated` when a caller starts training with it) or
// failed (error banner above Try again / Edit the request, close matches from the library).
// Offline disables Try again; a quota error turns it into Upgrade; a moderation block leaves Edit only.

struct CustomDrillGeneratorView: View {
    /// What an entry point already knows: a weak spot, a sentence, a level.
    struct Prefill {
        var weakness: SelectedWeakness? = nil
        var text: String = ""
        var difficulty: DifficultyLevel? = nil
    }

    let player: Player
    var prefill: Prefill? = nil
    /// When set, a created drill is handed over and the sheet closes instead of showing "Drill ready".
    var onCreated: ((Exercise) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var drillService = CustomDrillService.shared
    @ObservedObject private var cloudService = CloudService.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    @State private var request = CustomDrillRequest.empty
    @State private var showingMoreOptions = false
    @State private var touchedCategory = false
    @State private var didApplyPrefill = false
    @State private var phase: Phase = .form
    @State private var showingDrillDetail = false
    @State private var showingPaywall = false
    @State private var closeMatch: Exercise?
    @State private var generationTask: Task<Void, Never>?

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
        .onAppear {
            applyPrefill()
            applyDebugPhase()
        }
    }

    // MARK: - Defaults and prefill

    private var playerDifficulty: DifficultyLevel {
        switch player.experienceLevel?.lowercased() {
        case "beginner": return .beginner
        case "advanced", "professional", "elite": return .advanced
        default: return .intermediate
        }
    }

    /// Quick mode starts from what a solo player usually has: a ball, a few cones and a goal,
    /// their own level, one player, a medium space. Everything is still editable under More options.
    private func applyPrefill() {
        guard !didApplyPrefill else { return }
        didApplyPrefill = true
        request.equipment = [.ball, .cones, .goals]
        request.difficulty = prefill?.difficulty ?? playerDifficulty
        if let weakness = prefill?.weakness { request.selectedWeaknesses = [weakness] }
        if let text = prefill?.text, !text.isEmpty { request.skillDescription = text }
    }

    /// The category follows the weak spot unless the player set it themselves.
    static func inferredCategory(for weaknesses: [SelectedWeakness]) -> DrillCategory {
        guard let first = weaknesses.first else { return .technical }
        switch first.category {
        case "Defending", "Positioning": return .tactical
        case "Speed & Agility", "Stamina": return .physical
        default: return .technical
        }
    }

    private var moreOptionsSummary: String {
        let equipment = request.equipment.isEmpty ? "no equipment" : request.equipment.map { $0.rawValue.lowercased() }.sorted().joined(separator: ", ")
        let category = touchedCategory ? request.category.displayName : Self.inferredCategory(for: request.selectedWeaknesses).displayName
        return "\(category) · \(request.difficulty.displayName) · \(equipment) · \(request.numberOfPlayers) player\(request.numberOfPlayers == 1 ? "" : "s") · \(request.fieldSize.displayName.lowercased())"
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
                                  leading: .tile(TQTile.category(exercise.category, isAI: exercise.drillSource == .ai, isVideo: exercise.drillSource == .video)),
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
        generationTask?.cancel()
        generationTask = nil
        dismiss()
    }

    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                headerSection
                weaknessPickerSection
                skillDescriptionSection
                moreOptionsSection
                generateButton
                if !subscriptionManager.isPro {
                    TQBody(subscriptionManager.freeDrillsLabel, tone: .muted, size: 13)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("generator.freeDrills")
                }
                DrillSafetyDisclaimer()
            }
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
    }

    // MARK: - More options (collapsed by default)

    private var moreOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            TQRowList {
                TQRow(
                    showingMoreOptions ? "Fewer options" : "More options",
                    subtitle: showingMoreOptions ? nil : moreOptionsSummary,
                    accessory: .none,
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: { withAnimation(DesignSystem.Animation.quick) { showingMoreOptions.toggle() } }
                )
                .accessibilityIdentifier("generator.moreOptions")
            }
            if showingMoreOptions {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    categorySection
                    difficultySection
                    equipmentSection
                    numberOfPlayersSection
                    fieldSizeSection
                }
            }
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
            TQDisplayTitle("What should \(CoachIdentity.name()) build?", size: .medium)
            TQBody("Pick a weak spot or write a sentence. \(CoachIdentity.name()) turns it into a drill with a diagram in about 20 seconds.")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Skill Description Section

    private var skillDescriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            TQGroupHeader("Anything else? (optional)")
            TextField("e.g. first touch under pressure, crossing accuracy", text: $request.skillDescription, axis: .vertical)
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.textField, style: .continuous).fill(DesignSystem.Colors.surfaceRaised))
            HStack {
                if !request.skillDescription.isEmpty && !request.skillDescription.isValidSkillDescription {
                    TQMeta("At least 10 characters", tone: .muted, size: 13, weight: .regular, uppercase: false)
                }
                Spacer()
                TQMeta("\(request.skillDescription.count)/500", tone: .muted, size: 13, weight: .regular)
            }
        }
    }

    // MARK: - Options (category, level, equipment, players, space)

    private func optionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TQGroupHeader(title)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var categorySection: some View {
        optionGroup("Category") {
            FlowLayout(spacing: 6) {
                ForEach(DrillCategory.allCases, id: \.self) { category in
                    TQChip(category.displayName, isSelected: request.category == category) {
                        request.category = category
                        touchedCategory = true
                    }
                }
            }
        }
    }

    private var difficultySection: some View {
        optionGroup("Level") {
            TQSegment(
                options: DifficultyLevel.allCases.map(\.displayName),
                selectedIndex: Binding(
                    get: { DifficultyLevel.allCases.firstIndex(of: request.difficulty) ?? 0 },
                    set: { request.difficulty = DifficultyLevel.allCases[$0] }
                )
            )
        }
    }

    private var equipmentSection: some View {
        optionGroup("Equipment you have") {
            FlowLayout(spacing: 6) {
                ForEach(Equipment.allCases, id: \.self) { equipment in
                    TQChip(equipment.displayName, isSelected: request.equipment.contains(equipment)) {
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

    private var numberOfPlayersSection: some View {
        TQValueStepper(label: "Players", value: $request.numberOfPlayers, range: 1...6)
            .overlay(alignment: .top) { TQRule() }
            .overlay(alignment: .bottom) { TQRule() }
    }

    private var fieldSizeSection: some View {
        optionGroup("Space") {
            TQSegment(
                options: FieldSize.allCases.map(\.shortName),
                selectedIndex: Binding(
                    get: { FieldSize.allCases.firstIndex(of: request.fieldSize) ?? 0 },
                    set: { request.fieldSize = FieldSize.allCases[$0] }
                )
            )
        }
    }

    // MARK: - Generate Button
    
    private var generateButton: some View {
        TQButton("Generate a drill") { generateDrill() }
            .disabled(!request.isValid)
    }
    
    // MARK: - Actions
    
    private func generateDrill() {
        if !touchedCategory {
            request.category = Self.inferredCategory(for: request.selectedWeaknesses)
        }
        phase = .generating
        generationTask?.cancel()
        generationTask = Task {
            defer { generationTask = nil }
            do {
                let exercise = try await drillService.generateCustomDrill(request: request, for: player)
                // "Cancel keeps nothing": a cancelled request never saves or spends quota.
                guard !Task.isCancelled else { return }
                SubscriptionManager.shared.markDrillGenerated()
                if let onCreated {
                    dismiss()
                    onCreated(exercise)
                    return
                }
                var warnings: [String] = []
                if case .success(let response) = drillService.generationState {
                    warnings = response.validationWarnings ?? []
                }
                phase = .created(exercise, warnings: warnings)
            } catch {
                guard !Task.isCancelled else { return }
                #if DEBUG
                print("Failed to generate drill: \(error)")
                #endif
                phase = .failed(failure(for: error))
            }
        }
    }
}

// MARK: - Safety Disclaimer

/// Footer shown on drill surfaces. Not medical advice; encourages warm-up.
struct DrillSafetyDisclaimer: View {
    var body: some View {
        Text("Warm up first. Stop if anything hurts. Not medical advice.")
            .font(DesignSystem.Typography.bodySmall)
            .foregroundColor(DesignSystem.Colors.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, DesignSystem.Spacing.sm)
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