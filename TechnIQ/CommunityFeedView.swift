import SwiftUI
import CoreData

struct CommunityFeedView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var communityService = CommunityService.shared
    @FetchRequest var players: FetchedResults<Player>

    @State private var showingCreatePost = false
    @State private var selectedPost: CommunityPost?
    @State private var showingPostDetail = false

    init() {
        self._players = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(value: false),
            animation: .default
        )
    }

    private var currentPlayer: Player? {
        players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    if communityService.isLoading && communityService.posts.isEmpty {
                        LoadingStateView(message: "Loading community...")
                            .frame(maxWidth: .infinity)
                            .padding(.top, DesignSystem.Spacing.xxl)
                    } else if communityService.posts.isEmpty && !communityService.isLoading {
                        EmptyStateView(
                            context: .noPosts,
                            actionTitle: "Create Post",
                            action: { showingCreatePost = true }
                        )
                        .padding(.top, DesignSystem.Spacing.lg)
                    } else {
                        ForEach(communityService.posts) { post in
                            CommunityPostCard(
                                post: post,
                                isOwnPost: post.authorID == authManager.userUID,
                                onLike: { likePost(post) },
                                onComment: {
                                    selectedPost = post
                                    showingPostDetail = true
                                },
                                onReport: { reportPost(post) },
                                onBlock: { blockUser(post.authorID) },
                                onDelete: { deletePost(post) },
                                onAuthorTap: {
                                    selectedPost = post
                                    showingPostDetail = true
                                }
                            )
                        }

                        // Load more trigger
                        if communityService.isLoading {
                            ProgressView()
                                .tint(DesignSystem.Colors.primaryGreen)
                                .padding()
                        } else {
                            Color.clear
                                .frame(height: 1)
                                .onAppear {
                                    Task { await communityService.fetchPosts() }
                                }
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxl)
            }
            .refreshable {
                await communityService.fetchPosts(refresh: true)
            }

            // FAB
            FloatingActionButton(icon: "square.and.pencil") {
                showingCreatePost = true
            }
            .padding(.trailing, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.lg)
        }
        .background(AdaptiveBackground().ignoresSafeArea())
        .onAppear {
            updatePlayersFilter()
            Task { await communityService.fetchPosts(refresh: true) }
        }
        .sheet(isPresented: $showingCreatePost) {
            if let player = currentPlayer {
                CreatePostView(player: player)
            }
        }
        .sheet(isPresented: $showingPostDetail) {
            if let post = selectedPost, let player = currentPlayer {
                PostDetailView(post: post, currentPlayer: player)
            }
        }
    }

    // MARK: - Actions

    private func likePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.toggleLike(for: post)
            } catch {
                #if DEBUG
                print("❌ Like error: \(error)")
                #endif
            }
        }
    }

    private func reportPost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.reportPost(post, reason: "Inappropriate content")
            } catch {
                #if DEBUG
                print("❌ Report error: \(error)")
                #endif
            }
        }
    }

    private func blockUser(_ userID: String) {
        Task {
            do {
                try await communityService.blockUser(userID)
            } catch {
                #if DEBUG
                print("❌ Block error: \(error)")
                #endif
            }
        }
    }

    private func deletePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.deletePost(post)
            } catch {
                #if DEBUG
                print("❌ Delete error: \(error)")
                #endif
            }
        }
    }

    private func updatePlayersFilter() {
        guard !authManager.userUID.isEmpty else { return }
        players.nsPredicate = NSPredicate(format: "firebaseUID == %@", authManager.userUID)
    }
}

// MARK: - Post Card

struct CommunityPostCard: View {
    let post: CommunityPost
    let isOwnPost: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onReport: () -> Void
    let onBlock: () -> Void
    let onDelete: () -> Void
    let onAuthorTap: () -> Void

    @State private var showingActions = false

    var body: some View {
        ModernCard {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Author row
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Avatar placeholder circle
                    ZStack {
                        Circle()
                            .fill(postTypeColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Text(String(post.authorName.prefix(1)).uppercased())
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(postTypeColor)
                    }
                    .onTapGesture(perform: onAuthorTap)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text(post.authorName)
                                .font(DesignSystem.Typography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .onTapGesture(perform: onAuthorTap)

                            if post.postType != .general {
                                HStack(spacing: 2) {
                                    Image(systemName: post.postType.icon)
                                        .font(.system(size: 10))
                                    Text(post.postType.displayName)
                                        .font(DesignSystem.Typography.labelSmall)
                                }
                                .foregroundColor(postTypeColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(postTypeColor.opacity(0.12))
                                .cornerRadius(DesignSystem.CornerRadius.xs)
                            }
                        }

                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Text("Lv.\(post.authorLevel)")
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.primaryGreen)
                            if !post.authorPosition.isEmpty {
                                Text("·")
                                    .foregroundColor(DesignSystem.Colors.textTertiary)
                                Text(post.authorPosition)
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            Text("·")
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            Text(post.timestamp.timeAgoDisplay())
                                .font(DesignSystem.Typography.labelSmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                        }
                    }

                    Spacer()

                    // More actions
                    Button {
                        showingActions = true
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                // Content
                Text(post.content)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                // Rich content for new post types
                richContentSection

                // Interaction bar
                HStack(spacing: DesignSystem.Spacing.lg) {
                    // Like
                    Button(action: onLike) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                                .foregroundColor(post.isLikedByCurrentUser ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                            if post.likesCount > 0 {
                                Text("\(post.likesCount)")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Comment
                    Button(action: onComment) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "bubble.left")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            if post.commentsCount > 0 {
                                Text("\(post.commentsCount)")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()
                }
                .font(.system(size: 18))
            }
        }
        .confirmationDialog("Post Actions", isPresented: $showingActions, titleVisibility: .hidden) {
            if isOwnPost {
                Button("Delete Post", role: .destructive, action: onDelete)
            } else {
                Button("Report Post", action: onReport)
                Button("Block User", role: .destructive, action: onBlock)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Rich Content

    @ViewBuilder
    private var richContentSection: some View {
        switch post.postType {
        case .sharedDrill:
            if let title = post.drillTitle {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(title)
                            .font(DesignSystem.Typography.headlineSmall)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if let cat = post.drillCategory {
                                GlowBadge(cat.capitalized, color: DesignSystem.Colors.primaryGreen)
                            }
                            if let diff = post.drillDifficulty {
                                HStack(spacing: 3) {
                                    ForEach(1...5, id: \.self) { i in
                                        Circle()
                                            .fill(i <= diff ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textTertiary.opacity(0.3))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.primaryGreen.opacity(0.06))
                .cornerRadius(DesignSystem.CornerRadius.md)
            }

        case .sharedAchievement:
            if let name = post.achievementName, let icon = post.achievementIcon {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: icon)
                        .font(.system(size: 28))
                        .foregroundColor(DesignSystem.Colors.accentGold)
                        .frame(width: 48, height: 48)
                        .background(DesignSystem.Colors.accentGold.opacity(0.12))
                        .clipShape(Circle())
                    GlowBadge(name, color: DesignSystem.Colors.accentGold)
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accentGold.opacity(0.06))
                .cornerRadius(DesignSystem.CornerRadius.md)
            }

        case .sharedSession:
            HStack(spacing: DesignSystem.Spacing.lg) {
                if let dur = post.sessionDuration {
                    sessionStatItem(icon: "clock", value: "\(dur)m", label: "Duration")
                }
                if let count = post.sessionExerciseCount {
                    sessionStatItem(icon: "figure.run", value: "\(count)", label: "Exercises")
                }
                if let xp = post.sessionXP {
                    sessionStatItem(icon: "star.fill", value: "+\(xp)", label: "XP")
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.primaryGreen.opacity(0.06))
            .cornerRadius(DesignSystem.CornerRadius.md)

        case .sharedLevelUp:
            if let level = post.newLevel {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Text("\(level)")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(DesignSystem.Colors.accentGold)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Level Up!")
                            .font(DesignSystem.Typography.titleSmall)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        if let rank = post.rankName {
                            GlowBadge(rank, color: DesignSystem.Colors.accentGold)
                        }
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.accentGold.opacity(0.06))
                .cornerRadius(DesignSystem.CornerRadius.md)
            }

        default:
            EmptyView()
        }
    }

    private func sessionStatItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.primaryGreen)
            Text(value)
                .font(DesignSystem.Typography.labelLarge)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var postTypeColor: Color {
        switch post.postType {
        case .general: return DesignSystem.Colors.secondaryBlue
        case .sessionComplete: return DesignSystem.Colors.primaryGreen
        case .achievement: return DesignSystem.Colors.accentYellow
        case .milestone: return DesignSystem.Colors.levelPurple
        case .sharedDrill, .sharedSession: return DesignSystem.Colors.primaryGreen
        case .sharedAchievement, .sharedLevelUp: return DesignSystem.Colors.accentGold
        }
    }
}

// MARK: - Time Ago Extension

extension Date {
    func timeAgoDisplay() -> String {
        let seconds = Int(-self.timeIntervalSinceNow)
        if seconds < 60 { return "now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h" }
        let days = hours / 24
        if days < 7 { return "\(days)d" }
        let weeks = days / 7
        if weeks < 4 { return "\(weeks)w" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: self)
    }
}

#Preview {
    NavigationView {
        CommunityFeedView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
