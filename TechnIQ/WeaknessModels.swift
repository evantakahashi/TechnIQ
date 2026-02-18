import Foundation

// MARK: - WeaknessCategory

enum WeaknessCategory: String, CaseIterable, Codable, Identifiable {
    case dribbling
    case passing
    case shooting
    case firstTouch
    case defending
    case speedAgility
    case stamina
    case positioning
    case weakFoot
    case aerialAbility

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dribbling: return "Dribbling"
        case .passing: return "Passing"
        case .shooting: return "Shooting"
        case .firstTouch: return "First Touch"
        case .defending: return "Defending"
        case .speedAgility: return "Speed & Agility"
        case .stamina: return "Stamina"
        case .positioning: return "Positioning"
        case .weakFoot: return "Weak Foot"
        case .aerialAbility: return "Aerial Ability"
        }
    }

    var icon: String {
        switch self {
        case .dribbling: return "figure.soccer"
        case .passing: return "arrow.triangle.branch"
        case .shooting: return "target"
        case .firstTouch: return "hand.point.up"
        case .defending: return "shield.fill"
        case .speedAgility: return "bolt.fill"
        case .stamina: return "heart.fill"
        case .positioning: return "mappin.and.ellipse"
        case .weakFoot: return "shoe.fill"
        case .aerialAbility: return "arrow.up.circle"
        }
    }

    var subWeaknesses: [SubWeakness] {
        switch self {
        case .dribbling:
            return [.underPressure, .changeOfDirection, .tightSpaces, .weakFootDribbling, .beat1v1, .speedDribbling]
        case .passing:
            return [.longRangeAccuracy, .weakFootPassing, .throughBalls, .firstTimePassing, .passingUnderPressure, .switchingPlay]
        case .shooting:
            return [.finishing1v1, .weakFootShooting, .volleys, .longRange, .placementVsPower, .headersOnGoal]
        case .firstTouch:
            return [.touchUnderPressure, .aerialBalls, .turningWithFirstTouch, .weakFootControl, .bouncingBalls]
        case .defending:
            return [.tackling1v1, .defensivePositioning, .aerialDuels, .recoveryRuns, .readingTheGame, .pressingTriggers]
        case .speedAgility:
            return [.acceleration, .agilityChangeOfDirection, .sprintEndurance, .agilityTightSpaces]
        case .stamina:
            return [.matchFitness, .highIntensityIntervals, .recoveryBetweenEfforts]
        case .positioning:
            return [.offTheBallMovement, .creatingSpace, .defensiveShape, .transitionPositioning]
        case .weakFoot:
            return [.weakFootDribbling, .weakFootPassing, .weakFootShooting, .weakFootControl, .weakFootCrossing]
        case .aerialAbility:
            return [.headingAccuracy, .jumpingTiming, .aerialDuels, .headedPasses]
        }
    }
}

// MARK: - SubWeakness

enum SubWeakness: String, CaseIterable, Codable, Identifiable {
    // Dribbling
    case underPressure
    case changeOfDirection
    case tightSpaces
    case weakFootDribbling
    case beat1v1
    case speedDribbling

    // Passing
    case longRangeAccuracy
    case weakFootPassing
    case throughBalls
    case firstTimePassing
    case passingUnderPressure
    case switchingPlay

    // Shooting
    case finishing1v1
    case weakFootShooting
    case volleys
    case longRange
    case placementVsPower
    case headersOnGoal

    // First Touch
    case touchUnderPressure
    case aerialBalls
    case turningWithFirstTouch
    case weakFootControl
    case bouncingBalls

    // Defending
    case tackling1v1
    case defensivePositioning
    case aerialDuels
    case recoveryRuns
    case readingTheGame
    case pressingTriggers

    // Speed & Agility
    case acceleration
    case agilityChangeOfDirection
    case sprintEndurance
    case agilityTightSpaces

    // Stamina
    case matchFitness
    case highIntensityIntervals
    case recoveryBetweenEfforts

    // Positioning
    case offTheBallMovement
    case creatingSpace
    case defensiveShape
    case transitionPositioning

    // Weak Foot (additional)
    case weakFootCrossing

    // Aerial
    case headingAccuracy
    case jumpingTiming
    case headedPasses

    var id: String { rawValue }

    var displayName: String {
        let result = rawValue.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: "([A-Z]+)([A-Z][a-z])",
            with: "$1 $2",
            options: .regularExpression
        )
        .replacingOccurrences(
            of: "(\\d+)(\\w)",
            with: "$1 $2",
            options: .regularExpression
        )
        return result.prefix(1).uppercased() + result.dropFirst()
    }
}

// MARK: - SelectedWeakness

struct SelectedWeakness: Codable {
    let category: String
    let specific: String
}

// MARK: - WeaknessProfile

struct WeaknessProfile: Codable {
    let suggestedWeaknesses: [SelectedWeakness]
    let dataSources: [String]
    let lastUpdated: Date
}
