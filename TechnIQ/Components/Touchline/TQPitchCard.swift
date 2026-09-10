import SwiftUI

// MARK: - TQPitchCard
//
// The one pitch-green surface per screen. `TQPitchCard` is the generic container (fill, markings,
// radius, padding); `TQHeroCard` is the Home/Train hero with typed slots — eyebrow, trailing meta,
// title, figures, body, action, link — and a `.loading` state whose skeleton slots keep the
// loaded height (9c). Variants: .hero (r14, 20/18/18 padding), .strip (r12, 14/16), .pinned
// (r12, 14/16, horizontal), .card (r12, 16), .fullscreen (no radius).

struct TQPitchCard<Content: View>: View {
    enum Variant { case hero, strip, pinned, card, fullscreen }

    let variant: Variant
    let markings: TQPitchMarkings.Preset
    let content: Content

    init(_ variant: Variant = .hero, markings: TQPitchMarkings.Preset, @ViewBuilder content: () -> Content) {
        self.variant = variant
        self.markings = markings
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .pitchSurface(markings, cornerRadius: cornerRadius)
    }

    private var cornerRadius: CGFloat {
        switch variant {
        case .hero: return DesignSystem.CornerRadius.pitchCard
        case .strip, .pinned, .card: return DesignSystem.CornerRadius.pitchCardCompact
        case .fullscreen: return 0
        }
    }

    private var padding: EdgeInsets {
        switch variant {
        case .hero: return EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18)
        case .strip, .pinned: return EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        case .card: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        case .fullscreen: return EdgeInsets()
        }
    }
}

// MARK: - Hero card with typed slots

struct TQHeroCard: View {
    enum State { case loaded, loading }

    var eyebrow: String
    var trailingMeta: String? = nil
    var title: String
    var figures: [(String, String)] = []
    var bodyText: String? = nil
    var bodyTone: TQBody.Tone = .onPitch
    var actionTitle: String
    var actionIcon: String? = "play.fill"
    var loadingActionTitle: String = "Coach is picking your drill"
    var linkTitle: String? = nil
    var state: State = .loaded
    var markings: TQPitchMarkings.Preset = .hero
    var action: () -> Void
    var linkAction: (() -> Void)? = nil

    init(eyebrow: String,
         trailingMeta: String? = nil,
         title: String,
         figures: [(String, String)] = [],
         body: String? = nil,
         bodyTone: TQBody.Tone = .onPitch,
         actionTitle: String,
         actionIcon: String? = "play.fill",
         loadingActionTitle: String = "Coach is picking your drill",
         linkTitle: String? = nil,
         state: State = .loaded,
         markings: TQPitchMarkings.Preset = .hero,
         action: @escaping () -> Void,
         linkAction: (() -> Void)? = nil) {
        self.eyebrow = eyebrow
        self.trailingMeta = trailingMeta
        self.title = title
        self.figures = figures
        self.bodyText = body
        self.bodyTone = bodyTone
        self.actionTitle = actionTitle
        self.actionIcon = actionIcon
        self.loadingActionTitle = loadingActionTitle
        self.linkTitle = linkTitle
        self.state = state
        self.markings = markings
        self.action = action
        self.linkAction = linkAction
    }

    var body: some View {
        TQPitchCard(.hero, markings: markings) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center) {
                    TQEyebrow(eyebrow)
                    Spacer()
                    if let trailingMeta {
                        TQMeta(trailingMeta, tone: .onPitch)
                    }
                }

                switch state {
                case .loaded:
                    TQDisplayTitle(title, size: .medium)
                    if !figures.isEmpty {
                        TQFigureRow(figures, onPitch: true)
                    }
                    if let bodyText {
                        TQBody(bodyText, tone: bodyTone)
                    }
                    TQButton(actionTitle, icon: actionIcon, action: action)
                    if let linkTitle, let linkAction {
                        HStack(spacing: 4) {
                            Spacer()
                            Text("or")
                                .font(Font.system(size: 13, weight: .semibold))
                                .foregroundColor(DesignSystem.Colors.textOnPitch)
                            TQTextLink(linkTitle, arrow: false, tone: .onPitch, action: linkAction)
                            Spacer()
                        }
                        .padding(.top, -6)
                    }

                case .loading:
                    // Title (two lines of 34), figures line (16), body (two lines of 12), waiting button.
                    VStack(alignment: .leading, spacing: 8) {
                        TQSkeleton(widthFraction: 0.78, height: 34, cornerRadius: 5, tone: .pitch)
                        TQSkeleton(widthFraction: 0.52, height: 34, cornerRadius: 5, tone: .pitch)
                    }
                    TQSkeleton(widthFraction: 0.64, height: 16, cornerRadius: 4, tone: .pitch)
                    VStack(alignment: .leading, spacing: 6) {
                        TQSkeleton(widthFraction: 0.96, height: 12, cornerRadius: 3, tone: .pitchSoft)
                        TQSkeleton(widthFraction: 0.70, height: 12, cornerRadius: 3, tone: .pitchSoft)
                    }
                    TQButton(loadingActionTitle, isLoading: true, action: {})
                        .accessibilityLabel("\(loadingActionTitle)")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

#if DEBUG
#Preview("Hero") {
    ScrollView {
        VStack(spacing: 18) {
            TQHeroCard(
                eyebrow: "Today's session",
                trailingMeta: "WK 3 · DAY 2",
                title: "Two-touch wall passing",
                figures: [("15", "min"), ("120", "reps"), ("L", "foot"), ("2", "lvl")],
                body: "Weak-foot passing rated lowest across your last three sessions. High reps, easy pace, accuracy first.",
                actionTitle: "Start session",
                action: {}
            )
            TQHeroCard(eyebrow: "Today's session", trailingMeta: "WK 3 · DAY 2", title: "", actionTitle: "", state: .loading, action: {})
            TQHeroCard(
                eyebrow: "Your first session",
                title: "Ten minutes, one ball, a wall",
                body: "No plan yet. Start with a quick drill built for your position and the coach will learn from how it goes.",
                actionTitle: "Start quick drill",
                linkTitle: "build a plan first",
                markings: .heroSimple,
                action: {},
                linkAction: {}
            )
            TQPitchCard(.strip, markings: .strip) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        TQEyebrow("From your coach · 3 new", size: 11)
                        TQDisplayTitle("Left-foot passing block", size: .strip)
                        Text("3 drills · 40 min · targets your weakest skill")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(DesignSystem.Colors.textOnPitch)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(DesignSystem.Colors.textOnPitch)
                }
            }
        }
        .padding(20)
    }
    .background(DesignSystem.Colors.surfaceBase)
}
#endif
