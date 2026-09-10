import SwiftUI

// MARK: - Screen headers
//
// `TQScreenTitle`: condensed 30 pt title ("TRAIN") with a trailing compact button or icon.
// `TQNavBar`: back / centred condensed label / trailing actions for pushed screens (Plan detail,
// Drill detail, AI drill). `TQScreen`: the base surface + 20 pt horizontal padding wrapper.

struct TQScreenTitle<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(DesignSystem.Typography.displaySmall)
                .textCase(.uppercase)
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            trailing
        }
    }
}

extension TQScreenTitle where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

struct TQNavBar<Leading: View, Trailing: View>: View {
    enum TitleTone { case muted, grass }

    let title: String
    var tone: TitleTone = .muted
    let leading: Leading
    let trailing: Trailing

    init(_ title: String, tone: TitleTone = .muted, @ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.tone = tone
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(Font.system(size: 14, weight: .semibold).width(.condensed))
                .textCase(.uppercase)
                .tracking(1.1)
                .foregroundColor(tone == .grass ? DesignSystem.Colors.grass : DesignSystem.Colors.dimIvory)
                .accessibilityAddTraits(.isHeader)
            HStack {
                leading
                Spacer()
                trailing
            }
        }
        .frame(height: 38)
    }
}

/// Back chevron for TQNavBar.
struct TQBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(DesignSystem.Colors.chalkWhite)
                .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Muted text action for nav bars ("Edit", "Cancel").
struct TQNavAction: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            Text(title)
                .font(Font.system(size: 14, weight: .semibold))
                .foregroundColor(DesignSystem.Colors.dimIvory)
                .frame(minHeight: DesignSystem.Spacing.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Muted icon action for title rows (gear, share).
struct TQIconAction: View {
    let systemImage: String
    var tone: Tone = .muted
    let accessibilityLabel: String
    let action: () -> Void

    enum Tone { case muted, grass, chalk }

    init(_ systemImage: String, tone: Tone = .muted, accessibilityLabel: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.tone = tone
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
                .frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var color: Color {
        switch tone {
        case .muted: return DesignSystem.Colors.dimIvory
        case .grass: return DesignSystem.Colors.grass
        case .chalk: return DesignSystem.Colors.chalkWhite
        }
    }
}

/// Base surface + horizontal screen padding. Content decides its own vertical spacing.
struct TQScreen<Content: View>: View {
    var horizontalPadding: CGFloat = DesignSystem.Spacing.screenPadding
    let content: Content

    init(horizontalPadding: CGFloat = DesignSystem.Spacing.screenPadding, @ViewBuilder content: () -> Content) {
        self.horizontalPadding = horizontalPadding
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
    }
}

/// 40 pt circular avatar frame used in the Home header: raised fill, 1.5 pt highlight border.
struct TQAvatarCircle<Content: View>: View {
    var size: CGFloat = 40
    let content: Content

    init(size: CGFloat = 40, @ViewBuilder content: () -> Content) {
        self.size = size
        self.content = content()
    }

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(DesignSystem.Colors.surfaceRaised)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(DesignSystem.Colors.surfaceHighlight, lineWidth: 1.5))
    }
}

#if DEBUG
#Preview("Headers") {
    VStack(spacing: 24) {
        TQScreenTitle("Train") {
            TQButton("+ New drill", size: .compact, fullWidth: false) {}
        }
        TQScreenTitle("You") {
            TQIconAction("gearshape", accessibilityLabel: "Settings") {}
        }
        TQNavBar("Plan") {
            TQBackButton {}
        } trailing: {
            TQNavAction("Edit") {}
        }
        TQNavBar("AI drill · Technical", tone: .grass) {
            TQBackButton {}
        } trailing: {
            HStack(spacing: 6) {
                TQIconAction("heart.fill", tone: .grass, accessibilityLabel: "Saved") {}
                TQIconAction("square.and.arrow.up", accessibilityLabel: "Share") {}
            }
        }
        TQAvatarCircle {
            Text("E")
                .font(DesignSystem.Typography.labelTile)
                .foregroundColor(DesignSystem.Colors.dimIvory)
        }
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
