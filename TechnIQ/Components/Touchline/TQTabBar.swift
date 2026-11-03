import SwiftUI

// MARK: - TQTabBar
//
// Four or five icon-only items (Community is flagged), 24 pt semibold. Selected = grass + .fill symbol, idle = textTertiary
// outline, so state reads without colour. 1 px top rule, base background, no labels — the
// screen title already names the tab.

struct TQTabBar: View {
    @Binding var selectedTab: DesignSystem.Icons.Tab
    var tabs: [DesignSystem.Icons.Tab] = DesignSystem.Icons.Tab.visible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                let isSelected = selectedTab == tab
                Button {
                    HapticManager.shared.tabChanged()
                    if reduceMotion {
                        selectedTab = tab
                    } else {
                        withAnimation(DesignSystem.Animation.tabMorph) { selectedTab = tab }
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
        TQTabBar(selectedTab: .constant(.home))
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
