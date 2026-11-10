import SwiftUI

// MARK: - SessionMonthCalendar
//
// Compact month grid for Session history: trained days are grass, today is outlined, the selected
// day is chalk. Tapping a day selects it (again to clear); the chevrons page by month. Purely
// presentational: the caller supplies the set of trained days (start-of-day dates).

struct SessionMonthCalendar: View {
    @Binding var month: Date
    @Binding var selectedDay: Date?
    let trainedDays: Set<Date>

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            weekdayRow
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.rowVertical)
        .overlay(alignment: .top) { TQRule() }
        .overlay(alignment: .bottom) { TQRule() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 4) {
            Text(monthTitle)
                .font(Font.system(size: 19, weight: .semibold).width(.condensed))
                .textCase(.uppercase)
                .tracking(DesignSystem.Typography.Tracking.label)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            pageButton("chevron.left", label: "Previous month") { shiftMonth(-1) }
            pageButton("chevron.right", label: "Next month") { shiftMonth(1) }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.35 : 1)
        }
    }

    private func pageButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .frame(width: DesignSystem.Spacing.hitTarget, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekdayRow: some View {
        HStack(spacing: 4) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Day cell

    private func dayCell(_ day: Date) -> some View {
        let trained = trainedDays.contains(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date()

        let fill: Color = isSelected ? DesignSystem.Colors.chalkWhite
            : trained ? DesignSystem.Colors.grass
            : DesignSystem.Colors.surfaceRaised
        let foreground: Color = isSelected || trained ? DesignSystem.Colors.textOnAccent
            : isFuture ? DesignSystem.Colors.textTertiary
            : DesignSystem.Colors.mutedIvory

        return Button {
            HapticManager.shared.selectionChanged()
            selectedDay = isSelected ? nil : day
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(Font.system(size: 15, weight: trained || isSelected ? .bold : .semibold).width(.condensed).monospacedDigit())
                .foregroundColor(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.tile, style: .continuous).fill(fill))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.tile, style: .continuous)
                        .strokeBorder(isToday && !isSelected ? DesignSystem.Colors.grass : Color.clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(accessibilityLabel(for: day, trained: trained))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: Derived

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    private var isCurrentMonth: Bool {
        calendar.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    /// Weekday initials starting on the calendar's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Leading blanks, then every day of the month.
    private var cells: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let blanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: blanks)
        for offset in 0..<dayCount {
            result.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return result
    }

    private func shiftMonth(_ value: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: value, to: month) else { return }
        withAnimation(DesignSystem.Animation.quick) {
            month = shifted
            selectedDay = nil
        }
    }

    private func accessibilityLabel(for day: Date, trained: Bool) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: day) + (trained ? ", trained" : "")
    }
}

#if DEBUG
#Preview {
    SessionMonthCalendar(month: .constant(Date()),
                         selectedDay: .constant(nil),
                         trainedDays: [Calendar.current.startOfDay(for: Date())])
        .padding(20)
        .background(DesignSystem.Colors.surfaceBase)
}
#endif
