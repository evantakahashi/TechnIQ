import CoreData

// MARK: - Pre-built drill seeding
//
// Keeps a player's rows in step with `PrebuiltDrillCatalog`:
//  1. Adopt: a starter row seeded before 1.1 (template source or the old "Follow standard …"
//     placeholder, no prebuiltKey) whose name matches a catalog drill gets the catalog content.
//     Its id, favorite, notes and last-used date are kept.
//  2. Refresh: rows that already carry a key get the current compiled diagram, film, DSL and
//     unlock criteria (fields the player can't edit), so a content update reaches old installs.
//  3. Create (when asked): any catalog drill the player has no row for.
// Idempotent: a second run changes nothing.

enum PrebuiltDrillSeeder {
    /// Old seeded rows carried this placeholder instead of real steps.
    static let legacyPlaceholderPrefix = "Follow standard"

    /// Returns the player's catalog rows by key, after adopting/refreshing (and creating, if asked).
    /// Does not save.
    @discardableResult
    static func sync(player: Player, context: NSManagedObjectContext, createMissing: Bool) -> (rows: [String: Exercise], changed: Bool) {
        let request: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let existing = (try? context.fetch(request)) ?? []

        var rows: [String: Exercise] = [:]
        var changed = false

        // Rows that already carry a key: refresh compiled assets.
        for exercise in existing {
            guard let key = exercise.prebuiltKey, let drill = PrebuiltDrillCatalog.drill(forKey: key) else { continue }
            if rows[key] == nil { rows[key] = exercise }
            changed = exercise.applyCatalogAssets(drill) || changed
        }

        // Old starter rows: adopt by name (first match per key wins; duplicates are left alone).
        for exercise in existing where isAdoptable(exercise) {
            guard let drill = PrebuiltDrillCatalog.drill(named: exercise.name), rows[drill.key] == nil else { continue }
            exercise.applyCatalogContent(drill)
            rows[drill.key] = exercise
            changed = true
        }

        if createMissing {
            for drill in PrebuiltDrillCatalog.all where rows[drill.key] == nil {
                let exercise = Exercise(context: context)
                exercise.id = UUID()
                exercise.isYouTubeContent = false
                exercise.applyCatalogContent(drill)
                exercise.player = player
                rows[drill.key] = exercise
                changed = true
            }
        }
        return (rows, changed)
    }

    /// A pre-1.1 starter row: no key, and either tagged as a template or holding the placeholder.
    static func isAdoptable(_ exercise: Exercise) -> Bool {
        guard exercise.prebuiltKey == nil else { return false }
        if exercise.source == TrainDrill.Source.template.rawValue { return true }
        return exercise.source == nil
            && (exercise.instructions ?? "").hasPrefix(legacyPlaceholderPrefix)
    }
}
