import Foundation

// MARK: - Train library layout
//
// The Train screen groups the player's drills into "My drills" first, then one section per skill
// the player actually trains, with the long tail folded into "More skills" chips. The rules live
// here as pure functions over `TrainDrill` value copies so they are unit-testable; the view only
// converts `Exercise` rows and renders.

/// A drill as the Train screen needs it: a value copy of `Exercise`.
struct TrainDrill: Identifiable, Equatable {
    enum Source: Equatable {
        case template, ai, manual, community, video
    }

    let id: UUID
    var name: String
    var category: String?
    var difficulty: Int
    var minutes: Int
    var targetSkills: [String]
    var weaknessCategories: String?
    var source: Source
    var isFavorite: Bool
    var lastUsedAt: Date?
    var usageCount: Int

    /// Generated, written, saved from the community or pulled in as video: anything but the starter kit.
    var isMine: Bool { source != .template }
}

/// Maps a drill's free-text skill tags onto the ten canonical skills the app knows from onboarding.
enum TrainSkillMapper {
    /// Keyword table, checked in order; the first hit wins. Longer, more specific phrases first so
    /// "weak foot passing" maps to weak foot and "first touch" never falls through to "touch".
    private static let keywords: [(WeaknessCategory, [String])] = [
        (.weakFoot, ["weak foot", "weak-foot", "weaker foot", "weakfoot", "off foot", "left foot", "right foot"]),
        (.aerialAbility, ["aerial", "heading", "header", "headers", "in the air"]),
        (.firstTouch, ["first touch", "first-touch", "ball control", "control", "receiving", "touch"]),
        (.dribbling, ["dribbl", "1v1 attack", "beat a defender", "cone weave", "close control", "juggl"]),
        (.passing, ["pass", "crossing", "cross", "through ball", "vision", "distribution", "playmak"]),
        (.shooting, ["shoot", "finish", "strike", "volley", "goal scoring", "scoring", "accuracy"]),
        (.defending, ["defend", "tackl", "marking", "block", "intercept", "clearance", "press"]),
        (.speedAgility, ["speed", "agility", "sprint", "acceleration", "quickness", "footwork", "ladder", "coordination"]),
        (.stamina, ["stamina", "endurance", "fitness", "conditioning", "aerobic", "run"]),
        (.positioning, ["position", "awareness", "movement", "off the ball", "reading the game", "decision", "teamwork", "tactic", "spacing"])
    ]

    /// Canonical skill for a drill: explicit weakness categories win, then skill tags, then the name.
    static func skill(for drill: TrainDrill) -> WeaknessCategory? {
        if let explicit = drill.weaknessCategories?
            .split(separator: ",")
            .compactMap({ WeaknessCategory(rawValue: String($0.split(separator: ":").first ?? "").trimmingCharacters(in: .whitespaces)) })
            .first {
            return explicit
        }
        for tag in drill.targetSkills {
            if let match = skill(matching: tag) { return match }
        }
        return skill(matching: drill.name)
    }

    static func skill(matching text: String) -> WeaknessCategory? {
        let lowered = text.lowercased()
        if let exact = WeaknessCategory.allCases.first(where: { $0.rawValue.lowercased() == lowered || $0.displayName.lowercased() == lowered }) {
            return exact
        }
        for (skill, needles) in keywords where needles.contains(where: { lowered.contains($0) }) {
            return skill
        }
        return nil
    }
}

struct TrainLibraryLayout: Equatable {
    struct Section: Identifiable, Equatable {
        enum Kind: Hashable {
            case mine
            case skill(WeaknessCategory)
            /// Drills whose skill could not be mapped, grouped by category ("Other · Physical").
            case other(String)

            var title: String {
                switch self {
                case .mine: return "My drills"
                case .skill(let skill): return skill.displayName
                case .other(let category): return "Other · \(category)"
                }
            }

            var skill: WeaknessCategory? {
                if case .skill(let skill) = self { return skill }
                return nil
            }
        }

        let kind: Kind
        /// Every drill in the group, most recently used first.
        let drills: [TrainDrill]
        let isPinned: Bool

        var id: String { kind.title }
        var title: String { kind.title }
        var count: Int { drills.count }
        var preview: [TrainDrill] { Array(drills.prefix(TrainLibraryModel.previewCount)) }
    }

    /// Groups too small for a section of their own, offered as chips.
    var sections: [Section]
    var more: [Section]

    var isEmpty: Bool { sections.isEmpty && more.isEmpty }
}

enum TrainLibraryModel {
    static let previewCount = 3
    static let minimumSectionSize = 2

    /// Builds the Train layout.
    /// - "My drills" leads whenever the player has any drill of their own.
    /// - A skill gets a section with at least `minimumSectionSize` drills or when pinned; smaller
    ///   groups become "More skills" chips. Unmappable drills group by category and follow the skills.
    /// - Section order: pinned first, then by how much the player trains that skill (total uses, most
    ///   recent use), then the onboarding weak-spot order for players with no history, then size.
    static func build(drills: [TrainDrill], pinned: [WeaknessCategory], weakSpots: [WeaknessCategory], now: Date = Date()) -> TrainLibraryLayout {
        var sections: [TrainLibraryLayout.Section] = []
        var more: [TrainLibraryLayout.Section] = []

        let mine = orderedByUse(drills.filter(\.isMine))
        if !mine.isEmpty {
            sections.append(.init(kind: .mine, drills: mine, isPinned: false))
        }

        var bySkill: [WeaknessCategory: [TrainDrill]] = [:]
        var byOther: [String: [TrainDrill]] = [:]
        for drill in drills {
            if let skill = TrainSkillMapper.skill(for: drill) {
                bySkill[skill, default: []].append(drill)
            } else {
                let category = drill.source == .video ? "Video" : (drill.category?.capitalized ?? "Drills")
                byOther[category, default: []].append(drill)
            }
        }

        let weakSpotRank = Dictionary(uniqueKeysWithValues: weakSpots.enumerated().map { ($1, $0) })
        let ranked = bySkill.map { skill, group -> (skill: WeaknessCategory, group: [TrainDrill], pinned: Bool, uses: Int, latest: Date) in
            (skill, orderedByUse(group), pinned.contains(skill),
             group.reduce(0) { $0 + $1.usageCount },
             group.compactMap(\.lastUsedAt).max() ?? .distantPast)
        }.sorted { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned }
            if lhs.uses != rhs.uses { return lhs.uses > rhs.uses }
            if lhs.latest != rhs.latest { return lhs.latest > rhs.latest }
            let lRank = weakSpotRank[lhs.skill] ?? Int.max
            let rRank = weakSpotRank[rhs.skill] ?? Int.max
            if lRank != rRank { return lRank < rRank }
            if lhs.group.count != rhs.group.count { return lhs.group.count > rhs.group.count }
            return lhs.skill.displayName < rhs.skill.displayName
        }

        for entry in ranked {
            let section = TrainLibraryLayout.Section(kind: .skill(entry.skill), drills: entry.group, isPinned: entry.pinned)
            if entry.pinned || entry.group.count >= minimumSectionSize {
                sections.append(section)
            } else {
                more.append(section)
            }
        }

        for (category, group) in byOther.sorted(by: { $0.key < $1.key }) {
            let section = TrainLibraryLayout.Section(kind: .other(category), drills: orderedByUse(group), isPinned: false)
            if group.count >= minimumSectionSize {
                sections.append(section)
            } else {
                more.append(section)
            }
        }

        return TrainLibraryLayout(sections: sections, more: more)
    }

    /// Most recently used first, then most used, then by name.
    static func orderedByUse(_ drills: [TrainDrill]) -> [TrainDrill] {
        drills.sorted { lhs, rhs in
            let l = lhs.lastUsedAt ?? .distantPast
            let r = rhs.lastUsedAt ?? .distantPast
            if l != r { return l > r }
            if lhs.usageCount != rhs.usageCount { return lhs.usageCount > rhs.usageCount }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// "Today", "Yesterday", "3 days ago", "Last week", "2 weeks ago", "Last month", "3 months ago".
    static func relativeUse(_ date: Date?, now: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let date, date <= now else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days) days ago"
        case 7...13: return "Last week"
        case 14...27: return "\(days / 7) weeks ago"
        case 28...59: return "Last month"
        case 60...364: return "\(days / 30) months ago"
        default: return "Over a year ago"
        }
    }

    /// Row meta line: "Passing · Lvl 2 · 15′ · Yesterday". `showSkill` is false inside a skill section.
    static func meta(for drill: TrainDrill, showSkill: Bool, now: Date = Date()) -> String {
        var parts: [String] = []
        if drill.source == .video {
            parts.append("Video")
        } else if showSkill, let skill = TrainSkillMapper.skill(for: drill) {
            parts.append(skill.displayName)
        }
        if drill.difficulty > 0 { parts.append("Lvl \(drill.difficulty)") }
        if drill.minutes > 0 { parts.append("\(drill.minutes)′") }
        if let ago = relativeUse(drill.lastUsedAt, now: now) { parts.append(ago) }
        return parts.joined(separator: " · ")
    }
}
