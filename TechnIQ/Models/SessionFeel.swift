import Foundation

/// "How did it feel?" on Session Complete. No default: the player must pick one before Done.
/// Raw values are persisted on `TrainingSession.feel` and synced — never rename.
enum SessionFeel: String, CaseIterable, Identifiable {
    case tooEasy
    case right
    case tooHard

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tooEasy: return "Too easy"
        case .right: return "Right"
        case .tooHard: return "Too hard"
        }
    }

    /// 1–5 performance score that feeds skill ratings: too easy = mastered, too hard = needs work.
    var rating: Int {
        switch self {
        case .tooEasy: return 5
        case .right: return 4
        case .tooHard: return 2
        }
    }

    init?(raw: String?) {
        guard let raw, let feel = SessionFeel(rawValue: raw) else { return nil }
        self = feel
    }
}
