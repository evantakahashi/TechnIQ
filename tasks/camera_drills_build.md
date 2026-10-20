# Camera Drills — build plan, phases 3–7 (2026-10-20)

Spec: `tasks/camera_drills.md` (main checkout). Spike: `9fe751d` on `worktree-camera-drills-spike`.
Evan: build ahead of the on-device gate (filming + iPhone 12 fps deferred). Risk accepted: if the gate fails,
only `CameraDrills/Core` + `Vision` change; UI, data, share, challenges carry over.
Phase 2 (data + fine-tuned ball model) still waits on footage — YOLO11n stays as the placeholder detector.

Rules: TDD for every pure piece (Mac harness `swift test` for counters, TechnIQTests for app logic);
build after each step; one commit per phase; TQ components only; additive Core Data only (model + `+CoreDataProperties`).

## Phase 3 — Camera mode (production, not DEBUG)
- [x] `CameraDrill` enum (juggling, weakFoot, alternating, toeTaps, wallPasses) + mode (streak / 30 s) + rules copy
- [x] `DrillCounter` protocol; JuggleCounter adopts it; foot touches carry side (left/right) for variants
- [x] Pure `HandsFreeFlow` state machine: setup (body in outline) → spoken 3-2-1 → active → result;
      step back into outline = go again; both arms up = end session (TDD on synthetic poses)
- [x] `CameraDrillSupport.isSupported` — A14 / iPhone 12+ by hw.machine; refusal screen below
- [x] Production `CameraSessionController` (from spike pipeline): capture, analyser, counter, flow, voice
- [x] Core Data `CameraRun` (id, drill, count, duration, createdAt, updatedAt, isPersonalBest, challengeId, clipPath → player);
      PB logic pure + tested; Firestore sync `users/{uid}/cameraRuns` (upload + restore, existing pattern)
- [x] Rewards: `CameraRewardLedger` (pure, tested) — per run 5 XP / 2 coins, PB +25 XP / +10, challenge beaten +100 / +50,
      cap 10 rewarded runs/day; new `CoinEarningEvent` cases
- [x] UI: Train tab "Camera" strip (beside coach strip) → `CameraDrillsView` (drills + PBs) → full-screen `CameraDrillSessionView`
      (outline, big count, voice, result panel: count / PB / go again / share)
- [x] Pro: `ProGates.Feature.cameraInsights` (run history, trends, slow-mo replay); drills + PBs + sharing free
- [ ] Spike screen stays DEBUG-only; Files-app sharing keys removed from Info.plist before merge
- [x] Demo seed: camera runs; `-TQRoute camera` (Train) for UI tests + tour screenshot

## Phase 4 — Share
- [ ] Session recorder: whole session to a temp file; runs keep start/end + touch timestamps
- [ ] `ShareClipPlan` (pure, tested): best run, ≤ 20 s with speed ramp, count-overlay keyframes
- [ ] `ShareClipRenderer`: AVMutableComposition + Core Animation overlay (live count, NEW PB / Challenge beaten, TechnIQ mark + App Store tag),
      9:16 1080×1920, beeps track; mic audio if granted
- [ ] Result card via ImageRenderer; share sheet for both

## Phase 5 — More drills
- [ ] Juggling variants: weak foot (from `Player.dominantFoot`), alternating — rule layer on JuggleCounter
- [ ] `ToeTapCounter`: alternating sole contacts on a ball at rest, 30 s
- [ ] `WallPassCounter`: ball leaves → returns to player = 1, 30 s
- [ ] Synthetic tests for each; harness `--drill` flag; accuracy unknown until footage (flag in UI as beta)

## Phase 6 — Creator challenges
- [ ] `challenges/{id}` (client read-only) + `challengeEntries/{id}` (owner create, status pending/approved/rejected — admin only)
- [ ] Link FirebaseStorage; `storage.rules`: `challengeClips/{uid}/*` owner write, video ≤ 50 MB, no client read; firebase.json `storage`
- [ ] `ChallengeEligibility` (pure, tested): active window, drill match, age ≥ 13 (unknown age blocks upload), one entry per run
- [ ] Home challenge strip (between resume strip and hero) → challenge detail (target, video link, your best, enter)
- [ ] Entry: upload clip + run, status shown; prize on approval = badge + prize-only avatar item (excluded from shop)
- [ ] USER ACTION: deploy firestore + storage rules, bucket 30-day lifecycle rule, write first challenge doc

## Phase 7 — Plan integration
- [ ] `CameraDrillMatcher` (pure, tested): Exercise → CameraDrill (closed vocabulary on name/skill)
- [ ] ActiveTrainingView: "Track with camera" replaces "+ 10 reps" for matched drills → camera session embedded → count becomes the drill's reps
- [ ] CameraRun links to the session exercise

## Verification per phase
`swift test` (harness) · TechnIQTests · build · swiftlint clean on new files · UI test / tour screenshot of new screens.

## Unresolved
1. Share clip audio: record mic (extra permission) or beeps only?
2. Unknown age (0) → block challenge uploads? (plan: yes)
3. Prize item: which avatar item / art? (plan: placeholder "Captain's armband")
4. XP/coin amounts + 10/day cap OK?
5. Camera runs inside plan sessions earn camera rewards on top of session XP? (plan: yes, same cap)
