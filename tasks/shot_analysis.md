# Camera Drills — shot analysis (speed + placement), plan (2026-10-31)

Builds on camera drills (`tasks/camera_drills.md`, `tasks/camera_drills_build.md`). Not part of v1.0.

## Decisions (Evan, 2026-10-31)
- Measure **average ball speed** (km/h, kick → goal line) + **placement** (3×3 zones in the goal; wide / over).
- **Set spots only:** penalty spot (11 m) or edge of the box (16.5 m), picked at setup. Free spots later.
- **Full-size goal, no keeper.** Ball struck from rest (no volleys).
- **One phone on the ground, propped on a water bottle**, ~2–3 m behind the ball and ~1–2 m to the side
  (keeps the shooter off the ball's line), **landscape** (the whole goal must fit).
- **No radar gun.** Ground truth = tape-measured spot distance + hand-marked kick / crossing frames.

## How it works
- **Capture:** back camera 1080p at 240 fps, recorded to file. Shots are analysed ~1–2 s after each kick
  (post-shot, not live), read back with real frame timestamps.
- **Goal plane:** player taps the 4 goal corners once → homography to the 7.32 × 2.44 m goal mouth.
- **Depth:** focal length from the device's field of view; goal depth from its pixel width (7.32 m), ball depth
  from its pixel diameter (0.22 m). Setup check: goal depth − ball-at-spot depth ≈ the picked spot (11 / 16.5 m),
  else "Move the ball to the spot / check the corners".
- **Kick time:** the resting ball leaves its spot (ball detector), refined by the kicking foot's pose.
- **Crossing time + point:** ball depth over the flight fitted against time → reaches goal depth; image position
  there → homography → (x, y) in the goal → zone, or wide / over. Net / post stops are the cross-check.
- **Speed:** straight-line distance spot → crossing point (√(D² + x² + y²)) ÷ flight time. Label "avg speed".
- **Ball detector:** same YOLOX-nano pipeline, run on crops (resting ball; goal + band in front of it) because
  the ball is ~20 px and blurred near the goal. Fine-tuned on shot frames (labeler + PC, as for juggling).

## Phase S1 — Spike (Mac harness, go/no-go)
- [ ] USER: film 40+ shots (both spots, power/placement mix, misses + posts, both feet, ≥2 times of day) with
      the iPhone Camera app's Slo-mo (240 fps), landscape, phone on the ground as above; tape-measure the spot
- [ ] Pure `ShotGeometry` (homography, depth from size, zone) — TDD, synthetic
- [ ] Pure `ShotAnalyzer` (ball track → kick, crossing, speed, zone / miss) — TDD, synthetic flights
- [ ] Harness `shot` mode: clip + `corners.json` + spot → per-shot speed / zone; `truth.csv` scoring
- [ ] Truth: hand-mark kick + crossing frames per clip (labeler gets a frame-marking mode)
- [ ] Gate: speed within ±5% of truth on ≥90% of shots; zone correct on ≥90%; misses called right

## Phase S2 — Detector on shot footage
- [ ] Harness `--labels-out` on shot clips (crops) → labeler → PC fine-tune (one model for juggling + shots)
- [ ] Re-score S1 gate

## Phase S3 — App capture
- [ ] `CameraDrill.shooting` (new raw value) + landscape session screen
- [ ] Setup: prop phone → tap 4 corners → pick spot → ball-at-spot check → "Shoot when ready"
- [ ] 240 fps recording (AVAssetWriter), kick trigger at low rate, segment analysis, spoken "87 km/h, top left"
- [ ] Session: N shots or arms-up to end; best + average speed, on-target %, zone map

## Phase S4 — Results, PBs, rewards
- [ ] Additive CameraRun fields (top speed, average, shots, on target) — model + `+CoreDataProperties`
- [ ] PB = top speed per spot; capped XP / coins via CameraRewards; sync

## Phase S5 — Share
- [ ] Best shot as slow-mo replay with speed + zone overlay (reuses the phase 4 share renderer)

## Later
Free spots (distance from depth alone), keeper, estimated strike speed (drag-corrected), technique cues
(plant foot, lean, follow-through), volleys.

## Unresolved
- km/h vs mph by locale?
- Session length: fixed (e.g. 10 shots) or open?
- Phones without 1080p240: fall back to 120 fps or block?
