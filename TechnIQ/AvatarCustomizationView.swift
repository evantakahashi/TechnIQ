import SwiftUI

/// Main avatar customization view where players can edit their avatar
struct AvatarCustomizationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AvatarCustomizationViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Avatar Preview
                avatarPreview

                // Category Tabs
                categoryTabs

                // Options Grid
                optionsGrid
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Customize Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.revertChanges()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                }
            }
        }
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    DesignSystem.Colors.primaryGreen.opacity(0.1),
                    DesignSystem.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                AvatarView(avatarState: viewModel.currentState, size: .xlarge)
                    .animation(.spring(response: 0.3), value: viewModel.currentState)

                // Current selection label
                if let currentSelection = viewModel.currentSelectionLabel {
                    Text(currentSelection)
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(DesignSystem.CornerRadius.pill)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .frame(height: 320)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(AvatarCustomizationCategory.allCases) { category in
                    categoryTab(category)
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.backgroundSecondary)
    }

    private func categoryTab(_ category: AvatarCustomizationCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedCategory = category
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                Text(category.displayName)
                    .font(DesignSystem.Typography.labelSmall)
            }
            .foregroundColor(isSelected ? DesignSystem.Colors.primaryGreen : DesignSystem.Colors.textSecondary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.15) : Color.clear)
            .cornerRadius(DesignSystem.CornerRadius.md)
        }
    }

    // MARK: - Options Grid

    private var optionsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: DesignSystem.Spacing.md
            ) {
                ForEach(viewModel.currentOptions, id: \.id) { option in
                    optionCell(option)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
    }

    private func optionCell(_ option: CustomizationOption) -> some View {
        let isSelected = viewModel.isSelected(option)
        let isLocked = option.isLocked

        return Button {
            if !isLocked {
                HapticManager.shared.selectionChanged()
                viewModel.selectOption(option)
            }
        } label: {
            VStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    // Option preview
                    optionPreview(option)
                        .frame(width: 60, height: 60)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(isSelected ? DesignSystem.Colors.primaryGreen.opacity(0.15) : DesignSystem.Colors.backgroundSecondary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(
                                    isSelected ? DesignSystem.Colors.primaryGreen : Color.clear,
                                    lineWidth: 2
                                )
                        )

                    // Lock overlay
                    if isLocked {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 60, height: 60)
                        Image(systemName: "lock.fill")
                            .foregroundColor(.white)
                    }

                    // Checkmark for selected
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.Colors.primaryGreen)
                                    .background(Circle().fill(Color.white).frame(width: 14, height: 14))
                            }
                            Spacer()
                        }
                        .frame(width: 60, height: 60)
                        .padding(4)
                    }
                }

                Text(option.name)
                    .font(DesignSystem.Typography.labelSmall)
                    .foregroundColor(isLocked ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func optionPreview(_ option: CustomizationOption) -> some View {
        switch option.previewType {
        case .color(let color):
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)

        case .icon(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 24))
                .foregroundColor(DesignSystem.Colors.textPrimary)

        case .hair(let style, let color):
            // Mini hair preview
            ZStack {
                Circle()
                    .fill(SkinTone.medium.color)
                    .frame(width: 30, height: 30)

                hairPreview(style: style, color: color)
            }

        case .clothing(let color):
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 35, height: 25)
        }
    }

    @ViewBuilder
    private func hairPreview(style: String, color: Color) -> some View {
        switch style {
        case "short_1", "short_2", "short_3":
            Capsule()
                .fill(color)
                .frame(width: 30, height: 10)
                .offset(y: -12)
        case "medium_1", "medium_2":
            Capsule()
                .fill(color)
                .frame(width: 32, height: 15)
                .offset(y: -10)
        case "long_1", "ponytail":
            VStack(spacing: 0) {
                Capsule()
                    .fill(color)
                    .frame(width: 32, height: 10)
                Rectangle()
                    .fill(color)
                    .frame(width: 25, height: 15)
            }
            .offset(y: -8)
        case "afro":
            Circle()
                .fill(color)
                .frame(width: 38, height: 38)
                .offset(y: -8)
        case "mohawk":
            Capsule()
                .fill(color)
                .frame(width: 8, height: 18)
                .offset(y: -15)
        case "bald":
            EmptyView()
        default:
            Capsule()
                .fill(color)
                .frame(width: 30, height: 10)
                .offset(y: -12)
        }
    }
}

// MARK: - View Model

@MainActor
final class AvatarCustomizationViewModel: ObservableObject {
    @Published var selectedCategory: AvatarCustomizationCategory = .skinTone
    @Published var currentState: AvatarState
    @Published var currentOptions: [CustomizationOption] = []

    private let avatarService = AvatarService.shared
    private var originalState: AvatarState

    init() {
        let state = AvatarService.shared.getAvatarState()
        self.currentState = state
        self.originalState = state
        updateOptionsForCategory()
    }

    var currentSelectionLabel: String? {
        switch selectedCategory {
        case .skinTone:
            return SkinTone(rawValue: currentState.skinTone)?.displayName
        case .hairStyle:
            return currentState.hairStyle.replacingOccurrences(of: "_", with: " ").capitalized
        case .hairColor:
            return HairColor(rawValue: currentState.hairColor)?.displayName
        case .face:
            return FaceStyle(rawValue: currentState.faceStyle)?.displayName ?? currentState.faceStyle.capitalized
        case .jersey:
            return AvatarCatalogService.shared.item(withId: currentState.jerseyId)?.name ?? "Jersey"
        case .shorts:
            return AvatarCatalogService.shared.item(withId: currentState.shortsId)?.name ?? "Shorts"
        case .cleats:
            return AvatarCatalogService.shared.item(withId: currentState.cleatsId)?.name ?? "Cleats"
        case .accessories:
            return currentState.accessoryIds.isEmpty ? "None" : "\(currentState.accessoryIds.count) equipped"
        }
    }

    func isSelected(_ option: CustomizationOption) -> Bool {
        switch selectedCategory {
        case .skinTone:
            return currentState.skinTone == option.value
        case .hairStyle:
            return currentState.hairStyle == option.value
        case .hairColor:
            return currentState.hairColor == option.value
        case .face:
            return currentState.faceStyle == option.value
        case .jersey:
            return currentState.jerseyId == option.value
        case .shorts:
            return currentState.shortsId == option.value
        case .cleats:
            return currentState.cleatsId == option.value
        case .accessories:
            return currentState.accessoryIds.contains(option.value)
        }
    }

    func selectOption(_ option: CustomizationOption) {
        switch selectedCategory {
        case .skinTone:
            currentState.skinTone = option.value
        case .hairStyle:
            currentState.hairStyle = option.value
        case .hairColor:
            currentState.hairColor = option.value
        case .face:
            currentState.faceStyle = option.value
        case .jersey:
            currentState.jerseyId = option.value
        case .shorts:
            currentState.shortsId = option.value
        case .cleats:
            currentState.cleatsId = option.value
        case .accessories:
            // Toggle accessories
            if currentState.accessoryIds.contains(option.value) {
                currentState.accessoryIds.removeAll { $0 == option.value }
            } else {
                currentState.accessoryIds.append(option.value)
            }
        }
    }

    func saveChanges() {
        avatarService.saveAvatarState(currentState)
    }

    func revertChanges() {
        currentState = originalState
    }

    private func updateOptionsForCategory() {
        currentOptions = buildOptions(for: selectedCategory)
    }

    private func buildOptions(for category: AvatarCustomizationCategory) -> [CustomizationOption] {
        switch category {
        case .skinTone:
            return SkinTone.allCases.map { skinTone in
                CustomizationOption(
                    id: skinTone.rawValue,
                    name: skinTone.displayName,
                    value: skinTone.rawValue,
                    previewType: .color(skinTone.color),
                    isLocked: false
                )
            }

        case .hairColor:
            return HairColor.allCases.map { hairColor in
                CustomizationOption(
                    id: hairColor.rawValue,
                    name: hairColor.displayName,
                    value: hairColor.rawValue,
                    previewType: .color(hairColor.color),
                    isLocked: false
                )
            }

        case .hairStyle:
            let catalog = AvatarCatalogService.shared
            let hairItems = catalog.items(for: .hairStyle)
            let hairColor = HairColor(rawValue: currentState.hairColor)?.color ?? HairColor.brown.color

            var options = hairItems.map { item in
                CustomizationOption(
                    id: item.id,
                    name: item.name,
                    value: item.id,
                    previewType: .hair(item.id, hairColor),
                    isLocked: !avatarService.ownsItem(item.id)
                )
            }

            // Add bald option
            options.append(CustomizationOption(
                id: "bald",
                name: "Bald",
                value: "bald",
                previewType: .icon("circle"),
                isLocked: false
            ))

            return options

        case .face:
            return FaceStyle.allCases.map { face in
                CustomizationOption(
                    id: face.rawValue,
                    name: face.displayName,
                    value: face.rawValue,
                    previewType: .icon(face.icon),
                    isLocked: false
                )
            }

        case .jersey:
            let catalog = AvatarCatalogService.shared
            return catalog.items(for: .jersey).map { item in
                CustomizationOption(
                    id: item.id,
                    name: item.name,
                    value: item.id,
                    previewType: .clothing(jerseyColor(for: item.id)),
                    isLocked: !avatarService.ownsItem(item.id)
                )
            }

        case .shorts:
            let catalog = AvatarCatalogService.shared
            return catalog.items(for: .shorts).map { item in
                CustomizationOption(
                    id: item.id,
                    name: item.name,
                    value: item.id,
                    previewType: .clothing(shortsColor(for: item.id)),
                    isLocked: !avatarService.ownsItem(item.id)
                )
            }

        case .cleats:
            let catalog = AvatarCatalogService.shared
            return catalog.items(for: .cleats).map { item in
                CustomizationOption(
                    id: item.id,
                    name: item.name,
                    value: item.id,
                    previewType: .clothing(cleatsColor(for: item.id)),
                    isLocked: !avatarService.ownsItem(item.id)
                )
            }

        case .accessories:
            let catalog = AvatarCatalogService.shared
            return catalog.items(for: .accessory).map { item in
                CustomizationOption(
                    id: item.id,
                    name: item.name,
                    value: item.id,
                    previewType: .icon("sparkles"),
                    isLocked: !avatarService.ownsItem(item.id)
                )
            }
        }
    }

    // Helper color mappings
    private func jerseyColor(for id: String) -> Color {
        switch id {
        case "starter_jersey": return DesignSystem.Colors.primaryGreen
        case "jersey_white_basic": return .white
        case "jersey_blue": return DesignSystem.Colors.secondaryBlue
        case "jersey_red": return .red
        case "jersey_yellow": return .yellow
        case "jersey_black": return .black
        default: return DesignSystem.Colors.primaryGreen
        }
    }

    private func shortsColor(for id: String) -> Color {
        switch id {
        case "starter_shorts": return .white
        case "shorts_black_basic", "shorts_black": return .black
        case "shorts_white": return .white
        case "shorts_blue": return DesignSystem.Colors.secondaryBlue
        default: return .white
        }
    }

    private func cleatsColor(for id: String) -> Color {
        switch id {
        case "starter_cleats", "cleats_black_basic": return .black
        case "cleats_white": return .white
        case "cleats_blue": return DesignSystem.Colors.secondaryBlue
        case "cleats_gold": return DesignSystem.Colors.xpGold
        case "cleats_neon": return .green
        default: return .black
        }
    }
}

// Keep options updated when category changes
extension AvatarCustomizationViewModel {
    func categoryDidChange() {
        currentOptions = buildOptions(for: selectedCategory)
    }
}

// MARK: - Supporting Types

enum AvatarCustomizationCategory: String, CaseIterable, Identifiable {
    case skinTone
    case hairStyle
    case hairColor
    case face
    case jersey
    case shorts
    case cleats
    case accessories

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skinTone: return "Skin"
        case .hairStyle: return "Hair"
        case .hairColor: return "Color"
        case .face: return "Face"
        case .jersey: return "Jersey"
        case .shorts: return "Shorts"
        case .cleats: return "Cleats"
        case .accessories: return "Extra"
        }
    }

    var icon: String {
        switch self {
        case .skinTone: return "hand.raised.fill"
        case .hairStyle: return "comb.fill"
        case .hairColor: return "paintpalette.fill"
        case .face: return "face.smiling.fill"
        case .jersey: return "tshirt.fill"
        case .shorts: return "rectangle.fill"
        case .cleats: return "shoe.fill"
        case .accessories: return "sparkles"
        }
    }
}

struct CustomizationOption: Identifiable {
    let id: String
    let name: String
    let value: String
    let previewType: PreviewType
    let isLocked: Bool

    enum PreviewType {
        case color(Color)
        case icon(String)
        case hair(String, Color)
        case clothing(Color)
    }
}

// MARK: - Preview

#Preview {
    AvatarCustomizationView()
}
