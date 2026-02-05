import SwiftUI
import CoreData

struct ActiveTrainingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    @StateObject private var manager: ActiveSessionManager

    // Session complete state
    @State private var xpBreakdown: XPService.SessionXPBreakdown?
    @State private var newLevel: Int?
    @State private var unlockedAchievements: [Achievement] = []

    // Pause overlay
    @State private var showingPauseMenu = false
    @State private var showingEndConfirm = false

    // Rating state (for exerciseComplete phase)
    @State private var currentRating: Int = 3
    @State private var currentNotes: String = ""

    init(exercises: [Exercise]) {
        _manager = StateObject(wrappedValue: ActiveSessionManager(exercises: exercises))
    }

    private var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        let request: NSFetchRequest<Player> = Player.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        return try? viewContext.fetch(request).first
    }

    var body: some View {
        ZStack {
            // Background
            AdaptiveBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar (hidden during preparing and sessionComplete)
                if manager.phase != .preparing && manager.phase != .sessionComplete {
                    topBar
                }

                // Phase content
                phaseContent
            }

            // Pause overlay
            if showingPauseMenu {
                pauseOverlay
            }
        }
        .interactiveDismissDisabled()
        .statusBarHidden(manager.phase == .preparing)
        .onAppear {
            manager.start()
        }
        .alert("End Session Early?", isPresented: $showingEndConfirm) {
            Button("End Session", role: .destructive) {
                manager.endSessionEarly()
                showingPauseMenu = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress so far will be saved with pro-rated XP.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Total time
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(manager.formattedTime(manager.totalElapsedTime))
                    .font(DesignSystem.Typography.numberSmall)
            }
            .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            // Exercise counter
            Text("\(manager.currentExerciseIndex + 1) of \(manager.exercises.count)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            // Pause button
            Button {
                manager.pause()
                showingPauseMenu = true
            } label: {
                Image(systemName: "pause.circle.fill")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.vertical, DesignSystem.Spacing.sm)
    }

    // MARK: - Phase Content

    @ViewBuilder
    private var phaseContent: some View {
        switch manager.phase {
        case .preparing:
            preparingView

        case .exerciseActive:
            ExerciseStepView(manager: manager)

        case .exerciseComplete:
            exerciseCompleteView

        case .rest:
            RestCountdownView(manager: manager)

        case .sessionComplete:
            sessionCompleteContent
        }
    }

    // MARK: - Preparing (3-2-1)

    private var preparingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            Text("Get Ready")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("\(manager.preparingCountdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: manager.preparingCountdown)

            if let exercise = manager.currentExercise {
                Text(exercise.name ?? "")
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            Spacer()
        }
    }

    // MARK: - Exercise Complete (Rating)

    private var exerciseCompleteView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Spacer()

            // Completion check
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Text("Exercise Complete!")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            // Duration display
            Text(manager.formattedTime(manager.exerciseDurations[manager.currentExerciseIndex]))
                .font(DesignSystem.Typography.numberMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            // Star rating
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("How did it go?")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= currentRating ? "star.fill" : "star")
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                            .font(.title)
                            .onTapGesture {
                                currentRating = star
                                HapticManager.shared.selectionChanged()
                            }
                    }
                }
            }

            // Quick note
            TextField("Quick note (optional)", text: $currentNotes)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            Spacer()

            // Next button
            Button {
                manager.rateExercise(currentRating, notes: currentNotes)
                currentRating = 3
                currentNotes = ""
                manager.nextExercise()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(manager.isLastExercise ? "Finish" : "Next")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                    Image(systemName: manager.isLastExercise ? "flag.checkered" : "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(DesignSystem.Colors.primaryGreen)
                .cornerRadius(DesignSystem.CornerRadius.button)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.md)
        }
    }

    // MARK: - Session Complete

    @ViewBuilder
    private var sessionCompleteContent: some View {
        if let player = currentPlayer {
            if xpBreakdown != nil {
                SessionCompleteView(
                    xpBreakdown: xpBreakdown,
                    newLevel: newLevel,
                    achievements: unlockedAchievements,
                    player: player,
                    onDismiss: { dismiss() }
                )
            } else {
                // Process results and show
                Color.clear
                    .onAppear {
                        let result = manager.finishSession(player: player, context: viewContext)
                        xpBreakdown = result.xpBreakdown
                        newLevel = result.newLevel
                        unlockedAchievements = result.achievements
                    }
            }
        } else {
            // Fallback if no player found
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)

                Text("Session Complete!")
                    .font(DesignSystem.Typography.headlineMedium)

                ModernButton("Done", style: .primary) {
                    dismiss()
                }
            }
            .padding()
        }
    }

    // MARK: - Pause Overlay

    private var pauseOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {} // prevent pass-through

            VStack(spacing: DesignSystem.Spacing.lg) {
                Text("Paused")
                    .font(DesignSystem.Typography.headlineMedium)
                    .foregroundColor(.white)

                // Total time while paused
                Text(manager.formattedTime(manager.totalElapsedTime))
                    .font(DesignSystem.Typography.numberLarge)
                    .foregroundColor(.white.opacity(0.7))

                VStack(spacing: DesignSystem.Spacing.md) {
                    // Resume
                    Button {
                        manager.resume()
                        showingPauseMenu = false
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Resume")
                                .fontWeight(.bold)
                        }
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(DesignSystem.CornerRadius.button)
                    }

                    // End session early
                    Button {
                        showingEndConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "stop.circle")
                            Text("End Session")
                        }
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.button)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.xl)
            }
        }
    }
}
