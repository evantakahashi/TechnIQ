import CoreData
import Foundation

extension CoreDataManager {
    // MARK: - Dynamic Description Generation

    func generateDrillDescription(for exercise: Exercise, player: Player) -> String {
        let name = exercise.name ?? "Unknown"
        let category = exercise.category ?? "Technical"
        let difficulty = Int(exercise.difficulty)
        let skills = exercise.targetSkills ?? []

        var description = "\(name) is a \(category.lowercased()) drill"

        if !skills.isEmpty {
            description += " focusing on \(skills.joined(separator: ", ").lowercased())"
        }

        description += "."

        switch difficulty {
        case 1:
            description += " This beginner-level drill is perfect for players just starting out."
        case 2:
            description += " This intermediate drill helps build on foundational skills."
        case 3:
            description += " This advanced drill challenges players to push their limits."
        case 4:
            description += " This expert-level drill demands precise technique and focus."
        case 5:
            description += " This professional-level drill is designed for elite performance."
        default:
            break
        }

        return description
    }

    func generateSessionSummary(for session: TrainingSession) -> String {
        let exerciseCount = session.exercises?.count ?? 0
        let duration = session.duration
        let rating = session.overallRating
        let date = session.date ?? Date()

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        var summary = "Training session on \(dateFormatter.string(from: date))"
        summary += " — \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")"

        if duration > 0 {
            let minutes = duration / 60
            summary += ", \(minutes) min"
        }

        if rating > 0 {
            summary += ", rated \(rating)/5"
        }

        return summary
    }

    func generatePlayerProgressDescription(for player: Player) -> String {
        let totalSessions = (player.sessions as? Set<TrainingSession>)?.count ?? 0
        let name = player.name ?? "Player"
        let position = player.position ?? "player"

        if totalSessions == 0 {
            return "\(name) is just getting started on their soccer journey!"
        } else if totalSessions < 5 {
            return "\(name) has completed \(totalSessions) training session\(totalSessions == 1 ? "" : "s") as a \(position)."
        } else if totalSessions < 20 {
            return "\(name) is making great progress with \(totalSessions) sessions completed!"
        } else {
            return "\(name) is a dedicated \(position) with \(totalSessions) training sessions under their belt!"
        }
    }

    func generateExerciseRecommendationReason(
        exercise: Exercise,
        for player: Player,
        basedOn history: [TrainingSession]
    ) -> String {
        let name = exercise.name ?? "this exercise"
        let skills = exercise.targetSkills ?? []
        let difficulty = Int(exercise.difficulty)
        let experienceLevel = player.experienceLevel?.lowercased() ?? "intermediate"

        // Check if player has done this exercise before
        let hasCompletedBefore = history.contains { session in
            (session.exercises as? Set<SessionExercise>)?.contains { sessionExercise in
                sessionExercise.exercise == exercise
            } ?? false
        }

        if hasCompletedBefore {
            if !skills.isEmpty {
                return "Continue building your \(skills.first!.lowercased()) skills with this familiar drill."
            }
            return "Revisit \(name) to reinforce your technique."
        }

        // New exercise recommendation reasons
        if experienceLevel == "beginner" && difficulty <= 2 {
            return "Perfect for beginners — \(name) will help you develop solid fundamentals."
        }

        if !skills.isEmpty {
            let skillList = skills.prefix(2).joined(separator: " and ")
            return "Strengthen your \(skillList.lowercased()) with this targeted drill."
        }

        return "Challenge yourself with \(name) to expand your skillset."
    }

    func generateWeeklyTrainingReport(for player: Player) -> String {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        guard let sessions = player.sessions as? Set<TrainingSession> else {
            return "No training sessions recorded this week."
        }

        let recentSessions = sessions.filter { session in
            guard let date = session.date else { return false }
            return date >= weekStart
        }

        let count = recentSessions.count

        if count == 0 {
            return "No training sessions recorded this week. Time to get back on the pitch!"
        } else if count == 1 {
            return "You completed 1 training session this week. Keep up the momentum!"
        } else if count <= 3 {
            return "Great week — \(count) sessions completed. Consistency is key!"
        } else {
            return "Excellent dedication — \(count) sessions this week! You're on fire!"
        }
    }

    func generateSkillProgressDescription(skill: String, performanceHistory: [Double]) -> String {
        guard !performanceHistory.isEmpty else {
            return "No performance data available for \(skill) yet."
        }

        let average = performanceHistory.reduce(0, +) / Double(performanceHistory.count)
        let recent = performanceHistory.suffix(3)
        let recentAverage = recent.reduce(0, +) / Double(recent.count)

        let trend: String
        if recentAverage > average + 0.3 {
            trend = "improving"
        } else if recentAverage < average - 0.3 {
            trend = "declining"
        } else {
            trend = "consistent"
        }

        let levelDescription: String
        switch average {
        case 0..<2.0: levelDescription = "needs significant work"
        case 2.0..<3.0: levelDescription = "developing"
        case 3.0..<4.0: levelDescription = "solid"
        case 4.0...: levelDescription = "excellent"
        default: levelDescription = "developing"
        }

        return "Your \(skill.lowercased()) is \(levelDescription) and \(trend). Average rating: \(String(format: "%.1f", average))/5."
    }
}
