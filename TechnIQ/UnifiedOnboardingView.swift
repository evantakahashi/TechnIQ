import SwiftUI
import CoreData

struct UnifiedOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool

    // Step state
    @State private var currentStep = 0
    private let totalSteps = 5

    // Step 2: Goal
    @State private var selectedGoal = "Improve Skills"
    @State private var selectedFrequency = "3-4x per week"

    // Step 3: About You
    @State private var playerName = ""
    @State private var playerAge = 16
    @State private var selectedExperienceLevel = "Beginner"
    @State private var yearsPlaying: Int = 2

    // Step 4: Soccer Profile
    @State private var selectedPosition = "Midfielder"
    @State private var selectedPlayingStyle = "Balanced"
    @State private var selectedDominantFoot = "Right"

    // Step 5: Plan Generation
    @State private var isGeneratingPlan = false
    @State private var planGenerationFailed = false
    @State private var planErrorMessage = ""
    @State private var loadingPhase: LoadingPhase = .connecting
    @State private var generationTask: Task<Void, Never>?
    @State private var planGenerationComplete = false

    // Constants
    let trainingGoals = ["Improve Skills", "Build Fitness", "Prepare for Tryouts", "Stay Active", "Become Pro"]
    let trainingFrequencies = ["2-3x per week", "3-4x per week", "5-6x per week", "Daily"]
    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    let experienceLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]

    /// Get mascot state for current step
    private var mascotState: MascotState {
        MascotState.forOnboarding(screenIndex: currentStep)
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.05),
                    DesignSystem.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                onboardingHeader

                // Progress Indicator
                progressIndicator
                    .padding(.top, DesignSystem.Spacing.lg)

                Spacer()

                // Step Content
                stepContent

                Spacer()

                // Continue Button
                continueButton
            }
        }
        .onAppear {
            if let prefillName = UserDefaults.standard.string(forKey: "onboarding_prefill_name"), !prefillName.isEmpty {
                playerName = prefillName
                UserDefaults.standard.removeObject(forKey: "onboarding_prefill_name")
            }
        }
    }

    // MARK: - Header

    private var onboardingHeader: some View {
        HStack {
            if currentStep > 0 && currentStep < totalSteps - 1 {
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep -= 1
                    }
                    HapticManager.shared.lightTap()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(width: 44, height: 44)
                }
            } else {
                Spacer()
                    .frame(width: 44)
            }

            Spacer()

            // Step title
            Text(stepTitle)
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            // Skip button (only on welcome and goal steps)
            if currentStep < 2 {
                Button("Skip") {
                    withAnimation {
                        currentStep = 2 // Skip to profile creation
                    }
                }
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 44, height: 44)
            } else {
                Spacer()
                    .frame(width: 44)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, DesignSystem.Spacing.md)
    }

    private var stepTitle: String {
        switch currentStep {
        case 0: return "Welcome"
        case 1: return "Your Goal"
        case 2: return "About You"
        case 3: return "Your Style"
        case 4: return "Your Plan"
        default: return ""
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentStep ? DesignSystem.Colors.primaryGreen : Color(.systemGray4))
                        .frame(height: 4)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            Text("Step \(currentStep + 1) of \(totalSteps)")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Step Content

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch currentStep {
            case 0:
                welcomeStep
            case 1:
                goalStep
            case 2:
                basicInfoStep
            case 3:
                positionStyleStep
            case 4:
                planGenerationStep
            default:
                EmptyView()
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Group {
            if currentStep < totalSteps - 1 {
                Button(action: {
                    HapticManager.shared.mediumTap()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if currentStep == 3 {
                            // End of soccer profile — create player, then advance to plan gen
                            createPlayer()
                            currentStep += 1
                            generateInitialPlan()
                        } else {
                            currentStep += 1
                        }
                    }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text(buttonTitle)
                            .font(DesignSystem.Typography.labelLarge)
                            .fontWeight(.semibold)
                        if currentStep == 3 {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(canContinue ? DesignSystem.Colors.primaryGreen : Color.gray)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .disabled(!canContinue)
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, 34)
            }
            // Step 5: no continue button — auto-navigates or shows retry/skip inline
        }
    }

    private var buttonTitle: String {
        switch currentStep {
        case 0: return "GET STARTED"
        case 3: return "START TRAINING"
        default: return "CONTINUE"
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case 2:
            return !playerName.isEmpty
        default:
            return true
        }
    }

    // MARK: - Step Views

    private var welcomeStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Mascot with speech bubble
            MascotView(
                state: .waving,
                size: .xlarge,
                showSpeechBubble: true,
                speechText: "Welcome!"
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Welcome to TechnIQ")
                    .font(DesignSystem.Typography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Your AI-powered soccer training companion")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Feature highlights
            VStack(spacing: DesignSystem.Spacing.md) {
                OnboardingFeatureRow(
                    icon: "star.fill",
                    iconColor: DesignSystem.Colors.xpGold,
                    title: "Earn XP & Level Up",
                    description: "Track progress like a game"
                )

                OnboardingFeatureRow(
                    icon: "brain.head.profile",
                    iconColor: DesignSystem.Colors.secondaryBlue,
                    title: "Smart Recommendations",
                    description: "AI-powered training plans"
                )

                OnboardingFeatureRow(
                    icon: "flame.fill",
                    iconColor: DesignSystem.Colors.streakOrange,
                    title: "Build Streaks",
                    description: "Stay consistent, unlock rewards"
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    private var goalStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Mascot
            MascotView(
                state: .coaching,
                size: .large,
                showSpeechBubble: true,
                speechText: "What's your goal?"
            )

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("What's Your Training Goal?")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("This helps us personalize your experience")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            // Goal selection
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(trainingGoals, id: \.self) { goal in
                    OnboardingOptionButton(
                        title: goal,
                        icon: goalIcon(for: goal),
                        isSelected: selectedGoal == goal
                    ) {
                        selectedGoal = goal
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // Frequency selection
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("How often can you train?")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(trainingFrequencies, id: \.self) { freq in
                            FrequencyChip(
                                title: freq,
                                isSelected: selectedFrequency == freq
                            ) {
                                selectedFrequency = freq
                                HapticManager.shared.selectionChanged()
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    private func goalIcon(for goal: String) -> String {
        switch goal {
        case "Improve Skills": return "target"
        case "Build Fitness": return "heart.fill"
        case "Prepare for Tryouts": return "trophy.fill"
        case "Stay Active": return "figure.walk"
        case "Become Pro": return "star.fill"
        default: return "target"
        }
    }

    private var basicInfoStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Mascot
                MascotView(
                    state: .encouraging,
                    size: .medium,
                    showSpeechBubble: true,
                    speechText: "Tell me about you!"
                )

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Create Your Profile")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Let's personalize your training")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Player Name
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Your Name")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        TextField("Enter your name", text: $playerName)
                            .font(DesignSystem.Typography.bodyLarge)
                            .padding(DesignSystem.Spacing.md)
                            .background(Color(.systemGray6))
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }

                    // Age Slider
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Age")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("\(playerAge) years")
                                .font(DesignSystem.Typography.labelLarge)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }

                        Slider(value: Binding(
                            get: { Double(playerAge) },
                            set: { playerAge = Int($0) }
                        ), in: 10...75, step: 1)
                        .tint(DesignSystem.Colors.primaryGreen)
                    }

                    // Experience Level
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Experience Level")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                            ForEach(experienceLevels, id: \.self) { level in
                                Button {
                                    selectedExperienceLevel = level
                                    HapticManager.shared.selectionChanged()
                                } label: {
                                    Text(level)
                                        .font(DesignSystem.Typography.labelMedium)
                                        .foregroundColor(selectedExperienceLevel == level ? .white : DesignSystem.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignSystem.Spacing.md)
                                        .background(selectedExperienceLevel == level ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                                        .cornerRadius(DesignSystem.CornerRadius.sm)
                                }
                            }
                        }
                    }

                    // Years Playing
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Years Playing")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Spacer()
                            Text("\(yearsPlaying) years")
                                .font(DesignSystem.Typography.labelLarge)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }

                        Slider(value: Binding(
                            get: { Double(yearsPlaying) },
                            set: { yearsPlaying = Int($0) }
                        ), in: 0...20, step: 1)
                        .tint(DesignSystem.Colors.primaryGreen)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private var positionStyleStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Mascot
                MascotView(
                    state: .coaching,
                    size: .medium,
                    showSpeechBubble: true,
                    speechText: "How do you play?"
                )

                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Your Playing Style")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("This helps tailor drills to your position")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Position Selection
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Primary Position")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.sm) {
                            ForEach(positions, id: \.self) { position in
                                PositionButton(
                                    title: position,
                                    icon: positionIcon(for: position),
                                    isSelected: selectedPosition == position
                                ) {
                                    selectedPosition = position
                                    HapticManager.shared.selectionChanged()
                                }
                            }
                        }
                    }

                    // Playing Style
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Playing Style")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(playingStyles, id: \.self) { style in
                                    FrequencyChip(
                                        title: style,
                                        isSelected: selectedPlayingStyle == style
                                    ) {
                                        selectedPlayingStyle = style
                                        HapticManager.shared.selectionChanged()
                                    }
                                }
                            }
                        }
                    }

                    // Dominant Foot
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Dominant Foot")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(dominantFeet, id: \.self) { foot in
                                Button {
                                    selectedDominantFoot = foot
                                    HapticManager.shared.selectionChanged()
                                } label: {
                                    Text(foot)
                                        .font(DesignSystem.Typography.labelLarge)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedDominantFoot == foot ? .white : DesignSystem.Colors.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, DesignSystem.Spacing.md)
                                        .background(selectedDominantFoot == foot ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                                        .cornerRadius(DesignSystem.CornerRadius.md)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
    }

    private func positionIcon(for position: String) -> String {
        switch position {
        case "Goalkeeper": return "hand.raised.fill"
        case "Defender": return "shield.fill"
        case "Midfielder": return "arrow.left.arrow.right"
        case "Forward": return "target"
        default: return "figure.soccer"
        }
    }

    // MARK: - Plan Generation Step

    private var planGenerationStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            if planGenerationComplete {
                // Celebration state
                MascotView(state: .excited, size: .xlarge, showSpeechBubble: true, speechText: "Let's go!")

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("You're All Set!")
                        .font(DesignSystem.Typography.headlineLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Your personalized training plan is ready")
                        .font(DesignSystem.Typography.bodyLarge)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else if planGenerationFailed {
                // Error state
                MascotView(state: .thinking, size: .large, showSpeechBubble: true, speechText: "Hmm...")

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Couldn't Generate Plan")
                        .font(DesignSystem.Typography.headlineMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(planErrorMessage)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    ModernButton("Try Again", icon: "arrow.clockwise", style: .primary) {
                        generateInitialPlan()
                    }

                    Button("Skip for Now") {
                        isOnboardingComplete = true
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            } else {
                // Loading state
                MascotView(state: .coaching, size: .large, showSpeechBubble: true, speechText: loadingPhase.title)

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("Building Your Plan")
                        .font(DesignSystem.Typography.headlineMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(loadingPhase.description)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                ProgressView(value: loadingPhase.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .frame(width: 200)
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    // MARK: - Helper Functions

    private func createPlayer() {
        #if DEBUG
        print("Starting player creation...")
        #endif
        let userUID = authManager.userUID
        if userUID.isEmpty {
            #if DEBUG
            print("No Firebase UID available - cannot create player")
            #endif
            return
        }

        #if DEBUG
        print("Creating player for UID: \(userUID)")
        #endif
        let displayName = playerName.isEmpty ? authManager.userDisplayName : playerName
        let finalName = displayName.isEmpty ? "Player" : displayName

        let newPlayer = Player(context: viewContext)
        newPlayer.id = UUID()
        newPlayer.firebaseUID = userUID
        newPlayer.name = finalName
        newPlayer.age = Int16(playerAge)
        newPlayer.position = selectedPosition
        newPlayer.playingStyle = selectedPlayingStyle
        newPlayer.dominantFoot = selectedDominantFoot
        newPlayer.experienceLevel = selectedExperienceLevel
        newPlayer.createdAt = Date()

        coreDataManager.createDefaultExercises(for: newPlayer)

        do {
            coreDataManager.save()
            #if DEBUG
            print("Successfully saved player profile to Core Data")
            #endif
        } catch {
            #if DEBUG
            print("Failed to save player profile: \(error)")
            #endif
            return
        }

        // Sync to Firebase/Cloud
        Task {
            await CloudSyncManager.shared.performFullSync()
            await CloudSyncManager.shared.trackUserEvent(.sessionStart, contextData: [
                "onboarding_completed": true,
                "player_name": playerName
            ])
        }
    }

    private func generateInitialPlan() {
        isGeneratingPlan = true
        planGenerationFailed = false
        loadingPhase = .connecting

        // Animate through loading phases
        let phaseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { timer in
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
                // Fetch the player we just created
                let request = Player.fetchRequest()
                request.predicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
                guard let player = try viewContext.fetch(request).first else {
                    throw NSError(domain: "Onboarding", code: 1, userInfo: [NSLocalizedDescriptionKey: "Player not found"])
                }

                let difficulty = mapExperienceToDifficulty(selectedExperienceLevel)
                let category = mapGoalToCategory(selectedGoal)
                let preferredDays = mapFrequencyToDays(selectedFrequency)
                let restDays = DayOfWeek.allCases.map(\.rawValue).filter { !preferredDays.contains($0) }

                let structure = try await CloudMLService.shared.generateTrainingPlan(
                    for: player,
                    duration: 4,
                    difficulty: difficulty,
                    category: category,
                    targetRole: selectedPosition,
                    focusAreas: [],
                    preferredDays: preferredDays,
                    restDays: restDays
                )

                // Save plan to Core Data
                let _ = TrainingPlanService.shared.createPlanFromAIGeneration(structure, for: player)

                await MainActor.run {
                    phaseTimer.invalidate()
                    isGeneratingPlan = false
                    planGenerationComplete = true

                    // Auto-navigate after brief celebration
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isOnboardingComplete = true
                    }
                }
            } catch {
                await MainActor.run {
                    phaseTimer.invalidate()
                    isGeneratingPlan = false
                    planGenerationFailed = true
                    planErrorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Mapping Helpers

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
