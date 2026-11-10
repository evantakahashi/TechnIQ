import SwiftUI
import Charts
import CoreData

// MARK: - Progress (You → Progress & analytics)
//
// What the player can actually measure: time on the ball per week, the three benchmark numbers over
// time, how sessions felt, and which skills the drills trained. Level, streak and achievements live
// on You; they are not repeated here. Numbers come from `ProgressSummary` (pure, tested).

struct PlayerProgressView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss

    @State private var rangeIndex = 1
    @State private var summary: ProgressSummary?
    @State private var benchmarks: [BenchmarkTrend] = []
    @State private var tips: [TrainingInsight] = []
    @State private var records: PlayerRecords?
    @ObservedObject private var aiCoachService = AICoachService.shared

    private var range: TimeRange { TimeRange.allCases[rangeIndex] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                TQNavBar("Progress") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                .padding(.top, 8)

                TQSegment(options: TimeRange.allCases.map(\.displayName), selectedIndex: $rangeIndex)

                if let summary {
                    headline(summary)
                    if !summary.isEmpty {
                        ProgressMinutesChart(summary: summary, range: range)
                    }
                    if !benchmarks.isEmpty { benchmarkSection }
                    if summary.feelTotal > 0 { ProgressFeelBar(feel: summary.feel) }
                    if !summary.skills.isEmpty { skillsSection(summary) }
                    if !tips.isEmpty { tipsSection }
                    if let records, records.totalSessions > 0 { recordsSection(records) }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: load)
        .onChange(of: rangeIndex) { _, _ in load() }
    }

    // MARK: Headline

    private func headline(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(range == .all ? "All time" : "Last \(range.displayName.lowercased())", size: 11)
                TQDisplayTitle(summary.isEmpty ? "Nothing yet" : "\(summary.totalSessions) session\(summary.totalSessions == 1 ? "" : "s")", size: .medium)
                if summary.isEmpty {
                    TQBody("Finish a session and it shows up here.")
                }
            }
            if !summary.isEmpty {
                TQStatRail(items: [
                    .init(summary.timeValue.value, unit: summary.timeValue.unit, label: "trained"),
                    .init(String(format: "%.1f", summary.sessionsPerWeek), label: "per week"),
                    .init("\(player.currentStreak)", label: "day streak", accent: player.currentStreak > 0)
                ])
            }
        }
    }

    // MARK: Benchmarks

    private var benchmarkSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Benchmarks")
            TQRule()
            ForEach(benchmarks) { trend in
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trend.type.title)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                        TQMeta("Best \(trend.best) \(trend.type.unit)", tone: .muted, size: 13, weight: .regular)
                    }
                    Spacer(minLength: 8)
                    if trend.values.count > 1 {
                        ProgressSparkline(values: trend.values)
                            .frame(width: 84, height: 30)
                            .accessibilityHidden(true)
                    }
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(trend.last)")
                            .font(DesignSystem.Typography.numberMedium)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                        if let delta = trend.deltaText {
                            Text(delta)
                                .font(Font.system(size: 13, weight: .semibold).width(.condensed).monospacedDigit())
                                .foregroundColor(trend.delta >= 0 ? DesignSystem.Colors.grass : DesignSystem.Colors.cone)
                        }
                    }
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .padding(.vertical, DesignSystem.Spacing.rowVertical)
                .overlay(alignment: .bottom) { TQRule() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(trend.type.title): last \(trend.last), best \(trend.best) \(trend.type.unit)")
            }
        }
    }

    // MARK: Skills

    private func skillsSection(_ summary: ProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Skills you trained")
            TQRule()
            ForEach(summary.skills) { skill in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(skill.name)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        TQMeta("\(skill.count) drill\(skill.count == 1 ? "" : "s")", tone: .muted, size: 14)
                    }
                    TQProgressBar(progress: skill.share, height: 4, track: DesignSystem.Colors.surfaceRaised)
                }
                .padding(.vertical, DesignSystem.Spacing.rowVertical)
                .overlay(alignment: .bottom) { TQRule() }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(skill.name), \(skill.count) drills")
            }
        }
    }

    // MARK: Personal bests

    private static let bestDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    private func recordsSection(_ records: PlayerRecords) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Personal bests")
            TQRowList {
                TQRow("Longest session", subtitle: records.longestSessionDate.map { Self.bestDate.string(from: $0) },
                      meta: .init(records.longestSessionMinutes > 0 ? "\(records.longestSessionMinutes) min" : "–"), accessory: .none)
                TQRow("Best week", subtitle: records.bestWeekStart.map { "week of \(Self.bestDate.string(from: $0))" },
                      meta: .init(records.bestWeekSessions > 0 ? "\(records.bestWeekSessions) sessions" : "–"), accessory: .none)
                TQRow("Most drills in a day", subtitle: records.mostDrillsDate.map { Self.bestDate.string(from: $0) },
                      meta: .init(records.mostDrillsInADay > 0 ? "\(records.mostDrillsInADay)" : "–"), accessory: .none)
                TQRow("Longest streak", subtitle: "current \(player.currentStreak)",
                      meta: .init("\(player.longestStreak) day\(player.longestStreak == 1 ? "" : "s")"), accessory: .none)
            }
        }
    }

    // MARK: Coach tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("\(CoachIdentity.name())'s notes")
            TQRule()
            ForEach(tips) { tip in
                VStack(alignment: .leading, spacing: 4) {
                    Text(tip.title)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                    TQBody(tip.description, tone: .muted, size: 13)
                    if let action = tip.actionable {
                        Text(action)
                            .font(DesignSystem.Typography.bodySmallStrong)
                            .foregroundColor(DesignSystem.Colors.grass)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, DesignSystem.Spacing.rowVertical)
                .overlay(alignment: .bottom) { TQRule() }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Data

    private func load() {
        let sessions = ((player.sessions as? Set<TrainingSession>) ?? []).filter { $0.date != nil }
        let facts = sessions.compactMap { session -> ProgressSummary.SessionFact? in
            guard let date = session.date else { return nil }
            let drills = (session.exercises as? Set<SessionExercise>) ?? []
            return ProgressSummary.SessionFact(
                date: date,
                minutes: Int(session.duration),
                feel: SessionFeel(raw: session.feel),
                skills: drills.flatMap { $0.exercise?.targetSkills ?? [] }
            )
        }
        let now = Date()
        let built = ProgressSummary.build(facts: facts, range: range, now: now, calendar: .current)
        summary = built

        records = PlayerRecords.build(sessions: PlayerRecords.facts(for: player), now: now, calendar: .current)

        let entries = BenchmarkService.shared.entries(for: player)
        benchmarks = BenchmarkType.allCases.compactMap { BenchmarkTrend(type: $0, entries: entries) }

        let start = range.start(from: now, calendar: .current) ?? .distantPast
        let inRange = sessions.filter { ($0.date ?? .distantPast) >= start }.sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let ruleBased = built.isEmpty ? [] : InsightsEngine.shared.generateInsights(for: player, sessions: inRange, timeRange: range)
        let ai = aiCoachService.aiInsights
        let aiTypes = Set(ai.map(\.type))
        tips = Array((ai + ruleBased.filter { !aiTypes.contains($0.type) }).sorted { $0.priority > $1.priority }.prefix(3))
    }
}

// MARK: - Benchmark trend

/// One benchmark's history, oldest first.
struct BenchmarkTrend: Identifiable {
    let type: BenchmarkType
    let values: [Int]

    var id: String { type.rawValue }
    var last: Int { values.last ?? 0 }
    var best: Int { values.max() ?? 0 }
    var delta: Int { (values.last ?? 0) - (values.first ?? 0) }
    var deltaText: String? {
        guard values.count > 1 else { return nil }
        return delta >= 0 ? "+\(delta)" : "\(delta)"
    }

    init?(type: BenchmarkType, entries: [BenchmarkEntry]) {
        let ordered = entries.filter { $0.type == type }.sorted { $0.date < $1.date }.map(\.value)
        guard !ordered.isEmpty else { return nil }
        self.type = type
        self.values = ordered
    }
}

extension PlayerRecords {
    /// The player's sessions as plain facts for `PlayerRecords.build`.
    static func facts(for player: Player) -> [SessionFact] {
        ((player.sessions as? Set<TrainingSession>) ?? []).compactMap { session in
            guard let date = session.date else { return nil }
            return SessionFact(date: date, minutes: Int(session.duration), drillCount: session.exercises?.count ?? 0)
        }
    }
}
