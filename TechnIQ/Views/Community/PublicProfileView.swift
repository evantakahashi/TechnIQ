import SwiftUI

struct PublicProfileView: View {
    let userID: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService.shared

    @State private var profileName = ""
    @State private var profileLevel = 1
    @State private var profilePosition = ""
    @State private var profileXP: Int64 = 0
    @State private var profileSessions = 0
    @State private var isLoading = true
    @State private var showingBlockConfirm = false
    @State private var userPosts: [CommunityPost] = []
    @State private var sharedDrillsCount = 0

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    if isLoading {
                        LoadingStateView(message: "Loading profile...")
                            .padding(.top, DesignSystem.Spacing.xxl)
                    } else {
                        // Profile header
                        profileHeader

                        // Stats
                        statsSection

                        // Recent posts
                        recentPostsSection
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showingBlockConfirm = true
                        } label: {
                            Label("Block User", systemImage: "hand.raised.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .alert("Block User", isPresented: $showingBlockConfirm) {
                Button("Block", role: .destructive) {
                    blockUser()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You won't see posts or comments from this user. This can't be undone.")
            }
            .onAppear { loadProfile() }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Avatar
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.primaryGreen.opacity(0.15))
                    .frame(width: 80, height: 80)
                Text(String(profileName.prefix(1)).uppercased())
                    .font(DesignSystem.Typography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
            }

            // Name & level
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(profileName)
                    .font(DesignSystem.Typography.titleLarge)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(DesignSystem.Colors.xpGold)
                        Text("Level \(profileLevel)")
                            .fontWeight(.medium)
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                    if !profilePosition.isEmpty {
                        Text("·")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text(profilePosition)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                StatCard(
                    title: "Total XP",
                    value: "\(profileXP)",
                    icon: "bolt.fill",
                    color: DesignSystem.Colors.xpGold
                )

                StatCard(
                    title: "Sessions",
                    value: "\(profileSessions)",
                    icon: "calendar",
                    color: DesignSystem.Colors.primaryGreen
                )
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                StatCard(
                    title: "Shared Drills",
                    value: "\(sharedDrillsCount)",
                    icon: "square.and.arrow.up.fill",
                    color: DesignSystem.Colors.secondaryBlue
                )
            }
        }
    }

    // MARK: - Recent Posts

    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Recent Posts")
                .font(DesignSystem.Typography.titleSmall)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)

            if userPosts.isEmpty {
                Text("No posts yet")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else {
                ForEach(userPosts) { post in
                    ModernCard {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(post.content)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .lineLimit(3)

                            HStack {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "heart.fill")
                                        .font(.caption2)
                                        .foregroundColor(DesignSystem.Colors.error)
                                    Text("\(post.likesCount)")
                                        .font(DesignSystem.Typography.labelSmall)
                                }
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "bubble.left")
                                        .font(.caption2)
                                    Text("\(post.commentsCount)")
                                        .font(DesignSystem.Typography.labelSmall)
                                }
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                                Spacer()

                                Text(post.timestamp.timeAgoDisplay())
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadProfile() {
        Task {
            do {
                let profile = try await communityService.fetchPublicProfile(userID: userID)
                profileName = profile.name
                profileLevel = profile.level
                profilePosition = profile.position
                profileXP = profile.totalXP
                profileSessions = profile.sessionsCount

                // Load user's posts from the existing feed
                userPosts = communityService.posts.filter { $0.authorID == userID }

                // Load shared drills count
                sharedDrillsCount = await communityService.fetchSharedDrillsCount(userID: userID)

                isLoading = false
            } catch {
                isLoading = false
                #if DEBUG
                print("❌ Load profile error: \(error)")
                #endif
            }
        }
    }

    private func blockUser() {
        Task {
            try? await communityService.blockUser(userID)
            dismiss()
        }
    }
}
