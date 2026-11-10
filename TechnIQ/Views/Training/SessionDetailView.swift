import SwiftUI
import CoreData

// MARK: - Session detail (sheet from Session history)
//
// What was done: the session's name and date, its figures, the drills in order, any notes, and
// the one destructive action (delete, confirmed).

struct SessionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var session: TrainingSession

    @State private var confirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Session") {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                } trailing: {
                    TQNavAction("Done") { dismiss() }
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 8) {
                    TQEyebrow(dateLine, size: 11)
                    TQDisplayTitle(session.sessionType ?? "Training", size: .medium)
                    if let location = session.location, !location.isEmpty {
                        TQMeta(location, tone: .muted, size: 13, weight: .regular, uppercase: false)
                    }
                }

                TQStatRail(items: figures)

                if !drills.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Drills")
                        TQRowList {
                            ForEach(Array(drills.enumerated()), id: \.element.objectID) { index, drill in
                                TQRow(drill.exercise?.name ?? "Drill",
                                      subtitle: Self.subtitle(for: drill),
                                      leading: .index(String(format: "%02d", index + 1)),
                                      meta: drill.duration > 0 ? TQRow.Meta("\(Int(drill.duration)) min") : nil,
                                      accessory: .none)
                            }
                        }
                    }
                }

                if let notes = session.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        TQGroupHeader("Notes")
                        TQBody(notes)
                    }
                }

                TQButton("Delete session", style: .destructive) { confirmingDelete = true }
                    .padding(.top, DesignSystem.Spacing.sm)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .confirmationDialog("Delete this session?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete session", role: .destructive) { deleteSession() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It comes off your history and totals. This can't be undone.")
        }
    }

    // MARK: Derived

    private var drills: [SessionExercise] {
        let all = (session.exercises?.allObjects as? [SessionExercise]) ?? []
        return all.sorted { ($0.exercise?.name ?? "") < ($1.exercise?.name ?? "") }
    }

    private var figures: [TQStatRail.Item] {
        var items: [TQStatRail.Item] = [.init("\(Int(session.duration))", unit: "min", label: "trained")]
        if !drills.isEmpty {
            items.append(.init("\(drills.count)", label: drills.count == 1 ? "drill" : "drills"))
        }
        if let feel = SessionFeel(raw: session.feel) {
            items.append(.init(feel.label, label: "felt", accent: feel == .right))
        } else if session.intensity > 0 {
            items.append(.init("\(session.intensity)", unit: "/5", label: "intensity"))
        }
        return items
    }

    private var dateLine: String {
        guard let date = session.date else { return "Session" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM · HH:mm"
        return formatter.string(from: date)
    }

    private static func subtitle(for drill: SessionExercise) -> String? {
        var parts: [String] = []
        if drill.sets > 0 { parts.append("\(drill.sets) set\(drill.sets == 1 ? "" : "s")") }
        if drill.reps > 0 { parts.append("\(drill.reps) rep\(drill.reps == 1 ? "" : "s")") }
        if let notes = drill.notes, !notes.isEmpty { parts.append(notes) }
        if parts.isEmpty, let category = drill.exercise?.category, !category.isEmpty { parts.append(category) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func deleteSession() {
        dismiss()
        viewContext.delete(session)
        do {
            try viewContext.save()
            HapticManager.shared.success()
        } catch {
            viewContext.rollback()
            AppLogger.shared.error("Failed to delete session: \(error.localizedDescription)")
        }
    }
}
