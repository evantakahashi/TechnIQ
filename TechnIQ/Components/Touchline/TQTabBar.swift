import SwiftUI

// MARK: - TQTabBar
//
// Five icon-only items, 24 pt semibold. Selected = grass + .fill symbol, idle = textTertiary
// outline, so state reads without colour. 1 px top rule, base background, no labels — the
// screen title already names the tab.

struct TQTabBar: View {
    @Binding var selectedTab: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DesignSystem.Icons.Tab.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab.rawValue
                Button {
                    HapticManager.shared.tabChanged()
                    if reduceMotion {
                        selectedTab = tab.rawValue
                    } else {
                        withAnimation(DesignSystem.Animation.tabMorph) { selectedTab = tab.rawValue }
                    }
                } label: {
                    Image(systemName: isSelected ? tab.selected : tab.idle)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isSelected ? DesignSystem.Colors.grass : DesignSystem.Colors.textTertiary)
                        .frame(width: 24, height: 24)
                        .frame(maxWidth: .infinity)
                        .frame(height: DesignSystem.Spacing.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.accessibilityLabel)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : [.isButton])
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .background(
            DesignSystem.Colors.surfaceBase
                .overlay(alignment: .top) { TQRule() }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#if DEBUG
#Preview("Tab bar") {
    VStack {
        Spacer()
        TQTabBar(selectedTab: .constant(0))
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
