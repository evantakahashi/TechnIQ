import Foundation
import CoreData

// MARK: - Insight Models

struct TrainingInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let icon: String
    let color: String // Color name as string for DesignSystem lookup
    let priority: Int // Higher = more important
    let actionable: String? // Optional action suggestion
}

enum InsightType: String {
    case pattern = "Pattern"
    case achievement = "Achievement"
    case recommendation = "Recommendation"
    case warning = "Warning"
    case celebration = "Celebration"
}

// MARK: - Insights Engine

class InsightsEngine {
    static let shared = InsightsEngine()
    private init() {}

    func generateInsights(for player: Player, sessions: [TrainingSession], timeRange: TimeRange = .month) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        // Generate various types of insights
        insights.append(contentsOf: analyzeTrainingPatterns(sessions: sessions))
        insights.append(contentsOf: analyzePerformanceTrends(sessions: sessions))
        insights.append(contentsOf: analyzeConsistency(sessions: sessions))
        insights.append(contentsOf: analyzeProgressVelocity(sessions: sessions))
        insights.append(contentsOf: analyzeCategoryBalance(sessions: sessions))
        insights.append(contentsOf: generatePredictions(sessions: sessions))

        // Sort by priority (highest first)
        return insights.sorted { $0.priority > $1.priority }
    }

    // MARK: - Training Pattern Analysis

    private func analyzeTrainingPatterns(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []
        let calendar = Calendar.current

        // Analyze day of week patterns
        var dayCount: [Int: Int] = [:] // Weekday -> count
        for session in sessions {
            guard let date = session.date else { continue }
            let weekday = calendar.component(.weekday, from: date)
            dayCount[weekday, default: 0] += 1
        }

        if let mostCommonDay = dayCount.max(by: { $0.value < $1.value }) {
            let dayName = calendar.weekdaySymbols[mostCommonDay.key - 1]
            let percentage = (Double(mostCommonDay.value) / Double(sessions.count)) * 100

            if percentage >= 40 {
                insights.append(TrainingInsight(
                    type: .pattern,
                    title: "Consistent Training Day",
                    description: "You train most often on \(dayName)s (\(Int(percentage))% of sessions). Keep this consistency!",
                    icon: "calendar.badge.checkmark",
                    color: "primaryGreen",
                    priority: 6,
                    actionable: nil
                ))
            }
        }

        // Analyze time of day patterns (if we had time data)
        // For now, analyze session duration patterns
        let durations = sessions.map { $0.duration }
        if !durations.isEmpty {
            let avgDuration = durations.reduce(0, +) / Double(durations.count)

            if avgDuration >= 60 {
                insights.append(TrainingInsight(
                    type: .pattern,
                    title: "Quality Over Quantity",
                    description: "Your sessions average \(Int(avgDuration)) minutes - great commitment to quality training!",
                    icon: "clock.badge.checkmark",
                    color: "secondaryBlue",
                    priority: 5,
                    actionable: nil
                ))
            } else if avgDuration < 30 {
                insights.append(TrainingInsight(
                    type: .recommendation,
                    title: "Extend Your Sessions",
                    description: "Your sessions average only \(Int(avgDuration)) minutes. Consider 45-60 minute sessions for better skill development.",
                    icon: "clock.arrow.2.circlepath",
                    color: "accentOrange",
                    priority: 7,
                    actionable: "Try longer sessions this week"
                ))
            }
        }

        return insights
    }

    // MARK: - Performance Trend Analysis

    private func analyzePerformanceTrends(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        // Calculate overall rating trend
        let sortedSessions = sessions.sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
        let ratings = sortedSessions.map { Double($0.overallRating) }.filter { $0 > 0 }

        guard ratings.count >= 4 else { return insights }

        let halfPoint = ratings.count / 2
        let firstHalf = Array(ratings.prefix(halfPoint))
        let secondHalf = Array(ratings.suffix(ratings.count - halfPoint))

        let firstAvg = firstHalf.reduce(0, +) / Double(firstHalf.count)
        let secondAvg = secondHalf.reduce(0, +) / Double(secondHalf.count)
        let improvement = ((secondAvg - firstAvg) / firstAvg) * 100

        if improvement >= 15 {
            insights.append(TrainingInsight(
                type: .celebration,
                title: "Impressive Improvement!",
                description: "Your performance has improved by \(Int(improvement))% over this period. You're leveling up!",
                icon: "chart.line.uptrend.xyaxis",
                color: "primaryGreen",
                priority: 9,
                actionable: nil
            ))
        } else if improvement <= -15 {
            insights.append(TrainingInsight(
                type: .warning,
                title: "Performance Dip Detected",
                description: "Your ratings have dropped by \(abs(Int(improvement)))%. Consider reviewing your training approach or taking a rest day.",
                icon: "exclamationmark.triangle",
                color: "error",
                priority: 8,
                actionable: "Review recent sessions for patterns"
            ))
        }

        return insights
    }

    // MARK: - Consistency Analysis

    private func analyzeConsistency(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []
        let calendar = Calendar.current

        // Calculate current streak
        let dates = sessions.compactMap { $0.date }.map { calendar.startOfDay(for: $0) }.sorted()
        var currentStreak = 0
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        if let lastDate = dates.last {
            if lastDate == today || lastDate == yesterday {
                currentStreak = 1

                for i in (0..<dates.count - 1).reversed() {
                    let current = dates[i]
                    let next = dates[i + 1]

                    if let dayDiff = calendar.dateComponents([.day], from: current, to: next).day, dayDiff == 1 {
                        currentStreak += 1
                    } else {
                        break
                    }
                }
            }
        }

        if currentStreak >= 7 {
            insights.append(TrainingInsight(
                type: .celebration,
                title: "Amazing Streak!",
                description: "You've trained for \(currentStreak) days in a row. Your dedication is paying off!",
                icon: "flame.fill",
                color: "accentOrange",
                priority: 8,
                actionable: nil
            ))
        } else if currentStreak == 0 && !sessions.isEmpty, let lastDate = dates.last {
            let daysSinceLastSession = calendar.dateComponents([.day], from: lastDate, to: today).day ?? 0

            if daysSinceLastSession >= 3 {
                insights.append(TrainingInsight(
                    type: .recommendation,
                    title: "Time to Train Again",
                    description: "It's been \(daysSinceLastSession) days since your last session. Get back on track today!",
                    icon: "figure.run",
                    color: "secondaryBlue",
                    priority: 9,
                    actionable: "Start a quick session now"
                ))
            }
        }

        return insights
    }

    // MARK: - Progress Velocity

    private func analyzeProgressVelocity(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        guard sessions.count >= 10 else { return insights }

        // Calculate sessions per week
        let calendar = Calendar.current
        if let firstDate = sessions.first?.date,
           let lastDate = sessions.last?.date {
            let daysBetween = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
            let weeks = max(1, Double(daysBetween) / 7.0)
            let sessionsPerWeek = Double(sessions.count) / weeks

            // Projection
            let weeksToGoal: Double = 50 // Example: 50 sessions goal
            let remaining = max(0, weeksToGoal - Double(sessions.count))
            let weeksNeeded = remaining / max(sessionsPerWeek, 0.1)

            if sessionsPerWeek >= 3 {
                insights.append(TrainingInsight(
                    type: .pattern,
                    title: "High Training Frequency",
                    description: String(format: "You're averaging %.1f sessions per week. At this pace, you'll hit 50 sessions in %.0f weeks!", sessionsPerWeek, weeksNeeded),
                    icon: "speedometer",
                    color: "primaryGreen",
                    priority: 6,
                    actionable: nil
                ))
            } else if sessionsPerWeek < 2 {
                insights.append(TrainingInsight(
                    type: .recommendation,
                    title: "Increase Training Frequency",
                    description: String(format: "You're averaging %.1f sessions per week. Try for 3+ sessions to see faster improvement.", sessionsPerWeek),
                    icon: "calendar.badge.plus",
                    color: "accentOrange",
                    priority: 7,
                    actionable: "Schedule 3 sessions this week"
                ))
            }
        }

        return insights
    }

    // MARK: - Category Balance

    private func analyzeCategoryBalance(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        var technicalCount = 0
        var physicalCount = 0
        var tacticalCount = 0

        for session in sessions {
            if let sessionExercises = session.exercises as? Set<SessionExercise> {
                for sessionExercise in sessionExercises {
                    if let exercise = sessionExercise.exercise {
                        let category = exercise.category?.lowercased() ?? ""
                        if category.contains("technical") {
                            technicalCount += 1
                        } else if category.contains("physical") {
                            physicalCount += 1
                        } else if category.contains("tactical") {
                            tacticalCount += 1
                        }
                    }
                }
            }
        }

        let total = technicalCount + physicalCount + tacticalCount
        guard total > 0 else { return insights }

        let technicalPct = Double(technicalCount) / Double(total) * 100
        let physicalPct = Double(physicalCount) / Double(total) * 100
        let tacticalPct = Double(tacticalCount) / Double(total) * 100

        // Check for imbalance (one category dominates)
        if technicalPct > 60 {
            insights.append(TrainingInsight(
                type: .recommendation,
                title: "Balance Your Training",
                description: "You're focusing heavily on technical skills (\(Int(technicalPct))%). Add more physical and tactical work for well-rounded development.",
                icon: "scale.3d",
                color: "accentOrange",
                priority: 7,
                actionable: "Add physical/tactical exercises"
            ))
        } else if physicalPct > 60 {
            insights.append(TrainingInsight(
                type: .recommendation,
                title: "Balance Your Training",
                description: "Physical training dominates (\(Int(physicalPct))%). Mix in technical and tactical skills for complete player development.",
                icon: "scale.3d",
                color: "accentOrange",
                priority: 7,
                actionable: "Add technical/tactical exercises"
            ))
        } else if technicalPct > 30 && physicalPct > 30 && tacticalPct > 20 {
            insights.append(TrainingInsight(
                type: .pattern,
                title: "Well-Balanced Training",
                description: "Great job maintaining balance across technical, physical, and tactical training!",
                icon: "checkmark.seal.fill",
                color: "primaryGreen",
                priority: 5,
                actionable: nil
            ))
        }

        return insights
    }

    // MARK: - Predictions & Forecasts

    private func generatePredictions(sessions: [TrainingSession]) -> [TrainingInsight] {
        var insights: [TrainingInsight] = []

        // Predict next milestone
        let sessionCount = sessions.count

        let milestones = [10, 25, 50, 100, 200]
        if let nextMilestone = milestones.first(where: { $0 > sessionCount }) {
            let remaining = nextMilestone - sessionCount

            // Calculate average sessions per week
            let calendar = Calendar.current
            if sessions.count >= 3,
               let firstDate = sessions.first?.date,
               let lastDate = sessions.last?.date {
                let daysBetween = calendar.dateComponents([.day], from: firstDate, to: lastDate).day ?? 1
                let weeks = max(1, Double(daysBetween) / 7.0)
                let sessionsPerWeek = Double(sessions.count) / weeks

                let weeksToMilestone = Double(remaining) / max(sessionsPerWeek, 0.1)
                let estimatedDate = calendar.date(byAdding: .day, value: Int(weeksToMilestone * 7), to: Date()) ?? Date()

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                insights.append(TrainingInsight(
                    type: .pattern,
                    title: "Next Milestone: \(nextMilestone) Sessions",
                    description: "Just \(remaining) sessions to go! At your current pace, you'll reach it around \(dateFormatter.string(from: estimatedDate)).",
                    icon: "flag.checkered",
                    color: "secondaryBlue",
                    priority: 6,
                    actionable: nil
                ))
            }
        }

        return insights
    }
}
