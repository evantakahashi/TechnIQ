import Foundation

// MARK: - Daily Coaching Models
//
// The coach functions answer in snake_case; the explicit keys below are the contract. Until they
// existed the client decoded camelCase keys, so every real answer failed to parse and the hero
// always fell back to the plan drill.

struct DailyCoaching: Codable {
    let focusArea: String
    let reasoning: String
    /// One imperative coaching cue for today's drill (≤ 12 words), added with the library-pick prompt.
    let cue: String?
    let recommendedDrill: RecommendedDrill
    let additionalTips: [String]
    let streakMessage: String?
    let insights: [AIInsight]
    let fetchDate: Date

    enum CodingKeys: String, CodingKey {
        case focusArea = "focus_area"
        case reasoning
        case cue
        case recommendedDrill = "recommended_drill"
        case additionalTips = "additional_tips"
        case streakMessage = "streak_message"
        case insights
        case fetchDate = "fetch_date"
    }

    init(focusArea: String, reasoning: String, cue: String? = nil, recommendedDrill: RecommendedDrill,
         additionalTips: [String], streakMessage: String?, insights: [AIInsight], fetchDate: Date) {
        self.focusArea = focusArea
        self.reasoning = reasoning
        self.cue = cue
        self.recommendedDrill = recommendedDrill
        self.additionalTips = additionalTips
        self.streakMessage = streakMessage
        self.insights = insights
        self.fetchDate = fetchDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusArea = try container.decodeIfPresent(String.self, forKey: .focusArea) ?? "Training"
        reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning) ?? ""
        cue = try container.decodeIfPresent(String.self, forKey: .cue)
        recommendedDrill = try container.decode(RecommendedDrill.self, forKey: .recommendedDrill)
        additionalTips = try container.decodeIfPresent([String].self, forKey: .additionalTips) ?? []
        streakMessage = try container.decodeIfPresent(String.self, forKey: .streakMessage)
        insights = try container.decodeIfPresent([AIInsight].self, forKey: .insights) ?? []
        // The server never sends a fetch date; the cache does.
        fetchDate = try container.decodeIfPresent(Date.self, forKey: .fetchDate) ?? Date()
    }
}

struct RecommendedDrill: Codable {
    let name: String
    let description: String
    let category: String
    let difficulty: Int
    let duration: Int
    let steps: [String]
    let equipment: [String]
    let targetSkills: [String]
    let isFromLibrary: Bool
    let libraryExerciseID: String?

    enum CodingKeys: String, CodingKey {
        case name, description, category, difficulty, duration, steps, equipment
        case targetSkills = "target_skills"
        case isFromLibrary = "is_from_library"
        case libraryExerciseID = "library_exercise_id"
    }

    init(name: String, description: String, category: String, difficulty: Int, duration: Int, steps: [String],
         equipment: [String], targetSkills: [String], isFromLibrary: Bool, libraryExerciseID: String?) {
        self.name = name
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.duration = duration
        self.steps = steps
        self.equipment = equipment
        self.targetSkills = targetSkills
        self.isFromLibrary = isFromLibrary
        self.libraryExerciseID = libraryExerciseID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Today's drill"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "Technical"
        difficulty = try container.decodeIfPresent(Int.self, forKey: .difficulty) ?? 2
        duration = try container.decodeIfPresent(Int.self, forKey: .duration) ?? 15
        steps = try container.decodeIfPresent([String].self, forKey: .steps) ?? []
        equipment = try container.decodeIfPresent([String].self, forKey: .equipment) ?? []
        targetSkills = try container.decodeIfPresent([String].self, forKey: .targetSkills) ?? []
        isFromLibrary = try container.decodeIfPresent(Bool.self, forKey: .isFromLibrary) ?? false
        libraryExerciseID = try container.decodeIfPresent(String.self, forKey: .libraryExerciseID)
    }
}

struct AIInsight: Codable {
    let title: String
    let description: String
    let type: String       // "celebration", "recommendation", "warning", "pattern"
    let priority: Int
    let actionable: String?

    init(title: String, description: String, type: String, priority: Int, actionable: String?) {
        self.title = title
        self.description = description
        self.type = type
        self.priority = priority
        self.actionable = actionable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "recommendation"
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 5
        actionable = try container.decodeIfPresent(String.self, forKey: .actionable)
    }
}

// MARK: - Plan Adaptation Models

struct PlanAdaptationResponse: Codable {
    let summary: String
    let adaptations: [PlanAdaptation]

    init(summary: String, adaptations: [PlanAdaptation]) {
        self.summary = summary
        self.adaptations = adaptations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        adaptations = try container.decodeIfPresent([PlanAdaptation].self, forKey: .adaptations) ?? []
    }
}

struct PlanAdaptation: Codable, Identifiable {
    let type: String           // "add_session", "modify_difficulty", "remove_session", "swap_exercise"
    let day: Int
    let sessionIndex: Int?
    let description: String
    /// Why the coach proposes it, citing a number. Older answers have none.
    let reason: String?
    let drill: RecommendedDrill?
    let oldDifficulty: Int?
    let newDifficulty: Int?

    var id: String { "\(type)-\(day)-\(sessionIndex ?? -1)-\(description.hashValue)" }

    enum CodingKeys: String, CodingKey {
        case type, day, description, reason, drill
        case sessionIndex = "session_index"
        case oldDifficulty = "old_difficulty"
        case newDifficulty = "new_difficulty"
    }

    init(type: String, day: Int, sessionIndex: Int?, description: String, reason: String? = nil,
         drill: RecommendedDrill?, oldDifficulty: Int?, newDifficulty: Int?) {
        self.type = type
        self.day = day
        self.sessionIndex = sessionIndex
        self.description = description
        self.reason = reason
        self.drill = drill
        self.oldDifficulty = oldDifficulty
        self.newDifficulty = newDifficulty
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "modify_difficulty"
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        sessionIndex = try container.decodeIfPresent(Int.self, forKey: .sessionIndex)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        reason = try container.decodeIfPresent(String.self, forKey: .reason)
        drill = try container.decodeIfPresent(RecommendedDrill.self, forKey: .drill)
        oldDifficulty = try container.decodeIfPresent(Int.self, forKey: .oldDifficulty)
        newDifficulty = try container.decodeIfPresent(Int.self, forKey: .newDifficulty)
    }
}
