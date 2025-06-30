import SwiftUI
import CoreData

struct DashboardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
        animation: .default)
    private var players: FetchedResults<Player>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
        animation: .default)
    private var recentSessions: FetchedResults<TrainingSession>
    
    @State private var showingNewSession = false
    
    var currentPlayer: Player? {
        players.first
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let player = currentPlayer {
                    headerSection(player: player)
                    statsOverviewCard(player: player)
                    quickActionsCard
                    recentActivityCard
                    recommendationsCard
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .sheet(isPresented: $showingNewSession) {
            if let player = currentPlayer {
                NewSessionView(player: player)
            }
        }
    }
    
    private func headerSection(player: Player) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good Morning")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(player.name ?? "Player")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "person.crop.circle")
                        .font(.title)
                        .foregroundColor(.primary)
                }
            }
            
            // Today's Goal
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Goal")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Complete 1 training session")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                Button(action: { showingNewSession = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.caption)
                        Text("Start")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
    }
    
    
    private func statsOverviewCard(player: Player) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your Progress")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                ModernStatCard(
                    title: "Total Sessions",
                    value: "\(player.sessions?.count ?? 0)",
                    subtitle: "completed"
                )
                
                ModernStatCard(
                    title: "Training Hours",
                    value: String(format: "%.1f", totalTrainingHours(for: player)),
                    subtitle: "logged"
                )
            }
            
            HStack(spacing: 16) {
                ModernStatCard(
                    title: "This Week",
                    value: "\(sessionsThisWeek(for: player))",
                    subtitle: "sessions"
                )
                
                ModernStatCard(
                    title: "Streak",
                    value: "3",
                    subtitle: "days"
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ActionButton(
                    title: "New Session",
                    icon: "plus.circle.fill",
                    color: .black
                ) {
                    showingNewSession = true
                }
                
                ActionButton(
                    title: "View Progress",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .blue
                ) {
                    // Handle action
                }
                
                ActionButton(
                    title: "Exercise Library",
                    icon: "book.fill",
                    color: .green
                ) {
                    // Handle action
                }
                
                ActionButton(
                    title: "Profile",
                    icon: "person.fill",
                    color: .orange
                ) {
                    // Handle action
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !recentSessions.isEmpty {
                    NavigationLink("View All") {
                        SessionHistoryView()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if recentSessions.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title)
                        .foregroundColor(.gray)
                    Text("No training sessions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Start your first session to begin tracking!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(recentSessions.prefix(3)), id: \.objectID) { session in
                        RecentSessionRow(session: session)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Recommended for You")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 10) {
                RecommendationRow(
                    title: "Ball Control Practice",
                    description: "Improve your first touch",
                    icon: "soccerball",
                    color: .green
                )
                
                RecommendationRow(
                    title: "Sprint Training",
                    description: "Build your speed and acceleration",
                    icon: "figure.run",
                    color: .blue
                )
                
                RecommendationRow(
                    title: "Shooting Drills",
                    description: "Work on accuracy and power",
                    icon: "target",
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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
}


struct RecentSessionRow: View {
    let session: TrainingSession
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.sessionType ?? "Training")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(formatDate(session.date ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(session.duration))min")
                    .font(.caption)
                    .fontWeight(.medium)
                
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { index in
                        Image(systemName: index < session.overallRating ? "star.fill" : "star")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

struct RecommendationRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    DashboardView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}