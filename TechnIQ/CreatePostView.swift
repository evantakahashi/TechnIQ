import SwiftUI

struct CreatePostView: View {
    let player: Player
    @Environment(\.dismiss) private var dismiss
    @StateObject private var communityService = CommunityService.shared

    @State private var content = ""
    @State private var selectedType: CommunityPostType = .general
    @State private var isPosting = false
    @State private var error: String?

    private let maxCharacters = 500

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Post type selector
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Post Type")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    ForEach(CommunityPostType.allCases, id: \.self) { type in
                                        Button {
                                            withAnimation(DesignSystem.Animation.quick) {
                                                selectedType = type
                                            }
                                        } label: {
                                            HStack(spacing: DesignSystem.Spacing.xs) {
                                                Image(systemName: type.icon)
                                                    .font(.system(size: 12))
                                                Text(type.displayName)
                                                    .font(DesignSystem.Typography.labelMedium)
                                                    .fontWeight(.medium)
                                            }
                                            .padding(.horizontal, DesignSystem.Spacing.md)
                                            .padding(.vertical, DesignSystem.Spacing.sm)
                                            .background(
                                                selectedType == type
                                                    ? DesignSystem.Colors.primaryGreen
                                                    : DesignSystem.Colors.backgroundSecondary
                                            )
                                            .foregroundColor(
                                                selectedType == type
                                                    ? .white
                                                    : DesignSystem.Colors.textSecondary
                                            )
                                            .cornerRadius(DesignSystem.CornerRadius.pill)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }

                        // Text input
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            ZStack(alignment: .topLeading) {
                                if content.isEmpty {
                                    Text("Share something with the community...")
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                        .padding(.top, DesignSystem.Spacing.md)
                                        .padding(.leading, DesignSystem.Spacing.md)
                                }

                                TextEditor(text: $content)
                                    .font(DesignSystem.Typography.bodyMedium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .padding(DesignSystem.Spacing.sm)
                                    .frame(minHeight: 150)
                                    .onChange(of: content) {
                                        if content.count > maxCharacters {
                                            content = String(content.prefix(maxCharacters))
                                        }
                                    }
                            }
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(DesignSystem.Colors.neutral300, lineWidth: 1)
                            )

                            // Character count
                            HStack {
                                Spacer()
                                Text("\(content.count)/\(maxCharacters)")
                                    .font(DesignSystem.Typography.labelSmall)
                                    .foregroundColor(
                                        content.count > maxCharacters - 50
                                            ? DesignSystem.Colors.warning
                                            : DesignSystem.Colors.textTertiary
                                    )
                            }
                        }

                        if let error = error {
                            Text(error)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(DesignSystem.Colors.error)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }

                // Post button
                VStack {
                    ModernButton("Post", icon: "paperplane.fill", style: .primary) {
                        submitPost()
                    }
                    .opacity(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPosting)
                }
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.cardBackground)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .overlay {
                if isPosting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    LoadingStateView(message: "Posting...")
                }
            }
        }
    }

    private func submitPost() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

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
