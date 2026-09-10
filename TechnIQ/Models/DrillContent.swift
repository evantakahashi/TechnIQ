import Foundation

// MARK: - DrillContent
//
// Structured view of `Exercise.instructions`. The AI drill pipeline stores a markdown-ish block
// ("**Setup:**", "**Instructions:**" numbered steps, "**Coaching Points:**" bullets …); library and
// manual drills store plain numbered or line-separated steps. Screens read `steps` and
// `coachingPoints` from here instead of re-parsing.

struct DrillContent: Equatable {
    var setup: String?
    var steps: [String]
    var coachingPoints: [String]
    var variations: [String]
    var progressions: [String]
    var safetyNotes: String?

    static let empty = DrillContent(setup: nil, steps: [], coachingPoints: [], variations: [], progressions: [], safetyNotes: nil)

    /// Everything after the numbered steps that a player might want to read: coaching points,
    /// variations, progressions, safety notes (in that order).
    var extras: [String] {
        coachingPoints + variations + progressions + (safetyNotes.map { [$0] } ?? [])
    }

    static func parse(_ raw: String?) -> DrillContent {
        guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .empty }
        var content = DrillContent.empty
        var section = "instructions"
        var loose: [String] = []

        for rawLine in raw.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("**"), line.contains(":**") {
                let title = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: ":", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                section = title
                continue
            }
            if line.hasPrefix("**Generated:**") || line.hasPrefix("**Original Request:**") { continue }

            let numbered = line.replacingOccurrences(of: "^\\d+[.):]\\s*", with: "", options: .regularExpression)
            let bulleted = line.replacingOccurrences(of: "^[•\\-*]\\s*", with: "", options: .regularExpression)

            switch section {
            case "setup":
                content.setup = (content.setup.map { $0 + " " } ?? "") + line
            case "instructions", "steps":
                content.steps.append(numbered)
            case "coaching points", "coaching":
                content.coachingPoints.append(bulleted)
            case "variations":
                content.variations.append(bulleted)
            case "progressions":
                content.progressions.append(bulleted)
            case "safety notes", "safety":
                content.safetyNotes = (content.safetyNotes.map { $0 + " " } ?? "") + line
            default:
                loose.append(numbered != line ? numbered : bulleted)
            }
        }

        if content.steps.isEmpty { content.steps = loose }
        content.setup = content.setup?.trimmingCharacters(in: .whitespaces)
        content.safetyNotes = content.safetyNotes?.trimmingCharacters(in: .whitespaces)
        return content
    }

    /// Short cue for the active-session coach strip: first coaching point, else the setup line,
    /// else the current step.
    func coachCue(forStep index: Int) -> String? {
        if !coachingPoints.isEmpty { return coachingPoints[index % coachingPoints.count] }
        if let setup, !setup.isEmpty { return setup }
        guard !steps.isEmpty else { return nil }
        return steps[min(index, steps.count - 1)]
    }
}
