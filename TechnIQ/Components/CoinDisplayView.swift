import SwiftUI

/// Animated coin counter display for showing player's coin balance
struct CoinDisplayView: View {
    @StateObject private var viewModel = CoinBalanceViewModel()
    let size: CoinDisplaySize

    enum CoinDisplaySize {
        case small   // For inline use
        case medium  // For cards
        case large   // For headers

        var iconSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }

        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.labelSmall
            case .medium: return DesignSystem.Typography.labelMedium
            case .large: return DesignSystem.Typography.titleMedium
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small:
                return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .medium:
                return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .large:
                return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            }
        }
    }

    init(size: CoinDisplaySize = .medium) {
        self.size = size
    }

    var body: some View {
        HStack(spacing: 6) {
            // Coin icon
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: size.iconSize))
                .foregroundColor(DesignSystem.Colors.coinGold)

            // Balance with animation
            Text("\(viewModel.balance)")
                .font(size.font)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3), value: viewModel.balance)

            // Animated change indicator
            if let amount = viewModel.animatingAmount {
                Text(amount > 0 ? "+\(amount)" : "\(amount)")
                    .font(DesignSystem.Typography.labelSmall)
                    .fontWeight(.bold)
                    .foregroundColor(amount > 0 ? DesignSystem.Colors.successGreen : DesignSystem.Colors.error)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }
        }
        .padding(size.padding)
        .background(
            Capsule()
                .fill(DesignSystem.Colors.coinGold.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(DesignSystem.Colors.coinGold.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Previews

#Preview("Coin Display Sizes") {
    VStack(spacing: 20) {
        CoinDisplayView(size: .small)
        CoinDisplayView(size: .medium)
        CoinDisplayView(size: .large)
    }
    .padding()
}
