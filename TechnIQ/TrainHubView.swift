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
        HStack(spacing: 0) {
            ForEach(TrainHubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(
                        selectedTab == tab
                            ? DesignSystem.Colors.primaryGreen
                            : Color.clear
                    )
                    .foregroundColor(
                        selectedTab == tab
                            ? .white
                            : DesignSystem.Colors.textSecondary
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(DesignSystem.CornerRadius.sm)
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
