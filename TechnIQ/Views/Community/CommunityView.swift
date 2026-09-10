import SwiftUI
import CoreData

// MARK: - Community (Touchline 6b)
//
// Title row with a raised "+ Post", a Feed / Drills / Leaderboard segment (Drills default — the
// kid-safe day-one choice), and the selected tab's content. Drills: a "DRILL OF THE WEEK" pitch
// card, a chip row, then flat rows with a saves count.

struct CommunityView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>

    // Default to the Drills tab rather than the stranger feed (kid-safety day-1 default).
    @State private var selectedTab = 1
    @State private var showingCreatePost = false

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    private var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.section) {
            TQScreenTitle("Community") {
                TQButton("+ Post", style: .raised, size: .compact, fullWidth: false) { showingCreatePost = true }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 8)

            TQSegment(options: ["Feed", "Drills", "Leaderboard"], selectedIndex: $selectedTab)
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            Group {
                switch selectedTab {
                case 0: CommunityFeedView()
                case 1: DrillMarketplaceView()
                default: LeaderboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { updatePlayersFilter() }
        .sheet(isPresented: $showingCreatePost) {
            if let player = currentPlayer {
                CreatePostView(player: player)
            }
        }
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}

#Preview {
    NavigationStack {
        CommunityView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
