import SwiftUI
import CoreData
import Foundation

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let player: Player

    @State private var allExercises: [Exercise] = []
    @State private var recommendations: [CoreDataManager.DrillRecommendation] = []
    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @State private var showingExerciseDetail = false
    @State private var isLoadingYouTubeContent = false
    @State private var showingCustomDrillGenerator = false
    @State private var showingManualDrillCreator = false

    // Organized exercises by type
    var customGeneratedExercises: [Exercise] {
        allExercises
            .filter { exercise in
                exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true
            }
            .sorted { first, second in
                guard let firstID = first.id?.uuidString,
                      let secondID = second.id?.uuidString else {
                    return false
                }
                return firstID > secondID
            }
    }

    var youtubeExercises: [Exercise] {
        allExercises.filter { exercise in
            exercise.exerciseDescription?.contains("🎥 YouTube Video") == true
        }
    }

    var physicalExercises: [Exercise] {
        allExercises.filter {
            $0.category?.lowercased() == "physical" &&
            $0.exerciseDescription?.contains("🎥 YouTube Video") == false &&
            $0.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == false
        }
    }

    var technicalExercises: [Exercise] {
        allExercises.filter {
            $0.category?.lowercased() == "technical" &&
            $0.exerciseDescription?.contains("🎥 YouTube Video") == false &&
            $0.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == false
        }
    }

    var tacticalExercises: [Exercise] {
        allExercises.filter {
            $0.category?.lowercased() == "tactical" &&
            $0.exerciseDescription?.contains("🎥 YouTube Video") == false &&
            $0.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == false
        }
    }

    // Get top 3 recommended exercises
    var recommendedExercises: [Exercise] {
        recommendations.prefix(3).map { $0.exercise }
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
                    // Main content with sections
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            // Simple Header
                            simpleHeader

                            // Search Bar
                            searchBar

                            // Action Buttons
                            actionButtons

                            // Recommended for You Section
                            if !recommendations.isEmpty {
                                recommendedSection
                            }

                            // AI Custom Drills Section
                            if !customGeneratedExercises.isEmpty {
                                categorySection(
                                    title: "🤖 AI Custom Drills",
                                    exercises: Array(customGeneratedExercises.prefix(6)),
                                    color: DesignSystem.Colors.primaryGreen
                                )
                            }

                            // YouTube Training Section
                            if !youtubeExercises.isEmpty {
                                categorySection(
                                    title: "🎥 YouTube Training",
                                    exercises: Array(youtubeExercises.prefix(6)),
                                    color: .red
                                )
                            }

                            // Physical Section
                            if !physicalExercises.isEmpty {
                                categorySection(
                                    title: "💪 Physical",
                                    exercises: Array(physicalExercises.prefix(6)),
                                    color: DesignSystem.Colors.accentOrange
                                )
                            }

                            // Technical Section
                            if !technicalExercises.isEmpty {
                                categorySection(
                                    title: "⚽ Technical",
                                    exercises: Array(technicalExercises.prefix(6)),
                                    color: DesignSystem.Colors.primaryGreen
                                )
                            }

                            // Tactical Section
                            if !tacticalExercises.isEmpty {
                                categorySection(
                                    title: "🧠 Tactical",
                                    exercises: Array(tacticalExercises.prefix(6)),
                                    color: DesignSystem.Colors.secondaryBlue
                                )
                            }

                            // Empty state if no exercises
                            if allExercises.isEmpty {
                                emptyState
                            }

                            // Bottom padding
                            Spacer(minLength: DesignSystem.Spacing.xxl)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.md)
                    }
                } else {
                    // Search Results
                    searchResultsView
                }

                // Loading Overlay
                if isLoadingYouTubeContent {
                    LoadingOverlay()
                }
            }
            .navigationTitle("Exercises")
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
                        loadExercises()
                    }
            }
            .sheet(isPresented: $showingManualDrillCreator) {
                ManualDrillCreatorView(player: player)
                    .environment(\.managedObjectContext, viewContext)
                    .onDisappear {
                        loadExercises()
                    }
            }
            .onAppear {
                loadExercises()
                loadRecommendations()
            }
        }
    }

    // MARK: - View Components

    private var simpleHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Hello, \(player.name ?? "Player")!")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("\(allExercises.count) exercises")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()
        }
    }

    private var searchBar: some View {
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

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Top row: AI Drill and Manual Drill
            HStack(spacing: DesignSystem.Spacing.md) {
                // AI Custom Drill Button
                ModernButton(
                    "AI Drill",
                    icon: "brain.head.profile",
                    style: .primary
                ) {
                    showingCustomDrillGenerator = true
                }
                .frame(maxWidth: .infinity)

                // Manual Custom Drill Button
                ModernButton(
                    "Manual Drill",
                    icon: "pencil.circle.fill",
                    style: .primary
                ) {
                    showingManualDrillCreator = true
                }
                .frame(maxWidth: .infinity)
            }

            // Bottom row: YouTube button
            ModernButton(
                "YouTube",
                icon: "play.rectangle.fill",
                style: .secondary
            ) {
                loadYouTubeContent()
            }
            .disabled(isLoadingYouTubeContent)
        }
    }

    // MARK: - Recommended Section

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("⭐ Recommended for You")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Based on your training history")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }

            // Horizontal scroll of recommendations
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(Array(recommendations.prefix(3)), id: \.exercise.objectID) { recommendation in
                        RecommendedExerciseCard(
                            exercise: recommendation.exercise,
                            matchPercentage: Int(recommendation.confidenceScore * 100),
                            reason: recommendation.reason
                        )
                        .onTapGesture {
                            selectedExercise = recommendation.exercise
                            showingExerciseDetail = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Category Section

    private func categorySection(title: String, exercises: [Exercise], color: Color) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Section Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }

            // Horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(exercises, id: \.objectID) { exercise in
                        SimpleExerciseCard(exercise: exercise)
                            .onTapGesture {
                                selectedExercise = exercise
                                showingExerciseDetail = true
                            }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Spacer()
                .frame(height: 60)

            Image(systemName: "figure.soccer")
                .font(.system(size: 64))
                .foregroundColor(DesignSystem.Colors.primaryGreen.opacity(0.5))

            Text("No Exercises Yet")
                .font(DesignSystem.Typography.titleLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Text("Create a custom drill or get YouTube recommendations to start training")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var searchResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                searchBar

                Button("Cancel") {
                    searchText = ""
                }
                .foregroundColor(DesignSystem.Colors.primaryGreen)
                .font(DesignSystem.Typography.bodyMedium)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            if searchResults.isEmpty {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Spacer()
                        .frame(height: 60)

                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

                    Text("No exercises found")
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("Try searching for a different term")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                            GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                        ],
                        spacing: DesignSystem.Spacing.md
                    ) {
                        ForEach(searchResults, id: \.objectID) { exercise in
                            SimpleExerciseCard(exercise: exercise)
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

    // MARK: - Helper Functions

    private func loadExercises() {
        allExercises = CoreDataManager.shared.fetchExercises(for: player)
    }

    private func loadRecommendations() {
        recommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: 3)
    }

    private func loadYouTubeContent() {
        guard !isLoadingYouTubeContent else { return }

        isLoadingYouTubeContent = true

        Task {
            await performYouTubeLoading()
        }
    }

    private func performYouTubeLoading() async {
        do {
            // Try LLM-powered CloudMLService first
            do {
                let youtubeRecommendations = try await CloudMLService.shared.getYouTubeRecommendations(
                    for: player,
                    limit: 3
                )

                // Convert YouTube recommendations to exercises
                await MainActor.run {
                    for recommendation in youtubeRecommendations {
                        _ = CoreDataManager.shared.createExerciseFromYouTubeVideo(
                            for: player,
                            videoId: recommendation.videoId,
                            title: recommendation.title,
                            description: recommendation.description,
                            thumbnailURL: recommendation.thumbnailUrl,
                            duration: 300,
                            channelTitle: recommendation.channelTitle,
                            category: "Technical",
                            difficulty: Int(recommendation.confidenceScore * 5),
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
                    progressCallback: { _, _ in }
                )
            }
        } catch {
            print("Error loading YouTube content: \(error)")
        }

        await MainActor.run {
            loadExercises()
            isLoadingYouTubeContent = false
        }
    }
}

// MARK: - Recommended Exercise Card (Larger, with match % and reason)

struct RecommendedExerciseCard: View {
    let exercise: Exercise
    let matchPercentage: Int
    let reason: String

    private var isYouTube: Bool {
        exercise.exerciseDescription?.contains("🎥 YouTube Video") == true
    }

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                // Top Image/Icon Area
                ZStack(alignment: .topTrailing) {
                    if isYouTube {
                        youTubePreview()
                    } else {
                        iconPreview()
                    }

                    // Match percentage badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text("\(matchPercentage)%")
                            .font(DesignSystem.Typography.labelSmall)
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                    .padding(DesignSystem.Spacing.sm)
                }
                .frame(height: 120)

                // Content Area
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Exercise Name
                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Reason
                    Text(reason)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Category and Difficulty
                    HStack {
                        CategoryBadge(category: exercise.category ?? "General")

                        Spacer()

                        SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .frame(width: 260, height: 230)
    }

    @ViewBuilder
    private func youTubePreview() -> some View {
        if let description = exercise.exerciseDescription,
           let videoIdRange = description.range(of: "Video ID: "),
           let endRange = description[videoIdRange.upperBound...].range(of: "\n") ?? description[videoIdRange.upperBound...].range(of: "$") {
            let videoId = String(description[videoIdRange.upperBound..<endRange.lowerBound])
            let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/medium.jpg"

            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipped()
                    .overlay(
                        ZStack {
                            Color.black.opacity(0.2)
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    )
            } placeholder: {
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            }
        } else {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                )
        }
    }

    @ViewBuilder
    private func iconPreview() -> some View {
        let color = colorForCategory(exercise.category)

        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: iconForCategory(exercise.category))
                    .font(.system(size: 40))
                    .foregroundColor(color)
            )
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
            return "figure.soccer"
        }
    }

    private func colorForCategory(_ category: String?) -> Color {
        switch category?.lowercased() {
        case "physical":
            return DesignSystem.Colors.accentOrange
        case "tactical":
            return DesignSystem.Colors.secondaryBlue
        case "technical":
            return DesignSystem.Colors.primaryGreen
        default:
            return DesignSystem.Colors.primaryGreen
        }
    }
}

// MARK: - Simple Exercise Card (Smaller, for category sections)

struct SimpleExerciseCard: View {
    let exercise: Exercise

    private var isAIGenerated: Bool {
        exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true
    }

    private var isYouTube: Bool {
        exercise.exerciseDescription?.contains("🎥 YouTube Video") == true
    }

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                // Top Image/Icon Area
                ZStack {
                    if isYouTube {
                        youTubePreview()
                    } else {
                        iconPreview()
                    }
                }
                .frame(height: 100)

                // Content Area
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Badge
                    if isAIGenerated {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                            Text("AI Generated")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                    } else if isYouTube {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption2)
                            Text("YouTube")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(.red)
                    } else {
                        CategoryBadge(category: exercise.category ?? "General")
                    }

                    // Exercise Name
                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Difficulty
                    SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                }
                .padding(DesignSystem.Spacing.sm)
            }
        }
        .frame(width: 160, height: 180)
    }

    @ViewBuilder
    private func youTubePreview() -> some View {
        if let description = exercise.exerciseDescription,
           let videoIdRange = description.range(of: "Video ID: "),
           let endRange = description[videoIdRange.upperBound...].range(of: "\n") ?? description[videoIdRange.upperBound...].range(of: "$") {
            let videoId = String(description[videoIdRange.upperBound..<endRange.lowerBound])
            let thumbnailURL = "https://img.youtube.com/vi/\(videoId)/medium.jpg"

            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .overlay(
                        ZStack {
                            Color.black.opacity(0.2)
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                    )
            } placeholder: {
                Rectangle()
                    .fill(Color.red.opacity(0.2))
                    .overlay(
                        ProgressView()
                    )
            }
        } else {
            Rectangle()
                .fill(Color.red.opacity(0.2))
                .overlay(
                    Image(systemName: "play.rectangle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                )
        }
    }

    @ViewBuilder
    private func iconPreview() -> some View {
        let color = colorForCategory(exercise.category)

        Rectangle()
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.3), color.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: iconForCategory(exercise.category))
                    .font(.system(size: 32))
                    .foregroundColor(color)
            )
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
            return "figure.soccer"
        }
    }

    private func colorForCategory(_ category: String?) -> Color {
        switch category?.lowercased() {
        case "physical":
            return DesignSystem.Colors.accentOrange
        case "tactical":
            return DesignSystem.Colors.secondaryBlue
        case "technical":
            return DesignSystem.Colors.primaryGreen
        default:
            return DesignSystem.Colors.primaryGreen
        }
    }
}

// MARK: - Simple Difficulty Indicator

struct SimpleDifficultyIndicator: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { index in
                Circle()
                    .fill(index <= level ? difficultyColor : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }

    private var difficultyColor: Color {
        switch level {
        case 1: return DesignSystem.Colors.primaryGreen
        case 2: return DesignSystem.Colors.accentOrange
        default: return .red
        }
    }
}

// MARK: - Simple Loading Overlay

struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.primaryGreen))
                    .scaleEffect(1.5)

                Text("Loading YouTube videos...")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(DesignSystem.Shadow.medium)
        }
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return ExerciseLibraryView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}
