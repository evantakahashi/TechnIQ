import SwiftUI
import CoreData

/// Train tab shell: resolves the current player and shows the Touchline drill library.
struct TrainHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>

    @State private var showingProfileCreation = false
    @State private var isOnboardingComplete = false

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        Group {
            if let player = currentPlayer {
                ExerciseLibraryView(player: player)
            } else {
                noProfileState
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { updatePlayersFilter() }
        .sheet(isPresented: $showingProfileCreation) {
            UnifiedOnboardingView(isOnboardingComplete: $isOnboardingComplete)
        }
        .onChange(of: isOnboardingComplete) { _, completed in
            if completed {
                showingProfileCreation = false
                isOnboardingComplete = false
                updatePlayersFilter()
            }
        }
    }

    private var noProfileState: some View {
        TQScreen {
            VStack(spacing: DesignSystem.Spacing.section) {
                TQScreenTitle("Train")
                    .padding(.top, 8)
                TQHeroCard(
                    eyebrow: "No player yet",
                    title: "Set up your player",
                    body: "Create your player profile to browse drills and start training.",
                    actionTitle: "Create profile",
                    actionIcon: nil,
                    markings: .heroSimple,
                    action: { showingProfileCreation = true }
                )
                Spacer()
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
        TrainHubView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
