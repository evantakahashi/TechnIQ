import SwiftUI
import CoreData

// MARK: - Assessment (full screen)
//
// The 10-minute benchmark test: first session for a new player and every plan's retest. Intro →
// 2-min warm-up (skippable) → juggling, best of 3 (camera or typed) → wall passes 30 s → toe taps
// 30 s → results with "New best" against earlier numbers. The steps live in `AssessmentFlow`;
// saving (3 benchmarks + one session, XP, plan completion) in `BenchmarkService.finishAssessment`.

struct AssessmentView: View {
    @Environment(\.dismiss) private var dismiss

    let player: Player
    /// The plan's assessment session this fulfils (retest week), if any.
    var planSession: PlanSession? = nil
    var onFinished: (() -> Void)? = nil

    @State private var flow = AssessmentFlow()
    @State private var startedAt = Date()
    @State private var now = Date()
    @State private var clockStartedAt: Date?
    @State private var jugglingStartedAt: Date?
    @State private var countText = ""
    @State private var previousBests: [BenchmarkType: Int] = [:]
    @State private var showingCamera = false
    @State private var showingQuitConfirm = false
    @State private var outcome: BenchmarkService.AssessmentOutcome?
    @State private var saveFailed = false

    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var cameraAvailable: Bool {
        CameraDrill.juggling.isAvailable && CameraDrillSupport.isCurrentDeviceSupported
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sectionLarge) {
                navBar
                content
            }
            .padding(.horizontal, DesignSystem.Spacing.screenPadding)
            .padding(.bottom, DesignSystem.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(DesignSystem.Colors.surfaceBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear(perform: loadPreviousBests)
        .onReceive(ticker) { tick($0) }
        .onChange(of: flow.step) { _, _ in
            countText = ""
            TQKeyboard.dismiss()
        }
        .confirmationDialog("Stop the assessment?", isPresented: $showingQuitConfirm, titleVisibility: .visible) {
            Button("Stop", role: .destructive) { dismiss() }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Nothing is saved until the last test.")
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraDrillSessionView(drill: .juggling, player: player, recordsBenchmark: false) { counts in
                for count in counts where count > 0 {
                    flow.addJugglingAttempt(count, cameraVerified: true)
                }
            }
        }
    }

    // MARK: - Chrome

    private var navBar: some View {
        TQNavBar("Assessment") {
            if flow.isFinished {
                Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
            } else {
                TQIconAction("xmark", accessibilityLabel: "Stop assessment") {
                    if flow.step == .intro { dismiss() } else { showingQuitConfirm = true }
                }
                .accessibilityIdentifier("assessment.close")
            }
        } trailing: {
            Color.clear.frame(width: DesignSystem.Spacing.hitTarget, height: DesignSystem.Spacing.hitTarget)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if flow.stepNumber > 0 && !flow.isFinished {
            TQStepper(current: flow.stepNumber, total: AssessmentFlow.stepCount)
        }
        switch flow.step {
        case .intro: intro
        case .warmup: warmup
        case .juggling: juggling
        case .wallPasses, .toeTaps: timedTest
        case .results: results
        }
    }

    // MARK: - Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(planSession == nil ? "10-minute assessment" : "Retest · 10 minutes", size: 12)
                TQDisplayTitle("Three numbers\nto beat", size: .medium)
                TQBody("Juggling, wall passes and toe taps. Every plan ends by testing them again, so you can see what moved.")
            }
            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("You need")
                TQRowList {
                    TQRow("A ball", leading: .tile(TQTile(symbol: "soccerball")), accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical)
                    TQRow("A wall", subtitle: "Flat, to pass against from 2–3 m", leading: .tile(TQTile(symbol: "square.grid.3x3")),
                          accessory: .none, verticalPadding: DesignSystem.Spacing.rowVertical)
                    TQRow("2 × 2 m of space", leading: .tile(TQTile(symbol: "square.dashed")), accessory: .none,
                          verticalPadding: DesignSystem.Spacing.rowVertical)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                TQGroupHeader("How it goes")
                TQIndexRow(index: "01", text: "Warm-up", meta: "2 min")
                TQIndexRow(index: "02", text: "Juggling, best of 3", meta: "in a row")
                TQIndexRow(index: "03", text: "Wall passes", meta: "30 s")
                TQIndexRow(index: "04", text: "Toe taps", meta: "30 s")
            }
            TQButton("Start warm-up", icon: "play.fill") {
                flow.begin()
                startedAt = Date()
                clockStartedAt = Date()
            }
            .accessibilityIdentifier("assessment.primary")
        }
    }

    // MARK: - Warm-up

    private var warmup: some View {
        let ran = elapsed(since: clockStartedAt)
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            TQPitchCard(.hero, markings: .heroSimple) {
                VStack(alignment: .leading, spacing: 14) {
                    TQEyebrow("Warm-up", tone: .onPitch, size: 12)
                    TQClock(seconds: AssessmentFlow.warmupSeconds - ran, subtitle: "of 2:00")
                        .frame(maxWidth: .infinity)
                    TQBody("Easy touches with both feet: sole rolls, toe taps, a few passes off the wall.", tone: .onPitch)
                }
            }
            TQButton("Skip warm-up", style: .raised) { endWarmup() }
                .accessibilityIdentifier("assessment.skipWarmup")
        }
    }

    // MARK: - Juggling

    private var juggling: some View {
        let attempts = flow.jugglingAttempts
        let eyebrow = flow.remainingJugglingAttempts > 0
            ? "Juggling · attempt \(attempts.count + 1) of \(AssessmentFlow.maxJugglingAttempts)"
            : "Juggling · done"
        return VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(eyebrow, size: 12)
                TQDisplayTitle("Keep it up", size: .medium)
                TQBody(CameraDrill.juggling.rules + " Best of three counts.")
            }

            if !attempts.isEmpty {
                TQRowList {
                    ForEach(Array(attempts.enumerated()), id: \.offset) { index, attempt in
                        TQRow("Attempt \(index + 1)",
                              meta: .init("\(attempt.value)"),
                              badge: attempt.cameraVerified ? TQBadge(.text("Camera")) : nil,
                              accessory: .none,
                              verticalPadding: DesignSystem.Spacing.rowVertical)
                    }
                }
            }

            if flow.remainingJugglingAttempts > 0 {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    if cameraAvailable {
                        TQButton("Count with camera", icon: "camera.viewfinder", style: .raised) { showingCamera = true }
                            .accessibilityIdentifier("assessment.camera")
                    }
                    countField("Juggles in a row")
                    TQButton("Add attempt", style: .raised) { addTypedAttempt() }
                        .disabled(typedCount == nil)
                        .accessibilityIdentifier("assessment.addAttempt")
                }
            }

            TQButton(attempts.isEmpty ? "Add an attempt first" : "Next: wall passes") { finishJuggling() }
                .disabled(attempts.isEmpty)
                .accessibilityIdentifier("assessment.primary")
        }
        .onAppear { if jugglingStartedAt == nil { jugglingStartedAt = Date() } }
    }

    // MARK: - Timed tests

    @ViewBuilder
    private var timedTest: some View {
        if let type = flow.currentType, let window = type.windowSeconds {
            let isLast = flow.step == .toeTaps
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                VStack(alignment: .leading, spacing: 8) {
                    TQEyebrow("\(type.title) · \(window) s", size: 12)
                    TQDisplayTitle(type == .wallPasses30 ? "Pass, receive,\nrepeat" : "Quick feet", size: .medium)
                    TQBody(type.cameraDrill.rules + " Count as you go.")
                }

                switch flow.timedPhase {
                case .ready, .running:
                    let running = flow.timedPhase == .running
                    TQPitchCard(.hero, markings: .heroSimple) {
                        VStack(spacing: 14) {
                            TQClock(seconds: running ? window - elapsed(since: clockStartedAt) : window,
                                    subtitle: running ? "go" : "ready", isRunning: running)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    if running {
                        TQButton("Stop early", style: .raised) { endClock() }
                            .accessibilityIdentifier("assessment.stopClock")
                    } else {
                        TQButton("Start \(window) s", icon: "play.fill") {
                            flow.startClock()
                            clockStartedAt = Date()
                            HapticManager.shared.mediumTap()
                        }
                        .accessibilityIdentifier("assessment.primary")
                    }
                case .entry:
                    countField("\(type.title) in \(window) s")
                    TQButton(isLast ? "See results" : "Next: toe taps") { enterTimedCount() }
                        .disabled(typedCount == nil)
                        .accessibilityIdentifier("assessment.primary")
                    TQTextLink("Run the clock again", arrow: false) {
                        flow.redoClock()
                        countText = ""
                    }
                }
            }
        }
    }

    // MARK: - Results

    private var results: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
            VStack(alignment: .leading, spacing: 8) {
                TQEyebrow(planSession == nil ? "Assessment done" : "Retest done", size: 12)
                TQDisplayTitle("Your numbers", size: .medium)
                TQBody(previousBests.isEmpty
                       ? "These are your starting point. Your plan ends by testing them again."
                       : "Against your best before today.")
            }
            TQRowList {
                ForEach(BenchmarkType.allCases) { type in
                    if let measurement = flow.results[type] {
                        TQRow(type.title,
                              subtitle: resultSubtitle(type, measurement),
                              meta: .init("\(measurement.value)"),
                              badge: resultBadge(type, measurement),
                              accessory: .none,
                              verticalPadding: DesignSystem.Spacing.rowVertical)
                    }
                }
            }
            if saveFailed {
                TQBanner(.warning, lead: "Couldn't save.", message: "Your numbers weren't stored. Try again.", actionTitle: "Retry") { save() }
            } else if let outcome {
                TQMeta("+\(outcome.xp.total) XP", tone: .muted, size: 14)
            }
            TQButton("Done") {
                onFinished?()
                dismiss()
            }
            .accessibilityIdentifier("assessment.done")
        }
    }

    private func resultSubtitle(_ type: BenchmarkType, _ measurement: AssessmentFlow.Measurement) -> String {
        var parts = [type.unit]
        if let previous = previousBests[type] { parts.append("best before \(previous)") }
        return parts.joined(separator: " · ")
    }

    private func resultBadge(_ type: BenchmarkType, _ measurement: AssessmentFlow.Measurement) -> TQBadge? {
        if BenchmarkSummary.isNewBest(value: measurement.value, previousBest: previousBests[type]) {
            return TQBadge(.status("New best"))
        }
        return measurement.cameraVerified ? TQBadge(.text("Camera")) : nil
    }

    // MARK: - Count entry

    private func countField(_ label: String) -> some View {
        TQFormField(label, text: $countText, placeholder: "0", keyboard: .numberPad)
            .accessibilityIdentifier("assessment.count")
    }

    /// The typed count, when it is a whole number 0…999.
    private var typedCount: Int? {
        guard let value = Int(countText.trimmingCharacters(in: .whitespaces)), (0...999).contains(value) else { return nil }
        return value
    }

    // MARK: - Actions

    private func tick(_ date: Date) {
        now = date
        switch flow.step {
        case .warmup where elapsed(since: clockStartedAt) >= AssessmentFlow.warmupSeconds:
            HapticManager.shared.success()
            endWarmup()
        case .wallPasses, .toeTaps:
            if flow.timedPhase == .running, let window = flow.currentType?.windowSeconds,
               elapsed(since: clockStartedAt) >= window {
                HapticManager.shared.success()
                endClock()
            }
        default:
            break
        }
    }

    private func elapsed(since start: Date?) -> Int {
        guard let start else { return 0 }
        return max(0, Int(now.timeIntervalSince(start)))
    }

    private func endWarmup() {
        flow.finishWarmup(ranSeconds: Int(Date().timeIntervalSince(clockStartedAt ?? Date())))
        clockStartedAt = nil
    }

    private func addTypedAttempt() {
        guard let value = typedCount else { return }
        flow.addJugglingAttempt(value, cameraVerified: false)
        countText = ""
        TQKeyboard.dismiss()
    }

    private func finishJuggling() {
        flow.finishJuggling(elapsedSeconds: Int(Date().timeIntervalSince(jugglingStartedAt ?? Date())))
    }

    private func endClock() {
        flow.clockEnded(ranSeconds: Int(Date().timeIntervalSince(clockStartedAt ?? Date())))
        clockStartedAt = nil
    }

    private func enterTimedCount() {
        guard let value = typedCount else { return }
        flow.enterCount(value)
        TQKeyboard.dismiss()
        if flow.isFinished { save() }
    }

    private func save() {
        guard outcome == nil else { return }
        outcome = BenchmarkService.shared.finishAssessment(flow, player: player, planSession: planSession, startedAt: startedAt)
        saveFailed = outcome == nil
        if outcome != nil { HapticManager.shared.success() }
    }

    private func loadPreviousBests() {
        guard previousBests.isEmpty, outcome == nil else { return }
        previousBests = BenchmarkService.shared.summaries(for: player).mapValues(\.best.value)
    }
}
