import SwiftUI

struct LeaderboardView: View {
    @StateObject private var communityService = CommunityService.shared
    @FetchRequest(sortDescriptors: [])
    private var players: FetchedResults<Player>

    @State private var selectedProfile: String?
    @State private var animatePodium = false
    @State private var animateList = false

    private var player: Player? { players.first }

    private var topThree: [LeaderboardEntry] {
        Array(communityService.leaderboard.prefix(3))
    }

    private var restOfList: [LeaderboardEntry] {
        Array(communityService.leaderboard.dropFirst(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            if communityService.isLoadingLeaderboard && communityService.leaderboard.isEmpty {
                Spacer()
                VStack(spacing: DesignSystem.Spacing.md) {
                    SoccerBallSpinner()
                    Text("Loading leaderboard...")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                Spacer()
            } else if communityService.leaderboard.isEmpty {
                Spacer()
                EmptyStateView(context: .noPosts)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Podium
                        if topThree.count >= 3 {
                            podiumSection
                        }

                        // Ranked list
                        if !restOfList.isEmpty {
                            rankedListSection
                        }
                    }
                    .padding(.vertical, DesignSystem.Spacing.lg)
                }
                .refreshable {
                    await communityService.fetchLeaderboard(forceRefresh: true)
                }
            }

            // Sticky rank bar
            if let rank = communityService.currentPlayerRank {
                stickyRankBar(rank: rank)
            }
        }
        .onAppear {
            Task {
                await communityService.fetchLeaderboard()
                if let xp = player?.totalXP {
                    await communityService.fetchCurrentPlayerRank(playerXP: Int(xp))
                }
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animatePodium = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.5)) {
                animateList = true
            }
        }
        .sheet(item: $selectedProfile) { userID in
            PublicProfileView(userID: userID)
        }
    }

    // MARK: - Podium

    private var podiumSection: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.md) {
            // 2nd place (left)
            podiumColumn(entry: topThree[1], height: 90, ringColor: Color.gray)
                .scaleEffect(animatePodium ? 1 : 0.5)
                .opacity(animatePodium ? 1 : 0)

            // 1st place (center, taller)
            podiumColumn(entry: topThree[0], height: 120, ringColor: DesignSystem.Colors.accentGold)
                .scaleEffect(animatePodium ? 1 : 0.5)
                .opacity(animatePodium ? 1 : 0)

            // 3rd place (right)
            podiumColumn(entry: topThree[2], height: 70, ringColor: DesignSystem.Colors.accentOrange)
                .scaleEffect(animatePodium ? 1 : 0.5)
                .opacity(animatePodium ? 1 : 0)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
    }

    private func podiumColumn(entry: LeaderboardEntry, height: CGFloat, ringColor: Color) -> some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Avatar circle with rank
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.backgroundSecondary)
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(ringColor, lineWidth: 3))

                Text(String(entry.name.prefix(1)).uppercased())
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.bold)
                    .foregroundColor(ringColor)

                // Rank badge
                Text("\(entry.rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(ringColor)
                    .clipShape(Circle())
                    .offset(x: 20, y: 20)
            }

            Text(entry.name)
                .font(DesignSystem.Typography.labelMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(1)

            Text("Lv. \(entry.level)")
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("\(entry.xp) XP")
                .font(DesignSystem.Typography.labelSmall)
                .fontWeight(.bold)
                .foregroundColor(ringColor)

            // Pedestal
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(ringColor.opacity(0.15))
                .frame(height: height)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(ringColor.opacity(0.3), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
        .onTapGesture { selectedProfile = entry.id }
    }

    // MARK: - Ranked List

    private var rankedListSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(restOfList.enumerated()), id: \.element.id) { index, entry in
                let isCurrentPlayer = entry.id == (player?.id?.uuidString ?? "")

                HStack(spacing: DesignSystem.Spacing.md) {
                    Text("\(entry.rank)")
                        .font(DesignSystem.Typography.labelLarge)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(width: 30, alignment: .center)

                    Circle()
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(String(entry.name.prefix(1)).uppercased())
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.name)
                            .font(DesignSystem.Typography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(isCurrentPlayer ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textPrimary)

                        Text("Lv. \(entry.level)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    Spacer()

                    Text("\(entry.xp) XP")
                        .font(DesignSystem.Typography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                .padding(.vertical, DesignSystem.Spacing.md)
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .background(
                    index % 2 == 0
                        ? Color.clear
                        : DesignSystem.Colors.backgroundSecondary.opacity(0.5)
                )
                .background(isCurrentPlayer ? DesignSystem.Colors.primaryGreen.opacity(0.08) : Color.clear)
                .onTapGesture { selectedProfile = entry.id }
                .opacity(animateList ? 1 : 0)
                .offset(y: animateList ? 0 : 10)
            }
        }
    }

    // MARK: - Sticky Rank Bar

    private func stickyRankBar(rank: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text("#\(rank)")
                .font(DesignSystem.Typography.titleMedium)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryGreen)

            Text(player?.name ?? "You")
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            Spacer()

            Text("\(player?.totalXP ?? 0) XP")
                .font(DesignSystem.Typography.labelLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.primaryGreen)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surfaceOverlay)
        .overlay(
            Rectangle()
                .fill(DesignSystem.Colors.primaryGreen)
                .frame(height: 2),
            alignment: .top
        )
    }
}

// Make String Identifiable for sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
