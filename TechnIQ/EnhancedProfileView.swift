import SwiftUI
import CoreData

struct EnhancedProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var avatarService = AvatarService.shared
    @FetchRequest var players: FetchedResults<Player>
    @FetchRequest var sessions: FetchedResults<TrainingSession>

    @State private var showingEditProfile = false
    @State private var showingAvatarCustomization = false
    @State private var showingShop = false
    @State private var showingSettings = false
    @State private var showingProgress = false
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
                NavigationView {
                    PlayerProgressView(player: player)
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
                    Text(player.name ?? "Player")
                        .font(DesignSystem.Typography.titleLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)

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
                        // TODO: Show achievements view
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
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(value)
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
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

#Preview {
    NavigationView {
        EnhancedProfileView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
