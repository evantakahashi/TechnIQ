# Camera Drills — shot analysis (speed + placement), plan (2026-10-31)

Builds on camera drills (`tasks/camera_drills.md`, `tasks/camera_drills_build.md`). Not part of v1.0.

## Decisions (Evan, 2026-10-31)
- Measure **average ball speed** (km/h, kick → goal line) + **placement** (3×3 zones in the goal; wide / over).
- **Set spots only:** penalty spot (11 m) or edge of the box (16.5 m), picked at setup. Free spots later.
- **Full-size goal, no keeper.** Ball struck from rest (no volleys).
- **One phone on the ground, propped on a water bottle**, ~2–3 m behind the ball and ~1 m to the side
  (keeps the shooter off the ball's line), **portrait** like Juggle Dude's shot mode (a full goal fits from
  behind the penalty spot; 9:16 shares as-is).
- **No radar gun.** Ground truth = tape-measured spot distance + hand-marked kick / crossing frames.
- **Sessions are open-ended.** 240 fps where the phone can, **120 fps fallback** otherwise.
- **UI + flow follow Juggle Dude** (promo video, frames reviewed 2026-10-31): record → replay screen → customise →
  one tap to Photos / share. Their shot mode ("Ball Distance") only shows flight time; ours adds speed + placement.

## Flow (Juggle Dude-style)
- Camera drills home: drill cards (Juggling "Start session", Shots "Record"), personal best row, session history,
  "Import a video" (slo-mo clips from Photos — same analysis), "How to set up your camera".
- Shot session: setup (prop phone, tap 4 corners, pick spot, ball-on-spot check) → shoot → each shot analysed and
  spoken ("87 km/h, top left") → keep shooting; arms up or Done ends.
- Replay screen per shot: slo-mo playback with scrubber, speed + zone + flight time overlay; Customise sheet:
  trail (fire / volt / plain), camera move (Freeze + Path with flight time, Ball Follow, Speed Ramp, Impact Zoom,
  Instant Replay), zone graphic; save to Photos, share.
- Juggling gets the same replay screen later (count overlay, rhythm graph, ball skins / effects) — phase 4 share.

## How it works
- **Capture:** back camera 1080p at 240 fps (120 fallback), portrait, recorded to file. Shots are analysed ~1–2 s after each kick
  (post-shot, not live), read back with real frame timestamps.
- **Goal plane:** player taps the 4 goal corners once → homography + focal length → the goal's position and
  orientation in camera space (`GoalPose`; its posts also give the direction of gravity).
- **Focal length:** the device's field of view; for imports, solved from the resting ball's size (0.22 m) sitting
  the picked spot's distance in front of the goal (`ShotGeometry.estimateFocal`). Setup check in the app: the same
  sum must roughly agree, else "Move the ball to the spot / check the corners".
- **Start point:** the resting ball's ray, the spot's distance in front of the goal plane.
- **Flight:** gravity + air drag from the start point; initial velocity + kick time fitted (Levenberg–Marquardt)
  to every sighting's image position and size up to the goal line, kick time searched across the frames the
  leg hides. Crossing = where the fitted flight meets the goal plane → (x, y) in the goal → zone, wide or over.
- **Speed:** straight-line distance spot → crossing point (√(D² + x² + y²)) ÷ flight time. Label "avg speed".
- **Ball detector:** same YOLOX-nano pipeline, run on crops (resting ball; goal + band in front of it) because
  the ball is ~20 px and blurred near the goal. Fine-tuned on shot frames (labeler + PC, as for juggling).

## Phase S1 — Spike (Mac harness, go/no-go)
- [ ] USER: film 40+ shots (both spots, power/placement mix, misses + posts, both feet, ≥2 times of day) with
      the iPhone Camera app's Slo-mo (240 fps), portrait, phone on the ground as above; tape-measure the spot.
      AirDrop with Options → "All Photos Data" (keeps the real 240 fps timestamps)
- [x] Pure `ShotGeometry` (goal pose from 4 corners, focal length from the resting ball) — TDD, synthetic
- [x] Pure `ShotAnalyzer` (kick → gravity + drag flight fitted to position + size → goal-line crossing, avg
      speed, zone / wide / over) — TDD; synthetic: ≥ 95% of 40 noisy shots within 5%, 120 fps works
- [x] `shot-harness`: clip + `<clip>.goal.json` corners + `shots.csv` truth → speed / zone / gate; detector runs on
      the full frame + a goal crop (crop path checked against full-frame boxes on real footage)
- [ ] Truth: hand-mark kick + crossing frames per clip (labeler gets a frame-marking mode)
- [ ] Gate: speed within ±5% of truth on ≥90% of shots; zone correct on ≥90%; misses called right

## Phase S2 — Detector on shot footage
- [ ] Harness `--labels-out` on shot clips (crops) → labeler → PC fine-tune (one model for juggling + shots)
- [ ] Re-score S1 gate

## Phase S3 — App capture
- [ ] `CameraDrill.shooting` (new raw value) + portrait session screen
- [ ] Setup: prop phone → tap 4 corners → pick spot → ball-at-spot check → "Shoot when ready"
- [ ] 240 fps recording (120 fallback, AVAssetWriter), kick trigger at low rate, segment analysis, spoken result
- [ ] Open-ended session (arms up / Done ends); best + average speed, on-target %, zone map
- [ ] Import a slo-mo video from Photos → same analysis (focal length from the resting ball)

## Phase S4 — Results, PBs, rewards
- [ ] Additive CameraRun fields (top speed, average, shots, on target) — model + `+CoreDataProperties`
- [ ] PB = top speed per spot; capped XP / coins via CameraRewards; sync

## Phase S5 — Share
- [ ] Replay screen + Customise (trails, Freeze + Path, Ball Follow, Speed Ramp, Impact Zoom, zone graphic),
      save to Photos, share — shared renderer with juggling's phase 4

## Later
Free spots (distance from depth alone), keeper, estimated strike speed (drag-corrected), technique cues
(plant foot, lean, follow-through), volleys.

## Unresolved
- km/h vs mph by locale?
