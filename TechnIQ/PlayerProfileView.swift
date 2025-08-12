import SwiftUI
import CoreData

struct PlayerProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>
    
    init() {
        // Initialize with empty predicate - will be updated in onAppear
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: false), // Temporary predicate
            animation: .default
        )
    }
    
    @State private var showingEditProfile = false
    @State private var showingSignOutAlert = false
    
    var currentPlayer: Player? {
        players.first
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let player = currentPlayer {
                    VStack(spacing: 20) {
                        profileHeaderCard(player: player)
                        physicalStatsCard(player: player)
                        playingStatsCard(player: player)
                        skillsProgressCard(player: player)
                        achievementsCard(player: player)
                    }
                    .padding()
                } else {
                    ContentUnavailableView(
                        "No Profile Found",
                        systemImage: "person.circle",
                        description: Text("Create a profile to get started")
                    )
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                if currentPlayer != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button("Edit Profile") {
                                showingEditProfile = true
                            }
                            Button("Sign Out", role: .destructive) {
                                showingSignOutAlert = true
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                if let player = currentPlayer {
                    EditProfileView(player: player)
                }
            }
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    authManager.signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .onAppear {
                updatePlayersFilter()
            }
            .onChange(of: authManager.userUID) {
                updatePlayersFilter()
            }
        }
    }
    
    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        print("🔍 Updated PlayerProfileView filter for user: \(authManager.userUID)")
    }
    
    private func profileHeaderCard(player: Player) -> some View {
        VStack(spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.name ?? "Player")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("\(player.age) years old")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 20) {
                ProfileInfoItem(title: "Position", value: player.position ?? "N/A")
                ProfileInfoItem(title: "Style", value: player.playingStyle ?? "N/A")
                ProfileInfoItem(title: "Foot", value: player.dominantFoot ?? "N/A")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func physicalStatsCard(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Physical Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                PhysicalStatItem(title: "Height", value: "\(Int(player.height)) cm")
                PhysicalStatItem(title: "Weight", value: "\(Int(player.weight)) kg")
                PhysicalStatItem(title: "BMI", value: String(format: "%.1f", calculateBMI(player)))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func playingStatsCard(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Training Stats")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 20) {
                PlayingStatItem(
                    title: "Total Sessions",
                    value: "\(player.sessions?.count ?? 0)",
                    icon: "calendar"
                )
                
                PlayingStatItem(
                    title: "Total Hours",
                    value: String(format: "%.1f", calculateTotalHours(player)),
                    icon: "clock"
                )
                
                PlayingStatItem(
                    title: "Avg Rating",
                    value: String(format: "%.1f", calculateAverageRating(player)),
                    icon: "star"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func skillsProgressCard(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Skills Progress")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let latestStats = getLatestStats(for: player),
               let skillRatings = latestStats.skillRatings {
                VStack(spacing: 10) {
                    ForEach(Array(skillRatings.keys.sorted()), id: \.self) { skill in
                        SkillProgressBar(
                            skill: skill,
                            rating: skillRatings[skill] ?? 0.0
                        )
                    }
                }
            } else {
                Text("No skill data available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func achievementsCard(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Achievements")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                AchievementBadge(
                    title: "First Session",
                    description: "Complete your first training",
                    isUnlocked: (player.sessions?.count ?? 0) > 0,
                    icon: "star.fill"
                )
                
                AchievementBadge(
                    title: "Dedicated",
                    description: "Complete 10 sessions",
                    isUnlocked: (player.sessions?.count ?? 0) >= 10,
                    icon: "medal.fill"
                )
                
                AchievementBadge(
                    title: "Marathon",
                    description: "Train for 10+ hours",
                    isUnlocked: calculateTotalHours(player) >= 10,
                    icon: "flame.fill"
                )
                
                AchievementBadge(
                    title: "Perfectionist",
                    description: "Get a 5-star session",
                    isUnlocked: hasMaxRating(player),
                    icon: "crown.fill"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // Helper functions
    private func calculateBMI(_ player: Player) -> Double {
        let heightInMeters = player.height / 100.0
        return player.weight / (heightInMeters * heightInMeters)
    }
    
    private func calculateTotalHours(_ player: Player) -> Double {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return 0.0 }
        return sessions.reduce(0) { $0 + $1.duration }
    }
    
    private func calculateAverageRating(_ player: Player) -> Double {
        guard let sessions = player.sessions as? Set<TrainingSession>, !sessions.isEmpty else { return 0.0 }
        let totalRating = sessions.reduce(0.0) { $0 + Double($1.overallRating) }
        return totalRating / Double(sessions.count)
    }
    
    private func getLatestStats(for player: Player) -> PlayerStats? {
        guard let stats = player.stats as? Set<PlayerStats> else { return nil }
        return stats.max { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
    }
    
    private func hasMaxRating(_ player: Player) -> Bool {
        guard let sessions = player.sessions as? Set<TrainingSession> else { return false }
        return sessions.contains { $0.overallRating >= 5 }
    }
}

struct ProfileInfoItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct PhysicalStatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct PlayingStatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SkillProgressBar: View {
    let skill: String
    let rating: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(skill)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(String(format: "%.1f/10", rating))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: rating, total: 10.0)
                .progressViewStyle(LinearProgressViewStyle(tint: progressColor(rating)))
        }
    }
    
    private func progressColor(_ rating: Double) -> Color {
        switch rating {
        case 0..<4: return .red
        case 4..<7: return .orange
        case 7..<9: return .yellow
        default: return .green
        }
    }
}

struct AchievementBadge: View {
    let title: String
    let description: String
    let isUnlocked: Bool
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isUnlocked ? .gold : .gray)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isUnlocked ? .primary : .secondary)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding()
        .background(isUnlocked ? Color.yellow.opacity(0.1) : Color.gray.opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isUnlocked ? Color.gold : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
}

#Preview {
    PlayerProfileView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .environmentObject(AuthenticationManager.shared)
}