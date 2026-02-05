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
    
    @State private var showingNewSession = false
    @State private var showingProfileCreation = false
    @State private var showingMatchLog = false
    @State private var isOnboardingComplete = false
    @State private var smartRecommendations: [CoreDataManager.DrillRecommendation] = []
    @State private var mlRecommendations: [MLDrillRecommendation] = []
    @StateObject private var cloudMLService = CloudMLService.shared

    // Welcome back detection
    @State private var showWelcomeBack = false
    @State private var daysInactive: Int = 0
    @AppStorage("lastAppOpenDate") private var lastAppOpenDate: Double = Date().timeIntervalSince1970

    // Quick start flow
    @State private var activePlan: TrainingPlanModel?
    @State private var currentWeekDay: (week: Int, day: Int)?
    @State private var showingQuickDrill = false
    @State private var showingActiveTraining = false
    @State private var quickStartExercises: [Exercise] = []
    
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
                        modernStatsOverview(player: player)
                        continuePlanCard(player: player)
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
            EnhancedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
        .sheet(isPresented: $showingQuickDrill) {
            if let player = currentPlayer {
                QuickDrillSheet(player: player) { exercise in
                    showingQuickDrill = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        quickStartExercises = [exercise]
                        showingActiveTraining = true
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingActiveTraining) {
            ActiveTrainingView(exercises: quickStartExercises)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
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
    
    
    private func modernStatsOverview(player: Player) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Your Progress")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)
            
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
                    showingQuickDrill = true
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
        }
        .onAppear {
            loadSmartRecommendations(for: player)
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
            CoreDataManager.shared.removeDuplicateExercises(for: player)
            
            do {
                let mlRecs = try await cloudMLService.getCloudRecommendations(for: player, limit: 3)
                await MainActor.run {
                    mlRecommendations = mlRecs
                    let recommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: 3)
                    smartRecommendations = recommendations
                }
            } catch {
                let recommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: 3)
                await MainActor.run {
                    smartRecommendations = recommendations
                }
            }
        }
    }
    
    private func cleanDuplicateExercises() {
        guard let player = currentPlayer else { return }
        Task {
            CoreDataManager.shared.removeDuplicateExercises(for: player)
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



struct ModernActionCard: View {
    let title: String
    let icon: String
    let color: Color
    var subtitle: String? = nil
    var disabled: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            guard !disabled else { return }
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(disabled ? 0.08 : 0.15))
                        .frame(width: 60, height: 60)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(disabled ? color.opacity(0.4) : color)
                }

                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(disabled ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(isPressed ? DesignSystem.Shadow.small : DesignSystem.Shadow.medium)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(disabled ? 0.7 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .allowsHitTesting(!disabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            if !disabled { isPressed = pressing }
        }, perform: {})
    }
}

struct ModernSessionRow: View {
    let session: TrainingSession
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Session Icon
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: DesignSystem.Icons.training)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(session.sessionType ?? "Training")
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)
                
                Text(formatDate(session.date ?? Date()))
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text("\(Int(session.duration))min")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < session.overallRating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(DesignSystem.Colors.accentYellow)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct ModernRecommendationRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(DesignSystem.Typography.titleSmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
    }
}

struct SmartRecommendationRow: View {
    let recommendation: CoreDataManager.DrillRecommendation
    @State private var showingPhysicalDetails = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: categoryIcon)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(categoryColor)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(recommendation.exercise.name ?? "Drill")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if recommendation.priority == 1 {
                            Text("HIGH")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(DesignSystem.Colors.error)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(recommendation.reason)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Physical Indicators Row
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.intensity.displayName,
                            color: intensityColor,
                            icon: "gauge"
                        )
                        
                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.duration.displayName,
                            color: DesignSystem.Colors.secondaryBlue,
                            icon: "clock"
                        )
                        
                        PhysicalIndicatorChip(
                            text: recommendation.physicalIndicators.heartRateZone.shortName,
                            color: DesignSystem.Colors.accentOrange,
                            icon: "heart.fill"
                        )
                        
                        Spacer()
                        
                        Button(action: {
                            showingPhysicalDetails.toggle()
                        }) {
                            Image(systemName: showingPhysicalDetails ? "chevron.up" : "info.circle")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                        }
                    }
                    
                    HStack {
                        Text("Level \(recommendation.exercise.difficulty)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.0f%% match", recommendation.confidenceScore * 100))
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            // Expandable Physical Details
            if showingPhysicalDetails {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Physical Demands
                    if !recommendation.physicalIndicators.physicalDemands.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Physical Demands")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 4) {
                                ForEach(recommendation.physicalIndicators.physicalDemands.prefix(6), id: \.rawValue) { demand in
                                    HStack(spacing: 4) {
                                        Image(systemName: demand.icon)
                                            .font(.caption2)
                                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                                        Text(demand.rawValue)
                                            .font(DesignSystem.Typography.labelSmall)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Recovery Information
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recovery")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                            Text(recommendation.physicalIndicators.recoveryTime.displayName)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Heart Rate")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .fontWeight(.semibold)
                            Text(recommendation.physicalIndicators.heartRateZone.percentageRange)
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.neutral100.opacity(0.5))
                .cornerRadius(8)
                .transition(.opacity.combined(with: .slide))
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .animation(DesignSystem.Animation.smooth, value: showingPhysicalDetails)
    }
    
    private var categoryColor: Color {
        switch recommendation.category {
        case .skillGap:
            return DesignSystem.Colors.error
        case .difficultyProgression:
            return DesignSystem.Colors.primaryGreen
        case .varietyBalance:
            return DesignSystem.Colors.accentOrange
        case .repeatSuccess:
            return DesignSystem.Colors.accentYellow
        case .complementarySkill:
            return DesignSystem.Colors.secondaryBlue
        }
    }
    
    private var categoryIcon: String {
        switch recommendation.category {
        case .skillGap:
            return "target"
        case .difficultyProgression:
            return "arrow.up.circle"
        case .varietyBalance:
            return "shuffle"
        case .repeatSuccess:
            return "star.circle"
        case .complementarySkill:
            return "link.circle"
        }
    }
    
    private var intensityColor: Color {
        switch recommendation.physicalIndicators.intensity.color {
        case "green":
            return DesignSystem.Colors.primaryGreen
        case "yellow":
            return DesignSystem.Colors.accentYellow
        case "orange":
            return DesignSystem.Colors.accentOrange
        case "red":
            return DesignSystem.Colors.error
        case "purple":
            return Color.purple
        default:
            return DesignSystem.Colors.primaryGreen
        }
    }
}

struct PhysicalIndicatorChip: View {
    let text: String
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(text)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .cornerRadius(4)
    }
}

// MARK: - Daily Goal Card

struct DailyGoalCard: View {
    let sessionsToday: Int
    let dailyGoal: Int
    let onStartSession: () -> Void

    private var progress: Double {
        min(1.0, Double(sessionsToday) / Double(dailyGoal))
    }

    private var isGoalComplete: Bool {
        sessionsToday >= dailyGoal
    }

    var body: some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Circular Progress Ring
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 8)
                        .frame(width: 70, height: 70)

                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            isGoalComplete ? DesignSystem.Colors.successGreen : DesignSystem.Colors.primaryGreen,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                    // Center content
                    VStack(spacing: 0) {
                        if isGoalComplete {
                            Image(systemName: "checkmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(DesignSystem.Colors.successGreen)
                        } else {
                            Text("\(sessionsToday)")
                                .font(DesignSystem.Typography.headlineMedium)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Text("/\(dailyGoal)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                }

                // Goal Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(isGoalComplete ? "Goal Complete!" : "Today's Goal")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(isGoalComplete ? DesignSystem.Colors.successGreen : DesignSystem.Colors.textSecondary)

                    Text(isGoalComplete ? "Great work today!" : "Complete \(dailyGoal) session\(dailyGoal == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.semibold)

                    if !isGoalComplete {
                        Text("\(dailyGoal - sessionsToday) more to go")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()

                // Action button
                FloatingActionButton(
                    icon: isGoalComplete ? "plus" : "play.fill"
                ) {
                    onStartSession()
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card)
                .stroke(
                    isGoalComplete ? DesignSystem.Colors.successGreen.opacity(0.3) : Color.clear,
                    lineWidth: 2
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isGoalComplete)
    }
}

// MARK: - Enhanced Stats Row

struct StatsRowView: View {
    let player: Player
    let sessionsThisWeek: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Streak
            StatPill(
                icon: "flame.fill",
                value: "\(player.currentStreak)",
                label: "Streak",
                color: DesignSystem.Colors.streakOrange
            )

            // Week Sessions
            StatPill(
                icon: "calendar",
                value: "\(sessionsThisWeek)",
                label: "This Week",
                color: DesignSystem.Colors.secondaryBlue
            )

            // Total XP
            StatPill(
                icon: "star.fill",
                value: formatXP(player.totalXP),
                label: "Total XP",
                color: DesignSystem.Colors.xpGold
            )

            // Level
            StatPill(
                icon: "trophy.fill",
                value: "Lv.\(player.currentLevel)",
                label: "Level",
                color: DesignSystem.Colors.levelPurple
            )
        }
    }

    private func formatXP(_ xp: Int64) -> String {
        if xp >= 1000 {
            return String(format: "%.1fK", Double(xp) / 1000.0)
        }
        return "\(xp)"
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

// MARK: - Compact Player Stats (for header)

struct CompactPlayerStats: View {
    let player: Player
    @StateObject private var coinVM = CoinBalanceViewModel()

    private var tier: XPService.LevelTier? {
        XPService.shared.tierForLevel(Int(player.currentLevel))
    }

    var body: some View {
        // Minimal vertical stack - just icons with values
        VStack(alignment: .trailing, spacing: 6) {
            // Rank row
            HStack(spacing: 4) {
                Image(systemName: tier?.icon ?? "star.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.xpGold)
                Text(tier?.title ?? "Rookie")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }

            // Stats row
            HStack(spacing: 8) {
                // Level
                Text("Lv.\(player.currentLevel)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                // Streak (if > 0)
                if player.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10))
                            .foregroundColor(DesignSystem.Colors.streakOrange)
                        Text("\(player.currentStreak)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.streakOrange)
                    }
                    .fixedSize()
                }

                // Coins
                HStack(spacing: 2) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.coinGold)
                    Text("\(coinVM.balance)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fixedSize()
                }
                .fixedSize()
            }
            .fixedSize()
        }
        .fixedSize()
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}

#Preview("Daily Goal Card") {
    VStack(spacing: 20) {
        DailyGoalCard(sessionsToday: 0, dailyGoal: 1, onStartSession: {})
        DailyGoalCard(sessionsToday: 1, dailyGoal: 1, onStartSession: {})
        DailyGoalCard(sessionsToday: 1, dailyGoal: 3, onStartSession: {})
    }
    .padding()
}