import SwiftUI
import CoreData

// MARK: - Plan tab root
//
// The third tab opens on the active plan's schedule, the screen a player returns to every week.
// "All plans" in its nav bar pushes the library (templates, My plans, + New plan). With no active
// plan the library is the root, so a finished or deleted plan drops the player straight back into
// choosing the next one.

struct PlanTabView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @ObservedObject private var planService = TrainingPlanService.shared
    @FetchRequest private var players: FetchedResults<Player>
    @State private var rootPlanID: UUID?

    init() {
        _players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: AuthenticationManager.shared.playerPredicate,
            animation: .default
        )
    }

    private var player: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        Group {
            if let player, let plan = planService.activePlan, plan.id == rootPlanID {
                TrainingPlanDetailView(initialPlan: plan, player: player, presentation: .tabRoot, onActivePlanChanged: refresh)
                    .id(plan.id)
            } else {
                TrainingPlansListView()
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: authManager.userUID) { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Activating, finishing or deleting a plan anywhere in the app re-roots the tab.
            syncRootIfNeeded()
        }
    }

    private func refresh() {
        guard let player else { rootPlanID = nil; return }
        planService.activePlan = planService.fetchActivePlan(for: player)
        rootPlanID = planService.activePlan?.id
    }

    private func syncRootIfNeeded() {
        guard let player else { return }
        let current = planService.fetchActivePlan(for: player)
        if current?.id != rootPlanID {
            planService.activePlan = current
            rootPlanID = current?.id
        }
    }
}
