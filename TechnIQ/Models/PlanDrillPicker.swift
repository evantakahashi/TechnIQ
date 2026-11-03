import Foundation

// MARK: - Plan drill picker
//
// Which drills a plan session gets. Plans fill only from the pre-built catalog drills plus the
// player's own AI and manual drills. AI plans suggest drill names: those match first (by name,
// then by skill). Anything left is filled from the catalog drills that suit the session type,
// two per session, rotating so consecutive sessions of a type don't repeat the same pair.
// Assessment (benchmark test) and match sessions get no drills.

struct PlanDrillCandidate: Equatable {
    let id: UUID
    let name: String
    /// Catalog key for pre-built drills; nil for the player's own drills.
    let prebuiltKey: String?
    let targetSkills: [String]
}

enum PlanDrillPicker {
    static let drillsPerSession = 2
    /// AI plans sometimes suggest three drills; keep at most this many name matches.
    static let maxMatched = 3

    /// Catalog drills that suit each session type, best fit first.
    static func preferredKeys(for type: SessionType) -> [String] {
        switch type {
        case .technical:
            return ["ball_control", "passing_accuracy", "dribbling_cones", "juggling", "shooting_practice"]
        case .physical:
            return ["sprint_training", "agility_ladder", "endurance_run"]
        case .tactical:
            return ["one_v_one", "small_sided_games"]
        case .recovery, .warmup, .cooldown:
            return ["ball_control", "juggling", "passing_accuracy"]
        case .match, .assessment:
            return []
        }
    }

    /// Session types that never get drills.
    static func takesNoDrills(_ type: SessionType) -> Bool {
        type == .assessment || type == .match
    }

    /// Picks drill ids for one session.
    /// - Parameter rotation: how many sessions of this type the plan has filled so far.
    static func pick(suggestedNames: [String],
                     sessionType: SessionType,
                     candidates: [PlanDrillCandidate],
                     rotation: Int) -> [UUID] {
        guard !takesNoDrills(sessionType) else { return [] }
        var picked: [UUID] = []

        for name in suggestedNames where picked.count < maxMatched {
            if let match = bestMatch(for: name, in: candidates.filter { !picked.contains($0.id) }) {
                picked.append(match.id)
            }
        }
        guard picked.count < drillsPerSession else { return picked }

        let catalog = candidates.filter { $0.prebuiltKey != nil }
        let byKey = Dictionary(catalog.map { ($0.prebuiltKey ?? "", $0) }, uniquingKeysWith: { first, _ in first })
        var pool = preferredKeys(for: sessionType).compactMap { byKey[$0] }
        if pool.isEmpty { pool = catalog }
        guard !pool.isEmpty else { return picked }

        let start = (max(0, rotation) * drillsPerSession) % pool.count
        for offset in 0..<pool.count where picked.count < drillsPerSession {
            let candidate = pool[(start + offset) % pool.count]
            if !picked.contains(candidate.id) { picked.append(candidate.id) }
        }
        return picked
    }

    // MARK: Matching

    /// Best candidate for a suggested drill name, or nil when nothing is close enough.
    static func bestMatch(for suggestion: String, in candidates: [PlanDrillCandidate]) -> PlanDrillCandidate? {
        let wanted = tokens(suggestion)
        guard !wanted.isEmpty else { return nil }
        let wantedText = wanted.joined(separator: " ")
        var best: (score: Double, candidate: PlanDrillCandidate)?
        for candidate in candidates {
            let score = matchScore(wanted: wanted, wantedText: wantedText, candidate: candidate)
            if score > (best?.score ?? 0) { best = (score, candidate) }
        }
        guard let best, best.score >= 0.5 else { return nil }
        return best.candidate
    }

    private static func matchScore(wanted: [String], wantedText: String, candidate: PlanDrillCandidate) -> Double {
        let name = tokens(candidate.name)
        guard !name.isEmpty else { return 0 }
        let nameText = name.joined(separator: " ")
        if nameText == wantedText { return 3 }
        if wantedText.contains(nameText) || nameText.contains(wantedText) { return 2 }
        let wantedSet = Set(wanted.map(stem)), nameSet = Set(name.map(stem))
        let overlap = Double(wantedSet.intersection(nameSet).count) / Double(wantedSet.union(nameSet).count)
        if overlap >= 0.5 { return 1 + overlap }
        // A skill named in the suggestion ("wall passing" → Passing) is a weaker match.
        let skillHits = candidate.targetSkills.filter { skill in
            let skillStems = Set(tokens(skill).map(stem))
            return !skillStems.isEmpty && skillStems.isSubset(of: wantedSet)
        }
        return skillHits.isEmpty ? 0 : 0.5 + 0.1 * Double(min(skillHits.count, 4))
    }

    private static let stopWords: Set<String> = ["the", "a", "an", "and", "with", "drill", "drills", "practice", "training", "session", "of", "for", "to", "in"]

    static func tokens(_ text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    /// Crude stem so "passing"/"passes"/"pass", "cones"/"cone" and "dribbling"/"dribble" meet.
    static func stem(_ word: String) -> String {
        for suffix in ["ing", "es", "s", "e"] where word.count > suffix.count + 2 && word.hasSuffix(suffix) {
            if suffix == "s" && word.hasSuffix("ss") { continue }
            return String(word.dropLast(suffix.count))
        }
        return word
    }
}
