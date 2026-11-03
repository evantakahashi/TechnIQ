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

## Phase J1 — Run stats (pure, TDD)
- [ ] `RunRecorder` (Core): takes frames + counter events for one run → per touch: time, part, side, apex
      height after the touch (m above the floor, ball as the ruler), sideways position; flags ambiguous touches
- [ ] `RunStats` (pure): touches/min, left/right foot split, part split, apex mean + spread per foot,
      interval consistency, drift (how far the ball wanders sideways, metres), ambiguous share
- [ ] Insight lines from stats, deterministic thresholds only: "Right foot sends it 40% higher than your
      left", "Drifting 0.6 m to your left", "62 touches a minute", "Left foot: 30% of touches"
- [ ] Harness: `replay` prints stats; check them on Evan's logged sessions

## Phase J2 — Judge (rules engine, TDD)
- [ ] `JuggleRule` set on `JuggleCounter.Config` (replaces `FootRule`): feet only (no thighs / chest /
      head), weak foot only, alternating feet, below the waist (ball never above hip line), below the knee,
      no hands (always on)
- [ ] Each rule checked at the touch (part / side) or every frame (height); violation → run ends with a
      `RunEndReason.rule(…)` + spoken reason; confidence margins so ambiguous evidence never ends a run
- [ ] Drill presets from rule sets: Juggling (no hands), Weak foot, Alternating, Feet only, Below the waist;
      plus "Custom" (toggle rules) — existing weak-foot / alternating drills migrate to presets
- [ ] Tests: every rule's violation and its ambiguous near-miss, on synthetic scenes; replay Evan's logs to
      check no false calls

## Phase J3 — Results + storage
- [ ] Additive Core Data on `CameraRun`: `rules` (preset / rule-set key), `statsJSON`, `endReason` — model +
      `+CoreDataProperties`; Firestore sync fields
- [ ] Result panel / back-to-back run banner: count, why it ended, one or two insight lines
- [ ] Personal bests per rule set (a "below the waist" best is its own record)

## Phase J4 — Trends
- [ ] Run history → per-drill trend screen (Swift Charts, TQ styling): best per day, weak-foot best,
      left/right split, touches/min over time; headline line "Weak foot: 8 → 23 in 3 weeks"
- [ ] Home / Train surfaces the headline when there's a meaningful change

## Unresolved
- Launch rule set: feet only, weak foot, alternating, below waist, below knee — all, or fewer?
- Presets as separate drills, or rule chips on one Juggling drill?
- Ambiguous touches: count them (benefit of the doubt)?
- Insights + trends: free, or Pro (`ProGates.cameraInsights` exists)?
- Height: metres (assumes a size-5 ball) or body bands (knee / waist / head)?
