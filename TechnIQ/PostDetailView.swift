import SwiftUI

struct PostDetailView: View {
    let post: CommunityPost
    let currentPlayer: Player
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService.shared

    @State private var comments: [CommunityComment] = []
    @State private var newCommentText = ""
    @State private var isLoadingComments = true
    @State private var isPostingComment = false
    @State private var showingProfile = false
    @State private var profileUserID: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Original post
                        postSection

                        // Comments header
                        if !comments.isEmpty || !isLoadingComments {
                            HStack {
                                Text("Comments")
                                    .font(DesignSystem.Typography.titleSmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Text("(\(comments.count))")
                                    .font(DesignSystem.Typography.labelMedium)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                            }
                            .padding(.top, DesignSystem.Spacing.sm)
                        }

                        // Comments list
                        if isLoadingComments {
                            ProgressView()
                                .tint(DesignSystem.Colors.primaryGreen)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if comments.isEmpty {
                            Text("No comments yet. Be the first!")
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.lg)
                        } else {
                            ForEach(comments) { comment in
                                CommentRow(
                                    comment: comment,
                                    isOwnComment: comment.authorID == currentPlayer.firebaseUID,
                                    onReport: { reportComment(comment) },
                                    onAuthorTap: {
                                        profileUserID = comment.authorID
                                        showingProfile = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.md)
                }

                // Comment input bar
                commentInputBar
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .onAppear { loadComments() }
            .sheet(isPresented: $showingProfile) {
                if let uid = profileUserID {
                    PublicProfileView(userID: uid)
                }
            }
        }
    }

    // MARK: - Post Section

    private var postSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Author
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.secondaryBlue.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Text(String(post.authorName.prefix(1)).uppercased())
                        .font(DesignSystem.Typography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.secondaryBlue)
                }
                .onTapGesture {
                    profileUserID = post.authorID
                    showingProfile = true
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Lv.\(post.authorLevel)")
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                        Text("·")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text(post.timestamp.timeAgoDisplay())
                            .font(DesignSystem.Typography.labelSmall)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
                Spacer()
            }

            // Content
            Text(post.content)
                .font(DesignSystem.Typography.bodyLarge)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Stats
            HStack(spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: post.isLikedByCurrentUser ? "heart.fill" : "heart")
                        .foregroundColor(post.isLikedByCurrentUser ? DesignSystem.Colors.error : DesignSystem.Colors.textSecondary)
                    Text("\(post.likesCount) likes")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "bubble.left")
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("\(post.commentsCount) comments")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Spacer()
            }
            .font(.system(size: 16))
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.card)
        .customShadow(DesignSystem.Shadow.medium)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                .font(DesignSystem.Typography.bodyMedium)
                .lineLimit(1...4)
                .padding(DesignSystem.Spacing.sm)
                .padding(.horizontal, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.backgroundSecondary)
                .cornerRadius(DesignSystem.CornerRadius.pill)

            Button {
                postComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(
                        newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? DesignSystem.Colors.neutral400
                            : DesignSystem.Colors.primaryGreen
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPostingComment)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.cardBackground)
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
                print("❌ Load comments error: \(error)")
                #endif
            }
        }
    }

    private func postComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

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
                #if DEBUG
                print("❌ Post comment error: \(error)")
                #endif
            }
        }
    }

    private func reportComment(_ comment: CommunityComment) {
        Task {
            try? await communityService.reportComment(comment)
        }
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: CommunityComment
    let isOwnComment: Bool
    let onReport: () -> Void
    let onAuthorTap: () -> Void

    @State private var showingActions = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // Mini avatar
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.neutral300)
                    .frame(width: 32, height: 32)
                Text(String(comment.authorName.prefix(1)).uppercased())
                    .font(DesignSystem.Typography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .onTapGesture(perform: onAuthorTap)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(comment.authorName)
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .onTapGesture(perform: onAuthorTap)

                    Text("Lv.\(comment.authorLevel)")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.primaryGreen)

                    Spacer()

                    Text(comment.timestamp.timeAgoDisplay())
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }

                Text(comment.content)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .contextMenu {
            if !isOwnComment {
                Button(role: .destructive) {
                    onReport()
                } label: {
                    Label("Report", systemImage: "exclamationmark.triangle")
                }
            }
        }
    }
}
