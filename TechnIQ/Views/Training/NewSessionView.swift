import SwiftUI
import CoreData

struct NewSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager

    let player: Player
    var planSession: PlanSession? = nil // Optional: if provided, this session is from a training plan
    
    @State private var sessionType = "Training"
    @State private var location = ""
    @State private var intensity = 3
    @State private var sessionNotes = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var exerciseDetails: [UUID: ExerciseDetail] = [:]
    @State private var showingExercisePicker = false
    @State private var overallRating = 3
    @State private var manualDuration: Double = 60 // Default 60 minutes
    @State private var useManualDuration = false

    @State private var availableExercises: [Exercise] = []

    // XP and Celebration states
    @State private var showSessionComplete = false
    @State private var xpBreakdown: SessionXPBreakdown?
    @State private var newLevel: Int?
    @State private var unlockedAchievements: [Achievement] = []
    
    let sessionTypes = ["Training", "Match", "Fitness", "Technical", "Tactical"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Adaptive background (gradient light, solid dark)
                AdaptiveBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        // Session Type Section
                        modernSessionTypeCard
                        
                        // Location Section
                        modernLocationCard
                        
                        // Intensity Section
                        modernIntensityCard
                        
                        // Duration Section
                        modernDurationCard
                        
                        // Exercises Section
                        modernExercisesCard
                        
                        // Rating Section
                        modernRatingCard
                        
                        // Notes Section
                        modernNotesCard
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
            .navigationTitle("New Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSession()
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedExercises.isEmpty ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.primaryGreen)
                    .disabled(selectedExercises.isEmpty)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(
                    selectedExercises: $selectedExercises,
                    availableExercises: Array(availableExercises)
                )
            }
            .sheet(isPresented: $showSessionComplete) {
                SessionCompleteView(
                    xpBreakdown: xpBreakdown,
                    newLevel: newLevel,
                    achievements: unlockedAchievements,
                    player: player,
                    onDismiss: {
                        showSessionComplete = false
                        dismiss()
                    }
                )
            }
            .onAppear {
                loadAvailableExercises()
                prefillFromPlanSession()
            }
        }
    }
    
    // MARK: - Modern Card Components
    
    private var modernSessionTypeCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Session Type")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(sessionTypes, id: \.self) { type in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                sessionType = type
                            }
                        }) {
                            HStack {
                                Image(systemName: iconForSessionType(type))
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(sessionType == type ? .white : DesignSystem.Colors.primaryGreen)
                                
                                Text(type)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.medium)
                                    .foregroundColor(sessionType == type ? .white : DesignSystem.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .background(
                                sessionType == type 
                                    ? DesignSystem.Colors.primaryGreen
                                    : Color.clear
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(
                                        sessionType == type 
                                            ? Color.clear 
                                            : DesignSystem.Colors.neutral300,
                                        lineWidth: 1
                                    )
                            )
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                        .pressAnimation()
                    }
                }
            }
        }
    }
    
    private var modernLocationCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Location")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                ModernTextField(
                    "Training Location",
                    text: $location,
                    placeholder: "Home, Park, Gym, Field...",
                    icon: "location"
                )
            }
        }
    }
    
    private var modernIntensityCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Text("Intensity Level")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(intensity)/5")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                
                // Visual intensity indicators
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(1...5, id: \.self) { level in
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                                .fill(
                                    level <= intensity 
                                        ? DesignSystem.Colors.primaryGreen
                                        : DesignSystem.Colors.neutral300
                                )
                                .frame(height: CGFloat(level * 6 + 10))
                                .animation(.easeInOut(duration: 0.3), value: intensity)
                            
                            Text(intensityLabel(for: level))
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(
                                    level <= intensity 
                                        ? DesignSystem.Colors.primaryGreen
                                        : DesignSystem.Colors.textSecondary
                                )
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                intensity = level
                            }
                        }
                    }
                }
                .frame(height: 60)
            }
        }
    }
    
    private var modernDurationCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Text("Session Duration")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text(useManualDuration ? "\(Int(manualDuration)) min" : "Auto")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.primaryGreen.opacity(0.1))
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                }
                
                // Toggle for manual vs automatic duration
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Duration Mode")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(useManualDuration ? "Set total session time manually" : "Calculate from exercises automatically")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $useManualDuration)
                        .tint(DesignSystem.Colors.primaryGreen)
                        .scaleEffect(0.9)
                }
                
                // Manual duration slider (only shown when manual mode is enabled)
                if useManualDuration {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Total Time")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(Int(manualDuration)) minutes")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                        
                        Slider(value: $manualDuration, in: 10...180, step: 5)
                            .tint(DesignSystem.Colors.primaryGreen)
                        
                        HStack {
                            Text("10 min")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            Spacer()
                            
                            Text("3 hours")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: useManualDuration)
                }
            }
        }
    }
    
    private var modernExercisesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Exercises")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(selectedExercises.count)")
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(DesignSystem.Colors.primaryGreen)
                        .cornerRadius(12)
                }
                
                if selectedExercises.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.neutral400)
                        
                        Text("No exercises selected")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        ModernButton("Add Exercises", icon: "plus.circle.fill") {
                            showingExercisePicker = true
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(selectedExercises, id: \.objectID) { exercise in
                            ModernExerciseRowView(
                                exercise: exercise,
                                detail: Binding(
                                    get: { exercise.id.flatMap { exerciseDetails[$0] } ?? ExerciseDetail() },
                                    set: { if let id = exercise.id { exerciseDetails[id] = $0 } }
                                ),
                                onRemove: {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        removeExercise(exercise)
                                    }
                                }
                            )
                        }
                    }
                    
                    ModernButton("Add More Exercises", icon: "plus.circle", style: .secondary) {
                        showingExercisePicker = true
                    }
                }
            }
        }
    }
    
    private var modernRatingCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Text("Session Rating")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Text(ratingDescription(for: overallRating))
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(1...5, id: \.self) { rating in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                overallRating = rating
                            }
                        }) {
                            Image(systemName: rating <= overallRating ? "star.fill" : "star")
                                .font(.system(size: 28))
                                .foregroundColor(
                                    rating <= overallRating 
                                        ? DesignSystem.Colors.warning
                                        : DesignSystem.Colors.neutral300
                                )
                                .scaleEffect(rating <= overallRating ? 1.1 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: overallRating)
                        }
                        .pressAnimation()
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var modernNotesCard: some View {
        ModernCard(padding: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Session Notes")
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.background)
                        .stroke(DesignSystem.Colors.neutral300, lineWidth: 1)
                        .frame(height: 120)
                    
                    TextEditor(text: $sessionNotes)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .padding(DesignSystem.Spacing.sm)
                        .background(Color.clear)
                        .scrollContentBackground(.hidden)
                    
                    if sessionNotes.isEmpty {
                        Text("How did your session go? Any highlights or areas for improvement?")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(DesignSystem.Spacing.sm)
                            .padding(.top, DesignSystem.Spacing.xs)
                            .allowsHitTesting(false)
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func iconForSessionType(_ type: String) -> String {
        switch type {
        case "Training": return "figure.run"
        case "Match": return "soccerball"
        case "Fitness": return "heart.fill"
        case "Technical": return "target"
        case "Tactical": return "brain.head.profile"
        default: return "figure.soccer"
        }
    }
    
    private func intensityLabel(for level: Int) -> String {
        switch level {
        case 1: return "Light"
        case 2: return "Easy"
        case 3: return "Moderate"
        case 4: return "Hard"
        case 5: return "Max"
        default: return ""
        }
    }
    
    private func ratingDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "Good"
        }
    }
    
    private func loadAvailableExercises() {
        availableExercises = CoreDataManager.shared.fetchExercises(for: player)
    }

    private func prefillFromPlanSession() {
        guard let planSession = planSession else { return }

        // Pre-fill session details from plan
        if let type = planSession.sessionType {
            sessionType = type
        }
        intensity = Int(planSession.intensity)
        manualDuration = Double(planSession.duration)
        useManualDuration = true

        if let notes = planSession.notes {
            sessionNotes = notes
        }

        // Pre-fill exercises from plan
        if let exercises = planSession.exercises?.allObjects as? [Exercise] {
            selectedExercises = exercises
        }
    }

    private func removeExercise(_ exercise: Exercise) {
        selectedExercises.removeAll { $0.objectID == exercise.objectID }
        if let id = exercise.id { exerciseDetails.removeValue(forKey: id) }
    }
    
    private func saveSession() {
        let newSession = TrainingSession(context: viewContext)
        newSession.id = UUID()
        newSession.player = player
        newSession.date = Date()
        newSession.sessionType = sessionType
        newSession.location = location.isEmpty ? nil : location
        newSession.intensity = Int16(intensity)
        newSession.notes = sessionNotes.isEmpty ? nil : sessionNotes
        newSession.overallRating = Int16(overallRating)
        
        var totalDuration: Double = 0
        
        for exercise in selectedExercises {
            let sessionExercise = SessionExercise(context: viewContext)
            sessionExercise.id = UUID()
            sessionExercise.session = newSession
            sessionExercise.exercise = exercise
            
            if let id = exercise.id, let detail = exerciseDetails[id] {
                sessionExercise.duration = detail.duration
                sessionExercise.sets = Int16(detail.sets)
                sessionExercise.reps = Int16(detail.reps)
                sessionExercise.performanceRating = Int16(detail.rating)
                sessionExercise.notes = detail.notes.isEmpty ? nil : detail.notes
                
                totalDuration += detail.duration
            }
        }
        
        // Use manual duration if enabled, otherwise use calculated duration from exercises
        newSession.duration = useManualDuration ? manualDuration : totalDuration
        
        #if DEBUG

        print("💾 Saving new session for player: \(player.name ?? "Unknown") - UID: \(player.firebaseUID ?? "No UID")")

        #endif
        coreDataManager.save()
        #if DEBUG
        print("✅ Session saved successfully")
        #endif

        // Mark plan session as completed if this was from a training plan
        if let planSession = planSession {
            TrainingPlanService.shared.markSessionCompleted(
                planSession.toModel(),
                actualDuration: Int(newSession.duration),
                actualIntensity: Int(intensity)
            )
            #if DEBUG
            print("✅ Plan session marked as completed")
            #endif
        }

        // Process XP earning
        let (breakdown, levelUp) = XPService.shared.processSessionCompletion(
            session: newSession,
            player: player,
            context: viewContext
        )
        xpBreakdown = breakdown
        newLevel = levelUp

        #if DEBUG
        print("🎮 XP earned: \(breakdown.total) (base: \(breakdown.baseXP), intensity: \(breakdown.intensityBonus), streak: \(breakdown.streakBonus))")
        if let level = levelUp {
            print("🎉 Level up! Now level \(level)")
        }
        #endif

        // Check for achievement unlocks
        unlockedAchievements = AchievementService.shared.checkAndUnlockAchievements(
            for: player,
            in: viewContext
        )

        #if DEBUG
        if !unlockedAchievements.isEmpty {
            print("🏆 Unlocked \(unlockedAchievements.count) achievements!")
        }
        #endif

        // Show completion view if XP was earned
        if breakdown.total > 0 {
            showSessionComplete = true
        } else {
            dismiss()
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let samplePlayer = Player(context: context)
    samplePlayer.name = "John Doe"

    return NewSessionView(player: samplePlayer)
        .environment(\.managedObjectContext, context)
        .environmentObject(CoreDataManager.shared)
}
