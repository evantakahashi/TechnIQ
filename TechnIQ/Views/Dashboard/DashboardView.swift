import SwiftUI
import CoreData
import Foundation
import Combine

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var recentSessions: FetchedResults<TrainingSession>
    @FetchRequest var recentMatches: FetchedResults<Match>
    @Binding var selectedTab: Int

    init(selectedTab: Binding<Int>) {
        self._selectedTab = selectedTab
        // Initialize with predicates that will be updated in onAppear
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true), // Allow all results initially
            animation: .default
        )

        self._recentSessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: true), // Allow all results initially
            animation: .default
        )

        self._recentMatches = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Match.date, ascending: false)],
            predicate: NSPredicate(value: true), // Allow all results initially
            animation: .default
        )
    }
    
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @State private var showingQuickDrillPaywall = false
    @State private var showingNewSession = false
    @State private var showingProfileCreation = false
    @State private var showingMatchLog = false
    @State private var isOnboardingComplete = false
    @State private var smartRecommendations: [YouTubeService.DrillRecommendation] = []
    @State private var mlRecommendations: [MLDrillRecommendation] = []
    @ObservedObject private var cloudMLService = AIRecommendationService.shared
    @ObservedObject private var aiCoachService = AICoachService.shared

    // Welcome back detection
    @State private var showWelcomeBack = false
    @State private var daysInactive: Int = 0
    @AppStorage("lastAppOpenDate") private var lastAppOpenDate: Double = Date().timeIntervalSince1970

    // Quick start flow
    @State private var activePlan: TrainingPlanModel?
    @State private var currentWeekDay: (week: Int, day: Int)?
    @State private var showingQuickDrill = false
    @State private var quickDrillWeakness: SelectedWeakness? = nil
    @State private var showingActiveTraining = false
    @State private var quickStartExercises: [Exercise] = []
    @State private var aiDrillExercise: Exercise?
    @State private var showingAIDrill = false
    
    var currentPlayer: Player? {
        players.first
    }
    
    var body: some View {
        ZStack {
            // Adaptive background (gradient light, solid dark)
            AdaptiveBackground()
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xl) {
                    if let player = currentPlayer {
                        modernHeaderSection(player: player)
                        aiDrillHeroBanner()
                        modernStatsOverview(player: player)
                        todaysFocusSection(player: player)
                        SmartDrillRecommendationsView(player: player) { weakness in
                            quickDrillWeakness = weakness
                            showingQuickDrill = true
                        }
                        continuePlanCard(player: player)
                            .coachMark(.dashboard)
                        modernQuickActions(player: player)
                        modernRecentActivity
                        modernMatchesSection(player: player)
                        modernRecommendations(player: player)
                    } else {
                        emptyStateView
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)
            }
        }
        .sheet(isPresented: $showingQuickDrillPaywall) {
            PaywallView(feature: .quickDrill)
        }
        .sheet(isPresented: $showingNewSession) {
            if let player = currentPlayer {
                NewSessionView(player: player)
            }
        }
        .sheet(isPresented: $showingMatchLog) {
            if let player = currentPlayer {
                MatchLogView(player: player, preselectedSeason: nil) {
                    // Refresh data after logging
                }
            }
        }
        .sheet(isPresented: $showingProfileCreation) {
            UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
        .sheet(isPresented: $showingQuickDrill) {
            if let player = currentPlayer {
                QuickDrillSheet(player: player, onGenerated: { exercise in
                    showingQuickDrill = false
                    quickDrillWeakness = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        quickStartExercises = [exercise]
                        showingActiveTraining = true
                    }
                }, prefilledWeakness: quickDrillWeakness)
            }
        }
        .fullScreenCover(isPresented: $showingActiveTraining) {
            ActiveTrainingView(exercises: quickStartExercises)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
        }
        .onChange(of: isOnboardingComplete) { completed in
            if completed {
                showingProfileCreation = false
                isOnboardingComplete = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    updateDataFilters()
                }
            }
        }
        .onAppear {
            updateDataFilters()
            checkWelcomeBack()
            loadActivePlan()
            if let player = currentPlayer, subscriptionManager.isPro {
                Task {
                    await aiCoachService.fetchDailyCoachingIfNeeded(for: player)
                }
            }
        }
        .onChange(of: authManager.userUID) {
            updateDataFilters()
        }
        .onChange(of: players.count) { count in
            if count == 0 && !authManager.userUID.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    updateDataFilters()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            DispatchQueue.main.async {
                if currentPlayer == nil && !authManager.userUID.isEmpty {
                    updateDataFilters()
                }
            }
        }
    }
    
    private func updateDataFilters() {
        guard !authManager.userUID.isEmpty else { return }

        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        recentSessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
        recentMatches.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }

    private func checkWelcomeBack() {
        let lastOpen = Date(timeIntervalSince1970: lastAppOpenDate)
        let daysSinceLastOpen = Calendar.current.dateComponents([.day], from: lastOpen, to: Date()).day ?? 0

        if daysSinceLastOpen >= 1 {
            daysInactive = daysSinceLastOpen
            showWelcomeBack = true
        }

        // Update last open date
        lastAppOpenDate = Date().timeIntervalSince1970
    }

    private func dismissWelcomeBack() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showWelcomeBack = false
        }
    }

    private func loadActivePlan() {
        guard let player = currentPlayer else { return }
        activePlan = TrainingPlanService.shared.fetchActivePlan(for: player)
        if let plan = activePlan {
            currentWeekDay = TrainingPlanService.shared.getCurrentWeekAndDay(for: plan)
        }
    }

    private func surpriseMe(player: Player) {
        guard let exercises = player.exercises?.allObjects as? [Exercise], !exercises.isEmpty else { return }

        let weaknesses = player.playerProfile?.selfIdentifiedWeaknesses ?? []
        var picked: Exercise?

        if !weaknesses.isEmpty {
            let matching = exercises.filter { ex in
                guard let skills = ex.targetSkills else { return false }
                return skills.contains(where: { skill in
                    weaknesses.contains(where: { weakness in
                        skill.localizedCaseInsensitiveContains(weakness) || weakness.localizedCaseInsensitiveContains(skill)
                    })
                })
            }
            picked = matching.randomElement()
        }

        if picked == nil {
            picked = exercises.randomElement()
        }

        if let exercise = picked {
            quickStartExercises = [exercise]
            showingActiveTraining = true
        }
    }

    // MARK: - AI Drill Hero Banner
    private func aiDrillHeroBanner() -> some View {
        Button {
            if subscriptionManager.canUseQuickDrill() {
                showingQuickDrill = true
            } else {
                showingQuickDrillPaywall = true
            }
        } label: {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 30))
                    .foregroundColor(DesignSystem.Colors.textOnAccent)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Generate AI Drill")
                        .font(DesignSystem.Typography.headlineLarge)
                        .foregroundColor(DesignSystem.Colors.textOnAccent)

                    Text("Describe any skill — get a personalized drill instantly")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textOnAccent.opacity(0.8))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textOnAccent.opacity(0.6))
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.athleticGradient)
            .cornerRadius(DesignSystem.CornerRadius.xl)
            .modifier(HeroBannerShadowModifier())
        }
        .buttonStyle(.plain)
    }

    private struct HeroBannerShadowModifier: ViewModifier {
        @Environment(\.colorScheme) private var colorScheme

        func body(content: Content) -> some View {
            if colorScheme == .dark {
                content.customShadow(DesignSystem.Shadow.glowLarge)
            } else {
                content.customShadow(DesignSystem.Shadow.large)
            }
        }
    }

    private func modernHeaderSection(player: Player) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Welcome Back Overlay (when returning after inactivity)
            if showWelcomeBack && daysInactive >= 3 {
                WelcomeBackView(daysInactive: daysInactive) {
                    dismissWelcomeBack()
                    showingNewSession = true
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Greeting Section with Avatar
            HStack(spacing: DesignSystem.Spacing.md) {
                // Player Avatar (compact)
                ProgrammaticAvatarView(
                    avatarState: AvatarService.shared.currentAvatarState,
                    size: .small
                )
                .frame(width: 50, height: 75)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(getGreeting())
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(player.name ?? "Player")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                // Compact stats
                CompactPlayerStats(player: player)
            }

            // XP Progress Bar
            xpProgressCard(player: player)

            // Daily Goal Card with Progress Ring
            DailyGoalCard(
                sessionsToday: sessionsToday(for: player),
                dailyGoal: 1,
                onStartSession: { showingNewSession = true }
            )
        }
    }

    private func sessionsToday(for player: Player) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        return sessions.filter { ($0.date ?? Date.distantPast) >= today }.count
    }
    
    private func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good Morning"
        case 12..<17:
            return "Good Afternoon"
        default:
            return "Good Evening"
        }
    }
    
    
    // MARK: - Today's Focus (AI Coach)

    @ViewBuilder
    private func todaysFocusSection(player: Player) -> some View {
        if subscriptionManager.isPro {
            if aiCoachService.isLoading {
                TodaysFocusCardSkeleton()
            } else if let coaching = aiCoachService.dailyCoaching {
                TodaysFocusCard(
                    coaching: coaching,
                    isStale: aiCoachService.isCacheStale,
                    onStartDrill: {
                        launchAIDrill(coaching.recommendedDrill, for: player)
                    },
                    onBrowseLibrary: {
                        selectedTab = 2
                    }
                )
            }
        } else {
            ProLockedCardView(feature: .dailyCoaching)
        }
    }

    private func launchAIDrill(_ drill: RecommendedDrill, for player: Player) {
        // If drill references a library exercise, fetch it
        if drill.isFromLibrary, let idString = drill.libraryExerciseID, let uuid = UUID(uuidString: idString) {
            let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
            request.fetchLimit = 1
            if let existing = try? viewContext.fetch(request).first {
                quickStartExercises = [existing]
                showingActiveTraining = true
                return
            }
        }

        // Otherwise create a temporary exercise from the AI drill
        let exercise = Exercise(context: viewContext)
        exercise.id = UUID()
        exercise.name = drill.name
        exercise.exerciseDescription = "AI Coach Recommendation: \(drill.description)"
        exercise.category = drill.category
        exercise.difficulty = Int16(drill.difficulty)
        exercise.targetSkills = drill.targetSkills
        exercise.instructions = drill.steps.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        exercise.player = player

        try? viewContext.save()
        quickStartExercises = [exercise]
        showingActiveTraining = true
    }

    private func modernStatsOverview(player: Player) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            PitchDivider(horizontalPadding: 0)

            Text("Your Progress")
                .font(DesignSystem.Typography.displaySmall)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                StatCard(
                    title: "Total Sessions",
                    value: "\(player.sessions?.count ?? 0)",
                    subtitle: "completed",
                    icon: DesignSystem.Icons.calendar,
                    color: DesignSystem.Colors.primaryGreen
                )
                
                StatCard(
                    title: "Training Hours",
                    value: String(format: "%.1f", totalTrainingHours(for: player)),
                    subtitle: "logged",
                    icon: DesignSystem.Icons.time,
                    color: DesignSystem.Colors.secondaryBlue
                )
                
                StatCard(
                    title: "This Week",
                    value: "\(sessionsThisWeek(for: player))",
                    subtitle: "sessions",
                    icon: DesignSystem.Icons.stats,
                    color: DesignSystem.Colors.accentOrange
                )
                
                StatCard(
                    title: "Streak",
                    value: "\(player.currentStreak)",
                    subtitle: "days",
                    icon: DesignSystem.Icons.trophy,
                    color: DesignSystem.Colors.accentYellow,
                    progress: min(1.0, Double(player.currentStreak) / 7.0)
                )
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Progress: \(player.sessions?.count ?? 0) sessions, \(String(format: "%.1f", totalTrainingHours(for: player))) hours, \(sessionsThisWeek(for: player)) this week, \(player.currentStreak) day streak")
        }
    }

    // MARK: - XP Progress Card

    private func xpProgressCard(player: Player) -> some View {
        let progress = XPService.shared.progressToNextLevel(totalXP: player.totalXP, currentLevel: Int(player.currentLevel))
        let tier = XPService.shared.tierForLevel(Int(player.currentLevel))
        let nextLevelXP = XPService.shared.xpRequiredForLevel(Int(player.currentLevel) + 1)
        let currentLevelXP = XPService.shared.xpRequiredForLevel(Int(player.currentLevel))
        let xpInLevel = player.totalXP - currentLevelXP
        let xpNeeded = nextLevelXP - currentLevelXP

        return ModernCard(padding: DesignSystem.Spacing.md) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let tier = tier {
                            Text(tier.title)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Text("\(player.totalXP) XP")
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }

                    Spacer()

                    // Streak flame
                    if player.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(DesignSystem.Colors.accentOrange)
                            Text("\(player.currentStreak)")
                                .font(DesignSystem.Typography.labelLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.accentOrange)
                        }
                    }
                }

                // XP Progress Bar
                VStack(spacing: 4) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.primaryGreen)
                                .frame(width: geometry.size.width * progress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    HStack {
                        Text("\(xpInLevel)/\(xpNeeded) to Level \(player.currentLevel + 1)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func continuePlanCard(player: Player) -> some View {
        if let plan = activePlan {
            NavigationLink {
                TodaysTrainingView(player: player, activePlan: plan)
            } label: {
                ModernCard(padding: DesignSystem.Spacing.md) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.primaryGreen.opacity(0.15))
                                .frame(width: 50, height: 50)
                            Image(systemName: "play.fill")
                                .font(.title3)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Continue Plan")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text(plan.name)
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            if let wd = currentWeekDay {
                                Text("Week \(wd.week), Day \(wd.day)")
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }

                            // Progress bar
                            VStack(spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray5))
                                            .frame(height: 6)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(DesignSystem.Colors.primaryGreen)
                                            .frame(width: geo.size.width * min(1.0, plan.progressPercentage / 100.0), height: 6)
                                    }
                                }
                                .frame(height: 6)

                                HStack {
                                    Text("\(Int(plan.progressPercentage))% Complete")
                                        .font(DesignSystem.Typography.labelSmall)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    Spacer()
                                }
                            }
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                        .stroke(DesignSystem.Colors.primaryGreen.opacity(0.3), lineWidth: 1.5)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Continue plan: \(plan.name), \(Int(plan.progressPercentage)) percent complete")
            .accessibilityHint("Double tap to start today's training")
        }
    }

    private func modernQuickActions(player: Player) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ModernActionCard(
                    title: "New Session",
                    icon: DesignSystem.Icons.plus,
                    color: DesignSystem.Colors.primaryGreen
                ) {
                    showingNewSession = true
                }
                
                ModernActionCard(
                    title: "View Progress",
                    icon: DesignSystem.Icons.stats,
                    color: DesignSystem.Colors.secondaryBlue
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedTab = 3 // Navigate to Progress tab
                    }
                }
                
                ModernActionCard(
                    title: "Quick Drill",
                    icon: "bolt.fill",
                    color: DesignSystem.Colors.accentOrange
                ) {
                    if subscriptionManager.canUseQuickDrill() {
                        showingQuickDrill = true
                    } else {
                        showingQuickDrillPaywall = true
                    }
                }

                let hasExercises = (player.exercises?.count ?? 0) > 0
                ModernActionCard(
                    title: "Surprise Me",
                    icon: "shuffle",
                    color: DesignSystem.Colors.accentYellow,
                    subtitle: hasExercises ? nil : "Add exercises to unlock",
                    disabled: !hasExercises
                ) {
                    surpriseMe(player: player)
                }
            }
        }
    }
    
    private var modernRecentActivity: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Recent Activity")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.bold)
                
                Spacer()
                
                if !recentSessions.isEmpty {
                    NavigationLink("View All") {
                        SessionHistoryView()
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
            
            ModernCard {
                if recentSessions.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: DesignSystem.Icons.calendar)
                            .font(.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("No training sessions yet")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Start your first session to begin tracking!")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        
                        ModernButton("START TRAINING", icon: DesignSystem.Icons.play, style: .primary) {
                            showingNewSession = true
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(Array(recentSessions.prefix(3)), id: \.objectID) { session in
                            ModernSessionRow(session: session)
                        }
                    }
                }
            }
        }
    }

    private func modernMatchesSection(player: Player) -> some View {
        let stats = MatchService.shared.calculateStats(for: Array(recentMatches))

        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Recent Matches")
                    .font(DesignSystem.Typography.headlineSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.bold)

                Spacer()

                if !recentMatches.isEmpty {
                    NavigationLink("View All") {
                        MatchHistoryView(player: player)
                    }
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }

            // Quick Stats Row
            if !recentMatches.isEmpty {
                HStack(spacing: DesignSystem.Spacing.md) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("\(stats.matchesPlayed)")
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("Matches")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Divider().frame(height: 30)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("\(stats.totalGoals)")
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("Goals")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Divider().frame(height: 30)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("\(stats.totalAssists)")
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.secondaryBlue)
                        Text("Assists")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Divider().frame(height: 30)

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(String(format: "%.0f%%", stats.winRate))
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.accentOrange)
                        Text("Win Rate")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
                .cornerRadius(DesignSystem.CornerRadius.card)
                .customShadow(DesignSystem.Shadow.small)
            }

            ModernCard {
                if recentMatches.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "sportscourt")
                            .font(.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textSecondary)

                        Text("No matches logged yet")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("Track your match performance and stats")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)

                        ModernButton("LOG MATCH", icon: "plus.circle", style: .primary) {
                            showingMatchLog = true
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                } else {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(Array(recentMatches.prefix(3)), id: \.objectID) { match in
                            MatchHistoryRow(match: match)
                        }

                        // Log Match Button
                        CompactActionButton(
                            title: "Log Match",
                            icon: "plus.circle",
                            color: DesignSystem.Colors.primaryGreen
                        ) {
                            showingMatchLog = true
                        }
                    }
                }
            }
        }
    }

    private func modernRecommendations(player: Player) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Recommended for You")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)

            if subscriptionManager.isPro {
                ModernCard {
                    if smartRecommendations.isEmpty {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            SoccerBallSpinner()
                            Text("Analyzing your training patterns...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .padding(.vertical, DesignSystem.Spacing.lg)
                    } else {
                        VStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(Array(smartRecommendations.enumerated()), id: \.offset) { index, recommendation in
                                SmartRecommendationRow(
                                    recommendation: recommendation
                                )

                                if index < smartRecommendations.count - 1 {
                                    Divider()
                                        .background(DesignSystem.Colors.neutral200)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    loadSmartRecommendations(for: player)
                }
            } else {
                ProLockedCardView(feature: .mlRecommendations)
            }
        }
    }
    
    private func totalTrainingHours(for player: Player) -> Double {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0.0 }
        let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
        return totalMinutes / 60.0 // Convert minutes to hours
    }
    
    private func sessionsThisWeek(for player: Player) -> Int {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0 }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return sessions.filter { $0.date ?? Date.distantPast >= weekAgo }.count
    }
    
    private func loadSmartRecommendations(for player: Player) {
        Task {
            // Clean up any duplicate exercises first
            YouTubeService.shared.removeDuplicateExercises(for: player)
            
            do {
                let mlRecs = try await cloudMLService.getCloudRecommendations(for: player, limit: 3)
                await MainActor.run {
                    mlRecommendations = mlRecs
                    let recommendations = YouTubeService.shared.getSmartRecommendations(for: player, limit: 3)
                    smartRecommendations = recommendations
                }
            } catch {
                let recommendations = YouTubeService.shared.getSmartRecommendations(for: player, limit: 3)
                await MainActor.run {
                    smartRecommendations = recommendations
                }
            }
        }
    }
    
    private func cleanDuplicateExercises() {
        guard let player = currentPlayer else { return }
        Task {
            YouTubeService.shared.removeDuplicateExercises(for: player)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: DesignSystem.Icons.soccer)
                    .font(.system(size: 80))
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                    .pulseAnimation()
                
                Text("Welcome to TechnIQ")
                    .font(DesignSystem.Typography.headlineLarge)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.bold)
                
                Text("Create your player profile to start tracking your soccer training journey")
                    .font(DesignSystem.Typography.bodyLarge)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.Spacing.xl)
            }
            
            ModernCard {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("Get Started")
                        .font(DesignSystem.Typography.titleLarge)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Set up your profile and begin your training")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    ModernButton("CREATE PROFILE", icon: "person.crop.circle.badge.plus") {
                        showingProfileCreation = true
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        }
        .padding(DesignSystem.Spacing.screenPadding)
    }

}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}
