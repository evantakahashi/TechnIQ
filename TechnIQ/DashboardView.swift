import SwiftUI
import CoreData
import Foundation
import Combine

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var recentSessions: FetchedResults<TrainingSession>
    
    init() {
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
    @State private var youtubeTestResults: [YouTubeTestVideo] = []
    @State private var isTestingYouTube = false
    @State private var youtubeTestError: String?
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
                        youtubeTestSection
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
            print("📊 Onboarding completion changed: \(completed)")
            if completed {
                print("✅ Profile creation completed! Dismissing sheet and refreshing data...")
                showingProfileCreation = false
                isOnboardingComplete = false // Reset for next time
                // Refresh data after profile creation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    print("🔄 Calling updateDataFilters after profile creation...")
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
            print("👥 Players count changed to: \(count)")
            if count == 0 && !authManager.userUID.isEmpty {
                print("⚠️ Player count dropped to 0 but user is authenticated. Refreshing filters in 0.5s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    updateDataFilters()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            print("🔄 Core Data context saved, checking player state...")
            DispatchQueue.main.async {
                if currentPlayer == nil && !authManager.userUID.isEmpty {
                    print("🔄 Player not found after save, refreshing filters...")
                    updateDataFilters()
                }
            }
        }
    }
    
    private func updateDataFilters() {
        guard !authManager.userUID.isEmpty else {
            print("⚠️ DashboardView: No userUID available, skipping filter update")
            return
        }
        
        // Filter players and sessions by Firebase UID
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        recentSessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
        print("🔍 Updated DashboardView filters for user: \(authManager.userUID)")
        print("👥 Current players count: \(players.count)")
        
        // Debug: Print current player info
        if let currentPlayer = players.first {
            print("✅ Current player found: \(currentPlayer.name ?? "Unknown") - UID: \(currentPlayer.firebaseUID ?? "No UID")")
        } else {
            print("❌ No current player found after filter update")
            
            // Debug: Check all players in database
            let allPlayersRequest = Player.fetchRequest()
            do {
                let allPlayers = try viewContext.fetch(allPlayersRequest)
                print("🔍 Total players in database: \(allPlayers.count)")
                for player in allPlayers {
                    print("  - Player: \(player.name ?? "Unknown") - UID: \(player.firebaseUID ?? "No UID")")
                }
                if authManager.isAuthenticated {
                    print("🔓 User IS authenticated with UID: \(authManager.userUID)")
                    print("📧 User email: \(authManager.userEmail)")
                    print("👤 User display name: \(authManager.userDisplayName)")
                } else {
                    print("🔒 User is NOT authenticated")
                }
            } catch {
                print("❌ Error fetching all players: \(error)")
            }
        }
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
                    // Handle action
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
        return sessions.reduce(0) { $0 + $1.duration }
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
                // Try cloud ML recommendations first
                let mlRecs = try await cloudMLService.getCloudRecommendations(for: player, limit: 3)
                await MainActor.run {
                    mlRecommendations = mlRecs
                    // For now, use the fallback since the UI expects the original DrillRecommendation format
                    let recommendations = CoreDataManager.shared.getSmartRecommendations(for: player, limit: 3)
                    smartRecommendations = recommendations
                }
            } catch {
                print("⚠️ Cloud ML failed, using fallback: \(error.localizedDescription)")
                // Fallback to original recommendations if cloud ML fails
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
    
    private var youtubeTestSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("YouTube API Test")
                .font(DesignSystem.Typography.headlineSmall)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fontWeight(.bold)
            
            ModernCard {
                VStack(spacing: DesignSystem.Spacing.md) {
                    if isTestingYouTube {
                        HStack {
                            SoccerBallSpinner()
                            Text("Testing YouTube API...")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    } else {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ModernButton("TEST YOUTUBE API", icon: "play.circle", style: .secondary) {
                                testYouTubeAPI()
                            }
                            
                            ModernButton("CLEAN DUPLICATES", icon: "trash.circle", style: .secondary) {
                                cleanDuplicateExercises()
                            }
                        }
                    }
                    
                    if let error = youtubeTestError {
                        HStack {
                            Image(systemName: DesignSystem.Icons.xmark)
                                .foregroundColor(DesignSystem.Colors.error)
                            Text(error)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                            Spacer()
                        }
                    }
                    
                    if !youtubeTestResults.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: DesignSystem.Icons.checkmark)
                                    .foregroundColor(DesignSystem.Colors.success)
                                Text("Found \(youtubeTestResults.count) drill videos!")
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.success)
                                Spacer()
                            }
                            
                            ForEach(youtubeTestResults.prefix(3), id: \.videoId) { drill in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(drill.title)
                                        .font(DesignSystem.Typography.labelMedium)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .lineLimit(2)
                                    
                                    HStack {
                                        Text(drill.channel)
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        
                                        Spacer()
                                        
                                        Text(drill.duration)
                                            .font(DesignSystem.Typography.bodySmall)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func testYouTubeAPI() {
        isTestingYouTube = true
        youtubeTestError = nil
        youtubeTestResults = []
        
        Task {
            do {
                guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                      let plist = NSDictionary(contentsOfFile: path),
                      let apiKey = plist["API_KEY"] as? String,
                      !apiKey.isEmpty else {
                    await MainActor.run {
                        youtubeTestError = "Google API key not found in GoogleService-Info.plist"
                        isTestingYouTube = false
                    }
                    return
                }
                print("✅ Using YouTube API key for testing: \(String(apiKey.prefix(10)))...")
                
                // Make a simple search request
                let searchResponse = try await performSimpleYouTubeSearch(apiKey: apiKey)
                
                await MainActor.run {
                    youtubeTestResults = searchResponse
                    isTestingYouTube = false
                }
            } catch {
                await MainActor.run {
                    youtubeTestError = error.localizedDescription
                    isTestingYouTube = false
                }
            }
        }
    }
    
    private func performSimpleYouTubeSearch(apiKey: String) async throws -> [YouTubeTestVideo] {
        let urlString = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=5&q=soccer+dribbling+drills&type=video&key=\(apiKey)"
        
        guard let url = URL(string: urlString) else {
            throw SimpleAPIError.invalidSearchQuery
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleAPIError.networkError
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            print("❌ YouTube API Error - Status Code: \(httpResponse.statusCode)")
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                print("❌ YouTube API Error Message: \(message)")
            }
            
            if httpResponse.statusCode == 403 {
                throw SimpleAPIError.quotaExceeded
            } else {
                throw SimpleAPIError.networkError
            }
        }
        
        // Simple JSON parsing
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            throw SimpleAPIError.parsingError
        }
        
        return items.compactMap { item in
            guard let id = item["id"] as? [String: Any],
                  let videoId = id["videoId"] as? String,
                  let snippet = item["snippet"] as? [String: Any],
                  let title = snippet["title"] as? String,
                  let channelTitle = snippet["channelTitle"] as? String else {
                return nil
            }
            
            return YouTubeTestVideo(
                videoId: videoId,
                title: title,
                channel: channelTitle,
                duration: "N/A"
            )
        }
    }
}

struct YouTubeTestVideo {
    let videoId: String
    let title: String
    let channel: String
    let duration: String
}

enum SimpleAPIError: LocalizedError {
    case apiKeyNotConfigured
    case quotaExceeded
    case invalidSearchQuery
    case networkError
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .apiKeyNotConfigured:
            return "YouTube API key is not configured"
        case .quotaExceeded:
            return "YouTube API quota exceeded or API not enabled. Please enable YouTube Data API v3 in Google Cloud Console."
        case .invalidSearchQuery:
            return "Invalid search query"
        case .networkError:
            return "Network error occurred"
        case .parsingError:
            return "Error parsing YouTube response"
        }
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
                        .lineLimit(2)
                    
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
    DashboardView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}