import Foundation

// MARK: - Drill Suggestion Model

struct DrillSuggestion: Identifiable {
    let id = UUID()
    let weakness: SelectedWeakness
    let title: String
    let description: String
    let difficulty: DifficultyLevel
}
