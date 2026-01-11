import SwiftUI

/// Main shop interface where players can browse and purchase avatar items
struct ShopView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ShopViewModel()
    @State private var selectedItem: AvatarItem?
    @State private var showingPurchaseSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Coin balance header
                coinHeader

                // Filter tabs
                filterTabs

                // Items grid
                itemsGrid
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Avatar Shop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
            }
            .sheet(item: $selectedItem) { item in
                ShopItemDetailView(
                    item: item,
                    onPurchase: { purchasedItem in
                        viewModel.purchaseItem(purchasedItem)
                        selectedItem = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Coin Header

    private var coinHeader: some View {
        HStack {
            CoinDisplayView(size: .large)

            Spacer()

            // Player level badge
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundColor(DesignSystem.Colors.xpGold)
                Text("Lv. \(viewModel.playerLevel)")
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.backgroundSecondary)
            .cornerRadius(DesignSystem.CornerRadius.pill)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary.opacity(0.5))
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Slot filters
                filterButton("All", isSelected: viewModel.selectedSlot == nil) {
                    viewModel.selectedSlot = nil
                }

                ForEach(AvatarSlot.allCases.filter { $0.requiresPurchase }) { slot in
                    filterButton(slot.displayName, isSelected: viewModel.selectedSlot == slot) {
                        viewModel.selectedSlot = slot
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
    }

    private func filterButton(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.Typography.labelMedium)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.backgroundSecondary)
                .cornerRadius(DesignSystem.CornerRadius.pill)
        }
    }

    // MARK: - Items Grid

    private var itemsGrid: some View {
        ScrollView {
            if viewModel.filteredItems.isEmpty {
                emptyState
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: DesignSystem.Spacing.md
                ) {
                    ForEach(viewModel.filteredItems) { item in
                        ShopItemCard(
                            item: item,
                            isOwned: viewModel.ownsItem(item),
                            canAfford: viewModel.canAfford(item),
                            meetsLevelRequirement: viewModel.meetsLevelRequirement(item)
                        ) {
                            selectedItem = item
                        }
                    }
                }
                .padding(DesignSystem.Spacing.md)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "bag.fill")
                .font(.system(size: 50))
                .foregroundColor(DesignSystem.Colors.textTertiary)

            Text("No items available")
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Text("Check back later for new items!")
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textTertiary)
        }
        .padding(.top, 100)
    }
}

// MARK: - Shop View Model

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var selectedSlot: AvatarSlot?
    @Published var playerLevel: Int = 1
    @Published private(set) var coinBalance: Int = 0

    private let coinService = CoinService.shared
    private let avatarService = AvatarService.shared
    private let catalog = AvatarCatalogService.shared
    private let coreDataManager = CoreDataManager.shared

    init() {
        loadPlayerData()
    }

    var filteredItems: [AvatarItem] {
        var items = catalog.allItems.filter { $0.rarity != .starter }

        if let slot = selectedSlot {
            items = items.filter { $0.slot == slot }
        }

        // Sort by: owned status, then level requirement, then price
        return items.sorted { lhs, rhs in
            let lhsOwned = ownsItem(lhs)
            let rhsOwned = ownsItem(rhs)

            if lhsOwned != rhsOwned {
                return !lhsOwned // Unowned items first
            }

            if lhs.levelRequirement != rhs.levelRequirement {
                return lhs.levelRequirement < rhs.levelRequirement
            }

            return lhs.price < rhs.price
        }
    }

    func ownsItem(_ item: AvatarItem) -> Bool {
        avatarService.ownsItem(item.id)
    }

    func canAfford(_ item: AvatarItem) -> Bool {
        coinBalance >= item.price
    }

    func meetsLevelRequirement(_ item: AvatarItem) -> Bool {
        playerLevel >= item.levelRequirement
    }

    func purchaseItem(_ item: AvatarItem) {
        guard !ownsItem(item) else { return }
        guard canAfford(item) else { return }
        guard meetsLevelRequirement(item) else { return }

        // Deduct coins
        if coinService.deductCoins(item.price, for: item.name) {
            // Add to inventory
            avatarService.addItemToInventory(item.id)
            coinBalance = coinService.getBalance()

            // Haptic feedback
            HapticManager.shared.success()
        }
    }

    private func loadPlayerData() {
        coinBalance = coinService.getBalance()

        if let player = coreDataManager.getCurrentPlayer() {
            playerLevel = Int(player.currentLevel)
        }
    }
}

// MARK: - Shop Item Card

struct ShopItemCard: View {
    let item: AvatarItem
    let isOwned: Bool
    let canAfford: Bool
    let meetsLevelRequirement: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Item preview
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(item.rarity.color.opacity(0.15))
                        .frame(height: 100)

                    itemPreview

                    // Rarity indicator
                    VStack {
                        HStack {
                            Spacer()
                            Text(item.rarity.displayName)
                                .font(DesignSystem.Typography.labelSmall)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.rarity.color)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(8)

                    // Owned badge
                    if isOwned {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(DesignSystem.Colors.successGreen)
                                    .font(.system(size: 24))
                                    .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                            }
                        }
                        .padding(8)
                    }

                    // Level lock overlay
                    if !meetsLevelRequirement {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color.black.opacity(0.6))

                        VStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 24))
                            Text("Lv. \(item.levelRequirement)")
                                .font(DesignSystem.Typography.labelSmall)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                    }
                }

                // Item name
                Text(item.name)
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)

                // Price or owned status
                if isOwned {
                    Text("Owned")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.successGreen)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(DesignSystem.Colors.coinGold)
                        Text("\(item.price)")
                            .fontWeight(.semibold)
                            .foregroundColor(canAfford ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.error)
                    }
                    .font(DesignSystem.Typography.labelMedium)
                }
            }
            .padding(DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.cardBackground)
            .cornerRadius(DesignSystem.CornerRadius.card)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var itemPreview: some View {
        // Placeholder preview based on item slot
        switch item.slot {
        case .jersey:
            RoundedRectangle(cornerRadius: 8)
                .fill(itemColor)
                .frame(width: 50, height: 40)
        case .shorts:
            RoundedRectangle(cornerRadius: 6)
                .fill(itemColor)
                .frame(width: 45, height: 25)
        case .cleats:
            RoundedRectangle(cornerRadius: 4)
                .fill(itemColor)
                .frame(width: 40, height: 15)
        case .hairStyle:
            Capsule()
                .fill(DesignSystem.Colors.textSecondary)
                .frame(width: 40, height: 15)
        case .accessory:
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(item.rarity.color)
        default:
            Circle()
                .fill(itemColor)
                .frame(width: 40, height: 40)
        }
    }

    private var itemColor: Color {
        // Map item ID to preview color
        if item.id.contains("blue") { return DesignSystem.Colors.secondaryBlue }
        if item.id.contains("red") { return .red }
        if item.id.contains("yellow") { return .yellow }
        if item.id.contains("black") { return .black }
        if item.id.contains("white") { return .white }
        if item.id.contains("gold") { return DesignSystem.Colors.xpGold }
        if item.id.contains("neon") { return .green }
        return DesignSystem.Colors.primaryGreen
    }
}

// MARK: - Shop Item Detail View

struct ShopItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let item: AvatarItem
    let onPurchase: (AvatarItem) -> Void

    @StateObject private var coinViewModel = CoinBalanceViewModel()
    @State private var showingConfirmation = false

    private var isOwned: Bool {
        AvatarService.shared.ownsItem(item.id)
    }

    private var canAfford: Bool {
        coinViewModel.balance >= item.price
    }

    private var meetsLevelRequirement: Bool {
        guard let player = CoreDataManager.shared.getCurrentPlayer() else { return false }
        return player.currentLevel >= item.levelRequirement
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Item preview
                    itemPreviewSection

                    // Item info
                    itemInfoSection

                    // Purchase section
                    purchaseSection
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                    }
                }
            }
            .alert("Confirm Purchase", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Buy for \(item.price) coins") {
                    onPurchase(item)
                }
            } message: {
                Text("Purchase \(item.name) for \(item.price) coins?")
            }
        }
    }

    private var itemPreviewSection: some View {
        ZStack {
            // Rarity gradient background
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(item.rarity.gradient)
                .frame(height: 200)

            // Large item preview
            VStack {
                Image(systemName: item.slot.icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text(item.slot.displayName)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(.white.opacity(0.8))
            }

            // Rarity badge
            VStack {
                HStack {
                    Text(item.rarity.displayName.uppercased())
                        .font(DesignSystem.Typography.labelSmall)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(DesignSystem.CornerRadius.pill)
                    Spacer()
                }
                Spacer()
            }
            .padding(DesignSystem.Spacing.md)
        }
    }

    private var itemInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(item.description)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(DesignSystem.Colors.textSecondary)

            Divider()

            // Requirements
            HStack {
                Label("Level \(item.levelRequirement)+", systemImage: "star.fill")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(meetsLevelRequirement ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.error)

                Spacer()

                if isOwned {
                    Label("Owned", systemImage: "checkmark.circle.fill")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.successGreen)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.card)
    }

    private var purchaseSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Current balance
            HStack {
                Text("Your Balance")
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                Spacer()
                CoinDisplayView(size: .medium)
            }

            // Purchase button
            if isOwned {
                Button {} label: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Already Owned")
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.successGreen)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .disabled(true)
            } else if !meetsLevelRequirement {
                Button {} label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Reach Level \(item.levelRequirement)")
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(DesignSystem.Colors.textTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .disabled(true)
            } else {
                Button {
                    showingConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(DesignSystem.Colors.coinGold)
                        Text("Buy for \(item.price)")
                    }
                    .font(DesignSystem.Typography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .background(canAfford ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.button)
                }
                .disabled(!canAfford)

                if !canAfford {
                    Text("You need \(item.price - coinViewModel.balance) more coins")
                        .font(DesignSystem.Typography.labelSmall)
                        .foregroundColor(DesignSystem.Colors.error)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Shop") {
    ShopView()
}

#Preview("Item Card") {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
        ShopItemCard(
            item: AvatarItem(
                id: "jersey_blue",
                name: "Blue Jersey",
                slot: .jersey,
                rarity: .common,
                price: 75,
                assetName: "blue",
                description: "Cool blue team jersey.",
                levelRequirement: 0
            ),
            isOwned: false,
            canAfford: true,
            meetsLevelRequirement: true
        ) {}

        ShopItemCard(
            item: AvatarItem(
                id: "jersey_galaxy",
                name: "Galaxy Jersey",
                slot: .jersey,
                rarity: .epic,
                price: 1500,
                assetName: "galaxy",
                description: "Out-of-this-world cosmic design.",
                levelRequirement: 25
            ),
            isOwned: false,
            canAfford: false,
            meetsLevelRequirement: false
        ) {}
    }
    .padding()
}
