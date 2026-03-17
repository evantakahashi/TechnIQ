import Foundation

// MARK: - WeaknessAnalysisService Protocol

protocol WeaknessAnalysisServiceProtocol: AnyObject {
    func analyzeWeaknesses(for player: Player) -> WeaknessProfile
    func getCachedProfile(for player: Player) -> WeaknessProfile?
}
