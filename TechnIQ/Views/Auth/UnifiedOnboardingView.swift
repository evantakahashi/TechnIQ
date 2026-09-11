import SwiftUI
import CoreData

// MARK: - Onboarding (Touchline 7b)
//
// One decision per screen: goal → frequency → position (+ foot + kit number) → weak spots →
// name / age / level. Chalk-line stepper 01/05, options as selectable rows (number, title,
// one-line consequence, radio), a "Next: …" button that names the next step and a "Next up · …"
// footer. Then plan generation and the Pro paywall. No welcome / feature tour — sign-in already
// made the pitch.

struct UnifiedOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool

    // MARK: Steps

    enum Step: Int, CaseIterable {
        case goal, frequency, position, weakSpots, about, generating, paywall

        var isDecision: Bool { rawValue <= Step.about.rawValue }

        /// Short name used in "Next: …" and "Next up · …".
        var shortName: String {
            switch self {
            case .goal: return "goal"
            case .frequency: return "how often"
            case .position: return "position"
            case .weakSpots: return "weak spots"
            case .about: return "about you"
            case .generating: return "your plan"
            case .paywall: return "go pro"
            }
        }
    }

    @State private var step: Step = .goal
    private let decisionSteps = Step.allCases.filter(\.isDecision)

    // Answers
    @State private var selectedGoal = "Improve Skills"
    @State private var selectedFrequency = "3-4x per week"
    @State private var selectedPosition = "Midfielder"
    @State private var selectedDominantFoot = 1          // Left / Right / Both
    @State private var kitNumberText = ""
    @State private var selectedWeaknesses: Set<WeaknessCategory> = []
    @State private var playerName = ""
    @State private var ageText = ""
    @State private var selectedExperienceLevel = "Beginner"

    // Plan generation
    @State private var planGenerationFailed = false
    @State private var planErrorMessage = ""
    @State private var loadingPhase: LoadingPhase = .connecting
    @State private var generationTask: Task<Void, Never>?
    @State private var phaseTimer: Timer?
    @State private var planGenerationComplete = false

    // Option catalogues
    private let goals: [(String, String)] = [
        ("Improve Skills", "Technique-heavy: touch, passing, finishing"),
        ("Build Fitness", "More conditioning and speed work"),
        ("Prepare for Tryouts", "Position-specific, match-paced sessions"),
        ("Stay Active", "Short, varied sessions you can keep up"),
        ("Become Pro", "Full load, weekly adaptation, no rest weeks")
    ]
    private let frequencies: [(String, String)] = [
        ("2-3x per week", "Three sessions, plenty of recovery"),
        ("3-4x per week", "The sweet spot for steady progress"),
        ("5-6x per week", "Club schedule: one rest day"),
        ("Daily", "Every day, shorter sessions")
    ]
    private let positions: [(String, String)] = [
        ("Goalkeeper", "Handling, footwork and distribution"),
        ("Defender", "1v1 defending, heading, clearances"),
        ("Midfielder", "Passing range, turns, pressing"),
        ("Forward", "Finishing, movement, first touch")
    ]
    private let feet = ["Left", "Right", "Both"]
    private let experienceLevels: [(String, String)] = [
        ("Beginner", "Just starting out"),
        ("Intermediate", "Play regularly"),
        ("Advanced", "Club or travel team"),
        ("Professional", "Academy level")
    ]

    // MARK: Body

    var body: some View {
        VStack(spacing: 0) {
            if step.isDecision {
                decisionScreen
            } else if step == .generating {
                planGenerationStep
            } else {
                OnboardingPaywallView(
                    planName: selectedGoal,
                    onContinueFree: { isOnboardingComplete = true },
                    onPurchaseComplete: { isOnboardingComplete = true }
                )
            }
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .onAppear {
            if let prefillName = UserDefaults.standard.string(forKey: "onboarding_prefill_name"), !prefillName.isEmpty {
                playerName = prefillName
                UserDefaults.standard.removeObject(forKey: "onboarding_prefill_name")
            }
            if playerName.isEmpty, authManager.currentUser?.isAnonymous == true {
                playerName = "Player"
            }
        }
        .onDisappear {
            generationTask?.cancel()
            phaseTimer?.invalidate()
        }
    }

    // MARK: - Decision screens

    private var stepIndex: Int { decisionSteps.firstIndex(of: step).map { $0 + 1 } ?? 1 }

    private var nextStep: Step? {
        Step(rawValue: step.rawValue + 1)
    }

    private var decisionScreen: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if step != .goal {
                    TQBackButton { goBack() }
                }
                TQStepper(current: stepIndex, total: decisionSteps.count)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 10)
            .padding(.bottom, 24)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    stepCopy
                    stepBody
                        .padding(.top, 22)
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))

            footer
        }
        // The footer stays put under the keyboard (the fields sit at the top of the scroll view);
        // the keyboard bar's Done dismisses it.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { TQKeyboard.dismiss() }
                    .font(Font.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.grass)
            }
        }
    }

    @ViewBuilder
    private var stepCopy: some View {
        switch step {
        case .goal:
            copy(eyebrow: "Your goal", title: "What are you\ntraining for?", body: "This sets the balance of your plan. You can change it later.")
        case .frequency:
            copy(eyebrow: "How often", title: "How often can\nyou train?", body: "Your plan schedules sessions on this many days each week.")
        case .position:
            copy(eyebrow: "Your position", title: "Where do\nyou play?", body: "Drills are picked for your position and stronger foot.")
        case .weakSpots:
            copy(eyebrow: "Weak spots", title: "What needs\nthe most work?", body: "Pick up to three. Your plan leans into these first.")
        case .about:
            copy(eyebrow: "About you", title: "Last thing —\nabout you", body: "Your name is shown to other players. Age and level size the load.")
        default:
            EmptyView()
        }
    }

    private func copy(eyebrow: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TQEyebrow(eyebrow, size: 13)
            TQDisplayTitle(title, size: .mediumLarge)
            TQBody(body, tone: .base, size: 16)
        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch step {
        case .goal:
            optionList(goals, selected: selectedGoal) { selectedGoal = $0 }
        case .frequency:
            optionList(frequencies, selected: selectedFrequency) { selectedFrequency = $0 }
        case .position:
            VStack(alignment: .leading, spacing: 0) {
                optionList(positions, selected: selectedPosition) { selectedPosition = $0 }
                TQGroupHeader("Stronger foot")
                    .padding(.top, 22)
                TQSegment(options: feet, selectedIndex: $selectedDominantFoot)
                TQGroupHeader("Kit number · optional")
                    .padding(.top, 22)
                TQFormField("Shirt number", text: $kitNumberText, placeholder: "e.g. 9", keyboard: .numberPad)
                    .onChange(of: kitNumberText) { _, value in
                        kitNumberText = String(value.filter(\.isNumber).prefix(2))
                    }
            }
        case .weakSpots:
            VStack(spacing: 10) {
                ForEach(Array(WeaknessCategory.allCases.enumerated()), id: \.element.id) { index, category in
                    TQOptionRow(
                        number: String(format: "%02d", index + 1),
                        title: category.displayName,
                        subtitle: nil,
                        isSelected: selectedWeaknesses.contains(category)
                    ) { toggleWeakness(category) }
                }
            }
        case .about:
            VStack(alignment: .leading, spacing: 12) {
                TQFormField("Name", text: $playerName, placeholder: "First name or nickname", contentType: .name)
                TQFormField("Age", text: $ageText, placeholder: "e.g. 14", keyboard: .numberPad)
                    .onChange(of: ageText) { _, value in
                        ageText = String(value.filter(\.isNumber).prefix(2))
                    }
                TQGroupHeader("Level")
                    .padding(.top, 10)
                optionList(experienceLevels, selected: selectedExperienceLevel) { selectedExperienceLevel = $0 }
            }
        default:
            EmptyView()
        }
    }

    private func optionList(_ options: [(String, String)], selected: String, select: @escaping (String) -> Void) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.element.0) { index, option in
                TQOptionRow(
                    number: String(format: "%02d", index + 1),
                    title: option.0,
                    subtitle: option.1,
                    isSelected: selected == option.0
                ) { select(option.0) }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 10) {
            TQButton(nextButtonTitle) { advance() }
                .disabled(!canContinue)
                .accessibilityIdentifier("onboarding.next")
            if let upcoming = upcomingSteps {
                Text("Next up · \(upcoming)")
                    .font(Font.system(size: 13, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.dimIvory)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(DesignSystem.Colors.surfaceBase)
    }

    private var nextButtonTitle: String {
        switch step {
        case .about: return "Build my plan"
        default: return "Next: \(nextStep?.shortName ?? "")"
        }
    }

    /// The remaining decision steps, e.g. "how often · position · weak spots · about you".
    private var upcomingSteps: String? {
        let remaining = decisionSteps.filter { $0.rawValue > step.rawValue }
        guard !remaining.isEmpty else { return nil }
        return remaining.map(\.shortName).joined(separator: " · ")
    }

    private var canContinue: Bool {
        switch step {
        case .about:
            return !playerName.trimmingCharacters(in: .whitespaces).isEmpty && (playerAge ?? 0) >= 5
        default:
            return true
        }
    }

    private var playerAge: Int? {
        guard let age = Int(ageText), (5...80).contains(age) else { return nil }
        return age
    }

    private var kitNumber: Int? {
        guard let number = Int(kitNumberText), (1...99).contains(number) else { return nil }
        return number
    }

    private func advance() {
        guard let next = nextStep else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            if step == .about {
                createPlayer()
                step = .generating
                generateInitialPlan()
            } else {
                step = next
            }
        }
    }

    private func goBack() {
        guard let previous = Step(rawValue: step.rawValue - 1), previous.isDecision else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = previous }
    }

    // MARK: - Plan generation

    private var planGenerationStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()
            if planGenerationComplete {
                TQEyebrow("Plan ready", size: 13)
                    .padding(.bottom, 12)
                TQDisplayTitle("You're\nall set", size: .mediumLarge)
                    .padding(.bottom, 12)
                TQBody("Day 1 is waiting on your home screen.", tone: .base, size: 16)
            } else if planGenerationFailed {
                TQEyebrow("Plan", size: 13)
                    .padding(.bottom, 12)
                TQDisplayTitle("Couldn't build\nyour plan", size: .mediumLarge)
                    .padding(.bottom, 12)
                TQBanner(.error, message: planErrorMessage.isEmpty ? "Something went wrong." : planErrorMessage, layout: .block)
                    .padding(.bottom, 20)
                TQButton("Try again", icon: "arrow.clockwise") { generateInitialPlan() }
                TQButton("Skip for now", style: .ghost, face: .text) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = .paywall }
                }
                .padding(.top, 8)
            } else {
                TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 3, size: 36)
                    .padding(.bottom, 24)
                TQEyebrow("Building your plan", size: 13)
                    .padding(.bottom, 12)
                TQDisplayTitle(loadingPhase.description.replacingOccurrences(of: "...", with: ""), size: .medium)
                    .padding(.bottom, 20)
                TQProgressBar(progress: loadingPhase.progress, height: 4)
                    .animation(DesignSystem.Animation.smooth, value: loadingPhase.progress)
            }
            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func toggleWeakness(_ category: WeaknessCategory) {
        if selectedWeaknesses.contains(category) {
            selectedWeaknesses.remove(category)
        } else if selectedWeaknesses.count < 3 {
            selectedWeaknesses.insert(category)
        }
    }

    private func createPlayer() {
        let userUID = authManager.userUID
        guard !userUID.isEmpty else {
            AppLogger.shared.error("Onboarding: no Firebase UID — cannot create player")
            return
        }

        let displayName = playerName.trimmingCharacters(in: .whitespaces)
        let finalName = displayName.isEmpty ? (authManager.userDisplayName.isEmpty ? "Player" : authManager.userDisplayName) : displayName

        let newPlayer = Player(context: viewContext)
        newPlayer.id = UUID()
        newPlayer.firebaseUID = userUID
        newPlayer.name = finalName
        newPlayer.age = Int16(playerAge ?? 0)
        newPlayer.position = selectedPosition
        newPlayer.playingStyle = "Balanced"
        newPlayer.dominantFoot = feet[min(max(selectedDominantFoot, 0), feet.count - 1)]
        newPlayer.experienceLevel = selectedExperienceLevel
        newPlayer.kitNumber = Int16(kitNumber ?? 0)
        newPlayer.createdAt = Date()

        if !selectedWeaknesses.isEmpty {
            let profile = PlayerProfile(context: viewContext)
            profile.id = UUID()
            profile.selfIdentifiedWeaknesses = selectedWeaknesses.map { $0.displayName }
            profile.createdAt = Date()
            profile.updatedAt = Date()
            profile.player = newPlayer
            newPlayer.playerProfile = profile
        }

        coreDataManager.createDefaultExercises(for: newPlayer)
        coreDataManager.save()

        Task {
            await CloudService.shared.performFullSync()
            await CloudService.shared.trackUserEvent(.sessionStart, contextData: [
                "onboarding_completed": true,
                "player_name": finalName
            ])
        }
    }

    private func generateInitialPlan() {
        planGenerationFailed = false
        planGenerationComplete = false
        loadingPhase = .connecting

        phaseTimer?.invalidate()
        phaseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
            DispatchQueue.main.async {
                switch loadingPhase {
                case .connecting: loadingPhase = .analyzing
                case .analyzing: loadingPhase = .generating
                case .generating: loadingPhase = .structuring
                case .structuring: loadingPhase = .finalizing
                case .finalizing: timer.invalidate()
                }
            }
        }

        generationTask = Task {
            do {
                let request = Player.fetchRequest()
                request.predicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
                guard let player = try viewContext.fetch(request).first else {
                    throw NSError(domain: "Onboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
                }

                let difficulty = mapExperienceToDifficulty(selectedExperienceLevel)
                let category = mapGoalToCategory(selectedGoal)
                let preferredDays = mapFrequencyToDays(selectedFrequency)
                let restDays = DayOfWeek.allCases.map(\.rawValue).filter { !preferredDays.contains($0) }

                let structure = try await AIRecommendationService.shared.generateTrainingPlan(
                    for: player,
                    duration: 4,
                    difficulty: difficulty,
                    category: category,
                    targetRole: selectedPosition,
                    focusAreas: selectedWeaknesses.map { $0.displayName },
                    preferredDays: preferredDays,
                    restDays: restDays
                )

                guard !Task.isCancelled else {
                    await MainActor.run { phaseTimer?.invalidate() }
                    return
                }

                if let plan = TrainingPlanService.shared.createPlanFromAIGeneration(structure, for: player) {
                    TrainingPlanService.shared.activatePlan(plan.toModel(), for: player)
                }

                await MainActor.run {
                    phaseTimer?.invalidate()
                    planGenerationComplete = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = .paywall }
                    }
                }
            } catch {
                await MainActor.run {
                    phaseTimer?.invalidate()
                    planGenerationFailed = true
                    planErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Mapping

    private func mapExperienceToDifficulty(_ experience: String) -> String {
        switch experience {
        case "Beginner": return PlanDifficulty.beginner.rawValue
        case "Intermediate": return PlanDifficulty.intermediate.rawValue
        case "Advanced": return PlanDifficulty.advanced.rawValue
        case "Professional": return PlanDifficulty.elite.rawValue
        default: return PlanDifficulty.intermediate.rawValue
        }
    }

    private func mapGoalToCategory(_ goal: String) -> String {
        switch goal {
        case "Improve Skills": return PlanCategory.technical.rawValue
        case "Build Fitness": return PlanCategory.physical.rawValue
        case "Prepare for Tryouts": return PlanCategory.general.rawValue
        case "Stay Active": return PlanCategory.general.rawValue
        case "Become Pro": return PlanCategory.technical.rawValue
        default: return PlanCategory.general.rawValue
        }
    }

    private func mapFrequencyToDays(_ frequency: String) -> [String] {
        switch frequency {
        case "2-3x per week": return ["Monday", "Wednesday", "Friday"]
        case "3-4x per week": return ["Monday", "Tuesday", "Thursday", "Friday"]
        case "5-6x per week": return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        case "Daily": return DayOfWeek.allCases.map(\.rawValue)
        default: return ["Monday", "Wednesday", "Friday"]
        }
    }
}

#Preview {
    UnifiedOnboardingView(isOnboardingComplete: .constant(false))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(CoreDataManager.shared)
        .environmentObject(AuthenticationManager.shared)
}
