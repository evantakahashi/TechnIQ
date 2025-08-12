import SwiftUI
import CoreData
import Foundation

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let player: Player
    
    @State private var allExercises: [Exercise] = []
    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @State private var showingExerciseDetail = false
    @State private var isLoadingYouTubeContent = false
    @State private var loadingProgress: Double = 0.0
    @State private var loadingMessage = ""
    @State private var showingCustomDrillGenerator = false
    
    // Organized exercises by category
    var youtubeExercises: [Exercise] {
        allExercises.filter { exercise in
            exercise.exerciseDescription?.contains("🎥 YouTube Video") == true
        }
    }
    
    var customGeneratedExercises: [Exercise] {
        allExercises
            .filter { exercise in
                exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true
            }
            .sorted { first, second in
                // Sort by UUID to show newest first (newer UUIDs have higher values)
                guard let firstID = first.id?.uuidString,
                      let secondID = second.id?.uuidString else {
                    return false
                }
                return firstID > secondID
            }
    }
    
    var physicalExercises: [Exercise] {
        allExercises.filter { $0.category?.lowercased() == "physical" }
    }
    
    var tacticalExercises: [Exercise] {
        allExercises.filter { $0.category?.lowercased() == "tactical" }
    }
    
    var technicalExercises: [Exercise] {
        allExercises.filter { $0.category?.lowercased() == "technical" }
    }
    
    // Search filtered exercises
    var searchResults: [Exercise] {
        if searchText.isEmpty {
            return []
        }
        return allExercises.filter { exercise in
            exercise.name?.localizedCaseInsensitiveContains(searchText) == true ||
            exercise.exerciseDescription?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                DesignSystem.Colors.backgroundGradient
                    .ignoresSafeArea()
                
                if searchText.isEmpty {
                    // Main content with horizontal sections
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: DesignSystem.Spacing.lg) {
                            // Header Section
                            headerSection
                            
                            // Search Bar
                            searchSection
                            
                            // Custom Drill Generator Section
                            customDrillSection
                            
                            // YouTube Section
                            if !youtubeExercises.isEmpty || isLoadingYouTubeContent {
                                exerciseSection(
                                    title: "🎥 Personalized Training",
                                    exercises: youtubeExercises,
                                    color: .red,
                                    emptyMessage: "Get AI-powered recommendations"
                                )
                            }
                            
                            // Physical Section
                            exerciseSection(
                                title: "💪 Physical",
                                exercises: physicalExercises,
                                color: DesignSystem.Colors.accentOrange,
                                emptyMessage: "No physical exercises yet"
                            )
                            
                            // Tactical Section
                            exerciseSection(
                                title: "🧠 Tactical",
                                exercises: tacticalExercises,
                                color: DesignSystem.Colors.secondaryBlue,
                                emptyMessage: "No tactical exercises yet"
                            )
                            
                            // Technical Section
                            exerciseSection(
                                title: "⚽ Technical",
                                exercises: technicalExercises,
                                color: DesignSystem.Colors.primaryGreen,
                                emptyMessage: "No technical exercises yet"
                            )
                            
                            // Bottom padding
                            Spacer(minLength: DesignSystem.Spacing.xxl)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                } else {
                    // Search Results
                    searchResultsView
                }
                
                // Floating Action Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingActionButton(
                            icon: "play.rectangle.fill"
                        ) {
                            loadYouTubeContent()
                        }
                        .disabled(isLoadingYouTubeContent)
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                
                // Loading Overlay
                if isLoadingYouTubeContent {
                    LoadingOverlay(
                        progress: loadingProgress,
                        message: loadingMessage
                    )
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingExerciseDetail) {
                if let exercise = selectedExercise {
                    ExerciseDetailView(exercise: exercise)
                }
            }
            .sheet(isPresented: $showingCustomDrillGenerator) {
                CustomDrillGeneratorView(player: player)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        // Refresh exercises when custom drill generator is dismissed
                        loadExercises()
                    }
            }
            .onAppear {
                loadExercises()
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Hello, \(player.name ?? "Player")!")
                        .font(DesignSystem.Typography.headlineSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Ready to train?")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                ModernCard(padding: DesignSystem.Spacing.sm) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        HStack {
                            Image(systemName: DesignSystem.Icons.exercises)
                                .font(.title3)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(allExercises.count)")
                                .font(DesignSystem.Typography.numberMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text("exercises")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(width: 100, height: 70)
            }
        }
    }
    
    private var searchSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .font(DesignSystem.Typography.bodyMedium)
            
            TextField("Search exercises...", text: $searchText)
                .font(DesignSystem.Typography.bodyMedium)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }
    
    private var customDrillSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("🤖 AI Custom Drills")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("\(customGeneratedExercises.count) \(customGeneratedExercises.count == 1 ? "drill" : "drills")")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                ModernButton(
                    "Create Drill",
                    icon: "brain.head.profile",
                    style: .primary
                ) {
                    showingCustomDrillGenerator = true
                }
            }
            
            if customGeneratedExercises.isEmpty {
                // Empty State
                ModernCard {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundColor(DesignSystem.Colors.primaryGreen.opacity(0.7))
                        
                        Text("Create Your First Custom Drill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Tell our AI what skills you want to work on, and we'll generate a personalized drill just for you.")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        ModernButton(
                            "Get Started",
                            icon: "brain.head.profile",
                            style: .primary
                        ) {
                            showingCustomDrillGenerator = true
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                .frame(height: 200)
            } else {
                // Horizontal Scroll of Custom Drills
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(customGeneratedExercises, id: \.objectID) { exercise in
                            CustomDrillCard(exercise: exercise)
                                .onTapGesture {
                                    selectedExercise = exercise
                                    showingExerciseDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
    }
    
    private func exerciseSection(title: String, exercises: [Exercise], color: Color, emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            ExerciseSectionHeader(title: title, count: exercises.count, color: color)
            
            if exercises.isEmpty {
                // Empty State
                EmptyExerciseSection(message: emptyMessage, color: color) {
                    if title.contains("🎥") {
                        loadYouTubeContent()
                    }
                }
            } else {
                // Horizontal Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(exercises, id: \.objectID) { exercise in
                            ModernExerciseCard(exercise: exercise, color: color)
                                .onTapGesture {
                                    selectedExercise = exercise
                                    showingExerciseDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
    }
    
    private var searchResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                searchSection
                
                Button("Cancel") {
                    searchText = ""
                }
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .font(DesignSystem.Typography.bodyMedium)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            
            if searchResults.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("No exercises found")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text("Try searching for a different term")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(searchResults, id: \.objectID) { exercise in
                            ExerciseLibraryRow(exercise: exercise)
                                .onTapGesture {
                                    selectedExercise = exercise
                                    showingExerciseDetail = true
                                }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.md)
                }
            }
        }
    }
    
    private func loadExercises() {
        allExercises = CoreDataManager.shared.fetchExercises(for: player)
    }
    
    private func loadYouTubeContent() {
        guard !isLoadingYouTubeContent else { return }
        
        isLoadingYouTubeContent = true
        loadingProgress = 0.0
        loadingMessage = "Searching YouTube..."
        
        Task {
            await performYouTubeLoading()
        }
    }
    
    private func performYouTubeLoading() async {
        let progressCallback: @Sendable @MainActor (Double, String) -> Void = { @MainActor progress, message in
            self.loadingProgress = progress
            self.loadingMessage = message
        }
            
            do {
                // Try LLM-powered CloudMLService first, fallback to local search
                do {
                    let youtubeRecommendations = try await CloudMLService.shared.getYouTubeRecommendations(
                        for: player,
                        limit: 3
                    )
                    
                    // Convert YouTube recommendations to exercises on main thread
                    await MainActor.run {
                        progressCallback(0.8, "Creating exercises from recommendations...")
                        
                        for recommendation in youtubeRecommendations {
                            _ = CoreDataManager.shared.createExerciseFromYouTubeVideo(
                                for: player,
                                videoId: recommendation.videoId,
                                title: recommendation.title,
                                description: recommendation.description,
                                thumbnailURL: recommendation.thumbnailUrl,
                                duration: 300, // Default duration
                                channelTitle: recommendation.channelTitle,
                                category: "Technical",
                                difficulty: Int(recommendation.confidenceScore * 5), // Convert confidence to difficulty
                                targetSkills: []
                            )
                        }
                    }
                    
                } catch {
                    // Fallback to local YouTube search
                    try await CoreDataManager.shared.loadYouTubeDrillsFromAPI(
                        for: player,
                        category: nil,
                        maxResults: 3,
                        progressCallback: progressCallback
                    )
                }
            } catch {
                await MainActor.run {
                    loadingMessage = "Error: \(error.localizedDescription)"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isLoadingYouTubeContent = false
                        loadingProgress = 0.0
                        loadingMessage = ""
                    }
                }
                return // Don't continue to completion logic
            }
            
            await MainActor.run {
                loadingProgress = 1.0
                loadingMessage = "Complete!"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    loadExercises() // Refresh the exercise list
                    isLoadingYouTubeContent = false
                    loadingProgress = 0.0
                    loadingMessage = ""
                }
            }
        }
    }


struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.green : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct ExerciseLibraryRow: View {
    let exercise: Exercise
    
    var body: some View {
        HStack(spacing: 12) {
            if let description = exercise.exerciseDescription, description.contains("🎥 YouTube Video") {
                if let videoIdRange = description.range(of: "Video ID: "),
                   let endRange = description[videoIdRange.upperBound...].range(of: "\n") ?? description[videoIdRange.upperBound...].range(of: "$") {
                    let videoId = String(description[videoIdRange.upperBound..<endRange.lowerBound])
                    let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/medium.jpg"
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 45)
                            .clipped()
                            .cornerRadius(8)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 60, height: 45)
                    }
                } else {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                        .frame(width: 60, height: 45)
                        .background(DesignSystem.Colors.neutral200)
                        .cornerRadius(8)
                }
            } else {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .frame(width: 60, height: 45)
                    .background(DesignSystem.Colors.neutral200)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(exercise.name ?? "Exercise")
                                .font(.headline)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            
                            if let description = exercise.exerciseDescription, description.contains("🎥 YouTube Video") {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Text(exercise.exerciseDescription ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    DifficultyIndicator(level: Int(exercise.difficulty))
                }
                
                HStack {
                    CategoryBadge(category: exercise.category ?? "General")
                    
                    Spacer()
                    
                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "target")
                                .font(.caption)
                                .foregroundColor(.blue)
                            Text(skills.prefix(2).joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}


struct DifficultyIndicator: View {
    let level: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level ? difficultyColor : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
    
    private var difficultyColor: Color {
        switch level {
        case 1: return .green
        case 2: return .orange
        default: return .red
        }
    }
}

struct LoadingOverlay: View {
    let progress: Double
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView(value: progress, total: 1.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .scaleEffect(1.5)
                
                VStack(spacing: 8) {
                    Text("Loading YouTube Content")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(15)
            .shadow(radius: 10)
        }
    }
}

// MARK: - Modern Components

struct ExerciseSectionHeader: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.titleLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("\(count) \(count == 1 ? "exercise" : "exercises")")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            if count > 0 {
                Button(action: {
                    // TODO: Navigate to "View All" screen
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("View All")
                            .font(DesignSystem.Typography.labelMedium)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(color)
                }
            }
        }
    }
}

struct ModernExerciseCard: View {
    let exercise: Exercise
    let color: Color
    
    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Top section with thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.3), color.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    if let description = exercise.exerciseDescription,
                       description.contains("🎥 YouTube Video") {
                        // YouTube video thumbnail
                        youTubePreview(from: description)
                    } else {
                        // Category icon
                        Image(systemName: iconForCategory(exercise.category))
                            .font(.system(size: 32))
                            .foregroundColor(color)
                    }
                }
                
                // Exercise details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        CategoryBadge(category: exercise.category ?? "General")
                        
                        Spacer()
                        
                        DifficultyIndicator(level: Int(exercise.difficulty))
                    }
                }
            }
        }
        .frame(width: 160)
    }
    
    @ViewBuilder
    private func youTubePreview(from description: String) -> some View {
        if let videoIdRange = description.range(of: "Video ID: "),
           let endRange = description[videoIdRange.upperBound...].range(of: "\n") ?? description[videoIdRange.upperBound...].range(of: "$") {
            let videoId = String(description[videoIdRange.upperBound..<endRange.lowerBound])
            let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/medium.jpg"
            
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 80)
                    .clipped()
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    )
            } placeholder: {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                    .fill(Color.red.opacity(0.2))
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                    )
            }
        } else {
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(Color.red.opacity(0.2))
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                )
        }
    }
    
    private func iconForCategory(_ category: String?) -> String {
        switch category?.lowercased() {
        case "physical":
            return "figure.run"
        case "tactical":
            return "brain.head.profile"
        case "technical":
            return "soccerball"
        default:
            return "book.fill"
        }
    }
}

struct EmptyExerciseSection: View {
    let message: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        ModernCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 32))
                    .foregroundColor(color.opacity(0.7))
                
                Text(message)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                
                ModernButton("Get Started", style: .ghost, action: action)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .frame(height: 160)
    }
}

struct CustomDrillCard: View {
    let exercise: Exercise
    
    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // AI Icon Header
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                        .fill(
                            LinearGradient(
                                colors: [DesignSystem.Colors.primaryGreen.opacity(0.3), DesignSystem.Colors.primaryGreen.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 80)
                    
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24))
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        
                        Text("AI Generated")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .fontWeight(.semibold)
                    }
                }
                
                // Exercise details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(exercise.name ?? "Custom Drill")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        CategoryBadge(category: exercise.category ?? "Custom")
                        
                        Spacer()
                        
                        DifficultyIndicator(level: Int(exercise.difficulty))
                    }
                }
            }
        }
        .frame(width: 160)
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"
    
    return ExerciseLibraryView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}
