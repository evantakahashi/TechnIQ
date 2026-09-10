import SwiftUI
import CoreData

// MARK: - Drills from the coach
//
// Pushed from the Home row. Lists the weakness-based drill suggestions as flat rows; tapping one
// opens the AI drill generator prefilled with that weakness and launches the drill when it's ready.

struct CoachDrillsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let player: Player

    @State private var suggestions: [DrillSuggestion] = []
    @State private var selectedWeakness: SelectedWeakness?
    @State private var showingQuickDrill = false
    @State private var showingPaywall = false
    @State private var trainingLaunch: TrainingLaunch?

    var body: some View {
        TQScreen {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Drills from the coach") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                        TQEyebrow("Built around your weak spots")
                        TQDisplayTitle("Pick what to fix", size: .medium)
                        TQBody("Each one becomes a drill with a diagram in about twenty seconds.", tone: .base)

                        if suggestions.isEmpty {
                            TQRowList {
                                TQRow("No suggestions yet", note: "train a few sessions first").disabled(true)
                            }
                        } else {
                            TQRowList {
                                ForEach(suggestions) { suggestion in
                                    TQRow(
                                        suggestion.title,
                                        subtitle: "\(suggestion.weakness.category) · \(suggestion.difficulty.displayName)",
                                        leading: .tile(TQTile("AI", style: .ai)),
                                        accessory: .chevron,
                                        verticalPadding: DesignSystem.Spacing.rowVertical,
                                        action: { generate(suggestion) }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: loadSuggestions)
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: .quickDrill)
        }
        .sheet(isPresented: $showingQuickDrill) {
            QuickDrillSheet(player: player, onGenerated: { exercise in
                guard showingQuickDrill else { return }
                showingQuickDrill = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trainingLaunch = TrainingLaunch(exercises: [exercise])
                }
            }, prefilledWeakness: selectedWeakness)
        }
        .fullScreenCover(item: $trainingLaunch) { launch in
            ActiveTrainingView(exercises: launch.exercises)
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(authManager)
                .environmentObject(subscriptionManager)
        }
    }

    private func loadSuggestions() {
        let profile = WeaknessAnalysisService.shared.getCachedProfile(for: player)
            ?? WeaknessAnalysisService.shared.analyzeWeaknesses(for: player)
        suggestions = profile.suggestedWeaknesses.prefix(3).map { weakness in
            DrillSuggestion(
                weakness: weakness,
                title: weakness.specific,
                description: weakness.detail ?? "",
                difficulty: difficultyForPlayer()
            )
        }
    }

    private func difficultyForPlayer() -> DifficultyLevel {
        switch player.experienceLevel {
        case "Beginner": return .beginner
        case "Advanced", "Elite": return .advanced
        default: return .intermediate
        }
    }

    private func generate(_ suggestion: DrillSuggestion) {
        selectedWeakness = suggestion.weakness
        if subscriptionManager.canUseQuickDrill() {
            showingQuickDrill = true
        } else {
            showingPaywall = true
        }
    }
}
