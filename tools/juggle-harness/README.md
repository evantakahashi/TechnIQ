# juggle-harness — Camera Drills phase-1 spike

Replays recorded juggling clips through the app's on-device pipeline (`TechnIQ/CameraDrills/{Core,Vision}`,
symlinked into `Sources/JuggleCore`) and scores the count against labels. Same code the iPhone runs.

## Gate (go/no-go)
GO if **≥ 90% of clips within ±1** of the true count (harness) **and ≥ 28 fps** on an iPhone 12 (spike screen).
Run both detectors; the one that passes decides the ship detector (YOLO11n is AGPL — spike only).

## 1. Film (~30 clips)
DEBUG build on device → You → **Juggle spike** (or launch arg `-TQScreen jugglespike`).
- Phone upright (portrait), back camera, propped ~3–4 m away at hip height, whole body + ball in frame.
- **Record clip** → drop ball from hands → juggle → let it hit the ground → **Stop clip**. One attempt per clip.
- Note the true count for each clip (count it on replay — every legal touch: feet/thighs/chest/head).
- Mix it up: counts 3–60, 2–3 players, backyard/garage/park, bright/overcast/dusk, different balls.
- While filming, read the fps badge for each detector (green ≥ 28).

Clips land in the app's Documents/JuggleSpike — pull them off via Finder (iPhone → Files → TechnIQ) or the Files app.

## 2. Label
Put the clips in one folder with `labels.csv`:
```
file,count
juggle-20261020-171501.mov,14
```

## 3. Run
```
swift run -c release --package-path tools/juggle-harness juggle-harness <clips-dir> \
    --model TechnIQ/CameraDrills/Models/yolo11n.mlpackage [--detector trajectory|yolo|both] \
    [--conf 0.1] [--no-fill] [--dump] [--frames-out <dir>]
```
Columns: true/pred/err, all runs found, % frames with a ball, with a pose and in the outline (`inpos`,
HandsFreeFlow's rule), touches with no pose (`unk`), Mac fps (not the device number).
`--conf` = YOLO ball threshold (app default 0.1). `--no-fill` turns off BallGapFiller (tracker fills short misses). `--dump` prints per-frame ball position, flow cues and
events. `--frames-out` writes `<clip>.frames.json` for replaying the clip in the simulator app
(`-TQCameraFile <clip>`; Vision pose doesn't run in the simulator).

### Real-footage check (2026-10-21, YouTube clips, no own filming yet)
Counter timing matched audio thumps 1:1 wherever the ball was tracked; the bottleneck is YOLO11n ball
recall (31–74% of frames). Fixed: a plant pot read as the ball (BallTracker scenery filter).
Runs also end, correctly, when the player walks out of frame or catches the ball.

### Gap filling (2026-10-27, 10 YouTube clips)
Vision's object tracker, seeded on each detection, fills misses up to 0.3 s: ball frames e.g. 49→73%, 26→58%,
61→86%; touches counted 491→538 at the same audio-thump precision (64% vs 63%; music/talk clips drag the proxy
down, clean clips ~89%). Mac fps ~130→~100 — check on device.

## Training our ball detector (Create ML — replaces YOLO11n)
1. **Suggest labels** — `juggle-harness <clips-dir> --detector yolo --model …/yolo11n.mlpackage --labels-out <dir> --every 10`
   writes every 10th frame (upright JPEG) + `annotations.json` with the analyser's ball box (YOLO + gap filler).
   Keep a few clips out for scoring.
2. **Check them** — open `tools/ball-labeler/index.html` in a browser → Open folder → `<dir>`. → / Space accepts,
   drag redraws, X = no ball, M jumps to frames with no suggestion (the misses — the most valuable ones).
   Export `checked.json` into `<dir>`.
3. **Train** — `swift run -c release --package-path tools/juggle-harness ball-train <dir> BallDetector.mlmodel
   --annotations checked.json [--iterations 3000] [--grid 13]` (Create ML YOLOv2-style detector, label `ball`).
4. **Score** — `juggle-harness <held-out-clips> --detector yolo --model BallDetector.mlmodel` vs the YOLO11n run.
5. **Ship** — add `BallDetector.mlmodel` to `TechnIQ/CameraDrills/Models/`; `DrillModels.yolo` prefers it over
   yolo11n. Delete yolo11n before release.

## Unit tests
`swift test --package-path tools/juggle-harness` — JuggleCounter, HandsFreeFlow, CameraRewards, BallTracker on synthetic footage.
