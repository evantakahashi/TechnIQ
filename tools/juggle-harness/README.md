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
    --model TechnIQ/CameraDrills/Models/yolo11n.mlpackage [--detector trajectory|yolo|both] [--dump]
```
Columns: true/pred/err, all runs found, % frames with a ball and with a pose, touches with no pose
(`unk`), Mac fps (not the device number). `--dump` prints per-frame ball position + events for debugging.

## Unit tests
`swift test --package-path tools/juggle-harness` — JuggleCounter on synthetic footage.
