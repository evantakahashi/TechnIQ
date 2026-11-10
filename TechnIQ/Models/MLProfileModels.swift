import Foundation

// MARK: - Enhanced Player Profiling Data Models

struct PlayerRoleModel {
    let id = UUID()
    let name: String
    let position: String
    let playingStyle: String
    let description: String
    let keyAttributes: [String]
    
    static let roleModels = [
        PlayerRoleModel(
            name: "Lionel Messi",
            position: "Forward/Attacking Midfielder",
            playingStyle: "Creative Playmaker",
            description: "Exceptional dribbling, vision, and finishing ability",
            keyAttributes: ["Dribbling", "Vision", "Finishing", "Ball Control", "Creativity"]
        ),
        PlayerRoleModel(
            name: "Cristiano Ronaldo",
            position: "Forward",
            playingStyle: "Goal-Scoring Machine",
            description: "Powerful shooting, aerial ability, and athleticism",
            keyAttributes: ["Shooting", "Heading", "Speed", "Power", "Finishing"]
        ),
        PlayerRoleModel(
            name: "Luka Modric",
            position: "Central Midfielder",
            playingStyle: "Deep-Lying Playmaker",
            description: "Exceptional passing range and game intelligence",
            keyAttributes: ["Passing", "Vision", "Ball Control", "Positioning", "Stamina"]
        ),
        PlayerRoleModel(
            name: "Virgil van Dijk",
            position: "Centre-Back",
            playingStyle: "Modern Defender",
            description: "Strong in air, excellent positioning and ball-playing ability",
            keyAttributes: ["Defending", "Heading", "Positioning", "Passing", "Leadership"]
        ),
        PlayerRoleModel(
            name: "Kevin De Bruyne",
            position: "Attacking Midfielder",
            playingStyle: "Box-to-Box Creator",
            description: "Outstanding crossing, long-range shooting, and assists",
            keyAttributes: ["Crossing", "Shooting", "Vision", "Passing", "Creativity"]
        ),
        PlayerRoleModel(
            name: "Kylian Mbappe",
            position: "Forward/Winger",
            playingStyle: "Pace and Power",
            description: "Lightning speed, clinical finishing, and direct running",
            keyAttributes: ["Speed", "Acceleration", "Finishing", "Dribbling", "Movement"]
        ),
        PlayerRoleModel(
            name: "N'Golo Kante",
            position: "Defensive Midfielder",
            playingStyle: "Ball-Winning Midfielder",
            description: "Exceptional work rate, tackling, and ball recovery",
            keyAttributes: ["Tackling", "Stamina", "Positioning", "Ball Recovery", "Work Rate"]
        ),
        PlayerRoleModel(
            name: "Erling Haaland",
            position: "Striker",
            playingStyle: "Clinical Finisher",
            description: "Physical presence, clinical finishing, and movement in box",
            keyAttributes: ["Finishing", "Positioning", "Power", "Movement", "Shooting"]
        )
    ]
}

// MARK: - Skill Goals Database

// MARK: - Physical Focus Areas

struct PhysicalFocusArea {
    let id = UUID()
    let name: String
    let description: String
    let exerciseTypes: [String]
    
    static let allAreas = [
        PhysicalFocusArea(
            name: "Speed Development",
            description: "Improve maximum running speed and acceleration",
            exerciseTypes: ["Sprint Training", "Acceleration Drills", "Plyometric Exercises"]
        ),
        PhysicalFocusArea(
            name: "Strength Building",
            description: "Develop muscular strength for power and injury prevention",
            exerciseTypes: ["Weight Training", "Bodyweight Exercises", "Resistance Training"]
        ),
        PhysicalFocusArea(
            name: "Agility Enhancement",
            description: "Improve change of direction and footwork",
            exerciseTypes: ["Ladder Drills", "Cone Exercises", "Direction Changes"]
        ),
        PhysicalFocusArea(
            name: "Endurance Training",
            description: "Build cardiovascular fitness for full game performance",
            exerciseTypes: ["Interval Running", "Fartlek Training", "Circuit Training"]
        ),
        PhysicalFocusArea(
            name: "Flexibility & Recovery",
            description: "Prevent injuries and improve range of motion",
            exerciseTypes: ["Stretching", "Yoga", "Foam Rolling", "Recovery Sessions"]
        ),
        PhysicalFocusArea(
            name: "Core Stability",
            description: "Strengthen core muscles for balance and power",
            exerciseTypes: ["Plank Variations", "Core Circuits", "Stability Exercises"]
        )
    ]
}

// MARK: - Experience Levels

