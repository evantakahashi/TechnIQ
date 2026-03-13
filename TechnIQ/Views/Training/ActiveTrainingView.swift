import SwiftUI
import CoreData

struct ActiveTrainingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthenticationManager

    @StateObject private var manager: ActiveSessionManager

    // Session complete state
    @State private var xpBreakdown: SessionXPBreakdown?
    @State private var newLevel: Int?
    @State private var unlockedAchievements: [Achievement] = []

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
                // Top bar (hidden during sessionComplete)
                if manager.phase != .sessionComplete {
                    topBar
                }

                // Phase content
                phaseContent
            }
        }
        .interactiveDismissDisabled()
        .onAppear {
            manager.start()
        }
        .alert("End Session Early?", isPresented: $showingEndConfirm) {
            Button("End Session", role: .destructive) {
                manager.endSessionEarly()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your progress so far will be saved with pro-rated XP.")
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text("\(manager.currentExerciseIndex + 1) of \(manager.exercises.count)")
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Button {
                showingEndConfirm = true
            } label: {
                Image(systemName: "xmark.circle.fill")
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
        case .exercise:
            if let exercise = manager.currentExercise, exercise.diagramJSON != nil {
                DrillWalkthroughView(exercise: exercise) { rating, difficulty, notes in
                    manager.completeExercise()
                    manager.rateExercise(rating, notes: notes)
                    manager.nextExercise()
                }
            } else {
                ExerciseStepView(manager: manager)
            }

        case .rating:
            exerciseCompleteView

        case .sessionComplete:
            sessionCompleteContent
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
                    onDismiss: { dismiss() },
                    exercises: manager.exercises
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

}
