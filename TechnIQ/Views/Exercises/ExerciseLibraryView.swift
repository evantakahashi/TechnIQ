import SwiftUI
import CoreData

// MARK: - Train (Touchline 5a / 9e)
//
// Title row with the single grass action ("+ New drill" → AI / Manual / Video sheet), search field,
// a compact pitch strip summarising the coach's drills, then the library grouped by skill:
// "My drills" first (generated, written, saved, video), one section per skill with at least two
// drills or a pin (top three by last use + "See all"), and the long tail as "More skills" chips.
// Typing in the search field flattens everything into one matched list. Empty library: the pitch
// card becomes the empty state and three rows offer the three creation routes.

struct ExerciseLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    let player: Player

    @State private var allExercises: [Exercise] = []
    @State private var layout = TrainLibraryLayout(sections: [], more: [])
    @State private var exercisesByID: [UUID: Exercise] = [:]
    @State private var searchText = ""
    @State private var coachSuggestions: [SelectedWeakness] = []

    @State private var route: LibraryRoute?
    @State private var showingNewDrillMenu = false
    @State private var showingCustomDrillGenerator = false
    @State private var showingManualDrillCreator = false
    @State private var showingDrillPaywall = false
    @State private var showingYouTubePaywall = false
    @State private var isLoadingYouTubeContent = false
    @State private var youtubeError: String?

    private enum LibraryRoute: Hashable {
        case drill(NSManagedObjectID)
        case coachDrills
        case section(TrainLibraryLayout.Section.Kind)
    }

    // MARK: - Derived

    /// Search results across the whole library (sections are replaced while a query is active).
    private var searchResults: [Exercise] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return allExercises.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(query)
                || ($0.exerciseDescription ?? "").localizedCaseInsensitiveContains(query)
                || ($0.targetSkills ?? []).contains { $0.localizedCaseInsensitiveContains(query) }
                || (TrainSkillMapper.skill(for: $0.trainDrill)?.displayName.localizedCaseInsensitiveContains(query) ?? false)
        }
        .sorted { ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "") == .orderedAscending }
    }

    private var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespaces).isEmpty }

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
                } else if isSearching {
                    searchList
                } else {
                    coachStrip
                    sections
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
            case .section(let kind):
                TrainSkillListView(player: player, kind: kind, exercises: allExercises, onChange: { loadExercises() })
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
            // `-TQRoute skill` pushes the Passing "See all" list for screenshots.
            if let index = args.firstIndex(of: "-TQRoute"), index + 1 < args.count, args[index + 1] == "skill" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { route = .section(.skill(.passing)) }
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

    // MARK: - Sections

    private var sections: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
            ForEach(layout.sections) { section in
                VStack(alignment: .leading, spacing: 0) {
                    TQSectionHeader("\(section.title) · \(section.count)") {
                        HStack(spacing: 12) {
                            if section.isPinned { TQEyebrow("Pinned", size: 11) }
                            TQTextLink("See all", arrow: false) { route = .section(section.kind) }
                                .accessibilityLabel("See all \(section.title)")
                                .accessibilityIdentifier("seeAll.\(section.title)")
                        }
                    }
                    TQRowList {
                        ForEach(section.preview) { drill in
                            drillRow(drill, showSkill: section.kind.skill == nil)
                        }
                    }
                }
            }

            if !layout.more.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    TQGroupHeader("More skills")
                    TQChipRow {
                        ForEach(layout.more) { group in
                            TQChip("\(group.title) · \(group.count)") { route = .section(group.kind) }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchList: some View {
        let results = searchResults
        if results.isEmpty {
            TQRowList {
                TQRow("No drills match \"\(searchText)\"", note: "clear the search").disabled(true)
            }
        } else {
            TQRowList {
                ForEach(results, id: \.objectID) { exercise in
                    drillRow(exercise.trainDrill, showSkill: true, exercise: exercise)
                }
            }
        }
    }

    private func drillRow(_ drill: TrainDrill, showSkill: Bool, exercise: Exercise? = nil) -> some View {
        let exercise = exercise ?? exercisesByID[drill.id]
        return TQRow(
            drill.name,
            subtitle: TrainLibraryModel.meta(for: drill, showSkill: showSkill),
            leading: .tile(TQTile.category(drill.category, isAI: drill.source == .ai, isVideo: drill.source == .video)),
            accessory: .heart(isOn: drill.isFavorite, action: { if let exercise { toggleFavorite(exercise) } }),
            verticalPadding: DesignSystem.Spacing.rowVertical,
            action: { if let exercise { route = .drill(exercise.objectID) } }
        )
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
            exercise.difficulty = Int16(Self.difficultyValue(for: template.difficulty))
            exercise.estimatedDurationSeconds = 15 * 60
            exercise.updatedAt = Date()
            exercise.player = player
        }
        CoreDataManager.shared.save()
        HapticManager.shared.success()
        loadExercises()
    }

    private static func difficultyValue(for label: String) -> Int {
        switch label.lowercased() {
        case "beginner": return 1
        case "advanced": return 3
        default: return 2
        }
    }

    // MARK: - Data

    private func loadExercises() {
        allExercises = CoreDataManager.shared.fetchExercises(for: player)
        rebuildLayout()
        #if DEBUG
        // `-TQTrainState empty` previews the first-run library (design 15-train-empty).
        if let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-TQTrainState"),
           index + 1 < ProcessInfo.processInfo.arguments.count,
           ProcessInfo.processInfo.arguments[index + 1] == "empty" {
            allExercises = []
            rebuildLayout()
        }
        #endif
    }

    private func rebuildLayout() {
        var byID: [UUID: Exercise] = [:]
        let drills = allExercises.map { exercise -> TrainDrill in
            let drill = exercise.trainDrill
            byID[drill.id] = exercise
            return drill
        }
        exercisesByID = byID
        let weakSpots = (player.playerProfile?.selfIdentifiedWeaknesses ?? []).compactMap { TrainSkillMapper.skill(matching: $0) }
        layout = TrainLibraryModel.build(drills: drills, pinned: player.pinnedSkillList, weakSpots: weakSpots)
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

    var isManualDrill: Bool {
        exerciseDescription?.contains("Manual Custom Drill") == true
    }

    /// Value copy for the Train layout rules. The id falls back to the object URI hash when a legacy
    /// row has no UUID, so lookups from the layout back to the row stay stable within one build.
    var trainDrill: TrainDrill {
        let source: TrainDrill.Source = isYouTubeExercise ? .video
            : isAIGenerated ? .ai
            : isCommunityDrill ? .community
            : isManualDrill ? .manual
            : .template
        let minutes = isYouTubeExercise ? max(1, Int(videoDuration) / 60) : (estimatedDurationSeconds > 0 ? max(1, Int(estimatedDurationSeconds) / 60) : 0)
        return TrainDrill(
            id: id ?? UUID(uuidString: String(format: "%08X-0000-4000-8000-%012X", objectID.uriRepresentation().absoluteString.hashValue & 0xFFFFFFFF, abs(objectID.uriRepresentation().absoluteString.hashValue) & 0xFFFFFFFFFFFF)) ?? UUID(),
            name: name ?? "Drill",
            category: category,
            difficulty: Int(difficulty),
            minutes: minutes,
            targetSkills: targetSkills ?? [],
            weaknessCategories: weaknessCategories,
            source: source,
            isFavorite: isFavorite,
            lastUsedAt: lastUsedAt,
            usageCount: sessionExercises?.count ?? 0
        )
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
