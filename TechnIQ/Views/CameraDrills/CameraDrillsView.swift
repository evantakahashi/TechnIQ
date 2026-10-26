import SwiftUI
import CoreData

// MARK: - Camera drills (Train → Camera drills)
//
// The phone counts the touches. Drills with their personal bests; drills whose counter hasn't shipped
// yet show as "soon". Run history is Pro (ProGates.Feature.cameraInsights); bests stay free.

struct CameraDrillsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let player: Player

    @FetchRequest private var runs: FetchedResults<CameraRun>
    @State private var activeDrill: CameraDrill?
    @State private var showingHistory = false
    @State private var paywall: PaywallFeature?
    @State private var autoStarted = false

    init(player: Player) {
        self.player = player
        _runs = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: NSPredicate(format: "player == %@", player)
        )
    }

    private var isSupported: Bool { CameraDrillSupport.isCurrentDeviceSupported }

    private func best(_ drill: CameraDrill) -> Int? {
        runs.filter { $0.drill == drill.rawValue }.map { Int($0.count) }.max()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Train") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }

                VStack(alignment: .leading, spacing: 6) {
                    TQEyebrow("Camera drills", size: 12)
                    TQDisplayTitle("Your phone\ncounts the touches", size: .small)
                    TQBody("Prop it up 3–4 m away, back camera facing you, whole body in frame. Stand in the outline and go.",
                           tone: .base, size: 14)
                }

                if !isSupported {
                    TQBanner(.warning, lead: "Needs an iPhone 12 or newer.",
                             message: "Live counting is too heavy for this phone.", layout: .block)
                }

                VStack(alignment: .leading, spacing: 0) {
                    TQGroupHeader("Drills")
                    TQRowList {
                        ForEach(CameraDrill.allCases) { drill in
                            drillRow(drill)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    TQGroupHeader("Your runs")
                    TQRowList {
                        TQRow("Run history",
                              subtitle: runs.isEmpty ? "Every run you finish lands here" : "\(runs.count) run\(runs.count == 1 ? "" : "s")",
                              badge: subscriptionManager.isPro ? nil : TQBadge(.text("Pro"))) {
                            if subscriptionManager.isPro { showingHistory = true } else { paywall = .cameraInsights }
                        }
                        .accessibilityIdentifier("camera.history")
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .navigationBarHidden(true)
        .fullScreenCover(item: $activeDrill) { drill in
            CameraDrillSessionView(drill: drill, player: player)
        }
        .navigationDestination(isPresented: $showingHistory) {
            CameraRunHistoryView(player: player)
        }
        .sheet(item: $paywall) { feature in
            PaywallView(feature: feature)
        }
        #if DEBUG
        // `-TQCameraFile clip.mov` plays a clip in place of the camera; go straight into Juggling.
        .onAppear {
            guard !autoStarted, VideoFileSource.fromLaunchArguments != nil else { return }
            autoStarted = true
            activeDrill = .juggling
        }
        #endif
    }

    @ViewBuilder
    private func drillRow(_ drill: CameraDrill) -> some View {
        if drill.isAvailable {
            TQRow(drill.title,
                  subtitle: drill.rules,
                  leading: .tile(TQTile(symbol: "camera.viewfinder")),
                  meta: best(drill).map { .init("Best \($0)") },
                  verticalPadding: DesignSystem.Spacing.rowVertical) {
                activeDrill = drill
            }
            .disabled(!isSupported)
            .accessibilityIdentifier("camera.drill.\(drill.rawValue)")
        } else {
            TQRow(drill.title,
                  subtitle: drill.rules,
                  leading: .tile(TQTile(symbol: "camera.viewfinder")),
                  accessory: .none,
                  note: "soon",
                  verticalPadding: DesignSystem.Spacing.rowVertical)
                .disabled(true)
        }
    }
}

// MARK: - Run history (Pro)

struct CameraRunHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @FetchRequest private var runs: FetchedResults<CameraRun>

    init(player: Player) {
        _runs = FetchRequest(
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)],
            predicate: NSPredicate(format: "player == %@", player)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                TQNavBar("Camera drills") {
                    TQBackButton { dismiss() }
                } trailing: {
                    Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
                }
                TQDisplayTitle("Run history", size: .small)
                TQRowList {
                    if runs.isEmpty {
                        TQRow("No runs yet", accessory: .none, note: "finish a camera drill").disabled(true)
                    }
                    ForEach(runs) { run in
                        TQRow(CameraDrill(rawValue: run.drill ?? "")?.title ?? "Drill",
                              subtitle: (run.createdAt ?? Date()).formatted(date: .abbreviated, time: .shortened),
                              meta: .init("\(run.count)", accent: run.isPersonalBest ? "PB" : nil),
                              accessory: .none,
                              verticalPadding: DesignSystem.Spacing.rowVertical)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
