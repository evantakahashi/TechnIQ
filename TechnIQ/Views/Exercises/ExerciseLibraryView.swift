import SwiftUI
import CoreData
import Foundation

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    let player: Player

    @State private var allExercises: [Exercise] = []
    @State private var recommendations: [YouTubeService.DrillRecommendation] = []
    @State private var searchText = ""
    @State private var selectedExercise: Exercise?
    @State private var showingExerciseDetail = false
    @State private var isLoadingYouTubeContent = false
    @State private var showingCustomDrillGenerator = false
    @State private var showingManualDrillCreator = false
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showingDrillPaywall = false
    @State private var showingYouTubePaywall = false

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
            .filter { $0.isAIGenerated }
            .sorted { ($0.id?.uuidString ?? "") > ($1.id?.uuidString ?? "") }
    }

    var youtubeExercises: [Exercise] {
        allExercises.filter { $0.isYouTubeExercise }
    }

    private func standardExercises(category: String) -> [Exercise] {
        allExercises.filter {
            $0.category?.lowercased() == category && !$0.isYouTubeExercise && !$0.isAIGenerated
        }
    }

    var physicalExercises: [Exercise] { standardExercises(category: "physical") }
    var technicalExercises: [Exercise] { standardExercises(category: "technical") }
    var tacticalExercises: [Exercise] { standardExercises(category: "tactical") }

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
            exercises = exercises.filter { $0.isAIGenerated }
        case .manual:
            exercises = exercises.filter { !$0.isYouTubeExercise && !$0.isAIGenerated && $0.exerciseDescription?.contains("Manual Custom Drill") == true }
        case .template:
            exercises = exercises.filter { !$0.isYouTubeExercise && !$0.isAIGenerated && $0.exerciseDescription?.contains("Manual Custom Drill") != true }
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
        ZStack {
                AdaptiveBackground()
                    .ignoresSafeArea()

                if searchText.isEmpty {
                    // Main content with sections
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: DesignSystem.Spacing.xl) {
                            // Hero AI Drill Card
                            heroAIDrillCard

                            // Filter toolbar (exercise count + view toggle + filter)
                            filterToolbar

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
        }
        .onChange(of: showingCustomDrillGenerator) { _, isShowing in
            if !isShowing {
                loadExercises()
            }
        }
        .sheet(isPresented: $showingManualDrillCreator) {
            ManualDrillCreatorView(player: player)
                .environment(\.managedObjectContext, viewContext)
        }
        .onChange(of: showingManualDrillCreator) { _, isShowing in
            if !isShowing {
                loadExercises()
            }
        }
        .sheet(isPresented: $showingDrillPaywall) {
            PaywallView(feature: .customDrill)
        }
        .sheet(isPresented: $showingYouTubePaywall) {
            PaywallView(feature: .youtubeRecs)
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

    // MARK: - View Components

    private var filterToolbar: some View {
        HStack {
            Text("\(allExercises.count) exercises")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewMode = isGridView ? "list" : "grid"
                    }
                } label: {
                    Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                        .font(.title3)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

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

    private var heroAIDrillCard: some View {
        ModernCard(
            accentEdge: .leading,
            accentColor: DesignSystem.Colors.primaryGreen
        ) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Text("Create AI Drill")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                Text("Get a personalized drill tailored to your weaknesses")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                ModernButton("Generate Drill", icon: "arrow.right.circle.fill", style: .primary) {
                    if subscriptionManager.canUseCustomDrill() {
                        showingCustomDrillGenerator = true
                    } else {
                        showingDrillPaywall = true
                    }
                }
            }
        }
        .background(
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.15),
                    DesignSystem.Colors.primaryGreen.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(DesignSystem.CornerRadius.card)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // AI Drill
            CompactActionButton(
                title: "AI",
                icon: "brain.head.profile",
                color: DesignSystem.Colors.primaryGreen
            ) {
                if subscriptionManager.canUseCustomDrill() {
                    showingCustomDrillGenerator = true
                } else {
                    showingDrillPaywall = true
                }
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
                if subscriptionManager.isPro {
                    loadYouTubeContent()
                } else {
                    showingYouTubePaywall = true
                }
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
        #if DEBUG
        let aiCount = allExercises.filter { $0.isAIGenerated }.count
        print("📋 loadExercises: \(allExercises.count) total, \(aiCount) AI-generated")
        for ex in allExercises where ex.isAIGenerated {
            print("  ✅ AI: \(ex.name ?? "nil") | desc prefix: \(String(ex.exerciseDescription?.prefix(50) ?? "nil"))")
        }
        #endif
    }

    private func loadRecommendations() {
        recommendations = YouTubeService.shared.getSmartRecommendations(for: player, limit: 3)
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
            // Try LLM-powered AIRecommendationService first
            do {
                let youtubeRecommendations = try await AIRecommendationService.shared.getYouTubeRecommendations(
                    for: player,
                    limit: 3
                )

                // Convert YouTube recommendations to exercises
                await MainActor.run {
                    for recommendation in youtubeRecommendations {
                        _ = YouTubeService.shared.createExerciseFromYouTubeVideo(
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
                try await YouTubeService.shared.loadYouTubeDrillsFromAPI(
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

// MARK: - Exercise Helpers (shared across card types)

extension Exercise {
    var isAIGenerated: Bool {
        exerciseDescription?.contains("AI-Generated Custom Drill") == true
    }

    var isCommunityDrill: Bool {
        communityDrillID != nil
    }

    var isYouTubeExercise: Bool {
        exerciseDescription?.contains("YouTube Video") == true
    }

    var videoId: String? {
        guard let description = exerciseDescription,
              let videoIdRange = description.range(of: "Video ID: ") else { return nil }
        let remaining = description[videoIdRange.upperBound...]
        if let endRange = remaining.range(of: "\n") {
            return String(remaining[..<endRange.lowerBound])
        }
        return String(remaining)
    }

    var categoryIcon: String {
        switch category?.lowercased() {
        case "technical": return "soccerball"
        case "physical": return "figure.run"
        case "tactical": return "brain.head.profile"
        case "recovery": return "heart.circle"
        default: return "figure.soccer"
        }
    }

    var categoryColor: Color {
        switch category?.lowercased() {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "physical": return DesignSystem.Colors.accentOrange
        case "tactical": return DesignSystem.Colors.secondaryBlue
        case "recovery": return DesignSystem.Colors.accentYellow
        default: return DesignSystem.Colors.primaryGreen
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
