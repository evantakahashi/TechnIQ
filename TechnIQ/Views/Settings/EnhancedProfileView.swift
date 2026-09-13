import SwiftUI
import CoreData

// MARK: - You (Touchline 6c)
//
// Pitch card (avatar, tier · position eyebrow, condensed name, LVL · XP · coins, level bar, ghosted
// kit number), a stat rail (sessions / hours / streak / season G A), then row groups under
// TRAINING / ACCOUNT / ABOUT eyebrows. This is the whole account surface: subscription (manage /
// restore), legal, version, Sign out, and Delete account all live here; there is no Settings sheet.

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
    @State private var showingReminders = false
    @State private var showingPaywall = false
    @State private var showingSignOutAlert = false
    @State private var restoreMessage: String?
    @State private var showingDeleteAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var deleteConfirmationText = ""
    @State private var isDeletingAccount = false
    @State private var deleteError: String?

    private enum ProfileRoute: Hashable {
        case progress, achievements, sessionHistory, matches
    }

    init() {
        self._players = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \Player.createdAt, ascending: false)],
            predicate: AuthenticationManager.shared.playerPredicate,
            animation: .default
        )
        self._sessions = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \TrainingSession.date, ascending: false)],
            predicate: AuthenticationManager.shared.ownedByPlayerPredicate,
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
                TQScreenTitle("You")
                    .padding(.top, 8)

                if let player = currentPlayer {
                    identityCard(player)
                        .coachMark(.progress)

                    statRail(player)

                    trainingGroup
                    accountGroup
                    aboutGroup

                    TQButton("Sign out", style: .ghost, face: .text) { showingSignOutAlert = true }
                        .padding(.top, DesignSystem.Spacing.sm)
                        .accessibilityIdentifier("profile.signOut")

                    HStack {
                        Spacer()
                        TQTextLink("Delete account", arrow: false) { showingDeleteAlert = true }
                            .disabled(isDeletingAccount)
                            .accessibilityIdentifier("profile.deleteAccount")
                            .accessibilityHint("Permanently deletes your account and training data")
                        Spacer()
                    }
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
            AvatarCustomizationView(kitNumber: currentPlayer?.kitNumberValue)
        }
        .sheet(isPresented: $showingShop) {
            ShopView()
        }
        .sheet(isPresented: $showingReminders) {
            if let player = currentPlayer {
                NotificationSettingsView(player: player)
                    .presentationDetents([.medium, .large])
            }
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
        .alert("Restore purchases", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
            Button("OK", role: .cancel) { restoreMessage = nil }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Delete account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) {
                deleteConfirmationText = ""
                showingDeleteConfirmation = true
            }
        } message: {
            Text("This permanently deletes your account, training data, plans and progress. It cannot be undone.")
        }
        .alert("Type DELETE to confirm", isPresented: $showingDeleteConfirmation) {
            TextField("Type DELETE", text: $deleteConfirmationText)
                .autocapitalization(.allCharacters)
            Button("Cancel", role: .cancel) { deleteConfirmationText = "" }
            Button("Delete account", role: .destructive) { performAccountDeletion() }
                .disabled(deleteConfirmationText != "DELETE")
        } message: {
            Text("This action is permanent and cannot be reversed.")
        }
        .alert("Deletion failed", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
            Button("Try again", role: .destructive) { performAccountDeletion() }
            Button("Cancel", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "Something went wrong. Please try again.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    VStack(spacing: 12) {
                        TQSpinner(color: DesignSystem.Colors.grass, lineWidth: 3, size: 28)
                        Text("Deleting account…")
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                    }
                    .padding(28)
                    .background(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.card, style: .continuous).fill(DesignSystem.Colors.surfaceRaised))
                }
            }
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
                ProgrammaticAvatarView(avatarState: avatarService.currentAvatarState, size: .medium, kitNumber: kit)
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
                        .init(value: "\(max(Int(player.currentLevel), 1))", unit: "LVL", unitFirst: true),
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
                TQRow("Reminders", meta: .init(ReminderSettings.load().timeLabel())) { showingReminders = true }
                    .accessibilityIdentifier("profile.reminders")
                TQRow("Shop", meta: .init("", accent: "\(currentPlayer.map { Int($0.coins) } ?? 0) C")) { showingShop = true }
                if subscriptionManager.isPro {
                    TQRow("TechnIQ Pro", subtitle: "Manage subscription", badge: TQBadge(.status("Active"))) {
                        open("https://apps.apple.com/account/subscriptions")
                    }
                } else {
                    TQRow("TechnIQ Pro", meta: .init("Upgrade")) { showingPaywall = true }
                    TQRow("Restore purchases", accessory: .none) { restorePurchases() }
                        .disabled(subscriptionManager.isLoading)
                }
            }
        }
    }

    private var versionLine: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var aboutGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("About")
            TQRowList {
                TQRow("Privacy policy") { open("https://techniq-b9a27.web.app/privacy-policy.html") }
                TQRow("Terms of service") { open("https://techniq-b9a27.web.app/terms-of-service.html") }
                TQRow("Version", meta: .init(versionLine), accessory: .none)
            }
        }
    }

    // MARK: - Account actions

    private func restorePurchases() {
        Task {
            await subscriptionManager.restorePurchases()
            restoreMessage = subscriptionManager.isPro ? "Your subscription is active." : (subscriptionManager.errorMessage ?? "No active subscription found.")
        }
    }

    private func performAccountDeletion() {
        isDeletingAccount = true
        deleteError = nil
        Task {
            do {
                try await authManager.deleteAccount()
                await MainActor.run { isDeletingAccount = false }
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    deleteError = error.localizedDescription
                }
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
