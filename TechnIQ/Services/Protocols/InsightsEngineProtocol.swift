import Foundation

// MARK: - InsightsEngine Protocol

protocol InsightsEngineProtocol: AnyObject {
    func generateInsights(for player: Player, sessions: [TrainingSession], timeRange: TimeRange) -> [TrainingInsight]
}
