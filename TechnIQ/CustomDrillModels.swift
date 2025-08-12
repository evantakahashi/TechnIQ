import Foundation

// MARK: - Custom Drill Generation Models

struct CustomDrillRequest {
    var skillDescription: String
    var category: DrillCategory
    var difficulty: DifficultyLevel
    var equipment: Set<Equipment>
    var duration: Int // minutes
    var focusArea: FocusArea
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
    case bibs = "bibs"
    case hurdles = "hurdles"
    case ladder = "ladder"
    case poles = "poles"
    case rebounder = "rebounder"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .ball: return "⚽ Ball"
        case .cones: return "🔶 Cones"
        case .goals: return "🥅 Goals"
        case .partner: return "👥 Partner"
        case .bibs: return "👕 Bibs"
        case .hurdles: return "🚧 Hurdles"
        case .ladder: return "🪜 Agility Ladder"
        case .poles: return "📍 Poles"
        case .rebounder: return "🎾 Rebounder"
        case .none: return "❌ No Equipment"
        }
    }
    
    var icon: String {
        switch self {
        case .ball: return "soccerball"
        case .cones: return "triangle"
        case .goals: return "rectangle.portrait"
        case .partner: return "person.2"
        case .bibs: return "tshirt"
        case .hurdles: return "square.stack"
        case .ladder: return "ladder"
        case .poles: return "location"
        case .rebounder: return "circle.hexagonpath"
        case .none: return "xmark.circle"
        }
    }
}

enum FocusArea: String, CaseIterable {
    case individual = "individual"
    case smallGroup = "small_group"
    case fullTeam = "full_team"
    
    var displayName: String {
        switch self {
        case .individual: return "👤 Individual"
        case .smallGroup: return "👥 Small Group (2-6)"
        case .fullTeam: return "⚽ Full Team (11+)"
        }
    }
}

// MARK: - LLM Response Model

struct CustomDrillResponse: Codable {
    let name: String
    let description: String
    let setup: String
    let instructions: [String]
    let progressions: [String]?
    let coachingPoints: [String]?
    let estimatedDuration: Int
    let difficulty: String
    let category: String
    let targetSkills: [String]
    let equipment: [String]
    let safetyNotes: String?
    let variations: [DrillVariation]?
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
            duration: 30,
            focusArea: .individual
        )
    }
    
    var isValid: Bool {
        return !skillDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               skillDescription.count >= 10 &&
               duration >= 10 &&
               duration <= 120
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