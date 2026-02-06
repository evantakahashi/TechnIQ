import SwiftUI
import CoreData

enum TrainHubTab: String, CaseIterable {
    case sessions = "Sessions"
    case exercises = "Exercises"

    var icon: String {
        switch self {
        case .sessions: return "calendar"
        case .exercises: return "book.fill"
        }
    }
}

struct TrainHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @FetchRequest var players: FetchedResults<Player>

    @State private var selectedTab: TrainHubTab = .sessions

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
        VStack(spacing: 0) {
            // Segmented Picker Header
            segmentedPicker
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.sm)
                .padding(.bottom, DesignSystem.Spacing.sm)

            // Content based on selection
            Group {
                switch selectedTab {
                case .sessions:
                    SessionHistoryView()
                case .exercises:
                    if let player = currentPlayer {
                        ExerciseLibraryView(player: player)
                    } else {
                        ProgressView("Loading...")
                    }
                }
            }
        }
        .navigationTitle("Train")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            updatePlayersFilter()
        }
    }

    private var segmentedPicker: some View {
        let selectedIndex = Binding<Int>(
            get: { TrainHubTab.allCases.firstIndex(of: selectedTab) ?? 0 },
            set: { newIndex in selectedTab = TrainHubTab.allCases[newIndex] }
        )
        return ModernSegmentControl(
            options: TrainHubTab.allCases.map { $0.rawValue },
            selectedIndex: selectedIndex,
            icons: TrainHubTab.allCases.map { $0.icon }
        )
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}

#Preview {
    NavigationView {
        TrainHubView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
