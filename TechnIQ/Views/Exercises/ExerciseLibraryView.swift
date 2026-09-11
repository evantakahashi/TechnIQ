import SwiftUI
import CoreData

// MARK: - Train (Touchline 5a / 9e)
//
// One searchable list. Title row with the single grass action ("+ New drill" → AI / Manual /
// Video sheet), search field, a compact pitch strip summarising the coach's drills, a chip row
// (All · Saved · Technical · Physical · Tactical · Video, plus Filters), then flat rows with a
// TEC/PHY/TAC/AI/VID tile, name, meta and a heart. Empty library: the pitch card becomes the
// empty state and three rows offer the three creation routes.

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let player: Player

    @State private var allExercises: [Exercise] = []
    @State private var searchText = ""
    @State private var chip: LibraryChip = .all
    @State private var filterState = ExerciseFilterState()
    @State private var coachSuggestions: [SelectedWeakness] = []

    @State private var route: LibraryRoute?
    @State private var showingNewDrillMenu = false
    @State private var showingCustomDrillGenerator = false
    @State private var showingManualDrillCreator = false
    @State private var showingFilterSheet = false
    @State private var showingDrillPaywall = false
    @State private var showingYouTubePaywall = false
    @State private var isLoadingYouTubeContent = false
    @State private var youtubeError: String?

    enum LibraryChip: String, CaseIterable, Identifiable {
        case all = "All", saved = "Saved", technical = "Technical", physical = "Physical", tactical = "Tactical", video = "Video"
        var id: String { rawValue }
    }

    private enum LibraryRoute: Hashable {
        case drill(NSManagedObjectID)
        case coachDrills
    }

    // MARK: - Derived

    private var visibleExercises: [Exercise] {
        var exercises = allExercises

        switch chip {
        case .all: break
        case .saved: exercises = exercises.filter { $0.isFavorite }
        case .technical, .physical, .tactical:
            exercises = exercises.filter { $0.category?.caseInsensitiveCompare(chip.rawValue) == .orderedSame && !$0.isYouTubeExercise }
        case .video: exercises = exercises.filter { $0.isYouTubeExercise }
        }

        if !filterState.selectedDifficulties.isEmpty {
            let values = filterState.selectedDifficulties.map { $0.difficultyValue }
            exercises = exercises.filter { values.contains(Int($0.difficulty)) }
        }
        switch filterState.selectedType {
        case .all: break
        case .youtube: exercises = exercises.filter { $0.isYouTubeExercise }
        case .aiGenerated: exercises = exercises.filter { $0.isAIGenerated }
        case .manual: exercises = exercises.filter { !$0.isYouTubeExercise && !$0.isAIGenerated && $0.exerciseDescription?.contains("Manual Custom Drill") == true }
        case .template: exercises = exercises.filter { !$0.isYouTubeExercise && !$0.isAIGenerated && $0.exerciseDescription?.contains("Manual Custom Drill") != true }
        }
        if !filterState.selectedSkills.isEmpty {
            exercises = exercises.filter { exercise in
                guard let skills = exercise.targetSkills else { return false }
                return !filterState.selectedSkills.isDisjoint(with: Set(skills))
            }
        }
        if filterState.favoritesOnly { exercises = exercises.filter { $0.isFavorite } }

        let query = searchText.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            exercises = exercises.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(query)
                    || ($0.exerciseDescription ?? "").localizedCaseInsensitiveContains(query)
                    || ($0.targetSkills ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
        return sortExercises(exercises)
    }

    private var availableSkills: [String] {
        Array(Set(allExercises.compactMap { $0.targetSkills }.flatMap { $0 })).sorted()
    }

    private func sortExercises(_ exercises: [Exercise]) -> [Exercise] {
        switch filterState.sortOption {
        case .nameAZ: return exercises.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .nameZA: return exercises.sorted { ($0.name ?? "") > ($1.name ?? "") }
        case .difficultyLowHigh: return exercises.sorted { $0.difficulty < $1.difficulty }
        case .difficultyHighLow: return exercises.sorted { $0.difficulty > $1.difficulty }
        case .newestFirst: return exercises.sorted { ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast) }
        case .oldestFirst: return exercises.sorted { ($0.updatedAt ?? .distantPast) < ($1.updatedAt ?? .distantPast) }
        case .mostUsed: return exercises.sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQScreenTitle("Train") {
                    TQButton("+ New drill", size: .compact, fullWidth: false) { showingNewDrillMenu = true }
                }

                TQSearchField(
                    allExercises.isEmpty ? "Search drills" : "Search \(allExercises.count) drill\(allExercises.count == 1 ? "" : "s")",
                    text: $searchText
                )
                    .disabled(allExercises.isEmpty)

                if allExercises.isEmpty {
                    emptyLibrary
                } else {
                    coachStrip
                    chipRow
                    list
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .coachMark(.train)
        .navigationDestination(item: $route) { route in
            switch route {
            case .drill(let objectID):
                if let exercise = try? viewContext.existingObject(with: objectID) as? Exercise {
                    ExerciseDetailView(exercise: exercise, onFavoriteChanged: { loadExercises() }, onExerciseDeleted: { loadExercises() })
                }
            case .coachDrills:
                CoachDrillsView(player: player)
            }
        }
        .sheet(isPresented: $showingNewDrillMenu) {
            NewDrillSheet(
                onAI: { showingNewDrillMenu = false; openAIGenerator() },
                onManual: { showingNewDrillMenu = false; showingManualDrillCreator = true },
                onVideo: { showingNewDrillMenu = false; loadYouTubeContent() }
            )
            .presentationDetents([.height(300)])
            .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingCustomDrillGenerator, onDismiss: { loadExercises() }) {
            CustomDrillGeneratorView(player: player)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingManualDrillCreator, onDismiss: { loadExercises() }) {
            ManualDrillCreatorView(player: player)
                .environment(\.managedObjectContext, viewContext)
        }
        .sheet(isPresented: $showingDrillPaywall) { PaywallView(feature: .customDrill) }
        .sheet(isPresented: $showingYouTubePaywall) { PaywallView(feature: .youtubeRecs) }
        .sheet(isPresented: $showingFilterSheet) {
            ExerciseFilterView(filterState: $filterState, availableSkills: availableSkills, onApply: {})
        }
        .onAppear {
            loadExercises()
            loadCoachSuggestions()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-TQDrillPhase") { showingCustomDrillGenerator = true }
            // `-TQRoute drill` pushes the first drill with a diagram (else the first drill) for screenshots.
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "-TQRoute"), index + 1 < args.count, args[index + 1] == "drill",
               let target = allExercises.first(where: { $0.diagramJSON != nil }) ?? allExercises.first {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { route = .drill(target.objectID) }
            }
            #endif
        }
    }

    // MARK: - Coach strip

    @ViewBuilder
    private var coachStrip: some View {
        if let first = coachSuggestions.first {
            Button {
                HapticManager.shared.lightTap()
                route = .coachDrills
            } label: {
                TQPitchCard(.strip, markings: .strip) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            TQEyebrow("From your coach · \(coachSuggestions.count) new", size: 11)
                            TQDisplayTitle("\(first.category) block", size: .strip)
                            Text("\(coachSuggestions.count) drill\(coachSuggestions.count == 1 ? "" : "s") · \(coachSuggestions.count * 15) min · targets your weakest skill")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textOnPitch)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        TQChevron(color: DesignSystem.Colors.textOnPitch)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Opens drills from the coach")
        }
    }

    // MARK: - Chips

    private var chipRow: some View {
        TQChipRow {
            ForEach(LibraryChip.allCases) { option in
                TQChip(option.rawValue, isSelected: chip == option) {
                    withAnimation(DesignSystem.Animation.quick) { chip = option }
                }
            }
            TQChip(
                filterState.hasActiveFilters ? "Filters · \(filterState.activeFilterCount)" : "Filters",
                isSelected: filterState.hasActiveFilters,
                icon: "slider.horizontal.3"
            ) {
                showingFilterSheet = true
            }
        }
    }

    // MARK: - List

    @ViewBuilder
    private var list: some View {
        let exercises = visibleExercises
        if exercises.isEmpty {
            TQRowList {
                TQRow(searchText.isEmpty ? "Nothing here yet" : "No drills match \"\(searchText)\"",
                      note: searchText.isEmpty ? "try another chip" : "clear the search")
                    .disabled(true)
            }
        } else {
            TQRowList {
                ForEach(exercises, id: \.objectID) { exercise in
                    TQRow(
                        exercise.name ?? "Drill",
                        subtitle: meta(for: exercise),
                        leading: .tile(TQTile.category(exercise.category, isAI: exercise.isAIGenerated, isVideo: exercise.isYouTubeExercise)),
                        accessory: .heart(isOn: exercise.isFavorite, action: { toggleFavorite(exercise) }),
                        verticalPadding: DesignSystem.Spacing.rowVertical,
                        action: { route = .drill(exercise.objectID) }
                    )
                }
            }
        }
    }

    private func meta(for exercise: Exercise) -> String {
        if exercise.isYouTubeExercise {
            let minutes = max(1, Int(exercise.videoDuration) / 60)
            return "Video · \(minutes) min"
        }
        var parts: [String] = [exercise.category ?? "Drill"]
        if exercise.difficulty > 0 { parts.append("Lvl \(exercise.difficulty)") }
        if exercise.estimatedDurationSeconds > 0 { parts.append("\(max(1, Int(exercise.estimatedDurationSeconds) / 60)) min") }
        if exercise.isAIGenerated { parts.append("from your coach") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Empty library (9e)

    private var emptyLibrary: some View {
        VStack(spacing: DesignSystem.Spacing.section) {
            TQHeroCard(
                eyebrow: "Your library is empty",
                title: "Describe what you want to fix",
                body: "\"Weak foot passing\", \"first touch under pressure\" — the coach turns it into a drill with a diagram in about 20 seconds.",
                actionTitle: "Generate a drill",
                actionIcon: nil,
                markings: .heroSimple,
                action: { openAIGenerator() }
            )
            TQRowList {
                TQRow("Browse the template library",
                      subtitle: "\(TemplateExerciseLibrary.shared.allExercises.count) drills · all positions",
                      leading: .tile(TQTile("\(TemplateExerciseLibrary.shared.allExercises.count)")),
                      action: { importTemplates() })
                TQRow("Pull in video drills", subtitle: "YouTube · Pro", leading: .tile(TQTile("VID")), action: { loadYouTubeContent() })
                TQRow("Write one yourself", subtitle: "Manual drill", leading: .tile(TQTile(symbol: "plus")), action: { showingManualDrillCreator = true })
            }
        }
    }

    // MARK: - Actions

    private func openAIGenerator() {
        if subscriptionManager.canUseQuickDrill() {
            showingCustomDrillGenerator = true
        } else {
            showingDrillPaywall = true
        }
    }

    private func toggleFavorite(_ exercise: Exercise) {
        CoreDataManager.shared.toggleFavorite(exercise: exercise)
        loadExercises()
    }

    /// Copies the template library into the player's drills so there is something to train with.
    private func importTemplates() {
        let existing = Set(allExercises.compactMap { $0.name })
        for template in TemplateExerciseLibrary.shared.allExercises where !existing.contains(template.name) {
            let exercise = Exercise(context: viewContext)
            exercise.id = UUID()
            exercise.name = template.name
            exercise.category = template.category
            exercise.exerciseDescription = template.description
            exercise.difficulty = Int16(ExerciseDifficulty(rawValue: template.difficulty)?.difficultyValue ?? 2)
            exercise.estimatedDurationSeconds = 15 * 60
            exercise.updatedAt = Date()
            exercise.player = player
        }
        CoreDataManager.shared.save()
        HapticManager.shared.success()
        loadExercises()
    }

    // MARK: - Data

    private func loadExercises() {
        allExercises = CoreDataManager.shared.fetchExercises(for: player)
        #if DEBUG
        // `-TQTrainState empty` previews the first-run library (design 15-train-empty).
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-TQTrainState"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           ProcessInfo.processInfo.arguments[index + 1] == "empty" {
            allExercises = []
        }
        #endif
    }

    private func loadCoachSuggestions() {
        let profile = WeaknessAnalysisService.shared.getCachedProfile(for: player)
            ?? WeaknessAnalysisService.shared.analyzeWeaknesses(for: player)
        coachSuggestions = Array(profile.suggestedWeaknesses.prefix(3))
    }

    private func loadYouTubeContent() {
        guard subscriptionManager.isPro else { showingYouTubePaywall = true; return }
        guard !isLoadingYouTubeContent else { return }
        isLoadingYouTubeContent = true
        Task { await performYouTubeLoading() }
    }

    private func performYouTubeLoading() async {
        do {
            do {
                let youtubeRecommendations = try await AIRecommendationService.shared.getYouTubeRecommendations(for: player, limit: 3)
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
                try await YouTubeService.shared.loadYouTubeDrillsFromAPI(for: player, category: nil, maxResults: 3, progressCallback: { _, _ in })
            }
        } catch {
            await MainActor.run { youtubeError = error.localizedDescription }
        }
        await MainActor.run {
            loadExercises()
            isLoadingYouTubeContent = false
        }
    }
}

// MARK: - New drill sheet (AI / Manual / Video)

struct NewDrillSheet: View {
    let onAI: () -> Void
    let onManual: () -> Void
    let onVideo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQGroupHeader("New drill")
                .padding(.top, 4)
            TQRowList {
                TQRow(
                    "Generate with the coach",
                    subtitle: "Describe what to fix · 20 s",
                    leading: .tile(TQTile("AI", style: .ai)),
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: onAI
                )
                TQRow(
                    "Write one yourself",
                    subtitle: "Manual drill",
                    leading: .tile(TQTile(symbol: "plus")),
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: onManual
                )
                TQRow(
                    "Pull in video drills",
                    subtitle: "YouTube · Pro",
                    leading: .tile(TQTile("VID")),
                    verticalPadding: DesignSystem.Spacing.rowVertical,
                    action: onVideo
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.top, DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

// MARK: - Exercise helpers (shared across screens)

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
        case "technical": return DesignSystem.Icons.technical
        case "physical": return DesignSystem.Icons.physical
        case "tactical": return DesignSystem.Icons.tactical
        case "recovery": return "heart.circle"
        default: return "figure.soccer"
        }
    }

    var categoryColor: Color {
        DesignSystem.Colors.grass
    }
}

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return NavigationStack {
        ExerciseLibraryView(player: mockPlayer)
            .environment(\.managedObjectContext, context)
            .environmentObject(SubscriptionManager.shared)
    }
}
