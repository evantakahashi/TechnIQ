import Foundation

// MARK: - Exercise content accessors
//
// One place for the drill fields screens read: the coach cue (Home's coach line and the
// in-session COACH banner both use `coachCue`), kit list, unlock criteria and the catalog entry.

extension Exercise {
    /// The drill's one-line cue: the `cue` field, else its first coaching point, else nil.
    var coachCue: String? {
        Self.coachCue(cue: cue, instructions: instructions)
    }

    static func coachCue(cue: String?, instructions: String?) -> String? {
        if let cue = cue?.trimmingCharacters(in: .whitespacesAndNewlines), !cue.isEmpty {
            return cue
        }
        let point = DrillContent.parse(instructions).coachingPoints.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (point?.isEmpty ?? true) ? nil : point
    }

    /// `equipment` split into items ("1 ball", "4 cones").
    var equipmentList: [String] {
        Self.equipmentList(from: equipment)
    }

    static func equipmentList(from text: String?) -> [String] {
        (text ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Stored form of an item list (nil when empty).
    static func equipmentText(_ items: [String]) -> String? {
        let cleaned = items
            .map { $0.replacingOccurrences(of: ",", with: " ").trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
    }

    /// What mastering this drill takes; drills without their own criteria get the default.
    var unlockCriteria: UnlockCriteria {
        UnlockCriteria.decode(unlockCriteriaJSON) ?? .default
    }

    /// The catalog entry this row was seeded from, if any.
    var prebuiltDrill: PrebuiltDrill? {
        PrebuiltDrillCatalog.drill(forKey: prebuiltKey)
    }

    /// Writes a catalog drill's full content onto this row, keeping the player's own fields (id,
    /// favorite, notes, last used). Returns true when anything changed.
    @discardableResult
    func applyCatalogContent(_ drill: PrebuiltDrill) -> Bool {
        var changed = false
        func set<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<Exercise, T>, _ value: T) {
            if self[keyPath: keyPath] != value {
                self[keyPath: keyPath] = value
                changed = true
            }
        }
        set(\.prebuiltKey, drill.key)
        set(\.source, TrainDrill.Source.template.rawValue)
        set(\.name, drill.name)
        set(\.category, drill.category)
        set(\.difficulty, Int16(drill.difficulty))
        set(\.exerciseDescription, drill.summary)
        set(\.targetSkills, drill.targetSkills)
        set(\.instructions, drill.instructionsText)
        set(\.estimatedDurationSeconds, Int16(drill.durationMinutes * 60))
        set(\.cue, drill.cue)
        set(\.equipment, Self.equipmentText(drill.equipment))
        set(\.space, drill.space)
        changed = applyCatalogAssets(drill) || changed
        if changed { updatedAt = Date() }
        return changed
    }

    /// Refreshes the compiled parts the player can't edit (diagram, film, DSL, unlock criteria)
    /// and fills content fields that are still empty. Returns true when anything changed.
    @discardableResult
    func applyCatalogAssets(_ drill: PrebuiltDrill) -> Bool {
        var changed = false
        func set(_ keyPath: ReferenceWritableKeyPath<Exercise, String?>, _ value: String?, onlyIfEmpty: Bool = false) {
            let current = self[keyPath: keyPath]
            if onlyIfEmpty, let current, !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
            if current != value {
                self[keyPath: keyPath] = value
                changed = true
            }
        }
        set(\.diagramJSON, drill.diagramJSON)
        set(\.animationJSON, drill.animationJSON)
        set(\.dsl, drill.dsl)
        // Compare decoded values: two encodings of the same criteria must not count as a change.
        if UnlockCriteria.decode(unlockCriteriaJSON) != drill.unlockCriteria {
            unlockCriteriaJSON = drill.unlockCriteria.encoded()
            changed = true
        }
        set(\.cue, drill.cue, onlyIfEmpty: true)
        set(\.equipment, Self.equipmentText(drill.equipment), onlyIfEmpty: true)
        set(\.space, drill.space, onlyIfEmpty: true)
        if changed { updatedAt = Date() }
        return changed
    }
}
