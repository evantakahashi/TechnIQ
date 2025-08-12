import SwiftUI
import CoreData

struct NewSessionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coreDataManager: CoreDataManager
    
    let player: Player
    
    @State private var sessionType = "Training"
    @State private var location = ""
    @State private var intensity = 3
    @State private var sessionNotes = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var exerciseDetails: [UUID: ExerciseDetail] = [:]
    @State private var showingExercisePicker = false
    @State private var overallRating = 3
    
    @State private var availableExercises: [Exercise] = []
    
    let sessionTypes = ["Training", "Match", "Fitness", "Technical", "Tactical"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Modern gradient background
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        // Session Type Section
                        modernSessionTypeCard
                        
                        // Location Section
                        modernLocationCard
                        
                        // Intensity Section
                        modernIntensityCard
                        
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
            .onAppear {
                loadAvailableExercises()
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
                                    get: { exerciseDetails[exercise.id!] ?? ExerciseDetail() },
                                    set: { exerciseDetails[exercise.id!] = $0 }
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
    
    private func removeExercise(_ exercise: Exercise) {
        selectedExercises.removeAll { $0.objectID == exercise.objectID }
        exerciseDetails.removeValue(forKey: exercise.id!)
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
            
            if let detail = exerciseDetails[exercise.id!] {
                sessionExercise.duration = detail.duration
                sessionExercise.sets = Int16(detail.sets)
                sessionExercise.reps = Int16(detail.reps)
                sessionExercise.performanceRating = Int16(detail.rating)
                sessionExercise.notes = detail.notes.isEmpty ? nil : detail.notes
                
                totalDuration += detail.duration
            }
        }
        
        newSession.duration = totalDuration
        
        print("💾 Saving new session for player: \(player.name ?? "Unknown") - UID: \(player.firebaseUID ?? "No UID")")
        coreDataManager.save()
        print("✅ Session saved successfully")
        dismiss()
    }
}

struct ExerciseDetail {
    var duration: Double = 10.0
    var sets: Int = 1
    var reps: Int = 10
    var rating: Int = 3
    var notes: String = ""
}

struct ModernExerciseRowView: View {
    let exercise: Exercise
    @Binding var detail: ExerciseDetail
    let onRemove: () -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Exercise Header
            HStack(spacing: DesignSystem.Spacing.md) {
                // Exercise Icon and Info
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: exerciseIcon)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(exercise.name ?? "Exercise")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .lineLimit(1)
                        
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(exercise.category ?? "General")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.primaryGreen.opacity(0.8))
                                .cornerRadius(DesignSystem.CornerRadius.xs)
                            
                            Text("Level \(exercise.difficulty)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, DesignSystem.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.warning.opacity(0.8))
                                .cornerRadius(DesignSystem.CornerRadius.xs)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Button(action: onRemove) {
                        Image(systemName: "trash.circle.fill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.error.opacity(0.7))
                    }
                    .pressAnimation()
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isExpanded.toggle()
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen.opacity(0.7))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .pressAnimation()
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.background)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .customShadow(DesignSystem.Shadow.small)
            
            // Expanded Details Section
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Duration Control
                    modernControlSection(
                        title: "Duration",
                        value: "\(Int(detail.duration)) min",
                        content: {
                            Slider(value: $detail.duration, in: 5...60, step: 5)
                                .tint(DesignSystem.Colors.primaryGreen)
                        }
                    )
                    
                    // Sets and Reps Controls
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        // Sets Control
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Sets")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                                
                                Text("\(detail.sets)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(detail.sets) },
                                set: { detail.sets = Int($0) }
                            ), in: 1...10, step: 1)
                            .tint(DesignSystem.Colors.primaryGreen)
                        }
                        
                        // Reps Control
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Text("Reps")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Spacer()
                                
                                Text("\(detail.reps)")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                            }
                            
                            Slider(value: Binding(
                                get: { Double(detail.reps) },
                                set: { detail.reps = Int($0) }
                            ), in: 1...50, step: 1)
                            .tint(DesignSystem.Colors.primaryGreen)
                        }
                    }
                    
                    // Performance Rating
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Performance")
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text(performanceDescription(for: detail.rating))
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(1...5, id: \.self) { rating in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        detail.rating = rating
                                    }
                                }) {
                                    Image(systemName: rating <= detail.rating ? "star.fill" : "star")
                                        .font(DesignSystem.Typography.titleMedium)
                                        .foregroundColor(
                                            rating <= detail.rating 
                                                ? DesignSystem.Colors.warning
                                                : DesignSystem.Colors.neutral300
                                        )
                                        .scaleEffect(rating <= detail.rating ? 1.1 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: detail.rating)
                                }
                                .pressAnimation()
                            }
                            Spacer()
                        }
                    }
                    
                    // Notes Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Exercise Notes")
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTextField(
                            "Notes",
                            text: $detail.notes,
                            placeholder: "Add notes about this exercise...",
                            icon: "note.text"
                        )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.primaryGreen.opacity(0.05))
                .cornerRadius(DesignSystem.CornerRadius.md)
                .padding(.top, DesignSystem.Spacing.xs)
            }
        }
    }
    
    private var exerciseIcon: String {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return "target"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        default: return "soccerball"
        }
    }
    
    private func performanceDescription(for rating: Int) -> String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "Good"
        }
    }
    
    @ViewBuilder
    private func modernControlSection<Content: View>(
        title: String,
        value: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text(value)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            
            content()
        }
    }
}

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedExercises: [Exercise]
    let availableExercises: [Exercise]
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    
    var categories: [String] {
        let allCategories = Set(availableExercises.compactMap { $0.category })
        return ["All"] + Array(allCategories).sorted()
    }
    
    var filteredExercises: [Exercise] {
        var exercises = availableExercises
        
        if selectedCategory != "All" {
            exercises = exercises.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            exercises = exercises.filter { 
                $0.name?.localizedCaseInsensitiveContains(searchText) == true 
            }
        }
        
        return exercises
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Modern Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(categories, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                    }
                                }) {
                                    Text(category)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .fontWeight(.medium)
                                        .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.textPrimary)
                                        .padding(.horizontal, DesignSystem.Spacing.md)
                                        .padding(.vertical, DesignSystem.Spacing.sm)
                                        .background(
                                            selectedCategory == category 
                                                ? DesignSystem.Colors.primaryGreen
                                                : DesignSystem.Colors.background
                                        )
                                        .cornerRadius(DesignSystem.CornerRadius.lg)
                                        .customShadow(selectedCategory == category ? DesignSystem.Shadow.medium : DesignSystem.Shadow.small)
                                }
                                .pressAnimation()
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    }
                    
                    // Search Bar
                    HStack {
                        ModernTextField(
                            "Search",
                            text: $searchText,
                            placeholder: "Search exercises...",
                            icon: "magnifyingglass"
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    
                    // Exercise List
                    if filteredExercises.isEmpty {
                        Spacer()
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundColor(DesignSystem.Colors.neutral400)
                            
                            Text("No exercises found")
                                .font(DesignSystem.Typography.titleMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            if !searchText.isEmpty {
                                Text("Try adjusting your search")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(filteredExercises, id: \.objectID) { exercise in
                                    ModernExercisePickerRow(
                                        exercise: exercise,
                                        isSelected: selectedExercises.contains { $0.objectID == exercise.objectID }
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if selectedExercises.contains(where: { $0.objectID == exercise.objectID }) {
                                                selectedExercises.removeAll { $0.objectID == exercise.objectID }
                                            } else {
                                                selectedExercises.append(exercise)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                            .padding(.bottom, DesignSystem.Spacing.xl)
                        }
                    }
                }
            }
            .navigationTitle("Choose Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }
}

struct ModernExercisePickerRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Exercise Icon
            ZStack {
                Circle()
                    .fill(exerciseColor.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: exerciseIcon)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(exerciseColor)
            }
            
            // Exercise Details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(exercise.name ?? "Exercise")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(2)
                
                if let description = exercise.exerciseDescription, !description.isEmpty {
                    Text(description)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
                
                // Tags
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(exercise.category ?? "General")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(exerciseColor.opacity(0.8))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                    
                    Text("Level \(exercise.difficulty)")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(difficultyColor.opacity(0.8))
                        .cornerRadius(DesignSystem.CornerRadius.xs)
                    
                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        Text("\(skills.count) skills")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.neutral200)
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                    }
                }
            }
            
            Spacer()
            
            // Selection Button
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .fill(
                            isSelected 
                                ? DesignSystem.Colors.primaryGreen
                                : DesignSystem.Colors.background
                        )
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .stroke(
                                    isSelected 
                                        ? DesignSystem.Colors.primaryGreen
                                        : DesignSystem.Colors.neutral300,
                                    lineWidth: 2
                                )
                        )
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(isSelected ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
            .pressAnimation()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
        .cornerRadius(DesignSystem.CornerRadius.lg)
        .customShadow(isSelected ? DesignSystem.Shadow.medium : DesignSystem.Shadow.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .stroke(
                    isSelected 
                        ? DesignSystem.Colors.primaryGreen.opacity(0.3)
                        : Color.clear,
                    lineWidth: 2
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
        }
    }
    
    private var exerciseIcon: String {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return "target"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        default: return "soccerball"
        }
    }
    
    private var exerciseColor: Color {
        let category = exercise.category?.lowercased() ?? ""
        switch category {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.error
        case "tactical": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.primaryGreen
        }
    }
    
    private var difficultyColor: Color {
        switch exercise.difficulty {
        case 1...2: return DesignSystem.Colors.success
        case 3...4: return DesignSystem.Colors.warning
        case 5: return DesignSystem.Colors.error
        default: return DesignSystem.Colors.neutral400
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