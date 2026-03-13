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

    // MARK: - Weak Foot Exercises

    let weakFootExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "Weak Foot Wall Passes",
            category: "Technical",
            difficulty: "Beginner",
            description: "Pass against a wall using only your weaker foot, focusing on accuracy and weight of pass"
        ),
        TemplateExercise(
            name: "Weak Foot Shooting Circuit",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Shoot from multiple angles and distances using only your non-dominant foot"
        ),
        TemplateExercise(
            name: "Non-Dominant Dribbling Gates",
            category: "Technical",
            difficulty: "Beginner",
            description: "Dribble through a series of cone gates using only your weaker foot"
        ),
        TemplateExercise(
            name: "Weak Foot Crossing Practice",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Deliver crosses into the box from wide positions using your non-dominant foot"
        ),
        TemplateExercise(
            name: "Weak Foot First Touch",
            category: "Technical",
            difficulty: "Beginner",
            description: "Receive and control balls of varying height and speed using only your weaker foot"
        ),
        TemplateExercise(
            name: "Weak Foot Juggling Progression",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Juggle the ball using only your weaker foot, progressing from 10 to 50 consecutive touches"
        ),
        TemplateExercise(
            name: "Weak Foot Passing Patterns",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Complete passing sequences with a partner using only your non-dominant foot for all passes"
        ),
        TemplateExercise(
            name: "Weak Foot Volleys",
            category: "Technical",
            difficulty: "Advanced",
            description: "Strike volleys and half-volleys with your weaker foot from tossed or crossed balls"
        ),
        TemplateExercise(
            name: "Weak Foot Finesse Shooting",
            category: "Technical",
            difficulty: "Advanced",
            description: "Practice curling shots into corners using the inside of your non-dominant foot"
        ),
        TemplateExercise(
            name: "Weak Foot Speed Dribble",
            category: "Technical",
            difficulty: "Intermediate",
            description: "Sprint with the ball over 30-40 meters controlling exclusively with your weaker foot"
        )
    ]

    // MARK: - Defending Exercises

    let defendingExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "1v1 Channel Defending",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Defend in a narrow channel forcing the attacker to one side while staying on your feet"
        ),
        TemplateExercise(
            name: "Recovery Run Drill",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Sprint to recover defensive position after being beaten, angling the run to cut off the attacker"
        ),
        TemplateExercise(
            name: "Pressing Trigger Exercise",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Identify and react to pressing triggers such as a poor touch or backwards pass to win the ball"
        ),
        TemplateExercise(
            name: "Aerial Duel Practice",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Practice timing jumps, body positioning, and heading clearances in aerial challenges"
        ),
        TemplateExercise(
            name: "Defensive Positioning Shadow Drill",
            category: "Tactical",
            difficulty: "Beginner",
            description: "Mirror an attacker's movements without the ball, maintaining correct body shape and distance"
        ),
        TemplateExercise(
            name: "Interception Timing Drill",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Read passing lanes and step in to intercept passes at the right moment"
        ),
        TemplateExercise(
            name: "Sliding Tackle Technique",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Practice safe and effective sliding tackle form on a padded surface"
        ),
        TemplateExercise(
            name: "Defensive Header Practice",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Clear crossed and lofted balls with powerful, directed defensive headers"
        ),
        TemplateExercise(
            name: "Cover and Balance Positioning",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Practice providing cover for a pressing teammate while maintaining balance across the backline"
        ),
        TemplateExercise(
            name: "Defensive Block Drill",
            category: "Tactical",
            difficulty: "Beginner",
            description: "Practice shot-blocking technique with correct body positioning to deflect or absorb strikes"
        )
    ]

    // MARK: - Under Pressure Exercises

    let underPressureExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "Rondo 3v1",
            category: "Tactical",
            difficulty: "Beginner",
            description: "Three players keep possession against one defender in a tight grid, emphasizing quick passing"
        ),
        TemplateExercise(
            name: "Rondo 4v2",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Four attackers maintain possession against two defenders, focusing on body shape and first touch"
        ),
        TemplateExercise(
            name: "Rondo 5v2",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Five attackers vs two defenders in a larger grid, practicing split passes and movement off the ball"
        ),
        TemplateExercise(
            name: "Pressing Escape Drill",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Receive the ball under immediate pressure and find a pass, turn, or dribble to escape the press"
        ),
        TemplateExercise(
            name: "Tight Space Turning",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Receive and turn in a small area with a passive then active defender closing in"
        ),
        TemplateExercise(
            name: "Receive and Turn Under Pressure",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Check to the ball, receive with back to goal, and turn past a defender using Cruyff turns, hooks, or roll-behinds"
        ),
        TemplateExercise(
            name: "Two-Touch Passing Under Press",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Complete passing circuits with a maximum of two touches while defenders apply progressive pressure"
        ),
        TemplateExercise(
            name: "Decision Making Under Pressure",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Receive in central areas with multiple options and choose the best action while being closed down"
        ),
        TemplateExercise(
            name: "Shielding the Ball",
            category: "Technical",
            difficulty: "Beginner",
            description: "Use body strength and positioning to protect the ball from a defender applying pressure from behind"
        ),
        TemplateExercise(
            name: "Quick Combination Play",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Execute rapid one-two and third-man combinations to break through pressing opponents"
        )
    ]

    // MARK: - Game-Realistic Scenario Exercises

    let gameScenarioExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "Counter-Attack Transition",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Win the ball and launch a fast break with direct passing and forward runs within 10 seconds"
        ),
        TemplateExercise(
            name: "Overlapping Run Patterns",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Practice timed overlapping runs between fullback and winger to create 2v1 situations"
        ),
        TemplateExercise(
            name: "Switching Play Exercise",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Move the ball from one side of the field to the other quickly to exploit space behind the defense"
        ),
        TemplateExercise(
            name: "Build-Up From Back",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Play out from the goalkeeper through defenders and midfielders under opposition pressure"
        ),
        TemplateExercise(
            name: "Final Third Combinations",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Practice wall passes, through balls, and cutbacks in and around the penalty area to create scoring chances"
        ),
        TemplateExercise(
            name: "Wing Play and Crossing",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Beat a defender on the wing and deliver crosses to runners attacking near post, far post, and cutback zones"
        ),
        TemplateExercise(
            name: "Set Piece Routines",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Rehearse coordinated free kick and corner routines with decoy runs and set delivery targets"
        ),
        TemplateExercise(
            name: "Transition Defense to Attack",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Practice regaining possession and immediately transitioning into an organized attacking move"
        ),
        TemplateExercise(
            name: "Positional Rotation Play",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Rotate positions fluidly in a small group to confuse defenders while maintaining team shape"
        ),
        TemplateExercise(
            name: "Through Ball Timing",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Time forward runs to receive through balls between or behind defensive lines without being offside"
        )
    ]

    // MARK: - Mental and Decision-Making Exercises

    let mentalExercises: [TemplateExercise] = [
        TemplateExercise(
            name: "Scanning Drill",
            category: "Tactical",
            difficulty: "Beginner",
            description: "Check shoulders before receiving the ball, calling out the number of fingers a coach holds up behind you"
        ),
        TemplateExercise(
            name: "Decision Gates",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Dribble toward color-coded gates and choose the correct one based on a coach's call or visual cue"
        ),
        TemplateExercise(
            name: "Reaction-Based Passing",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Pass to targets that light up or are called out randomly, training quick recognition and execution"
        ),
        TemplateExercise(
            name: "Visual Awareness Exercise",
            category: "Tactical",
            difficulty: "Intermediate",
            description: "Navigate a dribbling course while identifying and avoiding randomly moving obstacles or players"
        ),
        TemplateExercise(
            name: "Communication Drill",
            category: "Tactical",
            difficulty: "Beginner",
            description: "Practice verbal and non-verbal communication during possession, calling for the ball and directing teammates"
        ),
        TemplateExercise(
            name: "Cognitive Overload Training",
            category: "Tactical",
            difficulty: "Advanced",
            description: "Perform technical tasks while simultaneously solving mental challenges like math problems or color sequences"
        )
    ]

    // MARK: - Helper Methods

    /// Get all exercises across all categories
    var allExercises: [TemplateExercise] {
        technicalExercises + physicalExercises + tacticalExercises + recoveryExercises
        + weakFootExercises + defendingExercises + underPressureExercises
        + gameScenarioExercises + mentalExercises
    }

    /// Find exercises by category
    func exercises(for category: String) -> [TemplateExercise] {
        switch category.lowercased() {
        case "technical":
            return technicalExercises + weakFootExercises.filter { $0.category == "Technical" }
                + underPressureExercises.filter { $0.category == "Technical" }
        case "physical":
            return physicalExercises
        case "tactical":
            return tacticalExercises + defendingExercises + underPressureExercises.filter { $0.category == "Tactical" }
                + gameScenarioExercises + mentalExercises
                + weakFootExercises.filter { $0.category == "Tactical" }
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
