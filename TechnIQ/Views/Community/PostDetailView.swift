import SwiftUI

// MARK: - Post (Community → a post)
//
// The post at full size, its comments as flat rows, and a comment field pinned to the bottom.

struct PostDetailView: View {
    let post: CommunityPost
    let currentPlayer: Player
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var communityService = CommunityService.shared

    @State private var comments: [CommunityComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = true
    @State private var isPostingComment = false
    @State private var showingProfile = false
    @State private var profileUserID: String?
    @State private var showingGuidelines = false
    @State private var commentError: String?

    private var trimmedComment: String { newCommentText.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                    TQNavBar("Post") {
                        TQNavAction("Close") { dismiss() }
                    } trailing: {
                        Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                    }
                    .padding(.top, 8)

                    postSection
                    commentsSection
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }

            commentInputBar
                .sheet(isPresented: $showingGuidelines) {
                    CommunityGuidelinesSheet { postComment() }
                }
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { loadComments() }
        .sheet(isPresented: $showingProfile) {
            if let uid = profileUserID {
                PublicProfileView(userID: uid)
            }
        }
        .alert("Comment not posted", isPresented: Binding(
            get: { commentError != nil },
            set: { if !$0 { commentError = nil } }
        )) {
            Button("OK", role: .cancel) { commentError = nil }
        } message: {
            Text(commentError ?? "")
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            CommunityAuthorLine(post: post) { showProfile(post.authorID) }
            CommunityPostBody(post: post, textSize: 16)
            TQMeta("\(post.likesCount) like\(post.likesCount == 1 ? "" : "s") · \(post.commentsCount) comment\(post.commentsCount == 1 ? "" : "s")",
                   tone: .muted, size: 13)
        }
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader(isLoadingComments ? "Comments" : "Comments · \(comments.count)")
            TQRule()
            if isLoadingComments {
                TQSpinner(size: 18)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            } else if comments.isEmpty {
                TQBody("No comments yet. Be the first.", tone: .muted)
                    .padding(.vertical, DesignSystem.Spacing.md)
            } else {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        isOwnComment: comment.authorID == currentPlayer.firebaseUID,
                        onReport: { reportComment(comment) },
                        onBlock: { blockCommentAuthor(comment) },
                        onAuthorTap: { showProfile(comment.authorID) }
                    )
                }
            }
        }
    }

    private func showProfile(_ userID: String) {
        profileUserID = userID
        showingProfile = true
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(alignment: .bottom, spacing: DesignSystem.Spacing.sm) {
            TextField("Add a comment…", text: $newCommentText, axis: .vertical)
                .font(Font.system(size: 16, weight: .regular))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .tint(DesignSystem.Colors.grass)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(DesignSystem.Colors.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.button, style: .continuous))

            TQIconButton("arrow.up", style: .primary, shape: .square, size: 44, accessibilityLabel: "Send comment") {
                postComment()
            }
            .disabled(trimmedComment.isEmpty || isPostingComment)
            .opacity(trimmedComment.isEmpty || isPostingComment ? 0.4 : 1)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surfaceBase)
        .overlay(alignment: .top) { TQRule() }
    }

    // MARK: - Actions

    private func loadComments() {
        Task {
            do {
                comments = try await communityService.fetchComments(for: post.id)
                isLoadingComments = false
            } catch {
                isLoadingComments = false
                #if DEBUG
                print("Load comments error: \(error)")
                #endif
            }
        }
    }

    private func postComment() {
        let trimmed = trimmedComment
        guard !trimmed.isEmpty else { return }

        guard CommunityGuidelines.hasAccepted else {
            showingGuidelines = true
            return
        }

        isPostingComment = true
        Task {
            do {
                try await communityService.addComment(to: post.id, content: trimmed, player: currentPlayer)
                newCommentText = ""
                // Reload comments
                comments = try await communityService.fetchComments(for: post.id)
                isPostingComment = false
            } catch {
                isPostingComment = false
                commentError = error.localizedDescription
                #if DEBUG
                print("Post comment error: \(error)")
                #endif
            }
        }
    }

    private func reportComment(_ comment: CommunityComment) {
        Task {
            try? await communityService.reportComment(comment)
        }
    }

    private func blockCommentAuthor(_ comment: CommunityComment) {
        Task {
            try? await communityService.blockUser(comment.authorID)
            comments.removeAll { $0.authorID == comment.authorID }
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: CommunityComment
    let isOwnComment: Bool
    let onReport: () -> Void
    let onBlock: () -> Void
    let onAuthorTap: () -> Void

    // Public identity only — first name + last initial.
    private var authorDisplayName: String {
        CommunityService.displayName(for: comment.authorName)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onAuthorTap) {
                CommunityInitial(name: authorDisplayName, size: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(authorDisplayName)'s profile")

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(authorDisplayName)
                        .font(DesignSystem.Typography.bodySmallStrong)
                        .foregroundColor(DesignSystem.Colors.chalkWhite)
                        .lineLimit(1)
                    TQMeta("Lvl \(comment.authorLevel) · \(comment.timestamp.timeAgoDisplay())", tone: .muted, size: 13, weight: .regular)
                    Spacer(minLength: 0)
                }
                if comment.isHidden {
                    TQBody("This comment was hidden after multiple reports.", tone: .italicMuted, size: 13)
                } else {
                    Text(comment.content)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(DesignSystem.Colors.mutedIvory)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !isOwnComment {
                Menu {
                    Button(role: .destructive, action: onReport) {
                        Label("Report", systemImage: "exclamationmark.triangle")
                    }
                    Button(role: .destructive, action: onBlock) {
                        Label("Block User", systemImage: "hand.raised.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.dimIvory)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Comment actions")
            }
        }
        .padding(.vertical, DesignSystem.Spacing.rowVertical)
        .overlay(alignment: .bottom) { TQRule() }
    }
}
