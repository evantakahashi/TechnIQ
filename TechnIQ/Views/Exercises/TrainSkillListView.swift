import SwiftUI
import CoreData

// MARK: - See all (one Train section)
//
// The flat list for one skill (or "My drills" / an "Other" group): nav bar with back and, for
// skills, Pin / Unpin; eyebrow, display title, a one-line summary; a Recent / Level / A–Z segment;
// All / Saved / Lvl 1–2 / Lvl 3+ chips; then rows with the heart. Pinned skills jump to the top of
// Train and show a PINNED tag on their section header.

struct TrainSkillListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let player: Player
    let kind: TrainLibraryLayout.Section.Kind
    let exercises: [Exercise]
    var onChange: () -> Void = {}

    @State private var sortIndex = 0
    @State private var filter: Filter = .all
    @State private var isPinned = false
    @State private var drillRoute: NSManagedObjectID?
    @State private var refreshToken = 0

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", saved = "Saved", easy = "Lvl 1–2", hard = "Lvl 3+"
        var id: String { rawValue }
    }

    // MARK: Derived

    private var members: [(drill: TrainDrill, exercise: Exercise)] {
        _ = refreshToken
        return exercises.compactMap { exercise in
            let drill = exercise.trainDrill
            let belongs: Bool
            switch kind {
            case .mine: belongs = drill.isMine
            case .skill(let skill): belongs = TrainSkillMapper.skill(for: drill) == skill
            case .other(let category):
                let unmapped = TrainSkillMapper.skill(for: drill) == nil
                let bucket = drill.source == .video ? "Video" : (drill.category?.capitalized ?? "Drills")
                belongs = unmapped && bucket == category
            }
            return belongs ? (drill, exercise) : nil
        }
    }

    private var visible: [(drill: TrainDrill, exercise: Exercise)] {
        var rows = members
        switch filter {
        case .all: break
        case .saved: rows = rows.filter { $0.drill.isFavorite }
        case .easy: rows = rows.filter { $0.drill.difficulty <= 2 }
        case .hard: rows = rows.filter { $0.drill.difficulty >= 3 }
        }
        switch sortIndex {
        case 1: return rows.sorted { ($0.drill.difficulty, $0.drill.name) < ($1.drill.difficulty, $1.drill.name) }
        case 2: return rows.sorted { $0.drill.name.localizedCaseInsensitiveCompare($1.drill.name) == .orderedAscending }
        default:
            let ordered = TrainLibraryModel.orderedByUse(rows.map(\.drill))
            let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.drill.id, $0) })
            return ordered.compactMap { byID[$0.id] }
        }
    }

    private var eyebrow: String {
        switch kind {
        case .mine: return "Yours"
        case .skill: return isPinned ? "Skill · pinned" : "Skill"
        case .other: return "Unsorted"
        }
    }

    private var summary: String {
        let all = members
        let uses = all.reduce(0) { $0 + $1.drill.usageCount }
        var parts = ["\(all.count) drill\(all.count == 1 ? "" : "s")"]
        if uses > 0 { parts.append("trained \(uses) time\(uses == 1 ? "" : "s")") }
        if let latest = all.compactMap(\.drill.lastUsedAt).max(), let ago = TrainLibraryModel.relativeUse(latest) {
            parts.append("last \(ago.lowercased())")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Train") {
                    TQBackButton { dismiss() }
                } trailing: {
                    if kind.skill != nil {
                        TQNavAction(isPinned ? "Unpin" : "Pin") { togglePin() }
                            .accessibilityIdentifier("skill.pin")
                    } else {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    TQEyebrow(eyebrow, size: 12)
                    TQDisplayTitle(kind.title, size: .small)
                    TQBody(summary, tone: .base, size: 14)
                }

                TQSegment(options: ["Recent", "Level", "A–Z"], selectedIndex: $sortIndex)

                TQChipRow {
                    ForEach(Filter.allCases) { option in
                        TQChip(option.rawValue, isSelected: filter == option) {
                            withAnimation(DesignSystem.Animation.quick) { filter = option }
                        }
                    }
                }

                let rows = visible
                if rows.isEmpty {
                    TQRowList {
                        TQRow("Nothing here", note: filter == .all ? "add a drill" : "try another chip").disabled(true)
                    }
                } else {
                    TQRowList {
                        ForEach(rows, id: \.drill.id) { entry in
                            TQRow(
                                entry.drill.name,
                                subtitle: TrainLibraryModel.meta(for: entry.drill, showSkill: kind.skill == nil),
                                leading: .tile(TQTile.category(entry.drill.category, isAI: entry.drill.source == .ai, isVideo: entry.drill.source == .video)),
                                accessory: .heart(isOn: entry.drill.isFavorite, action: { toggleFavorite(entry.exercise) }),
                                verticalPadding: DesignSystem.Spacing.rowVertical,
                                action: { drillRoute = entry.exercise.objectID }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { isPinned = kind.skill.map { player.pinnedSkillList.contains($0) } ?? false }
        .navigationDestination(item: $drillRoute) { objectID in
            if let exercise = try? viewContext.existingObject(with: objectID) as? Exercise {
                ExerciseDetailView(exercise: exercise, onFavoriteChanged: { refresh() }, onExerciseDeleted: { refresh() })
            }
        }
    }

    // MARK: Actions

    private func togglePin() {
        guard let skill = kind.skill else { return }
        var pins = player.pinnedSkillList
        if let index = pins.firstIndex(of: skill) {
            pins.remove(at: index)
        } else {
            pins.append(skill)
        }
        player.pinnedSkillList = pins
        CoreDataManager.shared.save()
        isPinned = pins.contains(skill)
        HapticManager.shared.selectionChanged()
        onChange()
    }

    private func toggleFavorite(_ exercise: Exercise) {
        CoreDataManager.shared.toggleFavorite(exercise: exercise)
        refresh()
    }

    private func refresh() {
        refreshToken += 1
        onChange()
    }
}
