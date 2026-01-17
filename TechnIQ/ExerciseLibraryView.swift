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

    // Favorites and Recently Used
    @State private var favoriteExercises: [Exercise] = []
    @State private var recentlyUsedExercises: [Exercise] = []

    // Filtering and Sorting
    @State private var filterState = ExerciseFilterState()
    @State private var showingFilterSheet = false

    // View Customization
    @AppStorage("exerciseLibraryViewMode") private var viewMode: String = "grid"
    @AppStorage("exercisesPerSection") private var exercisesPerSection: Int = 6

    private var isGridView: Bool {
        viewMode == "grid"
    }

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

    // Available skills from all exercises
    var availableSkills: [String] {
        let allSkills = allExercises.compactMap { $0.targetSkills }.flatMap { $0 }
        return Array(Set(allSkills)).sorted()
    }

    // Apply filters to exercises
    var filteredExercises: [Exercise] {
        var exercises = allExercises

        // Filter by difficulty
        if !filterState.selectedDifficulties.isEmpty {
            exercises = exercises.filter { exercise in
                let difficultyValues = filterState.selectedDifficulties.map { $0.difficultyValue }
                return difficultyValues.contains(Int(exercise.difficulty))
            }
        }

        // Filter by type
        switch filterState.selectedType {
        case .all:
            break
        case .youtube:
            exercises = exercises.filter { $0.exerciseDescription?.contains("YouTube Video") == true }
        case .aiGenerated:
            exercises = exercises.filter { $0.exerciseDescription?.contains("AI-Generated Custom Drill") == true }
        case .manual:
            exercises = exercises.filter { exercise in
                exercise.exerciseDescription?.contains("YouTube Video") != true &&
                exercise.exerciseDescription?.contains("AI-Generated Custom Drill") != true &&
                exercise.exerciseDescription?.contains("Manual Custom Drill") == true
            }
        case .template:
            exercises = exercises.filter { exercise in
                exercise.exerciseDescription?.contains("YouTube Video") != true &&
                exercise.exerciseDescription?.contains("AI-Generated Custom Drill") != true &&
                exercise.exerciseDescription?.contains("Manual Custom Drill") != true
            }
        }

        // Filter by skills
        if !filterState.selectedSkills.isEmpty {
            exercises = exercises.filter { exercise in
                guard let skills = exercise.targetSkills else { return false }
                return !filterState.selectedSkills.isDisjoint(with: Set(skills))
            }
        }

        // Filter favorites only
        if filterState.favoritesOnly {
            exercises = exercises.filter { $0.isFavorite }
        }

        // Apply sort
        exercises = sortExercises(exercises)

        return exercises
    }

    // Sort exercises based on selected option
    private func sortExercises(_ exercises: [Exercise]) -> [Exercise] {
        switch filterState.sortOption {
        case .nameAZ:
            return exercises.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .nameZA:
            return exercises.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case .difficultyLowHigh:
            return exercises.sorted { $0.difficulty < $1.difficulty }
        case .difficultyHighLow:
            return exercises.sorted { $0.difficulty > $1.difficulty }
        case .newestFirst:
            return exercises.sorted { ($0.id?.uuidString ?? "") > ($1.id?.uuidString ?? "") }
        case .oldestFirst:
            return exercises.sorted { ($0.id?.uuidString ?? "") < ($1.id?.uuidString ?? "") }
        case .mostUsed:
            return exercises.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                AdaptiveBackground()
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

                            // Show filtered results when filters active
                            if filterState.hasActiveFilters {
                                filteredResultsSection
                            } else {
                                // Favorites Section
                                if !favoriteExercises.isEmpty {
                                    favoritesSection
                                }

                                // Recently Used Section
                                if !recentlyUsedExercises.isEmpty {
                                    recentlyUsedSection
                                }

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
                    ExerciseDetailView(
                        exercise: exercise,
                        onFavoriteChanged: {
                            loadExercises()
                        },
                        onExerciseDeleted: {
                            loadExercises()
                        }
                    )
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
            .sheet(isPresented: $showingFilterSheet) {
                ExerciseFilterView(
                    filterState: $filterState,
                    availableSkills: availableSkills,
                    onApply: { }
                )
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
            VStack(alignment: .leading, spacing: 2) {
                Text("Exercise Library")
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("\(allExercises.count) exercises available")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                // View Toggle Button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = isGridView ? "list" : "grid"
                    }
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                // Filter Button
                Button {
                    showingFilterSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundColor(filterState.hasActiveFilters ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)

                        if filterState.activeFilterCount > 0 {
                            Text("\(filterState.activeFilterCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Circle().fill(DesignSystem.Colors.primaryGreen))
                                .offset(x: 6, y: -6)
                        }
                    }
                }
            }
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
        HStack(spacing: DesignSystem.Spacing.sm) {
            // AI Drill
            CompactActionButton(
                title: "AI",
                icon: "brain.head.profile",
                color: DesignSystem.Colors.primaryGreen
            ) {
                showingCustomDrillGenerator = true
            }

            // Manual Drill
            CompactActionButton(
                title: "Manual",
                icon: "pencil.circle.fill",
                color: DesignSystem.Colors.secondaryBlue
            ) {
                showingManualDrillCreator = true
            }

            // YouTube
            CompactActionButton(
                title: "YouTube",
                icon: "play.rectangle.fill",
                color: DesignSystem.Colors.error
            ) {
                loadYouTubeContent()
            }
            .disabled(isLoadingYouTubeContent)
        }
    }

    // MARK: - Recommended Section

    // MARK: - Favorites Section

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("❤️ Favorites")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(favoriteExercises.count) exercise\(favoriteExercises.count == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(favoriteExercises, id: \.objectID) { exercise in
                        FavoriteExerciseCard(exercise: exercise, onFavoriteToggle: {
                            toggleFavorite(exercise)
                        })
                        .onTapGesture {
                            selectedExercise = exercise
                            showingExerciseDetail = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recently Used Section

    private var recentlyUsedSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("🕐 Recently Used")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("Your last \(recentlyUsedExercises.count) exercises")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(recentlyUsedExercises, id: \.objectID) { exercise in
                        SimpleExerciseCard(exercise: exercise, isFavorite: exercise.isFavorite, onFavoriteToggle: {
                            toggleFavorite(exercise)
                        })
                        .onTapGesture {
                            selectedExercise = exercise
                            showingExerciseDetail = true
                        }
                    }
                }
            }
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

    /// Toggle favorite status for an exercise
    private func toggleFavorite(_ exercise: Exercise) {
        CoreDataManager.shared.toggleFavorite(exercise: exercise)
        loadExercises() // Refresh to update UI
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

            // Grid or List view based on preference
            if isGridView {
                // Horizontal scroll (Grid mode)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(exercises, id: \.objectID) { exercise in
                            SimpleExerciseCard(
                                exercise: exercise,
                                isFavorite: exercise.isFavorite,
                                onFavoriteToggle: {
                                    toggleFavorite(exercise)
                                }
                            )
                            .onTapGesture {
                                selectedExercise = exercise
                                showingExerciseDetail = true
                            }
                        }
                    }
                }
            } else {
                // Vertical list (List mode)
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(exercises, id: \.objectID) { exercise in
                        ListExerciseCard(
                            exercise: exercise,
                            onFavoriteToggle: {
                                toggleFavorite(exercise)
                            }
                        )
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

    // MARK: - Filtered Results Section

    private var filteredResultsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with filter summary and clear button
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Filtered Results")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text("\(filteredExercises.count) exercise\(filteredExercises.count == 1 ? "" : "s") found")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        filterState.reset()
                    }
                } label: {
                    Text("Clear")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }

            // Active filter chips
            activeFilterChips

            // Results grid
            if filteredExercises.isEmpty {
                noFilterResultsView
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                        GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                    ],
                    spacing: DesignSystem.Spacing.md
                ) {
                    ForEach(filteredExercises, id: \.objectID) { exercise in
                        SimpleExerciseCard(
                            exercise: exercise,
                            isFavorite: exercise.isFavorite,
                            onFavoriteToggle: {
                                toggleFavorite(exercise)
                            }
                        )
                        .onTapGesture {
                            selectedExercise = exercise
                            showingExerciseDetail = true
                        }
                    }
                }
            }
        }
    }

    private var activeFilterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Difficulty chips
                ForEach(filterState.selectedDifficulties.sorted { $0.rawValue < $1.rawValue }, id: \.rawValue) { difficulty in
                    FilterChip(
                        text: difficulty.rawValue,
                        color: difficultyColor(difficulty)
                    ) {
                        withAnimation {
                            _ = filterState.selectedDifficulties.remove(difficulty)
                        }
                    }
                }

                // Type chip
                if filterState.selectedType != .all {
                    FilterChip(
                        text: filterState.selectedType.rawValue,
                        color: DesignSystem.Colors.secondaryBlue
                    ) {
                        withAnimation {
                            filterState.selectedType = .all
                        }
                    }
                }

                // Skill chips
                ForEach(filterState.selectedSkills.sorted(), id: \.self) { skill in
                    FilterChip(
                        text: skill,
                        color: DesignSystem.Colors.accentOrange
                    ) {
                        withAnimation {
                            _ = filterState.selectedSkills.remove(skill)
                        }
                    }
                }

                // Favorites chip
                if filterState.favoritesOnly {
                    FilterChip(
                        text: "Favorites",
                        color: .red
                    ) {
                        withAnimation {
                            filterState.favoritesOnly = false
                        }
                    }
                }
            }
        }
    }

    private func difficultyColor(_ difficulty: ExerciseDifficulty) -> Color {
        switch difficulty {
        case .beginner: return DesignSystem.Colors.primaryGreen
        case .intermediate: return DesignSystem.Colors.accentOrange
        case .advanced: return .red
        }
    }

    private var noFilterResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

            Text("No exercises match your filters")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Try adjusting your filter criteria")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Button {
                withAnimation {
                    filterState.reset()
                }
            } label: {
                Text("Clear All Filters")
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.primaryGreen)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            }
            .padding(.top, DesignSystem.Spacing.md)

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
        favoriteExercises = CoreDataManager.shared.fetchFavoriteExercises(for: player)
        recentlyUsedExercises = CoreDataManager.shared.fetchRecentlyUsedExercises(for: player, limit: 5)
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
            #if DEBUG
            print("Error loading YouTube content: \(error)")
            #endif
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
    var isFavorite: Bool = false
    var onFavoriteToggle: (() -> Void)? = nil

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
        .overlay(alignment: .topTrailing) {
            if onFavoriteToggle != nil {
                Button {
                    onFavoriteToggle?()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(6)
                        .background(Color.black.opacity(0.4))
                        .clipShape(Circle())
                }
                .padding(8)
            }
        }
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

// MARK: - Favorite Exercise Card

struct FavoriteExerciseCard: View {
    let exercise: Exercise
    let onFavoriteToggle: () -> Void

    private var isAIGenerated: Bool {
        exercise.exerciseDescription?.contains("🤖 AI-Generated Custom Drill") == true
    }

    private var isYouTube: Bool {
        exercise.exerciseDescription?.contains("🎥 YouTube Video") == true
    }

    var body: some View {
        ModernCard(padding: 0) {
            VStack(spacing: 0) {
                // Top Image/Icon Area with prominent favorite
                ZStack(alignment: .topTrailing) {
                    if isYouTube, let videoId = extractVideoId() {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/medium.jpg")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.red.opacity(0.3))
                        }
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Image(systemName: categoryIcon)
                                    .font(.system(size: 30))
                                    .foregroundColor(categoryColor)
                            )
                    }

                    // Favorite Button
                    Button {
                        onFavoriteToggle()
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .padding(8)
                }
                .frame(height: 100)
                .clipped()

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

    private func extractVideoId() -> String? {
        guard let description = exercise.exerciseDescription,
              let videoIdRange = description.range(of: "Video ID: ") else { return nil }
        let remaining = description[videoIdRange.upperBound...]
        if let endRange = remaining.range(of: "\n") {
            return String(remaining[..<endRange.lowerBound])
        }
        return String(remaining)
    }

    private var categoryIcon: String {
        switch exercise.category?.lowercased() {
        case "technical": return "figure.soccer"
        case "physical": return "figure.strengthtraining.traditional"
        case "tactical": return "brain.head.profile"
        default: return "figure.run"
        }
    }

    private var categoryColor: Color {
        switch exercise.category?.lowercased() {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.accentOrange
        case "tactical": return DesignSystem.Colors.secondaryBlue
        default: return DesignSystem.Colors.primaryGreen
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

// MARK: - List Exercise Card (for list view mode)

struct ListExerciseCard: View {
    let exercise: Exercise
    let onFavoriteToggle: () -> Void

    private var isAIGenerated: Bool {
        exercise.exerciseDescription?.contains("AI-Generated Custom Drill") == true
    }

    private var isYouTube: Bool {
        exercise.exerciseDescription?.contains("YouTube Video") == true
    }

    var body: some View {
        ModernCard(padding: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Thumbnail/Icon
                ZStack {
                    if isYouTube, let videoId = extractVideoId() {
                        AsyncImage(url: URL(string: "https://img.youtube.com/vi/\(videoId)/default.jpg")) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.red.opacity(0.2))
                        }
                    } else {
                        Rectangle()
                            .fill(categoryColor.opacity(0.2))
                            .overlay(
                                Image(systemName: categoryIcon)
                                    .font(.title3)
                                    .foregroundColor(categoryColor)
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .cornerRadius(DesignSystem.CornerRadius.sm)
                .clipped()

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Type badge
                    HStack(spacing: 4) {
                        if isAIGenerated {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            Text("AI")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        } else if isYouTube {
                            Image(systemName: "play.rectangle.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text("YouTube")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text(exercise.category ?? "General")
                                .font(.caption2)
                                .foregroundColor(categoryColor)
                        }

                        Spacer()

                        SimpleDifficultyIndicator(level: Int(exercise.difficulty))
                    }

                    // Name
                    Text(exercise.name ?? "Unknown Exercise")
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

                    // Skills preview
                    if let skills = exercise.targetSkills, !skills.isEmpty {
                        Text(skills.prefix(3).joined(separator: " • "))
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .lineLimit(1)
                    }
                }

                // Favorite button
                Button {
                    onFavoriteToggle()
                } label: {
                    Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 18))
                        .foregroundColor(exercise.isFavorite ? .red : DesignSystem.Colors.textSecondary)
                }
            }
        }
    }

    private func extractVideoId() -> String? {
        guard let description = exercise.exerciseDescription,
              let videoIdRange = description.range(of: "Video ID: ") else { return nil }
        let remaining = description[videoIdRange.upperBound...]
        if let endRange = remaining.range(of: "\n") {
            return String(remaining[..<endRange.lowerBound])
        }
        return String(remaining)
    }

    private var categoryIcon: String {
        switch exercise.category?.lowercased() {
        case "technical": return "figure.soccer"
        case "physical": return "figure.strengthtraining.traditional"
        case "tactical": return "brain.head.profile"
        case "recovery": return "heart.circle"
        default: return "figure.run"
        }
    }

    private var categoryColor: Color {
        switch exercise.category?.lowercased() {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.accentOrange
        case "tactical": return DesignSystem.Colors.secondaryBlue
        case "recovery": return DesignSystem.Colors.accentYellow
        default: return DesignSystem.Colors.primaryGreen
        }
    }
}

// MARK: - Filter Chip (for showing active filters)

struct FilterChip: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(color)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(color.opacity(0.7))
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return ExerciseLibraryView(player: mockPlayer)
        .environment(\.managedObjectContext, context)
}
