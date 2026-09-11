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
// (+XP, streak, +coins). Level bar animates from before to after over 0.8 s; a level-up completes
// the bar and adds one row. Drill recap rows, "How did it feel?" writes the session rating, Done
// and Share. No confetti, no modals.

struct SessionCompleteView: View {
    let xpBreakdown: SessionXPBreakdown?
    let newLevel: Int?
    let achievements: [Achievement]
    let player: Player
    let onDismiss: () -> Void

    var exercises: [Exercise] = []
    var sessionDurationMinutes: Int = 0
    var sessionRating: Int? = nil

    // Touchline
    var recap: [SessionRecapItem] = []
    var xpBefore: Int64? = nil
    var levelBefore: Int? = nil
    var weekSummary: String? = nil
    var onEffort: ((SessionEffort) -> Void)? = nil

    @State private var effortIndex: Int = 2   // Easy · OK · Good · Hard → Good
    @State private var coinsEarned = 0
    @State private var didAwardCoins = false
    @State private var showingWeeklyCheckIn = false
    @State private var showingShareSheet = false
    @ObservedObject private var aiCoachService = AICoachService.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    private let efforts = SessionEffort.allCases

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

                    effortSection

                    HStack(spacing: 10) {
                        TQButton("Done") { onDismiss() }
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
            awardCoinsIfNeeded()
            if let rating = sessionRating, let index = efforts.firstIndex(of: SessionEffort.from(rating: rating)) {
                effortIndex = index
            }
            if newLevel != nil { HapticManager.shared.levelUp() }
            if !achievements.isEmpty { HapticManager.shared.achievementUnlocked() }
        }
        .onChange(of: effortIndex) { _, index in
            guard index < efforts.count else { return }
            onEffort?(efforts[index])
        }
        .task {
            // Ask for notification permission right after the first dopamine hit
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            NotificationManager.shared.requestPermissionIfNeeded()
            NotificationManager.shared.scheduleDailyTrainingReminder()
        }
        .sheet(isPresented: $showingWeeklyCheckIn) {
            WeeklyCheckInView(weekNumber: aiCoachService.completedWeekNumber, player: player)
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareToCommunitySheet(
                shareType: .session(
                    duration: sessionDurationMinutes,
                    exerciseCount: recap.isEmpty ? exercises.count : recap.count,
                    rating: Double(efforts[min(effortIndex, efforts.count - 1)].rating),
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
            HStack {
                Spacer()
                TQIconButton("xmark", style: .translucent, shape: .circle, size: 36, iconSize: 13, accessibilityLabel: "Close") { onDismiss() }
            }
            .padding(.top, 4)

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

    private var summaryLine: String {
        let count = recap.isEmpty ? exercises.count : recap.count
        var parts: [String] = ["\(count) drill\(count == 1 ? "" : "s")"]
        if sessionDurationMinutes > 0 { parts.append("\(sessionDurationMinutes) min") }
        if let focus = dominantSkill { parts.append("\(focus.lowercased()) work done") }
        var line = parts.joined(separator: " · ") + "."
        if let weekSummary { line += " " + weekSummary }
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
        var items: [TQStatRail.Item] = [
            .init("+\(xpBreakdown?.total ?? 0)", label: "xp", accent: true),
            .init("\(player.currentStreak)", label: player.currentStreak == 1 ? "day streak" : "day streak")
        ]
        if coinsEarned > 0 { items.append(.init("+\(coinsEarned)", label: "coins")) }
        return items
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
        let items: [(String, String?)] = recap.isEmpty
            ? exercises.map { ($0.name ?? "Drill", nil) }
            : recap.map { ($0.name, recapMeta($0)) }
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
                          meta: .init("+\(achievement.xpReward) XP", size: 14),
                          accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical)
                }
                if aiCoachService.weeklyCheckInAvailable {
                    if subscriptionManager.isPro {
                        TQRow("Week \(aiCoachService.completedWeekNumber) complete · coach review",
                              subtitle: "Adapt next week's plan",
                              leading: .tile(TQTile("AI", style: .ai)),
                              verticalPadding: DesignSystem.Spacing.rowVertical,
                              action: { showingWeeklyCheckIn = true })
                    } else {
                        TQRow("Week \(aiCoachService.completedWeekNumber) complete · coach review", note: "Pro")
                            .disabled(true)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Effort

    private var effortSection: some View {
        VStack(spacing: 10) {
            Text("How did it feel?")
                .font(DesignSystem.Typography.bodySmallStrong)
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            TQSegment(options: efforts.map(\.label), selectedIndex: $effortIndex, style: .detached)
        }
    }

    // MARK: - Coins

    private func awardCoinsIfNeeded() {
        guard !didAwardCoins else { return }
        didAwardCoins = true

        var total = CoinService.shared.awardSessionCoins(
            duration: sessionDurationMinutes,
            isFirstOfDay: (xpBreakdown?.firstSessionBonus ?? 0) > 0,
            rating: sessionRating,
            streakDay: Int(player.currentStreak)
        )
        if let level = newLevel {
            total += CoinService.shared.awardLevelUpCoins(newLevel: level)
        }
        for achievement in achievements {
            total += CoinService.shared.awardAchievementCoins(xpReward: Int(achievement.xpReward))
        }
        coinsEarned = total
    }
}
