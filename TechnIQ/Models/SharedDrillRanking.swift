import Foundation

// MARK: - SharedDrillRanking
//
// Pure ranking/filtering rules for the Community drills tab (Touchline 6b), kept out of the view
// so they can be unit-tested: the "drill of the week" pick, chip filtering and the saves label.

enum SharedDrillRanking {
    enum Chip: String, CaseIterable, Identifiable {
        case trending, new, technical, tactical, physical

        var id: String { rawValue }

        var title: String {
            switch self {
            case .trending: return "Trending"
            case .new: return "New"
            case .technical: return "Technical"
            case .tactical: return "Tactical"
            case .physical: return "Physical"
            }
        }

        /// Firestore category filter for the chip, nil for the unfiltered chips.
        var category: String? {
            switch self {
            case .technical, .tactical, .physical: return rawValue
            case .trending, .new: return nil
            }
        }
    }

    /// Most-saved drill shared in the last seven days; falls back to the most-saved overall.
    /// Hidden drills never feature. Ties keep the more recent drill.
    static func featured(from drills: [SharedDrill], now: Date = Date(), calendar: Calendar = .current) -> SharedDrill? {
        let visible = drills.filter { !$0.isHidden }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let recent = visible.filter { $0.timestamp >= weekAgo && $0.timestamp <= now }
        let pool = recent.isEmpty ? visible : recent
        return pool.sorted(by: rankBySaves).first
    }

    /// The rows under the chip: hidden drills dropped; Trending by saves, New by recency,
    /// category chips filtered by category (case-insensitive) then by saves.
    static func visible(_ drills: [SharedDrill], chip: Chip) -> [SharedDrill] {
        let shown = drills.filter { !$0.isHidden }
        switch chip {
        case .trending:
            return shown.sorted(by: rankBySaves)
        case .new:
            return shown.sorted { $0.timestamp > $1.timestamp }
        case .technical, .tactical, .physical:
            return shown
                .filter { $0.category.lowercased() == chip.category }
                .sorted(by: rankBySaves)
        }
    }

    /// "842", "1.2K", "12K".
    static func savesLabel(_ count: Int) -> String {
        guard count >= 1000 else { return "\(max(count, 0))" }
        let thousands = Double(count) / 1000
        let text = thousands >= 10 ? String(format: "%.0f", thousands) : String(format: "%.1f", thousands)
        return text.replacingOccurrences(of: ".0", with: "") + "K"
    }

    private static func rankBySaves(_ lhs: SharedDrill, _ rhs: SharedDrill) -> Bool {
        if lhs.saveCount != rhs.saveCount { return lhs.saveCount > rhs.saveCount }
        return lhs.timestamp > rhs.timestamp
    }
}
