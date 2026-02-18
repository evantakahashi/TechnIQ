import Foundation

// MARK: - Custom Drill Generation Models

struct CustomDrillRequest {
    var skillDescription: String
    var category: DrillCategory
    var difficulty: DifficultyLevel
    var equipment: Set<Equipment>
    var numberOfPlayers: Int
    var fieldSize: FieldSize
    var selectedWeaknesses: [SelectedWeakness] = []
}

enum DrillCategory: String, CaseIterable {
    case technical = "technical"
    case physical = "physical"
    case tactical = "tactical"
    case mental = "mental"
    
    var displayName: String {
        switch self {
        case .technical: return "⚽ Technical"
        case .physical: return "💪 Physical"
        case .tactical: return "🧠 Tactical"
        case .mental: return "🎯 Mental"
        }
    }
    
    var color: String {
        switch self {
        case .technical: return "primaryGreen"
        case .physical: return "accentOrange"
        case .tactical: return "secondaryBlue"
        case .mental: return "accentYellow"
        }
    }
}

enum DifficultyLevel: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "🟢 Beginner"
        case .intermediate: return "🟡 Intermediate"
        case .advanced: return "🔴 Advanced"
        }
    }
    
    var numericValue: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        }
    }
}

enum Equipment: String, CaseIterable {
    case ball = "ball"
    case cones = "cones"
    case goals = "goals"
    case partner = "partner"
    case hurdles = "hurdles"
    case ladder = "ladder"
    case poles = "poles"
    case wall = "wall"
    case none = "none"

    var displayName: String {
        switch self {
        case .ball: return "⚽ Ball"
        case .cones: return "🔶 Cones"
        case .goals: return "🥅 Goals"
        case .partner: return "👥 Partner"
        case .hurdles: return "🚧 Hurdles"
        case .ladder: return "🪜 Agility Ladder"
        case .poles: return "📍 Poles"
        case .wall: return "🧱 Wall"
        case .none: return "❌ No Equipment"
        }
    }

    var icon: String {
        switch self {
        case .ball: return "soccerball"
        case .cones: return "triangle"
        case .goals: return "rectangle.portrait"
        case .partner: return "person.2"
        case .hurdles: return "square.stack"
        case .ladder: return "chart.bar.fill"
        case .poles: return "location"
        case .wall: return "rectangle.portrait.fill"
        case .none: return "xmark.circle"
        }
    }
}

enum FieldSize: String, CaseIterable {
    case small = "small"      // 20x15m (individual)
    case medium = "medium"    // 30x20m (small group)
    case large = "large"      // 50x30m (full team)

    var displayName: String {
        switch self {
        case .small: return "Small (20x15m)"
        case .medium: return "Medium (30x20m)"
        case .large: return "Large (50x30m)"
        }
    }

    var subtitle: String {
        switch self {
        case .small: return "Individual drills"
        case .medium: return "Small group work"
        case .large: return "Full team exercises"
        }
    }

    var icon: String {
        switch self {
        case .small: return "square"
        case .medium: return "rectangle"
        case .large: return "rectangle.landscape"
        }
    }
}

// MARK: - LLM Response Model

struct CustomDrillResponse: Codable {
    let name: String
    let description: String
    let setup: String
    let instructions: [String]
    let diagram: DrillDiagram?
    let progressions: [String]?
    let coachingPoints: [String]?
    let estimatedDuration: Int
    let difficulty: String
    let category: String
    let targetSkills: [String]
    let equipment: [String]
    let safetyNotes: String?
    let variations: [DrillVariation]?
    let validationWarnings: [String]?
}

// MARK: - Drill Diagram Models

struct DrillDiagram: Codable {
    let field: DiagramField
    let elements: [DiagramElement]
    let paths: [DiagramPath]?
}

struct DiagramField: Codable {
    let width: Double
    let length: Double
}

struct DiagramElement: Codable, Identifiable {
    let type: String  // "cone", "player", "target", "goal", "ball"
    let x: Double
    let y: Double
    let label: String

    var id: String { "\(type)_\(label)_\(x)_\(y)" }

    var elementType: DiagramElementType {
        DiagramElementType(rawValue: type) ?? .cone
    }
}

struct DiagramPath: Codable {
    let from: String
    let to: String
    let style: String  // "dribble", "run", "pass"
    let step: Int?     // nil = show on all steps (backward compat)

    var pathStyle: DiagramPathStyle {
        DiagramPathStyle(rawValue: style) ?? .run
    }

    init(from: String, to: String, style: String, step: Int? = nil) {
        self.from = from
        self.to = to
        self.style = style
        self.step = step
    }
}

enum DiagramElementType: String {
    case cone = "cone"
    case player = "player"
    case target = "target"
    case goal = "goal"
    case ball = "ball"
}

enum DiagramPathStyle: String {
    case dribble = "dribble"  // Solid line (with ball)
    case run = "run"          // Dashed line (without ball)
    case pass = "pass"        // Arrow line (ball trajectory)
}

struct DrillVariation: Codable {
    let name: String
    let description: String
    let modification: String
}

// MARK: - Generation State

enum DrillGenerationState {
    case idle
    case generating
    case success(CustomDrillResponse)
    case error(String)
}

// MARK: - Extensions for UI

extension CustomDrillRequest {
    static var empty: CustomDrillRequest {
        CustomDrillRequest(
            skillDescription: "",
            category: .technical,
            difficulty: .intermediate,
            equipment: [.ball],
            numberOfPlayers: 1,
            fieldSize: .medium,
            selectedWeaknesses: []
        )
    }

    var isValid: Bool {
        let hasDescription = !skillDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               skillDescription.count >= 10
        let hasWeaknesses = !selectedWeaknesses.isEmpty
        return hasDescription || hasWeaknesses
    }

    var equipmentList: [String] {
        equipment.map { $0.rawValue }
    }
}

// MARK: - Validation Helpers

extension String {
    var isValidSkillDescription: Bool {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 10 && 
               trimmed.count <= 500 &&
               !trimmed.lowercased().contains("inappropriate") // Basic content filtering
    }
}