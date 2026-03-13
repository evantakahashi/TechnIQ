import SwiftUI
import CoreData

struct CalendarHeatMapView: View {
    let player: Player
    let sessions: [TrainingSession]

    @State private var monthsToShow: Int = 6

    // Calculate training data grouped by date
    private var trainingDays: [Date: TrainingDayData] {
        var days: [Date: TrainingDayData] = [:]
        let calendar = Calendar.current

        for session in sessions {
            guard let sessionDate = session.date else { continue }
            let dayStart = calendar.startOfDay(for: sessionDate)

            if var existingDay = days[dayStart] {
                existingDay.sessionCount += 1
                existingDay.totalDuration += Int(session.duration)
                existingDay.totalIntensity += Int(session.intensity)
                days[dayStart] = existingDay
            } else {
                days[dayStart] = TrainingDayData(
                    sessionCount: 1,
                    totalDuration: Int(session.duration),
                    totalIntensity: Int(session.intensity)
                )
            }
        }

        return days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Heat map grid
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    // Month labels
                    monthLabelsView

                    // Calendar grid
                    HStack(spacing: 3) {
                        ForEach(Array(monthColumns.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: 3) {
                                ForEach(0..<7, id: \.self) { dayOfWeek in
                                    if let date = column[dayOfWeek] {
                                        DayCell(
                                            date: date,
                                            data: trainingDays[date],
                                            isToday: Calendar.current.isDateInToday(date)
                                        )
                                    } else {
                                        Color.clear
                                            .frame(width: 12, height: 12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.sm)
            }

            // Legend
            legendView
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
    }

    // MARK: - Month Labels

    private var monthLabelsView: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(monthLabelsWithWidths.enumerated()), id: \.offset) { _, item in
                Text(item.label)
                    .font(.system(size: 11))
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(width: CGFloat(item.width) * 15, alignment: .leading)
                    .padding(.trailing, 8)
            }
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textSecondary)

            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colorForLevel(level))
                    .frame(width: 12, height: 12)
            }

            Text("More")
                .font(.system(size: 11))
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Computed Properties

    private var monthColumns: [[Date?]] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -monthsToShow, to: endDate) ?? endDate

        var columns: [[Date?]] = []
        var currentDate = calendar.startOfDay(for: startDate)

        // Adjust to start of week
        let weekday = calendar.component(.weekday, from: currentDate)
        if weekday != 1 { // Not Sunday
            currentDate = calendar.date(byAdding: .day, value: -(weekday - 1), to: currentDate) ?? currentDate
        }

        while currentDate <= endDate {
            var column: [Date?] = Array(repeating: nil, count: 7)

            for dayOfWeek in 0..<7 {
                if currentDate <= endDate && currentDate >= startDate {
                    column[dayOfWeek] = currentDate
                }
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            }

            columns.append(column)
        }

        return columns
    }

    private var monthLabelsWithWidths: [(label: String, width: Int)] {
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"

        var result: [(label: String, width: Int)] = []
        var currentMonth: Int? = nil
        var currentWidth = 0
        var currentLabel = ""

        for column in monthColumns {
            if let firstDate = column.first(where: { $0 != nil }), let date = firstDate {
                let month = calendar.component(.month, from: date)
                if month != currentMonth {
                    // Save previous month if exists
                    if currentWidth > 0 {
                        result.append((label: currentLabel, width: currentWidth))
                    }
                    // Start new month
                    currentLabel = dateFormatter.string(from: date)
                    currentWidth = 1
                    currentMonth = month
                } else {
                    currentWidth += 1
                }
            } else {
                currentWidth += 1
            }
        }

        // Don't forget the last month
        if currentWidth > 0 {
            result.append((label: currentLabel, width: currentWidth))
        }

        return result
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0:
            return Color(.systemGray6)
        case 1:
            return DesignSystem.Colors.primaryGreen.opacity(0.25)
        case 2:
            return DesignSystem.Colors.primaryGreen.opacity(0.5)
        case 3:
            return DesignSystem.Colors.primaryGreen.opacity(0.75)
        case 4:
            return DesignSystem.Colors.primaryGreen
        default:
            return Color(.systemGray6)
        }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let data: TrainingDayData?
    let isToday: Bool

    private var intensityLevel: Int {
        guard let data = data else { return 0 }

        // Calculate level based on session count and intensity
        let score = Double(data.sessionCount) + (Double(data.totalIntensity) / Double(max(1, data.sessionCount))) / 5.0

        switch score {
        case 0:
            return 0
        case ...1.5:
            return 1
        case ...2.5:
            return 2
        case ...3.5:
            return 3
        default:
            return 4
        }
    }

    private var color: Color {
        switch intensityLevel {
        case 0:
            return Color(.systemGray6)
        case 1:
            return DesignSystem.Colors.primaryGreen.opacity(0.25)
        case 2:
            return DesignSystem.Colors.primaryGreen.opacity(0.5)
        case 3:
            return DesignSystem.Colors.primaryGreen.opacity(0.75)
        case 4:
            return DesignSystem.Colors.primaryGreen
        default:
            return Color(.systemGray6)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 12, height: 12)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(isToday ? DesignSystem.Colors.secondaryBlue : Color.clear, lineWidth: 1.5)
            )
    }

    private var tooltipView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formatDate(date))
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(.semibold)

            if let data = data {
                Text("\(data.sessionCount) session\(data.sessionCount == 1 ? "" : "s")")
                    .font(DesignSystem.Typography.labelSmall)
                Text("\(data.totalDuration) min")
                    .font(DesignSystem.Typography.labelSmall)
            }
        }
        .padding(6)
        .background(Color(.systemBackground))
        .cornerRadius(4)
        .customShadow(DesignSystem.Shadow.medium)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Data Model

struct TrainingDayData {
    var sessionCount: Int
    var totalDuration: Int
    var totalIntensity: Int
}

#Preview {
    let context = CoreDataManager.shared.context
    let mockPlayer = Player(context: context)
    mockPlayer.name = "Preview Player"

    return CalendarHeatMapView(player: mockPlayer, sessions: [])
        .padding()
        .background(DesignSystem.Colors.background)
}
