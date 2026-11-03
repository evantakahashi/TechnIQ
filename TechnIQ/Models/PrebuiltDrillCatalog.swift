import Foundation

// MARK: - Pre-built drills
//
// The ten drills that ship with the app. Content lives in scripts/prebuilt_drills/drills.json;
// scripts/compile_prebuilt_drills.py runs each DSL through the server's deterministic drill
// pipeline and writes `PrebuiltDrillCatalog.all` (PrebuiltDrillCatalog+Generated.swift) with the
// compiled diagram and film. Plans and Train fill from these plus the player's own drills.

struct PrebuiltDrill: Identifiable, Equatable {
    /// Stable key, persisted on `Exercise.prebuiltKey` and synced — never rename.
    let key: String
    /// Display name. Matches the names the app seeded before 1.1 so old rows can be upgraded.
    let name: String
    let category: String
    let difficulty: Int
    let summary: String
    let targetSkills: [String]
    let durationMinutes: Int
    let steps: [String]
    let coachingPoint: String
    /// Short imperative shown as Home's coach line and the in-session COACH banner.
    let cue: String
    let equipment: [String]
    let space: String
    let unlockCriteria: UnlockCriteria
    /// Bundled demo clip, e.g. "juggling.mp4". To add one: drop the file into the TechnIQ target
    /// (Copy Bundle Resources), set `videoClip` in drills.json and rerun the compile script.
    let videoClip: String?
    let dsl: String
    let diagramJSON: String
    let animationJSON: String

    var id: String { key }

    /// `Exercise.instructions` in the block format `DrillContent.parse` reads.
    var instructionsText: String {
        var text = "**Instructions:**\n"
        for (index, step) in steps.enumerated() {
            text += "\(index + 1). \(step)\n"
        }
        text += "\n**Coaching Points:**\n• \(coachingPoint)"
        return text
    }

    var diagram: DrillDiagram? {
        guard let data = diagramJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(DrillDiagram.self, from: data)
    }

    /// The bundled clip, when one has been added.
    var videoURL: URL? {
        guard let videoClip, !videoClip.isEmpty else { return nil }
        let file = videoClip as NSString
        let ext = file.pathExtension.isEmpty ? "mp4" : file.pathExtension
        return Bundle.main.url(forResource: file.deletingPathExtension, withExtension: ext)
    }
}

enum PrebuiltDrillCatalog {
    static func drill(forKey key: String?) -> PrebuiltDrill? {
        guard let key, !key.isEmpty else { return nil }
        return all.first { $0.key == key }
    }

    /// Case- and whitespace-insensitive name lookup (old seeded rows carry only a name).
    static func drill(named name: String?) -> PrebuiltDrill? {
        guard let wanted = name.map(normalized), !wanted.isEmpty else { return nil }
        return all.first { normalized($0.name) == wanted }
    }

    private static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
