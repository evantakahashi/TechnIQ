import SwiftUI

// MARK: - Day cells, week strip and schedule grid
//
// One cell enum for both: done (grass + tick), planned (raised, 1 px highlight border), today
// (pitch fill, 1.5 pt grass border), rest (empty), missed (raised, 1 px error border — past
// planned days only), locked (highlight at 50 % — future weeks before the plan starts).
// A cell may carry a session count ("2"). WeekStrip = one row of cells with day letters under
// them (34 pt, r6); ScheduleGrid = rows × 7 with a "WK n" label column (30 pt, r5).

enum TQDayCellState: Equatable {
    case done
    case planned
    case today
    case rest
    case missed
    case locked
}

struct TQDayCell: Equatable {
    var state: TQDayCellState
    var sessions: Int = 0

    static let rest = TQDayCell(state: .rest)
}

struct TQDayCellView: View {
    enum RestStyle { case empty, raised }

    let cell: TQDayCell
    var height: CGFloat = 34
    var cornerRadius: CGFloat = DesignSystem.CornerRadius.tile
    var restStyle: RestStyle = .empty

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(border.color, lineWidth: border.width)
            switch cell.state {
            case .done:
                if cell.sessions > 1 {
                    countLabel(color: DesignSystem.Colors.textOnAccent)
                } else {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textOnAccent)
                }
            case .planned, .missed:
                if cell.sessions > 1 { countLabel(color: DesignSystem.Colors.dimIvory) }
            case .today:
                if cell.sessions > 1 { countLabel(color: DesignSystem.Colors.grass) }
            case .rest, .locked:
                EmptyView()
            }
        }
        .frame(height: height)
        .opacity(cell.state == .locked ? 0.5 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func countLabel(color: Color) -> some View {
        Text("\(cell.sessions)")
            .font(Font.system(size: 12, weight: .bold).width(.condensed).monospacedDigit())
            .foregroundColor(color)
    }

    private var fill: Color {
        switch cell.state {
        case .done: return DesignSystem.Colors.grass
        case .planned, .missed: return DesignSystem.Colors.surfaceRaised
        case .today: return DesignSystem.Colors.pitch
        case .rest: return restStyle == .raised ? DesignSystem.Colors.surfaceRaised : .clear
        case .locked: return DesignSystem.Colors.surfaceHighlight
        }
    }

    private var border: (color: Color, width: CGFloat) {
        switch cell.state {
        case .planned: return (DesignSystem.Colors.surfaceHighlight, 1)
        case .today: return (DesignSystem.Colors.grass, 1.5)
        case .missed: return (DesignSystem.Colors.error, 1)
        default: return (.clear, 0)
        }
    }

    private var accessibilityText: String {
        let count = cell.sessions > 1 ? ", \(cell.sessions) sessions" : ""
        switch cell.state {
        case .done: return "done" + count
        case .planned: return "planned" + count
        case .today: return "today" + count
        case .rest: return "rest day"
        case .missed: return "missed" + count
        case .locked: return "locked"
        }
    }
}

// MARK: - Week strip (Home)

struct TQWeekStrip: View {
    let cells: [TQDayCell]          // 7, Monday first
    var todayIndex: Int? = nil       // highlights the day letter
    var dayLetters: [String] = ["M", "T", "W", "T", "F", "S", "S"]
    var showsLetters: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                let cell = index < cells.count ? cells[index] : TQDayCell.rest
                VStack(spacing: 6) {
                    // On Home, rest days render as plain raised cells (no border).
                    TQDayCellView(cell: cell, height: 34, restStyle: .raised)
                    if showsLetters {
                        Text(index < dayLetters.count ? dayLetters[index] : "")
                            .font(Font.system(size: 11, weight: index == todayIndex ? .bold : .semibold))
                            .foregroundColor(letterColor(for: cell, index: index))
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func letterColor(for cell: TQDayCell, index: Int) -> Color {
        if index == todayIndex || cell.state == .today { return DesignSystem.Colors.grass }
        if cell.state == .done { return DesignSystem.Colors.dimIvory }
        return DesignSystem.Colors.textTertiary
    }
}

// MARK: - Schedule grid (Plan detail)

struct TQScheduleGrid: View {
    struct Row: Identifiable {
        let id = UUID()
        let label: String        // "WK 3"
        let cells: [TQDayCell]   // 7
        var isCurrent: Bool = false
    }

    let rows: [Row]
    var dayLetters: [String] = ["M", "T", "W", "T", "F", "S", "S"]
    var onTap: ((_ row: Int, _ day: Int) -> Void)? = nil

    private let labelWidth: CGFloat = 44

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Color.clear.frame(width: labelWidth, height: 1)
                ForEach(0..<7, id: \.self) { index in
                    Text(index < dayLetters.count ? dayLetters[index] : "")
                        .font(Font.system(size: 12, weight: .regular).width(.condensed))
                        .tracking(0.5)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)

            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                HStack(spacing: 6) {
                    Text(row.label)
                        .font(Font.system(size: 13, weight: row.isCurrent ? .bold : .regular).width(.condensed))
                        .tracking(0.5)
                        .foregroundColor(row.isCurrent ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.dimIvory)
                        .frame(width: labelWidth, alignment: .leading)
                    ForEach(0..<7, id: \.self) { dayIndex in
                        let cell = dayIndex < row.cells.count ? row.cells[dayIndex] : TQDayCell.rest
                        Group {
                            if let onTap, cell.state != .rest {
                                Button {
                                    HapticManager.shared.selectionChanged()
                                    onTap(rowIndex, dayIndex)
                                } label: {
                                    TQDayCellView(cell: cell, height: 30, cornerRadius: 5)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                TQDayCellView(cell: cell, height: 30, cornerRadius: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(row.label), \(dayName(dayIndex))")
                    }
                }
            }

            legend
                .padding(.top, 4)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(fill: DesignSystem.Colors.grass, border: .clear, borderWidth: 0, label: "Done")
            legendItem(fill: DesignSystem.Colors.surfaceRaised, border: DesignSystem.Colors.surfaceHighlight, borderWidth: 1, label: "Session")
            legendItem(fill: DesignSystem.Colors.pitch, border: DesignSystem.Colors.grass, borderWidth: 1.5, label: "Today")
            Spacer()
        }
        .accessibilityHidden(true)
    }

    private func legendItem(fill: Color, border: Color, borderWidth: CGFloat, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 2, style: .continuous).strokeBorder(border, lineWidth: borderWidth))
                .frame(width: 10, height: 10)
            Text(label)
                .font(Font.system(size: 12, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.dimIvory)
        }
    }

    private func dayName(_ index: Int) -> String {
        ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"][min(max(index, 0), 6)]
    }
}

#if DEBUG
#Preview("Week strip + grid") {
    VStack(spacing: 24) {
        TQWeekStrip(cells: [.init(state: .done), .init(state: .rest), .init(state: .done), .init(state: .done), .init(state: .rest), .init(state: .today), .init(state: .rest)], todayIndex: 5)
        TQScheduleGrid(rows: [
            .init(label: "WK 1", cells: [.init(state: .done), .rest, .init(state: .done), .init(state: .done), .rest, .init(state: .done, sessions: 2), .rest]),
            .init(label: "WK 2", cells: [.init(state: .done), .init(state: .done), .rest, .init(state: .done), .rest, .init(state: .done), .rest]),
            .init(label: "WK 3", cells: [.init(state: .done), .rest, .init(state: .planned), .init(state: .planned), .rest, .init(state: .today, sessions: 2), .rest], isCurrent: true),
            .init(label: "WK 4", cells: [.init(state: .planned), .init(state: .planned), .rest, .init(state: .planned), .rest, .init(state: .planned), .rest])
        ])
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
