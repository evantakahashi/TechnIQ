import SwiftUI

// MARK: - Public profile (tap a community author)
//
// Public identity only (first name + last initial): level and position, three figures, their
// recent posts. Report / block sit behind the nav bar's menu.

struct PublicProfileView: View {
    let userID: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var communityService = CommunityService.shared

    @State private var profileName = ""
    @State private var profileLevel = 1
    @State private var profilePosition = ""
    @State private var profileXP: Int64 = 0
    @State private var profileSessions = 0
    @State private var isLoading = true
    @State private var showingBlockConfirm = false
    @State private var showingReportConfirm = false
    @State private var reportSubmitted = false
    @State private var userPosts: [CommunityPost] = []
    @State private var sharedDrillsCount = 0

    // Public identity only — first name + last initial.
    private var displayName: String {
        CommunityService.displayName(for: profileName)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                navBar

                if isLoading {
                    loadingBlock
                } else {
                    profileHeader
                    TQStatRail(items: [
                        .init("\(profileXP)", label: "XP"),
                        .init("\(profileSessions)", label: "sessions"),
                        .init("\(sharedDrillsCount)", label: "shared drills")
                    ])
                    recentPostsSection
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .alert("Block User", isPresented: $showingBlockConfirm) {
            Button("Block", role: .destructive) {
                blockUser()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see posts or comments from this user. This can't be undone.")
        }
        .alert("Report User", isPresented: $showingReportConfirm) {
            Button("Report", role: .destructive) {
                reportUser()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Report this profile for review by our team.")
        }
        .alert("Thanks for reporting", isPresented: $reportSubmitted) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Our team will review this profile.")
        }
        .onAppear { loadProfile() }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        TQNavBar("Profile") {
            TQNavAction("Close") { dismiss() }
        } trailing: {
            Menu {
                Button {
                    showingReportConfirm = true
                } label: {
                    Label("Report User", systemImage: "exclamationmark.triangle")
                }
                Button(role: .destructive) {
                    showingBlockConfirm = true
                } label: {
                    Label("Block User", systemImage: "hand.raised.fill")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.Colors.dimIvory)
                    .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget, alignment: .trailing)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Profile actions")
        }
        .padding(.top, 8)
    }

    private var loadingBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            TQSkeleton(width: 120, height: 12)
            TQSkeleton(width: 220, height: 36, cornerRadius: 4)
            TQSkeleton(widthFraction: 1, height: 56, cornerRadius: 4)
        }
        .accessibilityLabel("Loading profile")
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            CommunityInitial(name: displayName, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                TQEyebrow(["Level \(profileLevel)", profilePosition].filter { !$0.isEmpty }.joined(separator: " · "), size: 11)
                TQDisplayTitle(displayName, size: .medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    // MARK: - Recent Posts

    private var recentPostsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TQGroupHeader("Recent posts")
            TQRule()
            if userPosts.isEmpty {
                TQBody("No posts yet.", tone: .muted)
                    .padding(.vertical, DesignSystem.Spacing.md)
            } else {
                ForEach(userPosts) { post in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(post.content)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                            .lineLimit(3)
                        TQMeta("\(post.likesCount) like\(post.likesCount == 1 ? "" : "s") · \(post.commentsCount) comment\(post.commentsCount == 1 ? "" : "s") · \(post.timestamp.timeAgoDisplay())",
                               tone: .muted, size: 13, weight: .regular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, DesignSystem.Spacing.rowVertical)
                    .overlay(alignment: .bottom) { TQRule() }
                    .accessibilityElement(children: .combine)
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
                print("Load profile error: \(error)")
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

    private func reportUser() {
        Task {
            try? await communityService.reportUser(userID)
            reportSubmitted = true
        }
    }
}
