import SwiftUI

/// One drill's line in the Session Complete recap.
struct SessionRecapItem: Identifiable {
    let id = UUID()
    let name: String
    let reps: Int
    let minutes: Int
}

// MARK: - Session complete (Touchline 6a)
//
// Pitch header (radius 28 bottom) with "FULL TIME", headline, summary line and a stat rail
// (+XP, streak). Level bar animates from before to after over 0.8 s, with the XP parts under it; a
// level-up completes the bar and adds one row. Drill recap rows, then "How did it feel?" (Too easy /
// Right / Too hard, no default): Done stays disabled until the player picks one, and there is no
// close button to skip it. The answer is saved on the session. Share. No confetti, no modals.

struct SessionCompleteView: View {
    let xpBreakdown: SessionXPBreakdown?
    let newLevel: Int?
    let achievements: [Achievement]
    let player: Player
    let onDismiss: () -> Void

    var exercises: [Exercise] = []
    var sessionDurationMinutes: Int = 0
    /// False when the session was under five active minutes (`StreakRule`): the summary says so.
    var countsTowardStreak: Bool = true

    // Touchline
    /// Completed drills. nil = not supplied (legacy callers): every exercise is listed.
    /// An empty array means the session ended before any drill was completed.
    var recap: [SessionRecapItem]? = nil
    var xpBefore: Int64? = nil
    var levelBefore: Int? = nil
    var weekSummary: String? = nil
    var onFeel: ((SessionFeel) -> Void)? = nil

    /// Index into `feels`; nil until the player answers.
    @State private var feelIndex: Int?
    @State private var showingWeeklyCheckIn = false
    @State private var showingShareSheet = false
    @ObservedObject private var aiCoachService = AICoachService.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private let feels = SessionFeel.allCases

    private var feel: SessionFeel? {
        guard let feelIndex, feelIndex < feels.count else { return nil }
        return feels[feelIndex]
    }

    var body: some View {
        GeometryReader { proxy in
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, proxy.safeAreaInsets.top)
                    .background(
                        ZStack {
                            DesignSystem.Colors.pitch
                            TQPitchMarkings(preset: .sessionHeader)
                        }
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28, style: .continuous))
                    )

                VStack(alignment: .leading, spacing: 0) {
                    levelSection
                        .padding(.top, 44)

                    recapSection
                        .padding(.top, 22)

                    extrasSection

                    Spacer(minLength: 28)

                    feelSection

                    HStack(spacing: 10) {
                        TQButton("Done") { onDismiss() }
                            .disabled(feel == nil)
                            .accessibilityHint(feel == nil ? "Choose how it felt first" : "")
                        TQIconButton("square.and.arrow.up", style: .raised, shape: .square, size: 54, iconSize: 18, accessibilityLabel: "Share to community") {
                            showingShareSheet = true
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
            }
        }
        .ignoresSafeArea(edges: .top)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            HapticManager.shared.sessionComplete()
            if newLevel != nil { HapticManager.shared.levelUp() }
            if !achievements.isEmpty { HapticManager.shared.achievementUnlocked() }
        }
        .onChange(of: feelIndex) { _, _ in
            if let feel { onFeel?(feel) }
        }
        .task {
            NotificationManager.shared.refresh(for: player)
        }
        .sheet(isPresented: $showingWeeklyCheckIn) {
            WeeklyReviewView(weekNumber: aiCoachService.completedWeekNumber, player: player)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareToCommunitySheet(
                shareType: .session(
                    duration: sessionDurationMinutes,
                    exerciseCount: completedCount,
                    rating: Double(feel?.rating ?? SessionFeel.right.rating),
                    xp: Int(xpBreakdown?.total ?? 0)
                ),
                player: player,
                onDismiss: { showingShareSheet = false }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // No close button: the session ends through Done, after "How did it feel?".
            Color.clear.frame(height: 40)

            VStack(alignment: .leading, spacing: 10) {
                TQEyebrow("Full time · \(dateLine)")
                TQDisplayTitle("Session\ncomplete", size: .large)
                TQBody(summaryLine, tone: .onPitch)
            }
            .padding(.top, 22)

            TQStatRail(items: statItems, style: .hero)
                .padding(.top, 26)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dateLine: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE d MMM"
        return formatter.string(from: Date())
    }

    /// Drills that count for this session: the supplied recap, else every exercise.
    private var completedCount: Int { recap?.count ?? exercises.count }

    private var summaryLine: String {
        let count = completedCount
        var parts: [String] = [count == 0 ? "Ended early" : "\(count) drill\(count == 1 ? "" : "s")"]
        if sessionDurationMinutes > 0 { parts.append("\(sessionDurationMinutes) min") }
        if let focus = dominantSkill { parts.append("\(focus.lowercased()) work done") }
        var line = parts.joined(separator: " · ") + "."
        if let weekSummary { line += " " + weekSummary }
        if !countsTowardStreak { line += " Five active minutes count toward the streak." }
        return line
    }

    private var dominantSkill: String? {
        var counts: [String: Int] = [:]
        for exercise in exercises {
            for skill in exercise.targetSkills ?? [] where !skill.isEmpty { counts[skill, default: 0] += 1 }
        }
        return counts.max { $0.value < $1.value }?.key
    }

    private var statItems: [TQStatRail.Item] {
        [
            .init("+\(xpBreakdown?.total ?? 0)", label: "xp", accent: true),
            .init("\(player.currentStreak)", label: "day streak")
        ]
    }

    /// The parts of `XPFormula`: "Time +12 · Touches +3".
    private var xpPartsLine: String {
        guard let xpBreakdown, xpBreakdown.total > 0 else { return "Train a minute or more to earn xp" }
        var parts = ["Time +\(xpBreakdown.timeXP)"]
        if xpBreakdown.touchXP > 0 { parts.append("Touches +\(xpBreakdown.touchXP)") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Level

    private var levelSection: some View {
        let level = max(Int(player.currentLevel), 1)
        let xpNow = player.totalXP
        let levelStart = XPService.shared.xpRequiredForLevel(level)
        let nextLevelXP = XPService.shared.xpRequiredForLevel(level + 1)
        let current = XPService.shared.progressToNextLevel(totalXP: xpNow, currentLevel: level)
        let earned = Int64(xpBreakdown?.total ?? 0)
        let before = xpBefore ?? max(0, xpNow - earned)
        let previous = newLevel != nil ? 0 : XPService.shared.progressToNextLevel(totalXP: before, currentLevel: level)
        let inLevel = max(0, xpNow - levelStart)
        let span = max(1, nextLevelXP - levelStart)
        let toNext = max(0, nextLevelXP - xpNow)

        return VStack(alignment: .leading, spacing: 0) {
            TQLevelBar(
                previous: previous,
                current: level >= 50 ? 1 : current,
                title: "Level \(level)",
                detail: "\(inLevel.formatted()) / \(span.formatted()) · ",
                detailAccent: level >= 50 ? "max level" : "\(toNext.formatted()) to lvl \(level + 1)"
            )
            TQMeta(xpPartsLine, size: 13)
                .padding(.top, 10)
            if let newLevel {
                TQRowList(topRule: true) {
                    TQRow("Level \(newLevel) · \(XPService.shared.tierForLevel(newLevel)?.title ?? "")",
                          badge: TQBadge(.status("Level up")),
                          accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical)
                }
                .padding(.top, 14)
            }
        }
    }

    // MARK: - Recap

    @ViewBuilder
    private var recapSection: some View {
        let items: [(String, String?)] = recap.map { $0.map { ($0.name, recapMeta($0)) } }
            ?? exercises.map { ($0.name ?? "Drill", nil) }
        if !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    TQIndexRow(
                        index: String(format: "%02d", index + 1),
                        text: item.0,
                        meta: item.1,
                        indexTone: .muted,
                        textColor: DesignSystem.Colors.chalkWhite,
                        indexWidth: 34,
                        verticalPadding: DesignSystem.Spacing.rowVertical
                    )
                }
                TQRule()
            }
        }
    }

    private func recapMeta(_ item: SessionRecapItem) -> String {
        var parts: [String] = []
        if item.reps > 0 { parts.append("\(item.reps) reps") }
        if item.minutes > 0 { parts.append("\(item.minutes)′") }
        return parts.joined(separator: " · ")
    }

    // MARK: - Achievements + weekly check-in

    @ViewBuilder
    private var extrasSection: some View {
        if !achievements.isEmpty || aiCoachService.weeklyCheckInAvailable {
            VStack(spacing: 0) {
                ForEach(achievements, id: \.id) { achievement in
                    TQRow(achievement.name,
                          subtitle: achievement.description,
                          leading: .tile(TQTile("ACH")),
                          badge: TQBadge(.status("Unlocked")),
                          accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical)
                }
                if aiCoachService.weeklyCheckInAvailable {
                    if subscriptionManager.isPro {
                        TQRow("Week \(aiCoachService.completedWeekNumber) done · \(CoachIdentity.name())'s review",
                              subtitle: "See the week and what changes next",
                              leading: .tile(TQTile("AI", style: .ai)),
                              verticalPadding: DesignSystem.Spacing.rowVertical,
                              action: { showingWeeklyCheckIn = true })
                    } else {
                        TQRow("Week \(aiCoachService.completedWeekNumber) done · \(CoachIdentity.name())'s review", note: "Pro")
                            .disabled(true)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Feel

    private var feelSection: some View {
        VStack(spacing: 10) {
            Text("How did it feel?")
                .font(DesignSystem.Typography.bodySmallStrong)
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            TQSegment(options: feels.map(\.label), selection: $feelIndex, style: .detached)
        }
    }

}
