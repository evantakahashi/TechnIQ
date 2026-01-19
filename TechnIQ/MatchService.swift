import Foundation
import CoreData

/// Service for managing matches and seasons
final class MatchService {
    static let shared = MatchService()

    private let context: NSManagedObjectContext

    private init() {
        context = CoreDataManager.shared.context
    }

    // MARK: - Match CRUD

    /// Creates a new match for a player
    func createMatch(
        for player: Player,
        date: Date,
        opponent: String?,
        competition: String?,
        minutesPlayed: Int16,
        goals: Int16,
        assists: Int16,
        positionPlayed: String?,
        isHomeGame: Bool,
        result: String?,
        notes: String?,
        rating: Int16,
        season: Season? = nil,
        strengths: String? = nil,
        weaknesses: String? = nil
    ) -> Match {
        let match = Match(context: context)
        match.id = UUID()
        match.date = date
        match.opponent = opponent
        match.competition = competition

        // Clamp values to valid ranges for data integrity
        match.minutesPlayed = min(max(minutesPlayed, 0), 150)  // Max 150 min (extra time + stoppage)
        match.goals = min(max(goals, 0), 50)                   // Reasonable max
        match.assists = min(max(assists, 0), 50)               // Reasonable max
        match.rating = min(max(rating, 1), 5)                  // 1-5 scale

        match.positionPlayed = positionPlayed
        match.isHomeGame = isHomeGame
        match.result = result
        match.notes = notes
        match.strengths = strengths
        match.weaknesses = weaknesses
        match.createdAt = Date()
        match.player = player
        match.season = season

        // Calculate XP using clamped values
        match.xpEarned = calculateMatchXP(goals: match.goals, assists: match.assists, minutesPlayed: match.minutesPlayed, result: result)

        saveContext()
        return match
    }

    /// Fetches matches for a player
    func fetchMatches(for player: Player, season: Season? = nil) -> [Match] {
        let request: NSFetchRequest<Match> = Match.fetchRequest()

        if let season = season {
            request.predicate = NSPredicate(format: "player == %@ AND season == %@", player, season)
        } else {
            request.predicate = NSPredicate(format: "player == %@", player)
        }

        request.sortDescriptors = [NSSortDescriptor(keyPath: \Match.date, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("Error fetching matches: \(error)")
            #endif
            return []
        }
    }

    /// Fetches matches within a date range
    func fetchMatches(for player: Player, from startDate: Date, to endDate: Date) -> [Match] {
        let request: NSFetchRequest<Match> = Match.fetchRequest()
        request.predicate = NSPredicate(
            format: "player == %@ AND date >= %@ AND date <= %@",
            player, startDate as NSDate, endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Match.date, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("Error fetching matches by date: \(error)")
            #endif
            return []
        }
    }

    /// Deletes a match
    func deleteMatch(_ match: Match) {
        context.delete(match)
        saveContext()
    }

    // MARK: - Season CRUD

    /// Creates a new season for a player
    func createSeason(
        for player: Player,
        name: String,
        startDate: Date,
        endDate: Date,
        team: String?
    ) -> Season {
        let season = Season(context: context)
        season.id = UUID()
        season.name = name
        season.startDate = startDate
        season.endDate = endDate
        season.team = team
        season.isActive = false
        season.createdAt = Date()
        season.player = player

        saveContext()
        return season
    }

    /// Fetches all seasons for a player
    func fetchSeasons(for player: Player) -> [Season] {
        let request: NSFetchRequest<Season> = Season.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Season.startDate, ascending: false)]

        do {
            return try context.fetch(request)
        } catch {
            #if DEBUG
            print("Error fetching seasons: \(error)")
            #endif
            return []
        }
    }

    /// Gets the active season for a player
    func getActiveSeason(for player: Player) -> Season? {
        let request: NSFetchRequest<Season> = Season.fetchRequest()
        request.predicate = NSPredicate(format: "player == %@ AND isActive == YES", player)
        request.fetchLimit = 1

        do {
            return try context.fetch(request).first
        } catch {
            #if DEBUG
            print("Error fetching active season: \(error)")
            #endif
            return nil
        }
    }

    /// Sets a season as active (deactivates others)
    func setActiveSeason(_ season: Season, for player: Player) {
        // Deactivate all other seasons
        let seasons = fetchSeasons(for: player)
        for s in seasons {
            s.isActive = false
        }

        // Activate the selected season
        season.isActive = true
        saveContext()
    }

    /// Deletes a season
    func deleteSeason(_ season: Season) {
        context.delete(season)
        saveContext()
    }

    // MARK: - Statistics

    /// Calculates stats for a season
    func calculateSeasonStats(for season: Season) -> SeasonStats {
        guard let matches = season.matches as? Set<Match> else {
            return SeasonStats.empty
        }

        let matchesArray = Array(matches)
        return calculateStats(for: matchesArray)
    }

    /// Calculates stats for a list of matches
    func calculateStats(for matches: [Match]) -> SeasonStats {
        guard !matches.isEmpty else { return SeasonStats.empty }

        let totalGoals = matches.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = matches.reduce(0) { $0 + Int($1.assists) }
        let totalMinutes = matches.reduce(0) { $0 + Int($1.minutesPlayed) }
        let matchCount = matches.count

        let wins = matches.filter { $0.result == "W" }.count
        let draws = matches.filter { $0.result == "D" }.count
        let losses = matches.filter { $0.result == "L" }.count

        return SeasonStats(
            matchesPlayed: matchCount,
            totalGoals: totalGoals,
            totalAssists: totalAssists,
            totalMinutes: totalMinutes,
            goalsPerGame: Double(totalGoals) / Double(matchCount),
            assistsPerGame: Double(totalAssists) / Double(matchCount),
            minutesPerGame: Double(totalMinutes) / Double(matchCount),
            wins: wins,
            draws: draws,
            losses: losses
        )
    }

    /// Calculates per-game averages for matches
    func calculatePerGameAverages(for matches: [Match]) -> PerGameAverages {
        guard !matches.isEmpty else {
            return PerGameAverages(goalsPerGame: 0, assistsPerGame: 0, minutesPerGame: 0)
        }

        let totalGoals = matches.reduce(0) { $0 + Int($1.goals) }
        let totalAssists = matches.reduce(0) { $0 + Int($1.assists) }
        let totalMinutes = matches.reduce(0) { $0 + Int($1.minutesPlayed) }
        let matchCount = Double(matches.count)

        return PerGameAverages(
            goalsPerGame: Double(totalGoals) / matchCount,
            assistsPerGame: Double(totalAssists) / matchCount,
            minutesPerGame: Double(totalMinutes) / matchCount
        )
    }

    /// Compares stats between two seasons
    func compareSeasons(_ season1: Season, _ season2: Season) -> SeasonComparison {
        let stats1 = calculateSeasonStats(for: season1)
        let stats2 = calculateSeasonStats(for: season2)

        return SeasonComparison(
            season1Name: season1.name ?? "Season 1",
            season2Name: season2.name ?? "Season 2",
            season1Stats: stats1,
            season2Stats: stats2,
            goalsPerGameDelta: stats2.goalsPerGame - stats1.goalsPerGame,
            assistsPerGameDelta: stats2.assistsPerGame - stats1.assistsPerGame,
            minutesPerGameDelta: stats2.minutesPerGame - stats1.minutesPerGame
        )
    }

    /// Calculates rolling stats for last N days
    func calculateRollingStats(for player: Player, days: Int) -> SeasonStats {
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: endDate) ?? endDate
        let matches = fetchMatches(for: player, from: startDate, to: endDate)
        return calculateStats(for: matches)
    }

    // MARK: - XP Calculation

    /// Calculates XP earned for a match
    private func calculateMatchXP(goals: Int16, assists: Int16, minutesPlayed: Int16, result: String?) -> Int32 {
        var xp: Int32 = 50 // Base XP for logging a match

        xp += Int32(goals) * 20  // 20 XP per goal
        xp += Int32(assists) * 15 // 15 XP per assist

        if minutesPlayed >= 90 {
            xp += 25 // Bonus for playing full match
        }

        if result == "W" {
            xp += 30 // Bonus for a win
        } else if result == "D" {
            xp += 10 // Small bonus for a draw
        }

        return xp
    }

    // MARK: - Private Helpers

    private func saveContext() {
        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving match context: \(error)")
            #endif
        }
    }
}

// MARK: - Data Models

/// Statistics for a season or time period
struct SeasonStats {
    let matchesPlayed: Int
    let totalGoals: Int
    let totalAssists: Int
    let totalMinutes: Int
    let goalsPerGame: Double
    let assistsPerGame: Double
    let minutesPerGame: Double
    let wins: Int
    let draws: Int
    let losses: Int

    static let empty = SeasonStats(
        matchesPlayed: 0,
        totalGoals: 0,
        totalAssists: 0,
        totalMinutes: 0,
        goalsPerGame: 0,
        assistsPerGame: 0,
        minutesPerGame: 0,
        wins: 0,
        draws: 0,
        losses: 0
    )

    var winRate: Double {
        guard matchesPlayed > 0 else { return 0 }
        return Double(wins) / Double(matchesPlayed) * 100
    }

    var goalContributions: Int {
        totalGoals + totalAssists
    }

    var goalContributionsPerGame: Double {
        goalsPerGame + assistsPerGame
    }
}

/// Per-game averages
struct PerGameAverages {
    let goalsPerGame: Double
    let assistsPerGame: Double
    let minutesPerGame: Double
}

/// Comparison between two seasons
struct SeasonComparison {
    let season1Name: String
    let season2Name: String
    let season1Stats: SeasonStats
    let season2Stats: SeasonStats
    let goalsPerGameDelta: Double
    let assistsPerGameDelta: Double
    let minutesPerGameDelta: Double
}
