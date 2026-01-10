import SwiftUI
import CoreData

struct EnhancedOnboardingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var coreDataManager: CoreDataManager
    @EnvironmentObject private var authManager: AuthenticationManager
    @Binding var isOnboardingComplete: Bool

    @State private var currentStep = 0
    @State private var playerName = ""
    @State private var playerAge = 16
    @State private var selectedPosition = "Midfielder"
    @State private var selectedPlayingStyle = "Balanced"
    @State private var selectedDominantFoot = "Right"
    @State private var selectedExperienceLevel = "Beginner"
    @State private var yearsPlaying: Int = 2
    @State private var selectedGoal = "Improve Skills"
    @State private var selectedFrequency = "3-4x per week"

    let positions = ["Goalkeeper", "Defender", "Midfielder", "Forward"]
    let playingStyles = ["Aggressive", "Defensive", "Balanced", "Creative", "Fast"]
    let dominantFeet = ["Left", "Right", "Both"]
    let experienceLevels = ["Beginner", "Intermediate", "Advanced", "Professional"]
    let trainingGoals = ["Improve Skills", "Build Fitness", "Prepare for Tryouts", "Stay Active", "Become Pro"]
    let trainingFrequencies = ["2-3x per week", "3-4x per week", "5-6x per week", "Daily"]

    private let totalSteps = 5

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

                // Step Content with Mascot
                stepContent

                Spacer()

                // Continue Button
                continueButton
            }
        }
    }

    // MARK: - Header

    private var onboardingHeader: some View {
        HStack {
            if currentStep > 0 {
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

            // Skip button (only on non-essential steps)
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
        case 4: return "Ready!"
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
                readyStep
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
        Button(action: {
            HapticManager.shared.mediumTap()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if currentStep < totalSteps - 1 {
                    currentStep += 1
                } else {
                    createPlayer()
                }
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text(buttonTitle)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)

                if currentStep == totalSteps - 1 {
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

    private var buttonTitle: String {
        switch currentStep {
        case 0: return "GET STARTED"
        case totalSteps - 1: return "START TRAINING"
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

    private var readyStep: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Mascot celebrating
            MascotView(
                state: .excited,
                size: .xlarge,
                showSpeechBubble: true,
                speechText: "Let's go!"
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                Text("You're All Set!")
                    .font(DesignSystem.Typography.headlineLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Complete your first session to earn +50 XP")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Summary card
            ModernCard(padding: DesignSystem.Spacing.lg) {
                VStack(spacing: DesignSystem.Spacing.md) {
                    SummaryRow(label: "Name", value: playerName.isEmpty ? "Player" : playerName)
                    SummaryRow(label: "Goal", value: selectedGoal)
                    SummaryRow(label: "Position", value: selectedPosition)
                    SummaryRow(label: "Level", value: selectedExperienceLevel)
                    SummaryRow(label: "Training", value: selectedFrequency)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            // First goal preview
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(DesignSystem.Colors.xpGold)

                VStack(alignment: .leading, spacing: 2) {
                    Text("First Session Bonus")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("+75 XP")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }

                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.xpGold.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)
            .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }
    
    // MARK: - Helper Functions
    
    private func createPlayer() {
        #if DEBUG
        print("🏗️ Starting player creation...")
        
        #endif
        let userUID = authManager.userUID
        if userUID.isEmpty {
            #if DEBUG
            print("❌ No Firebase UID available - cannot create player")
            #endif
            return
        }
        
        #if DEBUG
        
        print("📝 Creating player for UID: \(userUID)")
        
        #endif
        let displayName = playerName.isEmpty ? authManager.userDisplayName : playerName
        let finalName = displayName.isEmpty ? "Player" : displayName
        #if DEBUG
        print("👤 Player name: \(finalName)")
        
        #endif
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
        
        #if DEBUG
        
        print("✅ Player object created with ID: \(newPlayer.id?.uuidString ?? "nil")")
        
        
        #endif
        coreDataManager.createDefaultExercises(for: newPlayer)
        #if DEBUG
        print("✅ Created default exercises")
        
        #endif
        do {
            coreDataManager.save()
            #if DEBUG
            print("✅ Successfully saved player profile to Core Data")
            
            #endif
            // Verify the save worked
            let request = Player.fetchRequest()
            request.predicate = NSPredicate(format: "firebaseUID == %@", userUID)
            let savedPlayers = try viewContext.fetch(request)
            #if DEBUG
            print("🔍 Verification: Found \(savedPlayers.count) players for UID \(userUID)")
            
            #endif
            if let savedPlayer = savedPlayers.first {
                #if DEBUG
                print("✅ Saved player: \(savedPlayer.name ?? "Unknown") with ID: \(savedPlayer.id?.uuidString ?? "nil")")
                #endif
            }
        } catch {
            #if DEBUG
            print("❌ Failed to save player profile: \(error)")
            #endif
            return
        }
        
        // Sync to Firebase/Cloud
        Task {
            do {
                await CloudSyncManager.shared.performFullSync()
                await CloudSyncManager.shared.trackUserEvent(.sessionStart, contextData: [
                    "onboarding_completed": true,
                    "player_name": playerName
                ])
                #if DEBUG
                print("✅ Successfully synced to cloud")
                #endif
            } catch {
                #if DEBUG
                print("⚠️ Failed to sync new player profile: \(error)")
                #endif
            }
        }
        
        #if DEBUG
        
        print("🎯 Setting isOnboardingComplete = true")
        
        #endif
        isOnboardingComplete = true
        #if DEBUG
        print("✅ Onboarding marked as complete")
        #endif
    }
}

// MARK: - Helper Views

/// Feature row for welcome screen
struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.15))
                .cornerRadius(DesignSystem.CornerRadius.sm)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }
}

/// Option button for goal selection
struct OnboardingOptionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryGreen)
                    .frame(width: 36, height: 36)
                    .background(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.primaryGreen.opacity(0.15))
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                Text(title)
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(DesignSystem.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .stroke(isSelected ? DesignSystem.Colors.primaryGreen : Color.clear, lineWidth: 2)
            )
        }
    }
}

/// Chip for frequency/style selection
struct FrequencyChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.labelMedium)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isSelected ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
                .cornerRadius(DesignSystem.CornerRadius.pill)
        }
    }
}

/// Position button with icon
struct PositionButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.primaryGreen)

                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .background(isSelected ? DesignSystem.Colors.primaryGreen : Color(.systemGray6))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }
}

/// Summary row for ready screen
struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

#Preview {
    EnhancedOnboardingView(isOnboardingComplete: .constant(false))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(CoreDataManager.shared)
        .environmentObject(AuthenticationManager.shared)
}