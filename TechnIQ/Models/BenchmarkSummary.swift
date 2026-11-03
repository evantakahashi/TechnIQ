import Foundation

// MARK: - Benchmark summary
//
// Pure "last vs best" rules for the three benchmark numbers, shared by Home's rows and the
// assessment's results. Views and services hand in plain entries; nothing here touches Core Data.

/// One recorded benchmark value, detached from Core Data.
struct BenchmarkEntry: Equatable {
    let type: BenchmarkType
    let value: Int
    let date: Date
    let cameraVerified: Bool
}

struct BenchmarkSummary: Equatable {
    let type: BenchmarkType
    /// The most recent entry.
    let last: BenchmarkEntry
    /// The highest value (ties: camera-verified first, then the earliest).
    let best: BenchmarkEntry
    /// The entry before `last`, nil when there is only one.
    let previous: BenchmarkEntry?
    /// `last` beat every earlier entry. False for the first entry: there was nothing to beat.
    let isNewBest: Bool

    /// "Last 14 · Best 22".
    var metaText: String { "Last \(last.value) · Best \(best.value)" }

    /// Summaries for every type that has at least one entry.
    static func summarize(_ entries: [BenchmarkEntry]) -> [BenchmarkType: BenchmarkSummary] {
        var result: [BenchmarkType: BenchmarkSummary] = [:]
        for type in BenchmarkType.allCases {
            if let summary = summary(for: type, in: entries) { result[type] = summary }
        }
        return result
    }

    static func summary(for type: BenchmarkType, in entries: [BenchmarkEntry]) -> BenchmarkSummary? {
        // Stable sort by date so same-day entries keep the order they were handed in.
        let ordered = entries.enumerated()
            .filter { $0.element.type == type }
            .sorted { ($0.element.date, $0.offset) < ($1.element.date, $1.offset) }
            .map(\.element)
        guard let last = ordered.last else { return nil }
        let earlier = ordered.dropLast()
        let best = ordered.enumerated().max { lhs, rhs in
            if lhs.element.value != rhs.element.value { return lhs.element.value < rhs.element.value }
            if lhs.element.cameraVerified != rhs.element.cameraVerified { return !lhs.element.cameraVerified }
            return lhs.offset > rhs.offset   // earlier wins a full tie
        }?.element ?? last
        return BenchmarkSummary(
            type: type,
            last: last,
            best: best,
            previous: earlier.last,
            isNewBest: isNewBest(value: last.value, previousBest: earlier.map(\.value).max())
        )
    }

    /// A value is a new best only when it beats an earlier best (a first result has nothing to beat).
    static func isNewBest(value: Int, previousBest: Int?) -> Bool {
        guard let previousBest else { return false }
        return value > previousBest
    }
}
