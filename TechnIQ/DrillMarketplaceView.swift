import SwiftUI

struct DrillMarketplaceView: View {
    @StateObject private var communityService = CommunityService.shared
    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var selectedDrill: SharedDrill?

    private let categories = ["All", "Technical", "Tactical", "Physical"]

    var filteredDrills: [SharedDrill] {
        if searchText.isEmpty {
            return communityService.sharedDrills
        }
        return communityService.sharedDrills.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.authorName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                TextField("Search drills...", text: $searchText)
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.backgroundSecondary)
            .cornerRadius(DesignSystem.CornerRadius.md)
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, DesignSystem.Spacing.sm)

            // Category filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(categories, id: \.self) { category in
                        let isSelected = (category == "All" && selectedCategory == nil) ||
                            (selectedCategory == category.lowercased())
                        Button {
                            withAnimation(DesignSystem.Animation.quick) {
                                selectedCategory = category == "All" ? nil : category.lowercased()
                            }
                            Task { await communityService.fetchSharedDrills(refresh: true, category: selectedCategory) }
                        } label: {
                            Text(category)
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                                .padding(.horizontal, DesignSystem.Spacing.md)
                                .padding(.vertical, DesignSystem.Spacing.sm)
                                .background(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.backgroundSecondary)
                                .cornerRadius(DesignSystem.CornerRadius.button)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.vertical, DesignSystem.Spacing.sm)
            }

            // Drills list
            if communityService.isLoadingDrills && communityService.sharedDrills.isEmpty {
                Spacer()
                LoadingStateView(message: "Loading drills...")
                Spacer()
            } else if filteredDrills.isEmpty {
                Spacer()
                EmptyStateView(context: .noPosts)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredDrills) { drill in
                            drillCard(drill)
                                .onTapGesture { selectedDrill = drill }
                                .onAppear {
                                    if drill.id == filteredDrills.last?.id {
                                        Task { await communityService.fetchSharedDrills(category: selectedCategory) }
                                    }
                                }
                        }

                        if communityService.isLoadingDrills {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                }
                .refreshable {
                    await communityService.fetchSharedDrills(refresh: true, category: selectedCategory)
                }
            }
        }
        .onAppear {
            if communityService.sharedDrills.isEmpty {
                Task { await communityService.fetchSharedDrills(refresh: true) }
            }
        }
        .sheet(item: $selectedDrill) { drill in
            SharedDrillDetailView(drill: drill)
        }
    }

    // MARK: - Drill Card

    private func drillCard(_ drill: SharedDrill) -> some View {
        let accentColor: Color = {
            switch drill.category.lowercased() {
            case "technical": return DesignSystem.Colors.primaryGreen
            case "tactical": return DesignSystem.Colors.accentGold
            case "physical": return DesignSystem.Colors.accentOrange
            default: return DesignSystem.Colors.primaryGreen
            }
        }()

        return ModernCard(accentEdge: .leading, accentColor: accentColor) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text(drill.title)
                        .font(DesignSystem.Typography.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 12))
                        Text("\(drill.saveCount)")
                            .font(DesignSystem.Typography.labelSmall)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                Text("by \(drill.authorName)")
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(DesignSystem.Colors.textSecondary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    GlowBadge(drill.category.capitalized, color: accentColor)

                    // Difficulty dots
                    HStack(spacing: 3) {
                        ForEach(1...5, id: \.self) { i in
                            Circle()
                                .fill(i <= drill.difficulty ? accentColor : DesignSystem.Colors.textTertiary.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }

                    Spacer()

                    Text("\(drill.duration) min")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
    }
}
