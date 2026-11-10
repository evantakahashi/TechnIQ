import SwiftUI
import CoreData

// MARK: - Community feed (Touchline)
//
// Flat posts separated by rules: author line, body, an optional attachment line (shared drill,
// session figures, achievement, level), then like / comment counts. The pieces every community
// screen shares (initial circle, empty block, attachment, text area) live at the bottom.

struct CommunityFeedView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var communityService = CommunityService.shared
    @FetchRequest var players: FetchedResults<Player>

    @State private var showingCreatePost = false
    @State private var selectedPost: CommunityPost?
    @State private var showingPostDetail = false

    init() {
        self._players = FetchRequest(
            sortDescriptors: [],
            predicate: AuthenticationManager.shared.playerPredicate,
            animation: .default
        )
    }

    private var currentPlayer: Player? {
        players.first { $0.firebaseUID == authManager.userUID }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if communityService.isLoading && communityService.posts.isEmpty {
                    CommunitySkeletonRows()
                } else if communityService.posts.isEmpty {
                    CommunityEmptyBlock(
                        title: "No posts yet",
                        message: "Be the first to share something with the community.",
                        actionTitle: "Create post",
                        action: { showingCreatePost = true }
                    )
                    .padding(.top, DesignSystem.Spacing.sm)
                } else {
                    TQRule()
                    ForEach(communityService.posts) { post in
                        postCard(post)
                    }
                    loadMore
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .refreshable {
            await communityService.fetchPosts(refresh: true)
        }
        .background(DesignSystem.Colors.surfaceBase)
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

    private func postCard(_ post: CommunityPost) -> some View {
        CommunityPostCard(
            post: post,
            isOwnPost: post.authorID == authManager.userUID,
            onLike: { likePost(post) },
            onComment: { open(post) },
            onReport: { reportPost(post) },
            onBlock: { blockUser(post.authorID) },
            onDelete: { deletePost(post) },
            onAuthorTap: { open(post) }
        )
    }

    @ViewBuilder
    private var loadMore: some View {
        if communityService.isLoading {
            TQSpinner(size: 18)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.md)
        } else {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task { await communityService.fetchPosts() }
                }
        }
    }

    private func open(_ post: CommunityPost) {
        selectedPost = post
        showingPostDetail = true
    }

    // MARK: - Actions

    private func likePost(_ post: CommunityPost) {
        Task {
            do {
                try await communityService.toggleLike(for: post)
            } catch {
                #if DEBUG
                print("Like error: \(error)")
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
                print("Report error: \(error)")
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
                print("Block error: \(error)")
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
                print("Delete error: \(error)")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                CommunityAuthorLine(post: post, onTap: onAuthorTap)
                Spacer(minLength: 8)
                TQIconAction("ellipsis", accessibilityLabel: "More actions") { showingActions = true }
            }

            CommunityPostBody(post: post)

            HStack(spacing: DesignSystem.Spacing.lg) {
                CommunityCountButton(
                    systemImage: post.isLikedByCurrentUser ? "heart.fill" : "heart",
                    count: post.likesCount,
                    isOn: post.isLikedByCurrentUser,
                    accessibilityLabel: post.isLikedByCurrentUser ? "Unlike, \(post.likesCount) likes" : "Like, \(post.likesCount) likes",
                    action: onLike
                )
                CommunityCountButton(
                    systemImage: "bubble.left",
                    count: post.commentsCount,
                    isOn: false,
                    accessibilityLabel: "Comments, \(post.commentsCount)",
                    action: onComment
                )
                Spacer()
            }
        }
        .padding(.vertical, DesignSystem.Spacing.rowVerticalLarge)
        .overlay(alignment: .bottom) { TQRule() }
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
}

// MARK: - Shared community pieces

/// Initial in a raised circle: the only "avatar" other players get (public identity is a first name).
struct CommunityInitial: View {
    let name: String
    var size: CGFloat = 40

    var body: some View {
        TQAvatarCircle(size: size) {
            Text(String(name.prefix(1)).uppercased())
                .font(Font.system(size: size * 0.4, weight: .bold).width(.condensed))
                .foregroundColor(DesignSystem.Colors.dimIvory)
        }
        .accessibilityHidden(true)
    }
}

/// "Sam K." over "LVL 7 · FORWARD · 2H", with the initial circle. Tapping it opens the author.
struct CommunityAuthorLine: View {
    let post: CommunityPost
    var onTap: () -> Void

    private var name: String { CommunityService.displayName(for: post.authorName) }

    private var meta: String {
        var parts = ["Lvl \(post.authorLevel)"]
        if !post.authorPosition.isEmpty { parts.append(post.authorPosition) }
        if post.postType != .general { parts.append(post.postType.displayName) }
        parts.append(post.timestamp.timeAgoDisplay())
        return parts.joined(separator: " · ")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                CommunityInitial(name: name)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(DesignSystem.Typography.titleMedium)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .lineLimit(1)
                    TQMeta(meta, tone: .muted, size: 13, weight: .regular)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name), \(meta)")
    }
}

/// Post text (or the hidden notice) plus its attachment.
struct CommunityPostBody: View {
    let post: CommunityPost
    var textSize: CGFloat = 14

    var body: some View {
        if post.isHidden {
            TQBody("This post was hidden after multiple reports.", tone: .italicMuted, size: textSize)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text(post.content)
                    .font(Font.system(size: textSize, weight: .regular))
                    .lineSpacing(textSize * 0.4)
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .fixedSize(horizontal: false, vertical: true)
                CommunityPostAttachment(post: post)
            }
        }
    }
}

/// What a shared post carries: one raised block with an eyebrow, a condensed title and figures.
struct CommunityPostAttachment: View {
    let post: CommunityPost

    var body: some View {
        switch post.postType {
        case .sharedDrill:
            if let title = post.drillTitle {
                block(eyebrow: "Drill", title: title) {
                    HStack(spacing: 8) {
                        if let category = post.drillCategory {
                            TQMeta(category, tone: .muted, size: 13)
                        }
                        if let difficulty = post.drillDifficulty {
                            TQBadge(difficulty: "\(difficulty)")
                        }
                    }
                }
            }
        case .sharedAchievement:
            if let name = post.achievementName {
                block(eyebrow: "Achievement", title: name) { EmptyView() }
            }
        case .sharedSession:
            block(eyebrow: "Session", title: nil) {
                TQFigureRow(sessionFigures, onPitch: false)
            }
        case .sharedLevelUp:
            if let level = post.newLevel {
                block(eyebrow: "Level up", title: "Level \(level)") {
                    if let rank = post.rankName {
                        TQMeta(rank, tone: .muted, size: 13)
                    }
                }
            }
        default:
            EmptyView()
        }
    }

    private var sessionFigures: [(String, String)] {
        var figures: [(String, String)] = []
        if let duration = post.sessionDuration { figures.append(("\(duration)", "min")) }
        if let count = post.sessionExerciseCount { figures.append(("\(count)", count == 1 ? "drill" : "drills")) }
        if let xp = post.sessionXP { figures.append(("+\(xp)", "XP")) }
        return figures
    }

    private func block<Detail: View>(eyebrow: String, title: String?, @ViewBuilder detail: () -> Detail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            TQEyebrow(eyebrow, size: 11)
            if let title {
                TQDisplayTitle(title, size: .strip)
                    .lineLimit(2)
            }
            detail()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg, style: .continuous)
                .fill(DesignSystem.Colors.surfaceRaised)
        )
    }
}

/// Heart / bubble with a count; grass when on.
struct CommunityCountButton: View {
    let systemImage: String
    let count: Int
    let isOn: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selectionChanged()
            action()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(DesignSystem.Typography.numberSmall)
                }
            }
            .foregroundColor(isOn ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Left-aligned empty state: condensed title, one line, optional action.
struct CommunityEmptyBlock: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQDisplayTitle(title, size: .small)
            TQBody(message)
            if let actionTitle, let action {
                TQButton(actionTitle, style: .raised, size: .compact, fullWidth: false, action: action)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Loading placeholder: three post-shaped skeletons.
struct CommunitySkeletonRows: View {
    var count = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<count, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        TQSkeleton(width: 40, height: 40, cornerRadius: 20)
                        VStack(alignment: .leading, spacing: 6) {
                            TQSkeleton(width: 120, height: 12)
                            TQSkeleton(width: 80, height: 10)
                        }
                    }
                    TQSkeleton(widthFraction: 0.9, height: 12)
                    TQSkeleton(widthFraction: 0.6, height: 12)
                }
                .padding(.vertical, DesignSystem.Spacing.rowVerticalLarge)
                .overlay(alignment: .bottom) { TQRule() }
            }
        }
        .accessibilityLabel("Loading")
    }
}

/// Multi-line text input with a character cap and counter.
struct CommunityTextArea: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let limit: Int
    var minHeight: CGFloat = 120

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                    .textCase(.uppercase)
                    .tracking(DesignSystem.Typography.Tracking.eyebrow)
                    .foregroundColor(DesignSystem.Colors.dimIvory)
                Spacer()
                Text("\(text.count)/\(limit)")
                    .font(Font.system(size: 12, weight: .semibold).width(.condensed).monospacedDigit())
                    .foregroundColor(text.count > limit - 50 ? DesignSystem.Colors.cone : DesignSystem.Colors.textTertiary)
            }
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(Font.system(size: 16, weight: .regular))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(Font.system(size: 16, weight: .regular))
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                    .tint(DesignSystem.Colors.grass)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(minHeight: minHeight)
                    .accessibilityLabel(label)
                    .onChange(of: text) { _, newValue in
                        if newValue.count > limit { text = String(newValue.prefix(limit)) }
                    }
            }
            .background(DesignSystem.Colors.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous)
                    .strokeBorder(isFocused ? DesignSystem.Colors.grass : DesignSystem.Colors.surfaceHighlight, lineWidth: 1)
            )
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
    NavigationStack {
        CommunityFeedView()
            .environment(\.managedObjectContext, CoreDataManager.shared.context)
            .environmentObject(AuthenticationManager.shared)
    }
}
