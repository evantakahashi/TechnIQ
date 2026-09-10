import SwiftUI

#if DEBUG
// MARK: - TQGallery
//
// Debug-only component inventory mirroring canvas #9a. Launch the app with the `-TQGallery`
// argument (Scheme › Run › Arguments) to render it instead of ContentView, or open it in a preview.

struct TQGalleryView: View {
    @State private var segment = 1
    @State private var effort = 2
    @State private var chip = 0
    @State private var search = ""

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-TQGallery")
    }

    /// `-TQGalleryPage n` shows only section n (0-based) so a simulator screenshot needs no scrolling.
    static var requestedPage: Int? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-TQGalleryPage"), index + 1 < args.count else { return nil }
        return Int(args[index + 1])
    }

    private var page: Int? { Self.requestedPage }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                section("TQPitchCard · .hero .strip .pinned", index: 0) {
                    TQHeroCard(
                        eyebrow: "Today's session",
                        trailingMeta: "WK 3 · DAY 2",
                        title: "Two-touch wall passing",
                        figures: [("15", "min"), ("120", "reps"), ("L", "foot"), ("2", "lvl")],
                        body: "Weak-foot passing rated lowest across your last three sessions. High reps, easy pace, accuracy first.",
                        actionTitle: "Start session",
                        action: {}
                    )
                    TQHeroCard(eyebrow: "Today's session", trailingMeta: "WK 3 · DAY 2", title: "", actionTitle: "", state: .loading, markings: .heroSimple, action: {})
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
                            TQChevron(color: DesignSystem.Colors.textOnPitch)
                        }
                    }
                    TQPitchCard(.pinned, markings: .pinned) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                TQEyebrow("Today · WK 3 Day 2", size: 11)
                                TQDisplayTitle("Two-touch wall passing", size: .strip)
                            }
                            TQButton("Start", icon: "play.fill", size: .compact, fullWidth: false) {}
                        }
                    }
                }

                section("TQButton · primary inverse raised ghost destructive · disabled loading", index: 1) {
                    HStack(spacing: 8) {
                        TQButton("Primary", size: .compact) {}
                        TQButton("Inverse", style: .inverse, size: .compact) {}
                    }
                    HStack(spacing: 8) {
                        TQButton("Raised", style: .raised, size: .compact) {}
                        TQButton("Ghost / text", style: .ghost, size: .compact) {}
                    }
                    HStack(spacing: 8) {
                        TQButton("Disabled", size: .compact) {}.disabled(true)
                        TQButton("Loading", size: .compact, isLoading: true) {}
                    }
                    HStack(spacing: 8) {
                        TQButton("Delete plan", style: .destructive, size: .compact) {}
                        TQButton("+ New drill", size: .compact, fullWidth: false) {}
                    }
                    TQButton("Continue with Apple", icon: "apple.logo", style: .inverse, size: .auth, face: .text) {}
                }

                section("TQRow · leading none/tile/index · trailing meta/badge/chevron/heart · pressed · disabled", index: 2) {
                    TQRowList {
                        TQRow("Plain row", meta: .init("META"), action: {})
                        TQRow("Tile row + subtitle", subtitle: "Technical · Lvl 2 · 20 min", leading: .tile(TQTile("TEC")), accessory: .heart(isOn: true, action: {}), verticalPadding: 12, action: {})
                        TQRow("Index row (steps, recap)", leading: .index("01"), badge: TQBadge(.count(3)), accessory: .none, verticalPadding: 12, action: {})
                        TQRow("Disabled", note: "after your first session").disabled(true)
                        TQRow("Wall pass & spin", subtitle: "Sofia R. · Lvl 2 · 12 min", leading: .tile(TQTile("AI", style: .ai)), accessory: .saves(842), verticalPadding: 12, action: {})
                    }
                }

                section("TQStatRail · TQWeekStrip · TQScheduleGrid", index: 3) {
                    TQStatRail(items: [.init("31", unit: "%", label: "complete"), .init("3", unit: "/8", label: "week"), .init("11", label: "done", accent: true)])
                    TQWeekStrip(cells: [.init(state: .done), .init(state: .planned), .init(state: .today), .rest, .init(state: .planned, sessions: 2), .init(state: .missed), .init(state: .locked)], todayIndex: 2, dayLetters: ["done", "plan", "today", "rest", "2", "miss", "lock"])
                    TQScheduleGrid(rows: [
                        .init(label: "WK 1", cells: [.init(state: .done), .rest, .init(state: .done), .init(state: .done), .rest, .init(state: .done, sessions: 2), .rest]),
                        .init(label: "WK 3", cells: [.init(state: .done), .rest, .init(state: .planned), .init(state: .planned), .rest, .init(state: .today, sessions: 2), .rest], isCurrent: true),
                        .init(label: "WK 4", cells: [.init(state: .planned), .init(state: .planned), .rest, .init(state: .planned), .rest, .init(state: .planned), .rest])
                    ])
                }

                section("TQSegment · TQChip · TQBadge", index: 4) {
                    TQSegment(options: ["Feed", "Drills", "Leaderboard"], selectedIndex: $segment)
                    TQSegment(options: ["Easy", "OK", "Good", "Hard"], selectedIndex: $effort, style: .detached)
                    TQChipRow {
                        ForEach(Array(["All", "Saved", "Technical", "Physical", "Tactical", "Video"].enumerated()), id: \.offset) { index, title in
                            TQChip(title, isSelected: chip == index) { chip = index }
                        }
                    }
                    HStack(spacing: 6) {
                        TQBadge(.level(.beginner)); TQBadge(.level(.intermediate)); TQBadge(.level(.advanced)); TQBadge(.level(.elite)); TQBadge(.status("Active")); TQBadge(.count(3))
                    }
                }

                section("TQTile · TQEyebrow · TQSearchField", index: 5) {
                    HStack(spacing: 6) {
                        TQTile("TEC"); TQTile("PHY"); TQTile("TAC"); TQTile("AI", style: .ai); TQTile("VID"); TQTile(number: "8", unit: "W", accent: true); TQTile(symbol: "plus")
                    }
                    TQEyebrow("Eyebrow · grass · 11–12 bold")
                    TQSearchField("Placeholder", text: $search)
                    TQSearchField("Search drills", text: .constant("")).disabled(true)
                }

                section("TQBanner · TQSkeleton", index: 6) {
                    TQBanner(.warning, lead: "Offline.", message: "Showing your last synced plan.", actionTitle: "Retry", action: {})
                    TQBanner(.error, lead: "Couldn't save.", message: "Your session is kept on this device.", actionTitle: "Retry", action: {})
                    TQBanner(.info, message: "Coach didn't answer in time. Showing today's plan drill.")
                    VStack(alignment: .leading, spacing: 6) {
                        TQSkeleton(widthFraction: 0.4, height: 10)
                        TQSkeleton(widthFraction: 0.8, height: 18, cornerRadius: 4)
                        TQSkeleton(widthFraction: 0.6, height: 10)
                    }
                }

                section("TQStepper · TQLevelBar · TQClock · TQStepRow · TQOptionRow", index: 7) {
                    TQStepper(current: 1, total: 4)
                    TQLevelBar(previous: 0.62, current: 0.87, title: "Level 12", detail: "630 / 720 · ", detailAccent: "90 to lvl 13")
                    TQClock(seconds: 7 * 60 + 28, subtitle: "of 15:00 · set 2 of 4")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .pitchSurface(.centre, cornerRadius: DesignSystem.CornerRadius.pitchCardCompact)
                    VStack(spacing: 0) {
                        TQStepRow(text: "Picked the archetype · wall passing", state: .done)
                        TQStepRow(text: "Laying out cones and the wall", state: .running)
                        TQStepRow(text: "Checking geometry", state: .pending)
                    }
                    TQOptionRow(number: "01", title: "Improve Skills", subtitle: "Technique-heavy: touch, passing, finishing", isSelected: true, action: {})
                    TQOptionRow(number: "02", title: "Build Fitness", subtitle: "More conditioning and speed work", isSelected: false, action: {})
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.vertical, 40)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, index: Int, @ViewBuilder content: () -> Content) -> some View {
        if page == nil || page == index {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(DesignSystem.Colors.chalkWhite)
                content()
            }
        }
    }
}

#Preview("Gallery") {
    TQGalleryView()
}
#endif
