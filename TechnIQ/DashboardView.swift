import SwiftUI
import CoreData
import Foundation
import Combine

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var recentSessions: FetchedResults<TrainingSession>
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
    }
    
    @State private var showingNewSession = false
    @State private var showingProfileCreation = false
    @State private var isOnboardingComplete = false
    @State private var smartRecommendations: [CoreDataManager.DrillRecommendation] = []
    @State private var mlRecommendations: [MLDrillRecommendation] = []
    @StateObject private var cloudMLService = CloudMLService.shared
    
    var currentPlayer: Player? {
        players.first
    }
    
    var body: some View {
        ZStack {
            // Modern gradient background
            DesignSystem.Colors.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xl) {
                    if let player = currentPlayer {
                        modernHeaderSection(player: player)
                        modernStatsOverview(player: player)
                        modernQuickActions
                        modernRecentActivity
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
        .sheet(isPresented: $showingProfileCreation) {
            EnhancedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
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
    }
    
    private func modernHeaderSection(player: Player) -> some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Greeting Section
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(getGreeting())
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Text(player.name ?? "Player")
                        .font(DesignSystem.Typography.headlineMedium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Profile Avatar
                Button(action: {}) {
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.primaryGreen.opacity(0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "person.fill")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                    }
                }
            }
            
            // Modern Today's Goal Card
            ModernCard {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Today's Goal")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("Complete 1 training session")
                            .font(DesignSystem.Typography.titleSmall)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    FloatingActionButton(icon: "plus") {
                        showingNewSession = true
                    }
                }
            }
            .pulseAnimation()
        }
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
                    value: "3",
                    subtitle: "days",
                    icon: DesignSystem.Icons.trophy,
                    color: DesignSystem.Colors.accentYellow,
                    progress: 0.6
                )
            }
        }
    }
    
    private var modernQuickActions: some View {
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
                    title: "Exercise Library",
                    icon: DesignSystem.Icons.exercises,
                    color: DesignSystem.Colors.accentOrange
                ) {
                    // Handle action
                }
                
                ModernActionCard(
                    title: "Profile",
                    icon: DesignSystem.Icons.profile,
                    color: DesignSystem.Colors.accentYellow
                ) {
                    // Handle action
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
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            action()
        }) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                Text(title)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .customShadow(isPressed ? DesignSystem.Shadow.small : DesignSystem.Shadow.medium)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(DesignSystem.Animation.quick, value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
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

#Preview {
    DashboardView(selectedTab: .constant(0))
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}