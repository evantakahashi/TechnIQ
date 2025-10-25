import SwiftUI
import Charts
import CoreData

struct SkillTrendChartView: View {
    let sessions: [TrainingSession]
    @State private var selectedSkill: String?
    @State private var selectedCategory: String = "All"

    // Available categories
    private let categories = ["All", "Technical", "Physical", "Tactical"]

    // Extract all skills from sessions
    private var availableSkills: [String] {
        var skills: Set<String> = []

        for session in sessions {
            if let sessionExercises = session.exercises as? Set<SessionExercise> {
                for sessionExercise in sessionExercises {
                    if let exercise = sessionExercise.exercise,
                       let targetSkills = exercise.targetSkills {
                        for skill in targetSkills {
                            // Filter by category if selected
                            if selectedCategory == "All" ||
                               exercise.category?.lowercased() == selectedCategory.lowercased() {
                                skills.insert(skill)
                            }
                        }
                    }
                }
            }
        }

        return Array(skills).sorted()
    }

    // Calculate skill performance over time
    private var skillDataPoints: [SkillDataPoint] {
        guard let skill = selectedSkill else { return [] }

        var dataPoints: [SkillDataPoint] = []
        let calendar = Calendar.current

        // Group sessions by week
        var weeklyData: [Date: [Double]] = [:]

        for session in sessions {
            guard let sessionDate = session.date else { continue }

            if let sessionExercises = session.exercises as? Set<SessionExercise> {
                for sessionExercise in sessionExercises {
                    if let exercise = sessionExercise.exercise,
                       let targetSkills = exercise.targetSkills,
                       targetSkills.contains(skill) {

                        // Get start of week for this session
                        let weekStart = calendar.dateInterval(of: .weekOfYear, for: sessionDate)?.start ?? sessionDate

                        let performance = Double(sessionExercise.performanceRating)
                        weeklyData[weekStart, default: []].append(performance)
                    }
                }
            }
        }

        // Convert to data points with averages
        for (date, performances) in weeklyData.sorted(by: { $0.key < $1.key }) {
            let average = performances.reduce(0, +) / Double(max(1, performances.count))
            dataPoints.append(SkillDataPoint(date: date, performance: average, count: performances.count))
        }

        return dataPoints
    }

    // Calculate trend line
    private var trendLine: [(Date, Double)] {
        guard skillDataPoints.count >= 2 else { return [] }

        // Simple linear regression
        let n = Double(skillDataPoints.count)
        let xValues = skillDataPoints.enumerated().map { Double($0.offset) }
        let yValues = skillDataPoints.map { $0.performance }

        let sumX = xValues.reduce(0, +)
        let sumY = yValues.reduce(0, +)
        let sumXY = zip(xValues, yValues).map(*).reduce(0, +)
        let sumX2 = xValues.map { $0 * $0 }.reduce(0, +)

        let denominator = (n * sumX2 - sumX * sumX)
        guard denominator != 0 else { return [] } // Prevent division by zero

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        return skillDataPoints.enumerated().map { index, point in
            let trendValue = slope * Double(index) + intercept
            return (point.date, min(5.0, max(0.0, trendValue)))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Category filter
            categoryPicker

            // Skill selector
            if !availableSkills.isEmpty {
                skillSelector
            }

            // Chart
            if let skill = selectedSkill, !skillDataPoints.isEmpty {
                chartView
            } else {
                emptyStateView
            }
        }
        .onAppear {
            // Auto-select first skill
            if selectedSkill == nil, let firstSkill = availableSkills.first {
                selectedSkill = firstSkill
            }
        }
        .onChange(of: selectedCategory) { _ in
            // Reset skill selection when category changes
            selectedSkill = availableSkills.first
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(DesignSystem.Typography.labelMedium)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .foregroundColor(selectedCategory == category ? .white : DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                selectedCategory == category ?
                                    categoryColor(category) : Color(.systemGray6)
                            )
                            .cornerRadius(16)
                    }
                }
            }
        }
    }

    // MARK: - Skill Selector

    private var skillSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Skill")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availableSkills, id: \.self) { skill in
                        Button {
                            withAnimation {
                                selectedSkill = skill
                            }
                        } label: {
                            Text(skill)
                                .font(DesignSystem.Typography.bodySmall)
                                .fontWeight(selectedSkill == skill ? .semibold : .regular)
                                .foregroundColor(selectedSkill == skill ? .white : DesignSystem.Colors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selectedSkill == skill ?
                                        DesignSystem.Colors.primaryGreen : Color(.systemGray6)
                                )
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Chart View

    private var chartView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Chart title and stats
            if let skill = selectedSkill {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(skill)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .fontWeight(.semibold)

                        Text("Performance over time")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    // Trend indicator
                    if let first = skillDataPoints.first?.performance,
                       let last = skillDataPoints.last?.performance {
                        let change = last - first
                        let percentChange = (change / first) * 100

                        HStack(spacing: 4) {
                            Image(systemName: change > 0 ? "arrow.up.right" : (change < 0 ? "arrow.down.right" : "minus"))
                                .font(.caption2)
                                .foregroundColor(change > 0 ? DesignSystem.Colors.primaryGreen :
                                                (change < 0 ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary))

                            Text(String(format: "%+.1f%%", percentChange))
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(change > 0 ? DesignSystem.Colors.primaryGreen :
                                                (change < 0 ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary))
                        }
                    }
                }
            }

            // The chart
            Chart {
                // Performance line
                ForEach(skillDataPoints) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date, unit: .weekOfYear),
                        y: .value("Performance", dataPoint.performance)
                    )
                    .foregroundStyle(DesignSystem.Colors.primaryGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("Date", dataPoint.date, unit: .weekOfYear),
                        y: .value("Performance", dataPoint.performance)
                    )
                    .foregroundStyle(DesignSystem.Colors.primaryGreen)
                    .symbolSize(40)
                }

                // Trend line
                ForEach(Array(trendLine.enumerated()), id: \.offset) { index, point in
                    LineMark(
                        x: .value("Date", point.0, unit: .weekOfYear),
                        y: .value("Trend", point.1)
                    )
                    .foregroundStyle(DesignSystem.Colors.secondaryBlue.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                }
            }
            .frame(height: 200)
            .chartYScale(domain: 0...5)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 1, 2, 3, 4, 5]) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundStyle(DesignSystem.Colors.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            // Legend
            HStack(spacing: DesignSystem.Spacing.md) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignSystem.Colors.primaryGreen)
                        .frame(width: 8, height: 8)
                    Text("Actual")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                HStack(spacing: 4) {
                    Rectangle()
                        .fill(DesignSystem.Colors.secondaryBlue.opacity(0.5))
                        .frame(width: 12, height: 2)
                    Text("Trend")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textSecondary.opacity(0.5))

            Text(selectedSkill == nil ? "Select a skill to view trends" : "No data available for this skill")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }

    // MARK: - Helpers

    private func categoryColor(_ category: String) -> Color {
        switch category.lowercased() {
        case "technical":
            return DesignSystem.Colors.primaryGreen
        case "physical":
            return DesignSystem.Colors.accentOrange
        case "tactical":
            return DesignSystem.Colors.secondaryBlue
        default:
            return DesignSystem.Colors.neutral400
        }
    }
}

// MARK: - Data Models

struct SkillDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let performance: Double
    let count: Int
}

#Preview {
    let context = CoreDataManager.shared.context

    return SkillTrendChartView(sessions: [])
        .padding()
        .background(DesignSystem.Colors.background)
}
