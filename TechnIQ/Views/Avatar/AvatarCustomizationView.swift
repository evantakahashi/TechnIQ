import SwiftUI

// MARK: - Kit & avatar (You → Kit & avatar)
//
// The character on the pitch card is the live preview; every option cell draws the same character
// with that one option applied, so what you tap is what you get. Nothing saves until Save.

struct AvatarCustomizationView: View {
    var kitNumber: Int?
    @Environment(\.dismiss) private var dismiss
    @State private var category: AvatarCategory = .skinTone
    @State private var draft = AvatarService.shared.getAvatarState()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            TQNavBar("Kit & avatar") {
                TQNavAction("Cancel") { dismiss() }
            } trailing: {
                TQNavAction("Save") { save() }
                    .accessibilityIdentifier("avatar.save")
            }
            .padding(.top, 8)
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)

            TQPitchCard(.hero, markings: .profile) {
                AvatarFigureView(avatarState: draft, kitNumber: kitNumber)
                    .frame(height: 232)
                    .frame(maxWidth: .infinity)
                    .animation(DesignSystem.Animation.quick, value: draft)
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 10)

            TQChipRow {
                ForEach(AvatarCategory.allCases) { item in
                    TQChip(item.title, isSelected: category == item) {
                        category = item
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(category.options, id: \.self) { value in
                        optionCell(value)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func save() {
        AvatarService.shared.saveAvatarState(draft)
        HapticManager.shared.selectionChanged()
        dismiss()
    }

    // MARK: Option cell

    private func optionCell(_ value: String) -> some View {
        let isSelected = category.value(in: draft) == value
        let name = category.name(of: value)
        return Button {
            category.apply(value, to: &draft)
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 6) {
                optionPreview(value)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .background(DesignSystem.Colors.surfaceRaised)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xl, style: .continuous)
                            .strokeBorder(isSelected ? DesignSystem.Colors.grass : .clear, lineWidth: 2)
                    )
                Text(name)
                    .font(Font.system(size: 12, weight: .semibold).width(.condensed))
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .foregroundColor(isSelected ? DesignSystem.Colors.chalkWhite : DesignSystem.Colors.dimIvory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func optionPreview(_ value: String) -> some View {
        if let swatch = category.swatch(of: value) {
            Circle()
                .fill(swatch)
                .overlay(Circle().strokeBorder(DesignSystem.Colors.chalkWhite.opacity(0.12), lineWidth: 1))
                .padding(16)
        } else {
            GeometryReader { geo in
                AvatarBustView(avatarState: category.applying(value, to: draft),
                               kitNumber: category == .jersey ? kitNumber : nil,
                               diameter: geo.size.width,
                               background: .clear,
                               focus: category.focus,
                               isCircular: false)
            }
        }
    }
}

// MARK: - Categories

enum AvatarCategory: String, CaseIterable, Identifiable {
    case skinTone, hairStyle, hairColor, face, jersey, shorts, socks, cleats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skinTone: return "Skin"
        case .hairStyle: return "Hair"
        case .hairColor: return "Hair colour"
        case .face: return "Face"
        case .jersey: return "Jersey"
        case .shorts: return "Shorts"
        case .socks: return "Socks"
        case .cleats: return "Boots"
        }
    }

    /// Raw values of every option in this category.
    var options: [String] {
        switch self {
        case .skinTone: return SkinTone.allCases.map(\.rawValue)
        case .hairStyle: return HairStyle.allCases.map(\.rawValue)
        case .hairColor: return HairColor.allCases.map(\.rawValue)
        case .face: return FaceStyle.allCases.map(\.rawValue)
        case .jersey: return JerseyStyle.allCases.map(\.rawValue)
        case .shorts: return ShortsStyle.allCases.map(\.rawValue)
        case .socks: return SocksStyle.allCases.map(\.rawValue)
        case .cleats: return CleatsStyle.allCases.map(\.rawValue)
        }
    }

    func name(of value: String) -> String {
        switch self {
        case .skinTone: return SkinTone(rawValue: value)?.displayName ?? value
        case .hairStyle: return HairStyle(rawValue: value)?.displayName ?? value
        case .hairColor: return HairColor(rawValue: value)?.displayName ?? value
        case .face: return FaceStyle(rawValue: value)?.displayName ?? value
        case .jersey: return JerseyStyle(rawValue: value)?.displayName ?? value
        case .shorts: return ShortsStyle(rawValue: value)?.displayName ?? value
        case .socks: return SocksStyle(rawValue: value)?.displayName ?? value
        case .cleats: return CleatsStyle(rawValue: value)?.displayName ?? value
        }
    }

    func value(in state: AvatarState) -> String {
        switch self {
        case .skinTone: return state.skinTone.rawValue
        case .hairStyle: return state.hairStyle.rawValue
        case .hairColor: return state.hairColor.rawValue
        case .face: return state.faceStyle.rawValue
        case .jersey: return state.jerseyStyle.rawValue
        case .shorts: return state.shortsStyle.rawValue
        case .socks: return state.socksStyle.rawValue
        case .cleats: return state.cleatsStyle.rawValue
        }
    }

    func apply(_ value: String, to state: inout AvatarState) {
        switch self {
        case .skinTone: if let v = SkinTone(rawValue: value) { state.skinTone = v }
        case .hairStyle: if let v = HairStyle(rawValue: value) { state.hairStyle = v }
        case .hairColor: if let v = HairColor(rawValue: value) { state.hairColor = v }
        case .face: if let v = FaceStyle(rawValue: value) { state.faceStyle = v }
        case .jersey: if let v = JerseyStyle(rawValue: value) { state.jerseyStyle = v }
        case .shorts: if let v = ShortsStyle(rawValue: value) { state.shortsStyle = v }
        case .socks: if let v = SocksStyle(rawValue: value) { state.socksStyle = v }
        case .cleats: if let v = CleatsStyle(rawValue: value) { state.cleatsStyle = v }
        }
    }

    func applying(_ value: String, to state: AvatarState) -> AvatarState {
        var copy = state
        apply(value, to: &copy)
        return copy
    }

    /// Colour-only categories show a swatch instead of the character.
    func swatch(of value: String) -> Color? {
        switch self {
        case .skinTone: return SkinTone(rawValue: value)?.color
        case .hairColor: return HairColor(rawValue: value)?.color
        default: return nil
        }
    }

    /// The part of the character an option cell shows.
    var focus: CGRect {
        switch self {
        case .jersey, .shorts: return AvatarRenderer.kitFocus
        case .socks, .cleats: return AvatarRenderer.bootsFocus
        default: return AvatarRenderer.bustFocus
        }
    }
}

#if DEBUG
#Preview {
    AvatarCustomizationView(kitNumber: 9)
}
#endif
