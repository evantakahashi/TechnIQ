import Foundation

// MARK: - Template Exercise Library
// Pre-defined exercises for use in training plans and AI-generated content

struct TemplateExercise {
    let name: String
    let category: String
    let difficulty: String
    let description: String
}

class TemplateExerciseLibrary {

    // MARK: - Singleton
    static let shared = TemplateExerciseLibrary()
    private init() {}

    // MARK: - Exercise Collections

    let technicalExercises: [TemplateExercise] = [
        // Ball Mastery
        TemplateExercise(
            name: "Cone Weaving",
            category: "Technical",
            difficulty: "Beginner",
            description: "Dribble through cones in a zig-zag pattern using both feet"
        ),
        TemplateExercise(
            name: "Inside-Outside Touches",
            category: "Technical",
            difficulty: "Beginner",
            description: "Alternate between inside and outside of foot touches"
        ),
        TemplateExercise(
            name: "Sole Rolls",
            category: "Technical",
            difficulty: "Beginner",
            description: "Roll ball with sole of foot, alternating feet"
        ),

        // Passing
        TemplateExercise(
            name: "Wall Passing",
            category: "Technical",
            difficulty: "Beginner",
            description: "Pass against wall with alternating feet, controlling return"
        ),
        TemplateExercise(
            name: "Triangle Passing Drill",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Pass in triangular pattern with multiple players"
        ),
        TemplateExercise(
            name: "Long Pass Accuracy",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Practice long-distance passing to targets"
        ),

        // Shooting
        TemplateExercise(
            name: "Instep Shooting",
            category: "Technical",
            difficulty: "Beginner",
            description: "Practice shooting with laces from various distances"
        ),
        TemplateExercise(
            name: "Finishing in the Box",
            category: "Technical",
            difficulty: "Intermediate",
            description: "One-touch finishing from crosses and through balls"
        ),
        TemplateExercise(
            name: "Volleys and Half-Volleys",
            category: "Technical",
            difficulty: "Advanced",
            description: "Practice striking ball in air from different angles"
        ),

        // First Touch
        TemplateExercise(
            name: "Cushion Control",
            category: "Technical",
            difficulty: "Beginner",
            description: "Control high balls with chest, thigh, and foot"
        ),
        TemplateExercise(
            name: "First Touch Turning",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Receive ball and turn in one motion"
        ),

        // Dribbling
        TemplateExercise(
            name: "Speed Dribbling",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Dribble at speed while maintaining control"
        ),
        TemplateExercise(
            name: "1v1 Moves",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Practice step-overs, feints, and changes of direction"
        ),
        TemplateExercise(
            name: "Tight Space Dribbling",
            category: "Technical",
            difficulty: "Advanced",
            description: "Maintain possession in confined areas with pressure"
        )
    ]

    let physicalExercises: [TemplateExercise] = [
        // Cardio
        TemplateExercise(
            name: "Interval Sprints",
            category: "Physical",
            difficulty: "Beginner",
            description: "Sprint 30 seconds, jog 30 seconds, repeat"
        ),
        TemplateExercise(
            name: "Shuttle Runs",
            category: "Physical",
            difficulty: "Intermediate",
            description: "Sprint between markers with quick direction changes"
        ),
        TemplateExercise(
            name: "Fartlek Training",
            category: "Physical",
            difficulty: "Intermediate",
            description: "Continuous run with varied intensity intervals"
        ),

        // Strength
        TemplateExercise(
            name: "Bodyweight Squats",
            category: "Physical",
            difficulty: "Beginner",
            description: "Perform squats with proper form for leg strength"
        ),
        TemplateExercise(
            name: "Push-Ups",
            category: "Physical",
            difficulty: "Beginner",
            description: "Upper body strength training"
        ),
        TemplateExercise(
            name: "Plank Holds",
            category: "Physical",
            difficulty: "Beginner",
            description: "Core stability exercise"
        ),
        TemplateExercise(
            name: "Lunges",
            category: "Physical",
            difficulty: "Intermediate",
            description: "Forward and reverse lunges for leg strength"
        ),

        // Agility
        TemplateExercise(
            name: "Ladder Drills",
            category: "Physical",
            difficulty: "Intermediate",
            description: "Quick feet exercises through agility ladder"
        ),
        TemplateExercise(
            name: "Cone Hops",
            category: "Physical",
            difficulty: "Intermediate",
            description: "Lateral and forward hops over cones"
        ),
        TemplateExercise(
            name: "Box Jumps",
            category: "Physical",
            difficulty: "Advanced",
            description: "Explosive power training with box jumps"
        ),

        // Flexibility
        TemplateExercise(
            name: "Dynamic Stretching",
            category: "Physical",
            difficulty: "Beginner",
            description: "Active stretching routine for warm-up"
        ),
        TemplateExercise(
            name: "Static Stretching",
            category: "Physical",
            difficulty: "Beginner",
            description: "Hold stretches for 20-30 seconds each"
        )
    ]

    let tacticalExercises: [TemplateExercise] = [
        // Positional
        TemplateExercise(
            name: "Positioning Drills",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Practice proper positioning for your role"
        ),
        TemplateExercise(
            name: "Defensive Shape",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Maintain defensive organization and compactness"
        ),
        TemplateExercise(
            name: "Attacking Movement",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Practice runs and movement in attacking third"
        ),

        // Game Situations
        TemplateExercise(
            name: "Small-Sided Games",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "3v3 or 4v4 to practice decision-making"
        ),
        TemplateExercise(
            name: "Pressing Drills",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Practice team pressing and triggering points"
        ),
        TemplateExercise(
            name: "Transition Play",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Quick switches between attack and defense"
        ),

        // Set Pieces
        TemplateExercise(
            name: "Corner Kick Practice",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Practice attacking and defending corners"
        ),
        TemplateExercise(
            name: "Free Kick Routines",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Set plays from free kicks"
        )
    ]

    let recoveryExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "Light Jogging",
            category: "Recovery",
            difficulty: "Beginner",
            description: "20-30 minutes of easy-pace jogging"
        ),
        TemplateExercise(
            name: "Foam Rolling",
            category: "Recovery",
            difficulty: "Beginner",
            description: "Self-myofascial release for muscle recovery"
        ),
        TemplateExercise(
            name: "Yoga Flow",
            category: "Recovery",
            difficulty: "Beginner",
            description: "Gentle yoga for flexibility and recovery"
        ),
        TemplateExercise(
            name: "Swimming",
            category: "Recovery",
            difficulty: "Beginner",
            description: "Low-impact cardio for active recovery"
        )
    ]

    // MARK: - Helper Methods

    /// Get all exercises across all categories
    var allExercises: [TemplateExercise] {
        technicalExercises + physicalExercises + tacticalExercises + recoveryExercises
    }

    /// Find exercises by category
    func exercises(for category: String) -> [TemplateExercise] {
        switch category.lowercased() {
        case "technical":
            return technicalExercises
        case "physical":
            return physicalExercises
        case "tactical":
            return tacticalExercises
        case "recovery":
            return recoveryExercises
        default:
            return []
        }
    }

    /// Find exercise by name (fuzzy matching)
    func findExercise(byName name: String) -> TemplateExercise? {
        let lowercasedName = name.lowercased()

        // Exact match first
        if let exact = allExercises.first(where: { $0.name.lowercased() == lowercasedName }) {
            return exact
        }

        // Partial match
        if let partial = allExercises.first(where: { $0.name.lowercased().contains(lowercasedName) }) {
            return partial
        }

        // Fuzzy match based on keywords
        return allExercises.first { exercise in
            let exerciseWords = Set(exercise.name.lowercased().split(separator: " ").map(String.init))
            let searchWords = Set(lowercasedName.split(separator: " ").map(String.init))
            return !exerciseWords.isDisjoint(with: searchWords)
        }
    }

    /// Get random exercises for a session type
    func randomExercises(for sessionType: String, count: Int, difficulty: String? = nil) -> [TemplateExercise] {
        var pool = exercises(for: sessionType)

        // Filter by difficulty if specified
        if let difficulty = difficulty {
            pool = pool.filter { $0.difficulty == difficulty }
        }

        // If pool is empty after filtering, use all exercises for that type
        if pool.isEmpty {
            pool = exercises(for: sessionType)
        }

        // Return random selection
        return Array(pool.shuffled().prefix(count))
    }
}
