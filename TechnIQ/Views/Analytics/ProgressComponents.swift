import SwiftUI
import Charts

// MARK: - Progress charts (flat, one accent)

/// Minutes per day (week range) or per week: the current bucket in grass, the rest raised.
struct ProgressMinutesChart: View {
    let summary: ProgressSummary
    let range: TimeRange

    private var title: String { range == .week ? "Minutes per day" : "Minutes per week" }

    /// Show at most ~6 axis labels however many bars there are.
    private var labelledStarts: Set<Date> {
        let buckets = summary.buckets
        let stride = max(1, Int((Double(buckets.count) / 6).rounded(.up)))
        return Set(buckets.enumerated().filter { ($0.offset - (buckets.count - 1)) % stride == 0 }.map(\.element.start))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TQSectionHeader(title) {
                TQMeta("avg \(summary.averageBucketMinutes) min", tone: .muted, size: 14)
            }
            Chart(summary.buckets) { bucket in
                BarMark(
                    x: .value("Start", bucket.start, unit: range == .week ? .day : .weekOfYear),
                    y: .value("Minutes", bucket.minutes),
                    width: .ratio(0.72)
                )
                .cornerRadius(2)
                .foregroundStyle(bucket.isCurrent ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight)
            }
            .chartXAxis {
                AxisMarks(values: summary.buckets.map(\.start)) { value in
                    if let date = value.as(Date.self), labelledStarts.contains(date),
                       let bucket = summary.buckets.first(where: { $0.start == date }) {
                        AxisValueLabel {
                            Text(bucket.label)
                                .font(Font.system(size: 11, weight: .semibold).width(.condensed))
                                .foregroundColor(bucket.isCurrent ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 1)).foregroundStyle(DesignSystem.Colors.surfaceOverlay)
                    AxisValueLabel()
                        .font(Font.system(size: 11, weight: .semibold).width(.condensed))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                }
            }
            .frame(height: 150)
            .accessibilityLabel("\(title), average \(summary.averageBucketMinutes) minutes")
        }
    }
}

/// "How it felt": one bar split three ways, counts underneath.
struct ProgressFeelBar: View {
    let feel: [SessionFeel: Int]

    private var total: Int { max(1, feel.values.reduce(0, +)) }

    private func color(_ feel: SessionFeel) -> Color {
        switch feel {
        case .tooEasy: return DesignSystem.Colors.dimIvory
        case .right: return DesignSystem.Colors.grass
        case .tooHard: return DesignSystem.Colors.cone
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TQSectionHeader("How it felt")
            GeometryReader { proxy in
                HStack(spacing: 2) {
                    ForEach(SessionFeel.allCases) { item in
                        let count = feel[item] ?? 0
                        if count > 0 {
                            Rectangle()
                                .fill(color(item))
                                .frame(width: max(4, (proxy.size.width - 4) * CGFloat(count) / CGFloat(total)))
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .frame(height: 10)
            HStack(spacing: 16) {
                ForEach(SessionFeel.allCases) { item in
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(color(item)).frame(width: 8, height: 8)
                        TQMeta("\(item.label) \(feel[item] ?? 0)", tone: .muted, size: 13)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SessionFeel.allCases.map { "\($0.label) \(feel[$0] ?? 0)" }.joined(separator: ", "))
    }
}

/// Small line of a benchmark's values, last point marked.
struct ProgressSparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { proxy in
            let low = Double(values.min() ?? 0), high = Double(values.max() ?? 1)
            let span = max(1, high - low)
            let inset: CGFloat = 4
            let points: [CGPoint] = values.enumerated().map { index, value in
                let x = inset + (proxy.size.width - 2 * inset) * CGFloat(index) / CGFloat(max(1, values.count - 1))
                let y = inset + (proxy.size.height - 2 * inset) * CGFloat(1 - (Double(value) - low) / span)
                return CGPoint(x: x, y: y)
            }
            ZStack {
                Path { path in
                    guard let first = points.first else { return }
                    path.move(to: first)
                    points.dropFirst().forEach { path.addLine(to: $0) }
                }
                .stroke(DesignSystem.Colors.dimIvory, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                if let last = points.last {
                    Circle().fill(DesignSystem.Colors.grass).frame(width: 7, height: 7).position(last)
                }
            }
        }
    }
}
