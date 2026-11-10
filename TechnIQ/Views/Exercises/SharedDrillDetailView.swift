import SwiftUI

// MARK: - Community drill (Community → Drills → a drill)
//
// Read-only drill card from another player: who made it, the figures, the steps, and one action —
// save it to your library.

struct SharedDrillDetailView: View {
    let drill: SharedDrill

    @ObservedObject private var communityService = CommunityService.shared
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [])
    private var players: FetchedResults<Player>

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showReportAlert = false
    @State private var reportReason = ""

    private var player: Player? { players.first }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TQNavBar("Community drill") {
                    TQNavAction("Close") { dismiss() }
                } trailing: {
                    TQIconAction("flag", accessibilityLabel: "Report drill") { showReportAlert = true }
                }
                .padding(.top, 8)

                headerSection
                TQStatRail(items: figures)

                if !drill.targetSkills.isEmpty {
                    DrillFormGroup("Skills") {
                        TQBody(drill.targetSkills.joined(separator: " · "))
                    }
                }

                if !drill.equipment.isEmpty {
                    DrillFormGroup("Equipment") {
                        TQBody(drill.equipment.joined(separator: " · "))
                    }
                }

                if !drill.steps.isEmpty {
                    stepsSection
                }

                saveSection
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Report drill", isPresented: $showReportAlert) {
            TextField("Reason", text: $reportReason)
            Button("Report", role: .destructive) {
                Task {
                    try? await communityService.reportDrill(drill, reason: reportReason)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Why are you reporting this drill?")
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TQEyebrow("\(drill.category) · by \(drill.authorName)")
                    .lineLimit(1)
                TQBadge(difficulty: String(drill.difficulty))
            }
            TQDisplayTitle(drill.title, size: .medium)
            if !drill.description.isEmpty {
                TQBody(drill.description)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var figures: [TQStatRail.Item] {
        var items: [TQStatRail.Item] = [.init("\(drill.duration)", unit: "min", label: "duration")]
        if drill.sets > 0 && drill.reps > 0 {
            items.append(.init("\(drill.sets)×\(drill.reps)", label: "sets × reps"))
        }
        items.append(.init("\(drill.saveCount)", label: drill.saveCount == 1 ? "save" : "saves"))
        items.append(.init("\(drill.authorLevel)", unit: "lvl", label: "author"))
        return items
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Steps")
            ForEach(Array(drill.steps.enumerated()), id: \.offset) { index, step in
                TQIndexRow(index: String(format: "%02d", index + 1), text: step)
            }
            TQRule()
        }
    }

    @ViewBuilder
    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let saveError {
                TQBanner(.error, lead: "Couldn't save.", message: saveError)
            }
            if let player {
                if drill.isSavedByCurrentUser {
                    TQButton("Saved to library", icon: "checkmark", style: .raised) {}
                        .disabled(true)
                } else {
                    TQButton("Save to library", isLoading: isSaving) {
                        saveDrill(player: player)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func saveDrill(player: Player) {
        isSaving = true
        saveError = nil
        Task {
            do {
                try await communityService.saveDrillToLibrary(drill: drill, player: player, context: context)
                HapticManager.shared.success()
            } catch {
                saveError = error.localizedDescription
                HapticManager.shared.error()
            }
            isSaving = false
        }
    }
}
