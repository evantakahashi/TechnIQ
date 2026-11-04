# Camera drills — judge, insights, trends (plan, 2026-11-03)

Evan's brief: go beyond the counter. (1) **Judge**: enforce rules impartially, end the run the moment one
breaks. (3) **Insights** he can't perceive himself. (4) **Trends** with zero logging effort. Proof for
competition (2) is out of scope for now. Everything is **deterministic**: rules and stats are computed from the
pose + ball track the counter already uses (no video model, no AI review).

## Principles
- A rule call must be confident. A wrong "run over" is worse than a missed one: when the evidence is
  ambiguous (touch hidden from the detector, two body parts equally close), give the player the benefit of
  the doubt and keep going. Ambiguous touches are counted, and the run records how many there were.
- The judge says why: spoken and on screen ("Thigh — run over at 23"), with the frame time kept for the replay.
- Stats come from the same run data, so they need no extra effort from the player.

Decisions (Evan, 2026-11-03): all five rules; presets as separate drills; hidden touches count (benefit of
the doubt); per-run insights free, trends Pro; heights shown as body bands, metres underneath. Surface every
failure: each run says why it ended, and the session says how runs usually end.

## Phase J1 — Run stats (pure, TDD) — done
- [x] `RunRecorder` (Core): takes frames + counter events for one run → per touch: time, part, side, apex
      height after the touch (m above the floor, ball as the ruler), sideways position; flags ambiguous touches
- [x] `RunStats` (pure): touches/min, left/right foot split, part split, apex mean + spread per foot,
      interval consistency, drift (how far the ball wanders sideways, metres), ambiguous share
- [x] Insight lines from stats, deterministic thresholds only: "Right foot sends it 40% higher than your
      left", "Drifting 0.6 m to your left", "62 touches a minute", "Left foot: 30% of touches"
- [x] Harness: `replay` prints stats; check them on Evan's logged sessions

- [x] Hidden contacts placed where the fall and the rise meet (foot touches were judged thigh / chest when the
      ball vanished below the knees): Evan's session went from 13 → 31 foot touches

## Phase J2 — Judge (rules engine, TDD) — engine done
- [x] `JuggleCounter.Config.partRule` (.feetOnly) + `heightLimit` (.waist / .knee) beside `footRule` (weak foot,
      alternating); no hands always on (raised hand only)
- [x] Each rule checked at the touch (part / side) or every frame (height); violation → run ends with a
      `RunEndReason` (thighTouch / chestTouch / headTouch / tooHigh / wrongFoot) + spoken call ("Thigh. 7");
      only seen touches with a `callMargin` are judged; height needs 2 sightings in a row of a normal-sized ball
- [x] Drill presets: Juggling, Weak foot, Alternating, Feet only, Below the waist. [ ] "Custom" (toggle rules),
      below-the-knee preset
- [x] Session shows why each run ended (red for a rule call), the run's insights, and how runs usually end
- [x] Tests: every rule's violation and its ambiguous near-miss, on synthetic scenes; replay Evan's logs to
      check no false calls

## Phase J3 — Results + storage — done
- [x] Additive Core Data on `CameraRun`: `statsJSON`, `endReason` (the drill already names the rule set) —
      model + `+CoreDataProperties`; Firestore sync fields
- [x] Result panel / back-to-back run banner: count, why it ended, one or two insight lines
- [x] Personal bests per rule set (presets are drills, so bests are per drill)

## Phase J4 — Trends — done (Run history, Pro)
- [x] `Core/CameraTrends` (pure): best per day, headline ("Juggling: 14 → 37 in 2 weeks"), how runs end,
      left-foot share, tempo; `CameraTrendsSection` (Swift Charts) on Run history; `-TQCameraHistory` (DEBUG)
- [ ] Home / Train surfaces the headline when there's a meaningful change

## Phase J5 — Ball effects (Evan, 2026-11-03)
- [ ] Live effects on the tracked ball (trail, fire, glow) + in the share replay, Juggle Dude-style

## Unresolved
- Launch rule set: feet only, weak foot, alternating, below waist, below knee — all, or fewer?
- Presets as separate drills, or rule chips on one Juggling drill?
- Ambiguous touches: count them (benefit of the doubt)?
- Insights + trends: free, or Pro (`ProGates.cameraInsights` exists)?
- Height: metres (assumes a size-5 ball) or body bands (knee / waist / head)?
