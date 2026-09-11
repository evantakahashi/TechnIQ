import SwiftUI
import CoreData

// MARK: - You (Touchline 6c)
//
// Pitch card (avatar, tier · position eyebrow, condensed name, LVL · XP · coins, level bar, ghosted
// kit number), a stat rail (sessions / hours / streak / season G A), then row groups under
// TRAINING / ACCOUNT / APP eyebrows. TechnIQ Pro shows an ACTIVE badge; Sign out is a ghost button.

struct EnhancedProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @ObservedObject private var avatarService = AvatarService.shared
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var sessions: FetchedResults<TrainingSession>

    @State private var route: ProfileRoute?
    @State private var showingEditProfile = false
    @State private var showingAvatarCustomization = false
    @State private var showingShop = false
    @State private var showingSettings = false
    @State private var showingPaywall = false
    @State private var showingSignOutAlert = false

    private enum ProfileRoute: Hashable {
        case progress, achievements, sessionHistory, matches
    }

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: NSPredicate(value: true),
            animation: .default
        )
    }

    var currentPlayer: Player? {
        guard !authManager.userUID.isEmpty else { return nil }
        return players.first { $0.firebaseUID == authManager.userUID }
    }

    // MARK: Derived

    private var totalTrainingHours: Int {
        Int((sessions.reduce(0) { $0 + $1.duration } / 60.0).rounded())
    }

    private func seasonGoalsAssists(for player: Player) -> (Int, Int) {
        let matches: [Match]
        if let season = MatchService.shared.getActiveSeason(for: player), let set = season.matches as? Set<Match> {
            matches = Array(set)
        } else {
            matches = (player.matches as? Set<Match>).map(Array.init) ?? []
        }
        let stats = MatchService.shared.calculateStats(for: matches)
        return (stats.totalGoals, stats.totalAssists)
    }

    private func tierTitle(for player: Player) -> String {
        XPService.shared.tierForLevel(Int(player.currentLevel))?.title ?? "Prospect"
    }

    private func levelProgress(for player: Player) -> Double {
        XPService.shared.progressToNextLevel(totalXP: player.totalXP, currentLevel: Int(player.currentLevel))
    }

    private var achievementSummary: String {
        guard let player = currentPlayer else { return "" }
        let unlocked = AchievementService.shared.getUnlockedAchievements(for: player).count
        return "\(unlocked) / \(AchievementService.allAchievements.count)"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
                TQScreenTitle("You") {
                    TQIconAction("gearshape", accessibilityLabel: "Settings") { showingSettings = true }
                        .accessibilityIdentifier("profile.settings")
                }
                .padding(.top, 8)

                if let player = currentPlayer {
                    identityCard(player)
                        .coachMark(.progress)

                    statRail(player)

                    trainingGroup
                    accountGroup
                    appGroup

                    TQButton("Sign out", style: .ghost, face: .text) { showingSignOutAlert = true }
                        .padding(.top, DesignSystem.Spacing.sm)
                        .accessibilityIdentifier("profile.signOut")
                } else {
                    TQRowList {
                        TQRow("No profile yet", note: "sign in to get started").disabled(true)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $route) { route in
            destination(for: route)
        }
        .sheet(isPresented: $showingEditProfile) {
            if let player = currentPlayer {
                EditProfileView(player: player)
            }
        }
        .sheet(isPresented: $showingAvatarCustomization) {
            AvatarCustomizationView()
        }
        .sheet(isPresented: $showingShop) {
            ShopView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(feature: .trainingPlan)
        }
        .alert("Sign out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .onAppear {
            updateFilters()
            avatarService.loadCurrentAvatar()
        }
    }

    // MARK: - Identity card

    private func identityCard(_ player: Player) -> some View {
        let kit = player.kitNumberValue
        let coins = Int(player.coins)
        return TQPitchCard(.hero, markings: .profile) {
            HStack(alignment: .top, spacing: 16) {
                ProgrammaticAvatarView(avatarState: avatarService.currentAvatarState, size: .medium)
                    .scaleEffect(0.65)
                    .frame(width: 78, height: 117)
                    .background(DesignSystem.Colors.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    TQEyebrow([tierTitle(for: player), player.position].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "), size: 12)
                    TQDisplayTitle(player.name ?? "Player", size: .medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    TQFigureRow(figures: [
                        .init(value: "\(player.currentLevel)", unit: "LVL", unitFirst: true),
                        .init(value: player.totalXP.formatted(.number), unit: "XP"),
                        .init(value: "\(coins)", unit: "C")
                    ], onPitch: true, valueSize: 18, unitSize: 16, spacing: 14)
                    TQLevelBar(previous: levelProgress(for: player), current: levelProgress(for: player), height: 6, animates: false, onPitch: true)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let kit {
                Text("\(kit)")
                    .font(Font.system(size: 56, weight: .bold).width(.condensed))
                    .foregroundColor(DesignSystem.Colors.chalkWhite.opacity(0.18))
                    .padding(.trailing, 18)
                    .padding(.top, 8)
                    .accessibilityLabel("Kit number \(kit)")
            }
        }
    }

    // MARK: - Stat rail

    private func statRail(_ player: Player) -> some View {
        let (goals, assists) = seasonGoalsAssists(for: player)
        return TQStatRail(items: [
            .init("\(sessions.count)", label: "sessions"),
            .init("\(totalTrainingHours)", unit: "h", label: "trained"),
            .init("\(player.currentStreak)", label: "streak", accent: true),
            .init("\(goals)G \(assists)A", label: "season")
        ])
    }

    // MARK: - Row groups

    private var trainingGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Training")
            TQRowList {
                TQRow("Progress & analytics") { route = .progress }
                TQRow("Achievements", meta: .init(achievementSummary)) { route = .achievements }
                TQRow("Session history") { route = .sessionHistory }
                TQRow("Matches & seasons") { route = .matches }
            }
        }
    }

    private var accountGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Account")
            TQRowList {
                TQRow("Edit profile") { showingEditProfile = true }
                TQRow("Kit & avatar") { showingAvatarCustomization = true }
                TQRow("Shop", meta: .init("", accent: "\(currentPlayer.map { Int($0.coins) } ?? 0) C")) { showingShop = true }
                if subscriptionManager.isPro {
                    TQRow("TechnIQ Pro", badge: TQBadge(.status("Active"))) { showingSettings = true }
                } else {
                    TQRow("TechnIQ Pro", meta: .init("Upgrade")) { showingPaywall = true }
                }
            }
        }
    }

    private var appGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("App")
            TQRowList {
                TQRow("Settings") { showingSettings = true }
                TQRow("Privacy policy") { open("https://techniq-b9a27.web.app/privacy-policy.html") }
                TQRow("Terms of service") { open("https://techniq-b9a27.web.app/terms-of-service.html") }
            }
        }
    }

    // MARK: - Navigation

    @ViewBuilder
    private func destination(for route: ProfileRoute) -> some View {
        if let player = currentPlayer {
            switch route {
            case .progress: PlayerProgressView(player: player)
            case .achievements: AchievementsBrowseView(player: player)
            case .sessionHistory: SessionHistoryView()
            case .matches: MatchHistoryView(player: player)
            }
        }
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func updateFilters() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        sessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }
}

// MARK: - Achievements Browse

struct AchievementsBrowseView: View {
    let player: Player
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
        GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
    ]

    private var unlockedCount: Int {
        AchievementService.shared.getUnlockedAchievements(for: player).count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
                TQNavBar("Achievements") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                TQStatRail(items: [
                    .init("\(unlockedCount)", label: "unlocked", accent: true),
                    .init("\(AchievementService.allAchievements.count - unlockedCount)", label: "to earn")
                ], style: .compact)

                ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
                    categorySection(category)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func categorySection(_ category: Achievement.AchievementCategory) -> some View {
        let items = AchievementService.allAchievements.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader(category.rawValue)
            TQRowList {
                ForEach(items, id: \.id) { achievement in
                    achievementRow(achievement)
                }
            }
        }
    }

    private func achievementRow(_ achievement: Achievement) -> some View {
        let unlocked = AchievementService.shared.isUnlocked(achievement.id, for: player)
        let progress = AchievementService.shared.getProgress(for: achievement, player: player, in: viewContext)
        let meta: TQRow.Meta = unlocked
            ? .init("", accent: "+\(achievement.xpReward) XP")
            : .init(progress > 0 ? "\(Int((progress * 100).rounded()))%" : "Locked")
        return TQRow(
            achievement.name,
            subtitle: achievement.description,
            leading: .tile(TQTile(symbol: unlocked ? achievement.icon : "lock.fill")),
            meta: meta,
            accessory: .none,
            verticalPadding: DesignSystem.Spacing.rowVertical
        )
        .opacity(unlocked ? 1 : 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.name), \(unlocked ? "unlocked" : "locked"). \(achievement.description)")
    }
}

#Preview {
    NavigationStack {
        EnhancedProfileView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
            .environmentObject(SubscriptionManager.shared)
    }
}
