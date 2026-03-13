import Foundation
import CoreData

protocol MatchServiceProtocol: AnyObject {
    func createMatch(for player: Player, date: Date, opponent: String?, competition: String?, minutesPlayed: Int16, goals: Int16, assists: Int16, positionPlayed: String?, isHomeGame: Bool, result: String?, notes: String?, rating: Int16, season: Season?, strengths: String?, weaknesses: String?) -> Match
    func fetchMatches(for player: Player, season: Season?) -> [Match]
    func fetchMatches(for player: Player, from startDate: Date, to endDate: Date) -> [Match]
    func deleteMatch(_ match: Match)
    func createSeason(for player: Player, name: String, startDate: Date, endDate: Date, team: String?) -> Season
    func fetchSeasons(for player: Player) -> [Season]
    func getActiveSeason(for player: Player) -> Season?
    func setActiveSeason(_ season: Season, for player: Player)
    func deleteSeason(_ season: Season)
    func calculateSeasonStats(for season: Season) -> SeasonStats
    func calculateStats(for matches: [Match]) -> SeasonStats
    func calculatePerGameAverages(for matches: [Match]) -> PerGameAverages
    func compareSeasons(_ season1: Season, _ season2: Season) -> SeasonComparison
    func calculateRollingStats(for player: Player, days: Int) -> SeasonStats
}
