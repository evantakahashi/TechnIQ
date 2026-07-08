import SwiftUI
import CoreData

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
        .coachMark(.train)
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SessionHistoryView()
                } label: {
                    Image(systemName: "calendar")
                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
        .onAppear {
            updatePlayersFilter()
        }
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
        ContentUnavailableView {
            Label("No Player Profile", systemImage: "person.crop.circle.badge.plus")
        } description: {
            Text("Create your player profile to browse drills and start training.")
        } actions: {
            ModernButton("Create Profile", icon: "person.crop.circle.badge.plus", style: .primary) {
                showingProfileCreation = true
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
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
