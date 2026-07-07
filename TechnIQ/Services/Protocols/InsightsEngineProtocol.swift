import Foundation

// MARK: - InsightsEngine Protocol

@MainActor
protocol InsightsEngineProtocol: AnyObject {
    func generateInsights(for player: Player, sessions: [TrainingSession], timeRange: TimeRange) -> [TrainingInsight]
}
