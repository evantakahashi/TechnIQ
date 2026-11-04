import Charts
import SwiftUI

// MARK: - Camera drill trends (Run history, Pro)
//
// Zero-effort logging turned into progress: the best run per day, a headline when there's real progress
// ("Weak-foot juggling: 8 → 23 in 3 weeks"), how runs end (where the player keeps failing) and the left-foot
// share. All from `CameraTrends` over the saved runs.

struct CameraTrendsSection: View {
    let runs: [TrendRun]
    @State private var selected: CameraDrill?

    private var drills: [CameraDrill] {
        CameraDrill.allCases.filter { drill in runs.contains { $0.drill == drill } }
    }

    private var drill: CameraDrill? { selected ?? drills.first }

    var body: some View {
        if let drill {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                TQGroupHeader("Trends")
                if drills.count > 1 {
                    TQChipRow {
                        ForEach(drills) { option in
                            TQChip(option.title, isSelected: option == drill) { selected = option }
                        }
                    }
                }
                if let headline = CameraTrends.headline(runs, drill: drill) {
                    TQBody(headline, tone: .base, size: 16)
                        .accessibilityIdentifier("camera.trends.headline")
                }
                bestChart(drill)
                endings(drill)
                leftFootChart(drill)
            }
        }
    }

    private func bestChart(_ drill: CameraDrill) -> some View {
        let points = CameraTrends.dailyBests(runs, drill: drill)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            TQMeta("Best each day")
            Chart(points, id: \.day) { point in
                LineMark(x: .value("Day", point.day, unit: .day), y: .value("Best", point.best))
                    .foregroundStyle(DesignSystem.Colors.grass)
                PointMark(x: .value("Day", point.day, unit: .day), y: .value("Best", point.best))
                    .foregroundStyle(DesignSystem.Colors.grass)
            }
            .chartYAxis { AxisMarks(position: .leading) }
            .frame(height: 160)
        }
    }

    /// Where runs keep ending: the failures, surfaced.
    @ViewBuilder
    private func endings(_ drill: CameraDrill) -> some View {
        let ends = CameraTrends.endings(runs, drill: drill)
        if !ends.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                TQMeta("How your runs end")
                TQRowList {
                    ForEach(ends, id: \.reason) { ending in
                        TQRow(Self.label(ending.reason), meta: .init("\(ending.count)"), accessory: .none)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func leftFootChart(_ drill: CameraDrill) -> some View {
        let shares = CameraTrends.leftFootShare(runs, drill: drill)
        if shares.count >= 2 {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                TQMeta("Left foot share")
                Chart(shares, id: \.day) { day in
                    BarMark(x: .value("Day", day.day, unit: .day), y: .value("Left foot", day.share * 100))
                        .foregroundStyle(DesignSystem.Colors.cone)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis { AxisMarks(position: .leading, values: [0, 50, 100]) }
                .frame(height: 120)
            }
        }
    }

    /// "Ended: thigh touch (feet only)" → "Thigh touch (feet only)".
    static func label(_ reason: RunEndReason) -> String {
        let line = RunStats(count: 0, endReason: reason, touches: []).endLine
        let trimmed = line.hasPrefix("Ended: ") ? String(line.dropFirst("Ended: ".count)) : line
        return trimmed.prefix(1).uppercased() + trimmed.dropFirst()
    }
}

extension CameraRun {
    /// This run for `CameraTrends` (nil if its drill is unknown).
    var trendRun: TrendRun? {
        guard let drill = CameraDrill(rawValue: drill ?? "") else { return nil }
        return TrendRun(drill: drill, count: Int(count), date: createdAt ?? Date(),
                        endReason: endReason.flatMap(RunEndReason.init(rawValue:)), stats: stats)
    }
}
