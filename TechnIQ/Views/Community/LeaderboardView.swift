import SwiftUI

// MARK: - Leaderboard (Community → Leaderboard)
//
// One flat ranked list: rank index (top three in grass), name, level, XP. The player's own rank
// is pinned on a pitch strip at the bottom.

struct LeaderboardView: View {
    @ObservedObject private var communityService = CommunityService.shared
    @FetchRequest(sortDescriptors: [])
    private var players: FetchedResults<Player>

    @State private var selectedProfile: String?

    private var player: Player? { players.first }

    // Public identity only — first name + last initial.
    private func publicName(_ entry: LeaderboardEntry) -> String {
        CommunityService.displayName(for: entry.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if communityService.isLoadingLeaderboard && communityService.leaderboard.isEmpty {
                        CommunitySkeletonRows()
                    } else if communityService.leaderboard.isEmpty {
                        CommunityEmptyBlock(
                            title: "No rankings yet",
                            message: "Complete sessions to earn XP and climb the board."
                        )
                        .padding(.top, DesignSystem.Spacing.sm)
                    } else {
                        TQRowList {
                            ForEach(communityService.leaderboard) { entry in
                                row(entry)
                            }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .refreshable {
                await communityService.fetchLeaderboard(forceRefresh: true)
            }

            if let rank = communityService.currentPlayerRank {
                rankStrip(rank: rank)
            }
        }
        .background(DesignSystem.Colors.surfaceBase)
        .onAppear {
            Task {
                await communityService.fetchLeaderboard()
                if let xp = player?.totalXP {
                    await communityService.fetchCurrentPlayerRank(playerXP: Int(xp))
                }
            }
        }
        .sheet(item: $selectedProfile) { userID in
            PublicProfileView(userID: userID)
        }
    }

    // MARK: - Row

    private func row(_ entry: LeaderboardEntry) -> some View {
        let isCurrentPlayer = entry.id == (player?.id?.uuidString ?? "")
        return TQRow(
            publicName(entry),
            subtitle: "Lvl \(entry.level)",
            leading: .index(String(format: "%02d", entry.rank), tone: entry.rank <= 3 ? .grass : .muted),
            meta: .init("\(entry.xp) XP"),
            accessory: .none,
            titleColor: isCurrentPlayer ? DesignSystem.Colors.grass : DesignSystem.Colors.chalkWhite,
            action: { selectedProfile = entry.id }
        )
    }

    // MARK: - Your rank

    private func rankStrip(rank: Int) -> some View {
        TQPitchCard(.strip, markings: .strip) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    TQEyebrow("Your rank", size: 11)
                    TQDisplayTitle("#\(rank) · \(player?.name ?? "You")", size: .strip)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                TQFigureRow([("\(player?.totalXP ?? 0)", "XP")])
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.bottom, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
    }
}

// Make String Identifiable for sheet(item:)
extension String: @retroactive Identifiable {
    public var id: String { self }
}
