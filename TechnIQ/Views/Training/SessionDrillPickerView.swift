import SwiftUI
import CoreData

// MARK: - Pick drills for a plan day
//
// Shown when today's plan session has no drills attached. The player picks from their library
// (most recently used first, searchable), the picks are saved onto the plan session so the day
// remembers them, and the live pitch starts. Replaces the old manual session logger, so every
// session is recorded by the one engine.

struct SessionDrillPickerView: View {
    /// `.start` saves the picks onto the plan session and starts training; `.add` just hands them back
    /// (the plan editor's "+ Add drill").
    enum Mode { case start, add }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    let player: Player
    let planSession: PlanSession?
    var mode: Mode = .start
    var excluding: Set<UUID> = []
    let onStart: ([Exercise]) -> Void

    @State private var library: [Exercise] = []
    @State private var picked: [NSManagedObjectID] = []
    @State private var query = ""

    private var visible: [Exercise] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return library }
        return library.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(trimmed)
                || ($0.targetSkills ?? []).contains { $0.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    private var pickedExercises: [Exercise] {
        picked.compactMap { id in library.first { $0.objectID == id } }
    }

    private var totalMinutes: Int {
        pickedExercises.reduce(0) { $0 + max(1, Int($1.estimatedDurationSeconds) / 60) }
    }

    private var sessionEyebrow: String {
        guard let planSession else { return "Today" }
        let type = SessionType(rawValue: planSession.sessionType ?? "")?.displayName ?? "Training"
        return "Today · \(type) · \(planSession.duration) min"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar(mode == .start ? "Pick drills" : "Add drills") {
                        TQNavAction("Cancel") { dismiss() }
                    } trailing: {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        TQEyebrow(sessionEyebrow, size: 11)
                        TQDisplayTitle(mode == .start ? "What will\nyou run?" : "Add from\nyour library", size: .medium)
                        TQBody(mode == .start
                               ? "This day has no drills attached yet. Pick from your library and they stay on the day."
                               : "Tap drills in the order you want them. They are added to this session.")
                    }

                    TQSearchField("Search \(library.count) drills", text: $query)

                    if visible.isEmpty {
                        TQRowList {
                            TQRow(library.isEmpty ? "Your library is empty" : "No drills match \"\(query)\"",
                                  note: library.isEmpty ? "add a drill from Train" : "clear the search").disabled(true)
                        }
                    } else {
                        TQRowList {
                            ForEach(visible, id: \.objectID) { exercise in
                                row(exercise)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            VStack(spacing: 6) {
                TQButton(startTitle, icon: mode == .start ? "play.fill" : "plus") { start() }
                    .disabled(picked.isEmpty)
                    .accessibilityIdentifier("picker.start")
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(DesignSystem.Colors.surfaceBase)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear(perform: load)
    }

    private var startTitle: String {
        let count = "\(picked.count) drill\(picked.count == 1 ? "" : "s")"
        switch mode {
        case .start:
            guard !picked.isEmpty else { return "Pick a drill to start" }
            return "Start · \(count) · \(totalMinutes) min"
        case .add:
            guard !picked.isEmpty else { return "Pick drills to add" }
            return "Add · \(count) · \(totalMinutes) min"
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let drill = exercise.trainDrill
        let position = picked.firstIndex(of: exercise.objectID)
        return TQRow(
            drill.name,
            subtitle: TrainLibraryModel.meta(for: drill, showSkill: true),
            leading: position.map { .index("\($0 + 1)") } ?? .tile(TQTile.category(drill.category, isAI: drill.source == .ai, isVideo: drill.source == .video)),
            badge: position == nil ? nil : TQBadge(.status("Added")),
            accessory: .none,
            verticalPadding: DesignSystem.Spacing.rowVertical,
            titleColor: position == nil ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.grass,
            action: { toggle(exercise) }
        )
    }

    private func toggle(_ exercise: Exercise) {
        HapticManager.shared.selectionChanged()
        if let index = picked.firstIndex(of: exercise.objectID) {
            picked.remove(at: index)
        } else {
            picked.append(exercise.objectID)
        }
    }

    private func load() {
        let exercises = CoreDataManager.shared.fetchExercises(for: player).filter { exercise in
            guard let id = exercise.id else { return true }
            return !excluding.contains(id)
        }
        let byID = Dictionary(exercises.map { ($0.trainDrill.id, $0) }, uniquingKeysWith: { first, _ in first })
        library = TrainLibraryModel.orderedByUse(exercises.map(\.trainDrill)).compactMap { byID[$0.id] }
    }

    private func start() {
        let exercises = pickedExercises
        guard !exercises.isEmpty else { return }
        if mode == .start, let planSession {
            planSession.exercises = NSSet(array: exercises)
            try? viewContext.save()
        }
        dismiss()
        onStart(exercises)
    }
}
