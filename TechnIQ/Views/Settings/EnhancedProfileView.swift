import SwiftUI
import CoreData

struct EnhancedProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @ObservedObject private var avatarService = AvatarService.shared
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var sessions: FetchedResults<TrainingSession>

    @State private var showingEditProfile = false
    @State private var showingAvatarCustomization = false
    @State private var showingShop = false
    @State private var showingSettings = false
    @State private var showingProgress = false
    @State private var showingAchievements = false
    @State private var showingSignOutAlert = false

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

    private var totalTrainingHours: Double {
        let totalMinutes = sessions.reduce(0) { $0 + $1.duration }
        return totalMinutes / 60.0
    }

    var body: some View {
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if let player = currentPlayer {
                        // Profile Header Card
                        profileHeader(player: player)

                        // Quick Stats Row
                        quickStatsRow(player: player)
                            .coachMark(.progress)

                        // Menu Sections
                        trainingSection(player: player)
                        accountSection
                        appSection

                        // Sign Out Button
                        signOutButton
                    } else {
                        ContentUnavailableView(
                            "No Profile Found",
                            systemImage: "person.circle",
                            description: Text("Create a profile to get started")
                        )
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(isPresented: $showingProgress) {
            if let player = currentPlayer {
                NavigationStack {
                    PlayerProgressView(player: player)
                }
            }
        }
        .sheet(isPresented: $showingAchievements) {
            if let player = currentPlayer {
                NavigationStack {
                    AchievementsBrowseView(player: player)
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
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

    // MARK: - Profile Header

    private func profileHeader(player: Player) -> some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Avatar
                ProgrammaticAvatarView(
                    avatarState: avatarService.currentAvatarState,
                    size: .medium
                )
                .frame(width: 80, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md))

                // Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text((player.name ?? "Player").uppercased())
                        .font(DesignSystem.Typography.displayLarge)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Label("Level \(player.currentLevel)", systemImage: "star.circle.fill")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(DesignSystem.Colors.xpGold)

                        if let position = player.position, !position.isEmpty {
                            Text(position)
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }

                    // XP Progress
                    let xpProgress = XPService.shared.progressToNextLevel(
                        totalXP: player.totalXP,
                        currentLevel: Int(player.currentLevel)
                    )
                    let xpToNext = XPService.shared.xpRequiredForLevel(Int(player.currentLevel) + 1) - player.totalXP

                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: xpProgress)
                            .tint(DesignSystem.Colors.xpGold)

                        Text("\(max(0, xpToNext)) XP to next level")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Quick Stats Row

    private func quickStatsRow(player: Player) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            QuickStatItem(
                value: "\(sessions.count)",
                label: "Sessions",
                icon: "calendar",
                color: DesignSystem.Colors.primaryGreen
            )

            QuickStatItem(
                value: String(format: "%.1f", totalTrainingHours),
                label: "Hours",
                icon: "clock.fill",
                color: DesignSystem.Colors.secondaryBlue
            )

            QuickStatItem(
                value: "\(player.currentStreak)",
                label: "Streak",
                icon: "flame.fill",
                color: DesignSystem.Colors.streakOrange
            )
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Menu Sections

    private func trainingSection(player: Player) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("TRAINING")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, DesignSystem.Spacing.sm)

            ModernCard(padding: 0) {
                VStack(spacing: 0) {
                    ProfileMenuItem(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Progress & Analytics",
                        color: DesignSystem.Colors.primaryGreen
                    ) {
                        showingProgress = true
                    }

                    Divider().padding(.leading, 52)

                    ProfileMenuItem(
                        icon: "trophy.fill",
                        title: "Achievements",
                        color: DesignSystem.Colors.xpGold
                    ) {
                        showingAchievements = true
                    }
                }
            }
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("ACCOUNT")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, DesignSystem.Spacing.sm)

            ModernCard(padding: 0) {
                VStack(spacing: 0) {
                    ProfileMenuItem(
                        icon: "person.fill",
                        title: "Edit Profile",
                        color: DesignSystem.Colors.secondaryBlue
                    ) {
                        showingEditProfile = true
                    }

                    Divider().padding(.leading, 52)

                    ProfileMenuItem(
                        icon: "paintpalette.fill",
                        title: "Customize Avatar",
                        color: DesignSystem.Colors.levelPurple
                    ) {
                        showingAvatarCustomization = true
                    }

                    Divider().padding(.leading, 52)

                    ProfileMenuItem(
                        icon: "cart.fill",
                        title: "Shop",
                        color: DesignSystem.Colors.coinGold
                    ) {
                        showingShop = true
                    }
                }
            }
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("APP")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, DesignSystem.Spacing.sm)

            ModernCard(padding: 0) {
                VStack(spacing: 0) {
                    ProfileMenuItem(
                        icon: "gearshape.fill",
                        title: "Settings",
                        color: DesignSystem.Colors.neutral500
                    ) {
                        showingSettings = true
                    }

                    Divider().padding(.leading, 52)

                    ProfileMenuItem(
                        icon: "questionmark.circle.fill",
                        title: "Help & Support",
                        color: DesignSystem.Colors.info
                    ) {
                        // TODO: Show help view
                    }
                }
            }
        }
    }

    private var signOutButton: some View {
        Button {
            showingSignOutAlert = true
        } label: {
            HStack {
                Spacer()
                Text("Sign Out")
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.error)
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.error.opacity(0.1))
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
        .padding(.top, DesignSystem.Spacing.md)
        .a11y(label: "Sign out", hint: "Double tap to sign out of your account")
    }

    // MARK: - Helpers

    private func updateFilters() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
        sessions.nsPredicate = NSPredicate(format: "player.firebaseUID == %@", authManager.userUID)
    }

}

// MARK: - Supporting Views

struct QuickStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(label.uppercased())
                .font(DesignSystem.Typography.labelSmall)
                .tracking(1.0)
                .foregroundColor(DesignSystem.Colors.mutedIvory)
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(color)
                Text(value)
                    .font(DesignSystem.Typography.heroDisplay)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .customShadow(DesignSystem.Shadow.small)
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(color)
                }

                Text(title)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .buttonStyle(PlainButtonStyle())
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
        ZStack {
            AdaptiveBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    summaryHeader

                    ForEach(Achievement.AchievementCategory.allCases, id: \.self) { category in
                        categorySection(category)
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }
        }
    }

    private var summaryHeader: some View {
        ModernCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.xpGold.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 26))
                        .foregroundColor(DesignSystem.Colors.xpGold)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(unlockedCount) of \(AchievementService.allAchievements.count) unlocked")
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("Keep training to earn them all!")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
        }
    }

    private func categorySection(_ category: Achievement.AchievementCategory) -> some View {
        let items = AchievementService.allAchievements.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(category.rawValue.uppercased())
                .font(DesignSystem.Typography.labelSmall)
                .tracking(1.0)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .padding(.leading, DesignSystem.Spacing.sm)

            LazyVGrid(columns: columns, spacing: DesignSystem.Spacing.md) {
                ForEach(items, id: \.id) { achievement in
                    achievementTile(achievement)
                }
            }
        }
    }

    private func achievementTile(_ achievement: Achievement) -> some View {
        let unlocked = AchievementService.shared.isUnlocked(achievement.id, for: player)
        let progress = AchievementService.shared.getProgress(for: achievement, player: player, in: viewContext)

        return VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                Circle()
                    .fill((unlocked ? DesignSystem.Colors.xpGold : DesignSystem.Colors.neutral400).opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: unlocked ? achievement.icon : "lock.fill")
                    .font(.system(size: 28))
                    .foregroundColor(unlocked ? DesignSystem.Colors.xpGold : DesignSystem.Colors.textTertiary)
            }

            Text(achievement.name)
                .font(DesignSystem.Typography.labelLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(achievement.description)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            if unlocked {
                Text("+\(achievement.xpReward) XP")
                    .font(DesignSystem.Typography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            } else if progress > 0 {
                ProgressView(value: progress)
                    .tint(DesignSystem.Colors.primaryGreen)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 190, alignment: .top)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.small)
        .opacity(unlocked ? 1.0 : 0.85)
        .a11y(
            label: "\(achievement.name), \(unlocked ? "unlocked" : "locked"). \(achievement.description)",
            trait: .isStaticText
        )
    }
}

#Preview {
    NavigationStack {
        EnhancedProfileView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
