import Foundation

// MARK: - Enhanced Player Profiling Data Models

struct SkillGoal {
    let id = UUID()
    let name: String
    let description: String
    let category: SkillCategory
    
    enum SkillCategory: String, CaseIterable {
        case technical = "Technical"
        case physical = "Physical" 
        case tactical = "Tactical"
        case mental = "Mental"
    }
}

struct TrainingPreferences {
    var preferredIntensity: Int = 5 // 1-10 scale
    var preferredSessionDuration: Int = 60 // minutes
    var preferredDrillComplexity: DrillComplexity = .intermediate
    var availableEquipment: Set<Equipment> = []
    var trainingEnvironment: TrainingEnvironment = .outdoorField
    
    enum DrillComplexity: String, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case expert = "Expert"
    }
    
    enum Equipment: String, CaseIterable {
        case cones = "Cones"
        case ball = "Ball"
        case goals = "Goals"
        case agililtyLadder = "Agility Ladder"
        case resistanceBands = "Resistance Bands"
        case weights = "Weights"
        case hurdles = "Hurdles"
        case rebounders = "Rebounders"
    }
    
    enum TrainingEnvironment: String, CaseIterable {
        case outdoorField = "Outdoor Field"
        case indoorGym = "Indoor Gym"
        case backyard = "Backyard"
        case park = "Park"
        case street = "Street"
    }
}

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

struct SkillGoalDatabase {
    static let allSkills = [
        // Technical Skills
        SkillGoal(name: "First Touch Control", description: "Ability to control the ball with your first touch", category: .technical),
        SkillGoal(name: "Shooting Accuracy", description: "Precision when shooting at goal", category: .technical),
        SkillGoal(name: "Dribbling Speed", description: "Maintaining control while dribbling at pace", category: .technical),
        SkillGoal(name: "Passing Accuracy", description: "Precise short and long range passing", category: .technical),
        SkillGoal(name: "Ball Control", description: "General ball manipulation and touches", category: .technical),
        SkillGoal(name: "Crossing Ability", description: "Delivering accurate crosses from wide positions", category: .technical),
        SkillGoal(name: "Heading Technique", description: "Proper heading form for power and accuracy", category: .technical),
        SkillGoal(name: "Weak Foot Development", description: "Improving skills with non-dominant foot", category: .technical),
        SkillGoal(name: "Finishing in the Box", description: "Clinical finishing from close range", category: .technical),
        SkillGoal(name: "Long Range Shooting", description: "Shooting from outside the penalty area", category: .technical),
        
        // Physical Skills
        SkillGoal(name: "Sprint Speed", description: "Maximum running velocity", category: .physical),
        SkillGoal(name: "Acceleration", description: "Rapid increase in speed from stationary", category: .physical),
        SkillGoal(name: "Agility", description: "Quick changes of direction", category: .physical),
        SkillGoal(name: "Endurance", description: "Ability to maintain performance over 90 minutes", category: .physical),
        SkillGoal(name: "Core Strength", description: "Stability and power from core muscles", category: .physical),
        SkillGoal(name: "Leg Strength", description: "Power in kicking and jumping", category: .physical),
        SkillGoal(name: "Balance", description: "Maintaining stability during play", category: .physical),
        SkillGoal(name: "Flexibility", description: "Range of motion for injury prevention", category: .physical),
        SkillGoal(name: "Jump Height", description: "Vertical leap for headers and goal scoring", category: .physical),
        SkillGoal(name: "Recovery Time", description: "Speed of recovery between intense efforts", category: .physical),
        
        // Tactical Skills
        SkillGoal(name: "Defensive Positioning", description: "Proper positioning when defending", category: .tactical),
        SkillGoal(name: "Offensive Movement", description: "Creating space and making runs", category: .tactical),
        SkillGoal(name: "Game Reading", description: "Understanding and anticipating play development", category: .tactical),
        SkillGoal(name: "Team Communication", description: "Effective on-field communication", category: .tactical),
        SkillGoal(name: "Set Piece Execution", description: "Corners, free kicks, and throw-ins", category: .tactical),
        SkillGoal(name: "Pressing", description: "Coordinated team pressing and pressure", category: .tactical),
        SkillGoal(name: "Counter Attacking", description: "Quick transitions from defense to attack", category: .tactical),
        SkillGoal(name: "Build-up Play", description: "Patient construction of attacking moves", category: .tactical),
        
        // Mental Skills
        SkillGoal(name: "Confidence", description: "Self-belief in abilities and decision making", category: .mental),
        SkillGoal(name: "Focus", description: "Maintaining concentration throughout the game", category: .mental),
        SkillGoal(name: "Decision Making", description: "Quick and accurate choices under pressure", category: .mental),
        SkillGoal(name: "Pressure Handling", description: "Performing well in high-pressure situations", category: .mental),
        SkillGoal(name: "Leadership", description: "Guiding and motivating teammates", category: .mental),
        SkillGoal(name: "Resilience", description: "Bouncing back from mistakes or setbacks", category: .mental)
    ]
    
    static func skillsByCategory(_ category: SkillGoal.SkillCategory) -> [SkillGoal] {
        return allSkills.filter { $0.category == category }
    }
}

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

enum ExperienceLevel: String, CaseIterable {
    case beginner = "Beginner (0-2 years)"
    case recreational = "Recreational (3-5 years)"
    case intermediate = "Intermediate (6-10 years)"
    case advanced = "Advanced (10+ years)"
    case semipro = "Semi-Professional"
    case professional = "Professional"
    
    var description: String {
        switch self {
        case .beginner:
            return "Just starting out or playing casually"
        case .recreational:
            return "Regular player with basic skills"
        case .intermediate:
            return "Experienced with good fundamental skills"
        case .advanced:
            return "Highly skilled with competitive experience"
        case .semipro:
            return "Playing at semi-professional level"
        case .professional:
            return "Professional or elite level player"
        }
    }
}

enum CompetitiveLevel: String, CaseIterable {
    case casual = "Casual/Social"
    case recreational = "Recreational League"
    case schoolTeam = "School/College Team"
    case clubTeam = "Local Club Team"
    case regional = "Regional Competition"
    case national = "National Level"
    case international = "International Level"
    
    var description: String {
        switch self {
        case .casual:
            return "Playing for fun with friends"
        case .recreational:
            return "Local recreational leagues"
        case .schoolTeam:
            return "School or college team"
        case .clubTeam:
            return "Competitive club team"
        case .regional:
            return "Regional tournaments and competitions"
        case .national:
            return "National championships and competitions"
        case .international:
            return "International competitions and tournaments"
        }
    }
}