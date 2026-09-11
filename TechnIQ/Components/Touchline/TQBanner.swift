import SwiftUI

// MARK: - TQBanner
//
// Non-blocking status strip that sits above the hero: raised fill, 3 pt left bar in the kind's
// colour, r6. `.inline` = one line with a bold lead and an optional action ("Retry");
// `.block` = title + body (AI drill failed). Never a modal unless the action is destructive.

struct TQBanner: View {
    enum Kind { case warning, error, info }
    enum Layout { case inline, block }

    let kind: Kind
    var lead: String? = nil         // bold lead-in: "You're offline."
    let message: String
    var layout: Layout = .inline
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    init(_ kind: Kind, lead: String? = nil, message: String, layout: Layout = .inline, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.kind = kind
        self.lead = lead
        self.message = message
        self.layout = layout
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            switch layout {
            case .inline:
                (Text(lead.map { $0 + " " } ?? "").fontWeight(.bold).foregroundColor(DesignSystem.Colors.chalkWhite)
                 + Text(message).foregroundColor(DesignSystem.Colors.bannerText))
                    .font(DesignSystem.Typography.bodySmall)
                    .lineSpacing(13 * 0.4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .block:
                VStack(alignment: .leading, spacing: 4) {
                    if let lead {
                        Text(lead)
                            .font(Font.system(size: 14, weight: .bold))
                            .foregroundColor(DesignSystem.Colors.chalkWhite)
                    }
                    Text(message)
                        .font(DesignSystem.Typography.bodySmall)
                        .lineSpacing(13 * 0.45)
                        .foregroundColor(DesignSystem.Colors.mutedIvory)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let actionTitle, let action {
                Button {
                    HapticManager.shared.selectionChanged()
                    action()
                } label: {
                    Text(actionTitle)
                        .font(Font.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.grass)
                        .frame(minHeight: DesignSystem.Spacing.hitTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, layout == .inline ? 10 : 12)
        .padding(.leading, layout == .inline ? 12 : 14)
        .padding(.trailing, layout == .inline ? 12 : 14)
        .background(
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.banner, style: .continuous)
                    .fill(DesignSystem.Colors.surfaceRaised)
                Rectangle()
                    .fill(barColor)
                    .frame(width: 3)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.banner, style: .continuous))
        )
        .accessibilityElement(children: .combine)
    }

    private var barColor: Color {
        switch kind {
        case .warning: return DesignSystem.Colors.cone
        case .error: return DesignSystem.Colors.error
        case .info: return DesignSystem.Colors.grass
        }
    }
}

#if DEBUG
#Preview("Banner") {
    VStack(spacing: 12) {
        TQBanner(
            .warning,
            lead: "You're offline.",
            message: "Today's drill comes from your plan; the coach's note will update when you're back.",
            actionTitle: "Retry",
            action: {}
        )
        TQBanner(.error, lead: "Couldn't save.", message: "Your session is kept on this device.", actionTitle: "Retry", action: {})
        TQBanner(.info, message: "Coach didn't answer in time. Showing today's plan drill.")
        TQBanner(
            .error,
            lead: "Couldn't generate this one",
            message: "The drill came back with a layout that didn't pass our checks. Nothing was saved and your quota wasn't used.",
            layout: .block
        )
    }
    .padding(20)
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
