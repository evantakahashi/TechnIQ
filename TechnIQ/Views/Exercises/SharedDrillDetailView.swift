import SwiftUI

struct SharedDrillDetailView: View {
    let drill: SharedDrill

    @StateObject private var communityService = CommunityService.shared
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(sortDescriptors: [])
    private var players: FetchedResults<Player>

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showReportAlert = false
    @State private var reportReason = ""

    private var player: Player? { players.first }

    private var accentColor: Color {
        switch drill.category.lowercased() {
        case "technical": return DesignSystem.Colors.primaryGreen
        case "tactical": return DesignSystem.Colors.accentGold
        case "physical": return DesignSystem.Colors.accentOrange
        default: return DesignSystem.Colors.primaryGreen
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Title & Author
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(drill.title)
                            .font(DesignSystem.Typography.headlineLarge)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Text("Created by \(drill.authorName)")
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            GlowBadge("Lv. \(drill.authorLevel)", color: DesignSystem.Colors.secondaryBlue)
                        }
                    }

                    // Badges row
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        GlowBadge(drill.category.capitalized, color: accentColor)

                        HStack(spacing: 3) {
                            ForEach(1...5, id: \.self) { i in
                                Circle()
                                    .fill(i <= drill.difficulty ? accentColor : DesignSystem.Colors.textTertiary.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }

                        Spacer()

                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 14))
                            Text("\(drill.saveCount) saves")
                                .font(DesignSystem.Typography.labelSmall)
                        }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    }

                    // Description
                    if !drill.description.isEmpty {
                        ModernCard {
                            Text(drill.description)
                                .font(DesignSystem.Typography.bodyMedium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    // Target skills
                    if !drill.targetSkills.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Target Skills")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            FlowLayout(spacing: DesignSystem.Spacing.sm) {
                                ForEach(drill.targetSkills, id: \.self) { skill in
                                    GlowBadge(skill, color: accentColor)
                                }
                            }
                        }
                    }

                    // Details
                    ModernCard {
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            detailItem(icon: "clock", value: "\(drill.duration) min", label: "Duration")
                            detailItem(icon: "repeat", value: "\(drill.sets) × \(drill.reps)", label: "Sets × Reps")
                        }
                    }

                    // Equipment
                    if !drill.equipment.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Equipment")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            ForEach(drill.equipment, id: \.self) { item in
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignSystem.Colors.primaryGreen)
                                        .font(.system(size: 14))
                                    Text(item)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                        }
                    }

                    // Steps
                    if !drill.steps.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Instructions")
                                .font(DesignSystem.Typography.titleSmall)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)

                            ForEach(Array(drill.steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                                    Text("\(index + 1)")
                                        .font(DesignSystem.Typography.labelLarge)
                                        .fontWeight(.bold)
                                        .foregroundColor(accentColor)
                                        .frame(width: 24, height: 24)
                                        .background(accentColor.opacity(0.12))
                                        .clipShape(Circle())

                                    Text(step)
                                        .font(DesignSystem.Typography.bodyMedium)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }

                    // Error message
                    if let error = saveError {
                        Text(error)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.error)
                    }

                    // Save button
                    if let player = player {
                        if drill.isSavedByCurrentUser {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Saved to Library")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(DesignSystem.Colors.primaryGreen)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(DesignSystem.Colors.primaryGreen.opacity(0.12))
                            .cornerRadius(DesignSystem.CornerRadius.button)
                        } else {
                            ModernButton("Save to Library", icon: "arrow.down.circle", style: .primary) {
                                saveDrill(player: player)
                            }
                            .disabled(isSaving)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(AdaptiveBackground().ignoresSafeArea())
            .navigationTitle("Drill Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showReportAlert = true
                    } label: {
                        Image(systemName: "flag")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .alert("Report Drill", isPresented: $showReportAlert) {
                TextField("Reason", text: $reportReason)
                Button("Report", role: .destructive) {
                    Task {
                        try? await communityService.reportDrill(drill, reason: reportReason)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Why are you reporting this drill?")
            }
        }
    }

    // MARK: - Helpers

    private func detailItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(accentColor)
            Text(value)
                .font(DesignSystem.Typography.titleSmall)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.labelSmall)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func saveDrill(player: Player) {
        isSaving = true
        saveError = nil
        Task {
            do {
                try await communityService.saveDrillToLibrary(drill: drill, player: player, context: context)
                HapticManager.shared.success()
            } catch {
                saveError = error.localizedDescription
                HapticManager.shared.error()
            }
            isSaving = false
        }
    }
}
