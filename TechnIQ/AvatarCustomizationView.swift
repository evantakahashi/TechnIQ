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
            .background(DesignSystem.Colors.darkModeBackground)
            .navigationTitle("Customize Avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DesignSystem.Colors.darkModeBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.revertChanges()
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.8))
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
        .preferredColorScheme(.dark)
    }

    // MARK: - Avatar Preview

    private var avatarPreview: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.20, blue: 0.15),
                    DesignSystem.Colors.darkModeBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: DesignSystem.Spacing.md) {
                ProgrammaticAvatarView(avatarState: viewModel.currentState, size: .xlarge)
                    .animation(.spring(response: 0.3), value: viewModel.currentState)

                // Current selection label
                if let currentSelection = viewModel.currentSelectionLabel {
                    Text(currentSelection)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.cellBackground)
                        .cornerRadius(DesignSystem.CornerRadius.pill)
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .frame(height: 280)
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
        .background(DesignSystem.Colors.darkModeBackground)
    }

    private func categoryTab(_ category: AvatarCustomizationCategory) -> some View {
        let isSelected = viewModel.selectedCategory == category

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedCategory = category
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.system(size: 24, weight: .medium))
                Text(category.displayName)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
            .frame(width: 60, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? DesignSystem.Colors.primaryGreen : Color.clear)
            )
        }
    }

    // MARK: - Options Grid

    private var optionsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                ForEach(viewModel.currentOptions, id: \.id) { option in
                    optionCell(option)
                }
            }
            .padding(DesignSystem.Spacing.md)
        }
        .background(DesignSystem.Colors.darkModeBackground)
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
            VStack(spacing: 8) {
                // Cell with preview
                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 14)
                        .fill(DesignSystem.Colors.cellBackground)
                        .frame(width: 80, height: 80)

                    // Selection border
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(DesignSystem.Colors.primaryGreen, lineWidth: 2.5)
                            .frame(width: 80, height: 80)
                    }

                    // Option preview
                    optionPreview(option)

                    // Lock overlay
                    if isLocked {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 80, height: 80)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    // Checkmark badge for selected
                    if isSelected && !isLocked {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.primaryGreen)
                                        .frame(width: 20, height: 20)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .offset(x: 4, y: -4)
                            }
                            Spacer()
                        }
                        .frame(width: 80, height: 80)
                    }
                }

                // Label below cell
                Text(option.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isLocked ? DesignSystem.Colors.textTertiary : .white)
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
                .frame(width: 50, height: 50)

        case .icon(let systemName):
            Image(systemName: systemName)
                .font(.system(size: 28))
                .foregroundColor(.white)

        case .assetImage(let assetName):
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
        }
    }
}

// MARK: - View Model

@MainActor
final class AvatarCustomizationViewModel: ObservableObject {
    @Published var selectedCategory: AvatarCustomizationCategory = .skinTone {
        didSet {
            updateOptionsForCategory()
        }
    }
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
            return currentState.skinTone.displayName
        case .hairStyle:
            return currentState.hairStyle.displayName
        case .hairColor:
            return currentState.hairColor.displayName
        case .face:
            return currentState.faceStyle.displayName
        case .jersey:
            return currentState.jerseyStyle.displayName
        case .shorts:
            return currentState.shortsStyle.displayName
        case .socks:
            return currentState.socksStyle.displayName
        case .cleats:
            return currentState.cleatsStyle.displayName
        }
    }

    func isSelected(_ option: CustomizationOption) -> Bool {
        switch selectedCategory {
        case .skinTone:
            return currentState.skinTone.rawValue == option.value
        case .hairStyle:
            return currentState.hairStyle.rawValue == option.value
        case .hairColor:
            return currentState.hairColor.rawValue == option.value
        case .face:
            return currentState.faceStyle.rawValue == option.value
        case .jersey:
            return currentState.jerseyStyle.rawValue == option.value
        case .shorts:
            return currentState.shortsStyle.rawValue == option.value
        case .socks:
            return currentState.socksStyle.rawValue == option.value
        case .cleats:
            return currentState.cleatsStyle.rawValue == option.value
        }
    }

    func selectOption(_ option: CustomizationOption) {
        switch selectedCategory {
        case .skinTone:
            if let skinTone = SkinTone(rawValue: option.value) {
                currentState.skinTone = skinTone
            }
        case .hairStyle:
            if let hairStyle = HairStyle(rawValue: option.value) {
                currentState.hairStyle = hairStyle
            }
        case .hairColor:
            if let hairColor = HairColor(rawValue: option.value) {
                currentState.hairColor = hairColor
            }
        case .face:
            if let faceStyle = FaceStyle(rawValue: option.value) {
                currentState.faceStyle = faceStyle
            }
        case .jersey:
            if let jerseyStyle = JerseyStyle(rawValue: option.value) {
                currentState.jerseyStyle = jerseyStyle
            }
        case .shorts:
            if let shortsStyle = ShortsStyle(rawValue: option.value) {
                currentState.shortsStyle = shortsStyle
            }
        case .socks:
            if let socksStyle = SocksStyle(rawValue: option.value) {
                currentState.socksStyle = socksStyle
            }
        case .cleats:
            if let cleatsStyle = CleatsStyle(rawValue: option.value) {
                currentState.cleatsStyle = cleatsStyle
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
                    previewType: .assetImage(skinTone.bodyAssetName),
                    isLocked: false
                )
            }

        case .hairStyle:
            return HairStyle.allCases.map { hairStyle in
                CustomizationOption(
                    id: hairStyle.rawValue,
                    name: hairStyle.displayName,
                    value: hairStyle.rawValue,
                    previewType: .assetImage(hairStyle.assetName(color: currentState.hairColor)),
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

        case .face:
            return FaceStyle.allCases.map { face in
                CustomizationOption(
                    id: face.rawValue,
                    name: face.displayName,
                    value: face.rawValue,
                    previewType: .assetImage(face.assetName),
                    isLocked: false
                )
            }

        case .jersey:
            return JerseyStyle.allCases.map { jersey in
                CustomizationOption(
                    id: jersey.rawValue,
                    name: jersey.displayName,
                    value: jersey.rawValue,
                    previewType: .assetImage(jersey.assetName),
                    isLocked: !jersey.isStarter && !avatarService.ownsItem(jersey.rawValue)
                )
            }

        case .shorts:
            return ShortsStyle.allCases.map { shorts in
                CustomizationOption(
                    id: shorts.rawValue,
                    name: shorts.displayName,
                    value: shorts.rawValue,
                    previewType: .assetImage(shorts.assetName),
                    isLocked: !shorts.isStarter && !avatarService.ownsItem(shorts.rawValue)
                )
            }

        case .socks:
            return SocksStyle.allCases.map { socks in
                CustomizationOption(
                    id: socks.rawValue,
                    name: socks.displayName,
                    value: socks.rawValue,
                    previewType: .assetImage(socks.assetName),
                    isLocked: !socks.isStarter && !avatarService.ownsItem(socks.rawValue)
                )
            }

        case .cleats:
            return CleatsStyle.allCases.map { cleats in
                CustomizationOption(
                    id: cleats.rawValue,
                    name: cleats.displayName,
                    value: cleats.rawValue,
                    previewType: .assetImage(cleats.assetName),
                    isLocked: !cleats.isStarter && !avatarService.ownsItem(cleats.rawValue)
                )
            }
        }
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
    case socks
    case cleats

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skinTone: return "Skin"
        case .hairStyle: return "Hair"
        case .hairColor: return "Color"
        case .face: return "Face"
        case .jersey: return "Jersey"
        case .shorts: return "Shorts"
        case .socks: return "Socks"
        case .cleats: return "Cleats"
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
        case .socks: return "figure.walk"
        case .cleats: return "shoe.fill"
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
        case assetImage(String)
    }
}

// MARK: - Preview

#Preview {
    AvatarCustomizationView()
}
