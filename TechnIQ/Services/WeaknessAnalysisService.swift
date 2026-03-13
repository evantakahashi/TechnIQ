import Foundation
import CoreData

// MARK: - WeaknessAnalysisService

class WeaknessAnalysisService {
    static let shared = WeaknessAnalysisService()

    private let cacheStaleInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {}

    // MARK: - Keyword → Category Mapping

    private let keywordMap: [(keywords: [String], category: WeaknessCategory)] = [
        (["dribbl"], .dribbling),
        (["pass"], .passing),
        (["shoot", "finish"], .shooting),
        (["touch", "control"], .firstTouch),
        (["defend", "tackle"], .defending),
        (["speed", "pace", "agil"], .speedAgility),
        (["fit", "stamin", "tir"], .stamina),
        (["position"], .positioning),
        (["weak foot", "left foot", "right foot"], .weakFoot),
        (["head", "aerial"], .aerialAbility)
    ]

    // MARK: - Public API

    /// Analyze all data sources and return a ranked WeaknessProfile with top 3 suggestions.
    func analyzeWeaknesses(for player: Player) -> WeaknessProfile {
        let (matchSuggestions, matchCount) = analyzeMatches(player)
        let (sessionSuggestions, sessionCount) = analyzeSessionRatings(player)
        let feedbackSuggestions = analyzeDrillFeedback(player)

        // Combine all suggestions
        var allSuggestions: [SelectedWeakness] = []
        allSuggestions.append(contentsOf: matchSuggestions)
        allSuggestions.append(contentsOf: sessionSuggestions)
        allSuggestions.append(contentsOf: feedbackSuggestions)

        // Deduplicate by (category + specific), counting frequency
        var frequencyMap: [String: (weakness: SelectedWeakness, count: Int)] = [:]
        for suggestion in allSuggestions {
            let key = "\(suggestion.category)|\(suggestion.specific)"
            if let existing = frequencyMap[key] {
                frequencyMap[key] = (existing.weakness, existing.count + 1)
            } else {
                frequencyMap[key] = (suggestion, 1)
            }
        }

        // Rank by frequency descending, take top 3
        let ranked = frequencyMap.values
            .sorted { $0.count > $1.count }
            .prefix(3)
            .map { $0.weakness }

        // Build data sources list
        var dataSources: [String] = []
        if matchCount > 0 {
            dataSources.append("\(matchCount) recent matches")
        }
        if sessionCount > 0 {
            dataSources.append("\(sessionCount) training sessions (last 30 days)")
        }
        if !feedbackSuggestions.isEmpty {
            dataSources.append("Drill feedback")
        }

        let profile = WeaknessProfile(
            suggestedWeaknesses: Array(ranked),
            dataSources: dataSources,
            lastUpdated: Date()
        )

        // Cache to player
        cacheProfile(profile, for: player)

        #if DEBUG
        print("[WeaknessAnalysis] Generated profile with \(ranked.count) suggestions from \(dataSources.count) sources")
        #endif

        return profile
    }

    /// Return cached profile if present and fresh (<24h old). Returns nil otherwise.
    func getCachedProfile(for player: Player) -> WeaknessProfile? {
        guard let json = player.weaknessProfileJSON,
              let data = json.data(using: .utf8) else {
            return nil
        }

        do {
            let profile = try JSONDecoder().decode(WeaknessProfile.self, from: data)
            let age = Date().timeIntervalSince(profile.lastUpdated)
            if age > cacheStaleInterval {
                #if DEBUG
                print("[WeaknessAnalysis] Cached profile stale (\(Int(age / 3600))h old)")
                #endif
                return nil
            }
            return profile
        } catch {
            #if DEBUG
            print("[WeaknessAnalysis] Failed to decode cached profile: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Match Analysis

    private func analyzeMatches(_ player: Player) -> (suggestions: [SelectedWeakness], matchCount: Int) {
        let context = CoreDataManager.shared.context
        let request = NSFetchRequest<Match>(entityName: "Match")
        request.predicate = NSPredicate(format: "player == %@", player)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        request.fetchLimit = 10

        var suggestions: [SelectedWeakness] = []

        do {
            let matches = try context.fetch(request)

            for match in matches {
                guard let weaknessesString = match.weaknesses, !weaknessesString.isEmpty else {
                    continue
                }

                let keywords = weaknessesString
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }

                for keyword in keywords {
                    if let category = mapKeywordToCategory(keyword) {
                        suggestions.append(SelectedWeakness(
                            category: category.displayName,
                            specific: keyword
                        ))
                    }
                }
            }

            #if DEBUG
            print("[WeaknessAnalysis] Analyzed \(matches.count) matches, found \(suggestions.count) weakness signals")
            #endif

            return (suggestions, matches.count)
        } catch {
            #if DEBUG
            print("[WeaknessAnalysis] Match fetch failed: \(error.localizedDescription)")
            #endif
            return ([], 0)
        }
    }

    // MARK: - Session Ratings Analysis

    private func analyzeSessionRatings(_ player: Player) -> (suggestions: [SelectedWeakness], sessionCount: Int) {
        let context = CoreDataManager.shared.context
        let request = NSFetchRequest<TrainingSession>(entityName: "TrainingSession")

        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        request.predicate = NSPredicate(format: "player == %@ AND date >= %@", player, thirtyDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        var suggestions: [SelectedWeakness] = []

        do {
            let sessions = try context.fetch(request)

            // Group low-rated exercises by category
            var lowRatingsByCategory: [String: Int] = [:]

            for session in sessions {
                guard let sessionExercises = session.exercises as? Set<SessionExercise> else {
                    continue
                }

                for sessionExercise in sessionExercises {
                    guard sessionExercise.performanceRating < 3,
                          let exercise = sessionExercise.exercise,
                          let category = exercise.category, !category.isEmpty else {
                        continue
                    }

                    lowRatingsByCategory[category, default: 0] += 1
                }
            }

            // Only suggest categories with 2+ low ratings
            for (category, count) in lowRatingsByCategory where count >= 2 {
                if let weaknessCategory = matchCategoryString(category) {
                    suggestions.append(SelectedWeakness(
                        category: weaknessCategory.displayName,
                        specific: "Low performance in \(category) (\(count) exercises rated below 3)"
                    ))
                } else {
                    // Use raw category name if no enum match
                    suggestions.append(SelectedWeakness(
                        category: category,
                        specific: "Low performance (\(count) exercises rated below 3)"
                    ))
                }
            }

            #if DEBUG
            print("[WeaknessAnalysis] Analyzed \(sessions.count) sessions, found \(suggestions.count) weakness signals")
            #endif

            return (suggestions, sessions.count)
        } catch {
            #if DEBUG
            print("[WeaknessAnalysis] Session fetch failed: \(error.localizedDescription)")
            #endif
            return ([], 0)
        }
    }

    // MARK: - Drill Feedback Analysis

    private func analyzeDrillFeedback(_ player: Player) -> [SelectedWeakness] {
        let context = CoreDataManager.shared.context
        let request = NSFetchRequest<RecommendationFeedback>(entityName: "RecommendationFeedback")
        // rating < 3 (poor) OR difficultyRating > 3 (too hard)
        request.predicate = NSPredicate(format: "player == %@ AND (rating < 3 OR difficultyRating > 3)", player)

        var suggestions: [SelectedWeakness] = []

        do {
            let feedbackItems = try context.fetch(request)

            for feedback in feedbackItems {
                // Try feedbackType first
                if let feedbackType = feedback.feedbackType, !feedbackType.isEmpty {
                    if let category = mapKeywordToCategory(feedbackType.lowercased()) {
                        let detail = feedback.difficultyRating > 3 ? "Found too difficult" : "Low rating"
                        suggestions.append(SelectedWeakness(
                            category: category.displayName,
                            specific: detail
                        ))
                        continue
                    }
                }

                // Fall back to notes content
                if let notes = feedback.notes, !notes.isEmpty {
                    let lowered = notes.lowercased()
                    if let category = mapKeywordToCategory(lowered) {
                        suggestions.append(SelectedWeakness(
                            category: category.displayName,
                            specific: "Feedback: \(notes)"
                        ))
                    }
                }
            }

            #if DEBUG
            print("[WeaknessAnalysis] Analyzed \(feedbackItems.count) feedback items, found \(suggestions.count) weakness signals")
            #endif

            return suggestions
        } catch {
            #if DEBUG
            print("[WeaknessAnalysis] Feedback fetch failed: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Helpers

    /// Match a raw keyword string to a WeaknessCategory via substring matching.
    private func mapKeywordToCategory(_ text: String) -> WeaknessCategory? {
        let lowered = text.lowercased()
        for entry in keywordMap {
            for keyword in entry.keywords {
                if lowered.contains(keyword) {
                    return entry.category
                }
            }
        }
        return nil
    }

    /// Match an exercise category string to a WeaknessCategory (case-insensitive).
    private func matchCategoryString(_ categoryString: String) -> WeaknessCategory? {
        let lowered = categoryString.lowercased()
        for category in WeaknessCategory.allCases {
            if category.displayName.lowercased() == lowered || category.rawValue.lowercased() == lowered {
                return category
            }
        }
        // Fall back to keyword matching
        return mapKeywordToCategory(lowered)
    }

    /// Encode and cache profile to player's weaknessProfileJSON.
    private func cacheProfile(_ profile: WeaknessProfile, for player: Player) {
        do {
            let data = try JSONEncoder().encode(profile)
            if let jsonString = String(data: data, encoding: .utf8) {
                player.weaknessProfileJSON = jsonString
                try CoreDataManager.shared.context.save()
                #if DEBUG
                print("[WeaknessAnalysis] Cached profile to player")
                #endif
            }
        } catch {
            #if DEBUG
            print("[WeaknessAnalysis] Failed to cache profile: \(error.localizedDescription)")
            #endif
        }
    }
}
