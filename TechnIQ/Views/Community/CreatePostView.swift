import SwiftUI

// MARK: - New post (Community → + Post)
//
// Type chips, one text area, one Post button. The community rules are shown once before the
// first post.

struct CreatePostView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var communityService = CommunityService.shared

    @State private var content = ""
    @State private var selectedType: CommunityPostType = .general
    @State private var isPosting = false
    @State private var error: String?
    @State private var showingGuidelines = false

    private let maxCharacters = 500
    private let postTypes: [CommunityPostType] = [.general, .sessionComplete, .achievement, .milestone]

    private var isEmpty: Bool { content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQNavBar("New post") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("Post type")
                TQChipRow {
                    ForEach(postTypes, id: \.self) { type in
                        TQChip(type.displayName, isSelected: selectedType == type) { selectedType = type }
                    }
                }
            }

            CommunityTextArea(label: "Post", placeholder: "Share something with the community…",
                              text: $content, limit: maxCharacters, minHeight: 150)

            if let error {
                TQBanner(.error, message: error)
            }

            Spacer(minLength: 0)

            TQButton("Post", isLoading: isPosting) { submitPost() }
                .disabled(isEmpty || isPosting)
                .opacity(isEmpty ? 0.5 : 1)
                .padding(.bottom, DesignSystem.Spacing.md)
        }
        .padding(.horizontal, DesignSystem.Spacing.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingGuidelines) {
            CommunityGuidelinesSheet { submitPost() }
        }
    }

    private func submitPost() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard CommunityGuidelines.hasAccepted else {
            showingGuidelines = true
            return
        }

        isPosting = true
        error = nil

        Task {
            do {
                try await communityService.createPost(
                    content: trimmed,
                    postType: selectedType,
                    player: player
                )
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isPosting = false
            }
        }
    }
}
