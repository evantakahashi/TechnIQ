import SwiftUI

// MARK: - TQDateRow
//
// A flat row holding an optional day: title (+ subtitle) on the left; when set, a compact date
// picker (grass tint) and a "Clear" link; when unset, an "Add" link that fills in `suggested`.
// Date only, from `range`. Used for the next match (Training profile, both plan builders, Home).

struct TQDateRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var date: Date?
    var range: PartialRangeFrom<Date>
    var suggested: () -> Date
    var showsRule: Bool = true

    init(_ title: String, subtitle: String? = nil, date: Binding<Date?>, range: PartialRangeFrom<Date>,
         showsRule: Bool = true, suggested: @escaping () -> Date) {
        self.title = title
        self.subtitle = subtitle
        self._date = date
        self.range = range
        self.showsRule = showsRule
        self.suggested = suggested
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.titleMedium)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .lineLimit(1)
                if let subtitle {
                    TQMeta(subtitle, tone: .muted, size: 13, weight: .regular)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let current = date {
                DatePicker("", selection: Binding(get: { current }, set: { date = $0 }), in: range, displayedComponents: .date)
                    .labelsHidden()
                    .tint(DesignSystem.Colors.grass)
                    .accessibilityLabel(title)
                TQTextLink("Clear", arrow: false) { date = nil }
                    .accessibilityLabel("Clear \(title.lowercased())")
            } else {
                TQTextLink("Add", arrow: false) { date = suggested() }
                    .accessibilityLabel("Add \(title.lowercased())")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.rowVertical)
        .frame(minHeight: DesignSystem.Spacing.hitTarget)
        .overlay(alignment: .bottom) {
            if showsRule { TQRule() }
        }
    }
}

enum NextMatchDefaults {
    /// The coming Saturday (today if it is Saturday): most youth matches are at the weekend.
    static func suggested(now: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let offset = (5 - HomeWeekModel.mondayIndex(of: today, calendar: calendar) + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: today) ?? today
    }

    static func range(now: Date = Date(), calendar: Calendar = .current) -> PartialRangeFrom<Date> {
        calendar.startOfDay(for: now)...
    }
}

#if DEBUG
#Preview("Date row") {
    VStack(spacing: 0) {
        TQDateRow("Next match", subtitle: "Light the day before, recovery after", date: .constant(Date()), range: Date()...) { Date() }
        TQDateRow("Next match", date: .constant(nil), range: Date()...) { Date() }
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
