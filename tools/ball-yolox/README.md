# ball-yolox — train the ball detector on a GPU PC (Windows + WSL2)

YOLOX-nano (Apache-2.0, shippable) fine-tuned on our labelled frames, exported to a Core ML pipeline
(`BallDetector.mlpackage`, label `ball`) that `FrameAnalyzer` uses through Vision like any Core ML detector.
Labels come from the same flow as Create ML: `juggle-harness --labels-out` → `tools/ball-labeler` → `checked.json`.

Pinned: YOLOX `6ddff4824372906469a7fae2dc3206c7aa4bbaee`, torch 2.7.0 (newest coremltools has been tested with),
coremltools 9.0. YOLOX is used from its source folder (`PYTHONPATH`), so no C++ build.

## 1. One-time setup (Windows, ~20 min)
PowerShell as admin:
```
wsl --install -d Ubuntu-22.04
```
Reboot, open "Ubuntu 22.04", make a user. The normal Windows NVIDIA driver already gives WSL the GPU
(don't install a driver inside Ubuntu). Then in Ubuntu:
```
nvidia-smi                                   # should list the 4070 SUPER
sudo apt update && sudo apt install -y python3-venv python3-pip git libgl1
python3 -m venv ~/yx && source ~/yx/bin/activate
pip install torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu126
pip install coremltools==9.0 loguru tabulate thop psutil opencv-python-headless pycocotools ninja tqdm tensorboard
git clone https://github.com/Megvii-BaseDetection/YOLOX.git ~/YOLOX
git -C ~/YOLOX checkout 6ddff4824372906469a7fae2dc3206c7aa4bbaee
wget -P ~/YOLOX https://github.com/Megvii-BaseDetection/YOLOX/releases/download/0.1.1rc0/yolox_nano.pth
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"   # True, ...4070 SUPER
```

## 2. Data (each training round)
On the Mac: zip the checked labels folder (JPEGs + `checked.json`) and this folder; copy both to the PC
(Windows `C:\Users\<you>\ball` = `/mnt/c/Users/<you>/ball` in Ubuntu). Work on the Linux side for speed:
```
source ~/yx/bin/activate
mkdir -p ~/ball && cp -r /mnt/c/Users/<you>/ball/* ~/ball/ && cd ~/ball
python ball-yolox/to_coco.py labels datasets/ball --annotations checked.json
```

## 3. Train (~minutes on a 4070 SUPER; the exact time isn't measured yet)
```
cd ~/YOLOX
BALL_DATA=~/ball/datasets/ball PYTHONPATH=~/YOLOX \
  python tools/train.py -f ~/ball/ball-yolox/ball_nano.py -d 1 -b 32 --fp16 -o -c yolox_nano.pth
```
Prints COCO AP on the validation clips every 5 epochs; the best checkpoint is
`YOLOX_outputs/ball_nano/best_ckpt.pth`. Out of GPU memory → `-b 16`.

## 4. Export to Core ML (on the PC)
```
PYTHONPATH=~/YOLOX python ~/ball/ball-yolox/export_coreml.py -f ~/ball/ball-yolox/ball_nano.py \
  -c YOLOX_outputs/ball_nano/best_ckpt.pth -o /mnt/c/Users/<you>/ball/BallDetector.mlpackage
```
Copy `BallDetector.mlpackage` back to the Mac.

## 5. Score and ship (Mac)
```
juggle-harness <held-out-clips> --detector yolo --model BallDetector.mlpackage     # vs the yolo11n run
```
Better → put it in `TechnIQ/CameraDrills/Models/` and add it to the target; `DrillModels` prefers `BallDetector`
over yolo11n. Delete yolo11n before release, and list YOLOX (Apache-2.0, Megvii) in the app's licences.

## Checked on the Mac (2026-10-27)
Export verified with the COCO-pretrained nano (`--class-index 32` = sports ball, 640 px): a 2 MB model that Vision
reads; its ball boxes match YOLO11n's within 0.2% of frame height. Untrained-on-our-data, it already sees the ball
in 25–96% of frames on the YouTube clips (YOLO11n + gap filler: 13–98%).
