"""Create ML labels → YOLOX's COCO layout.

    python to_coco.py <labels-dir> <dataset-dir> [--annotations checked.json] [--val-clips a,b] [--val-share 0.15]

<labels-dir> = `juggle-harness --labels-out` folder (JPEGs + annotations.json, or the labeler's checked.json).
Writes <dataset-dir>/{train2017,val2017}/*.jpg and annotations/instances_{train,val}2017.json.
The split is by clip (frame names are <clip>_<frame>.jpg) so near-identical neighbouring frames never
land on both sides. Frames with no ball stay in as negatives.
"""
import argparse
import json
import os
import shutil

import cv2


def clip_of(name):
    return name.rsplit("_", 1)[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("labels_dir")
    ap.add_argument("dataset_dir")
    ap.add_argument("--annotations", default="annotations.json")
    ap.add_argument("--val-clips", default="", help="comma-separated clip names for validation")
    ap.add_argument("--val-share", type=float, default=0.15, help="share of clips for validation when --val-clips is empty")
    args = ap.parse_args()

    with open(os.path.join(args.labels_dir, args.annotations)) as f:
        items = json.load(f)
    clips = sorted({clip_of(it["image"]) for it in items})
    if args.val_clips:
        val = set(args.val_clips.split(","))
    else:
        n = max(1, round(len(clips) * args.val_share))
        val = set(clips[::max(1, len(clips) // n)][:n])
    print(f"{len(items)} frames from {len(clips)} clips; validation clips: {sorted(val)}")

    for split in ("train2017", "val2017"):
        os.makedirs(os.path.join(args.dataset_dir, split), exist_ok=True)
    os.makedirs(os.path.join(args.dataset_dir, "annotations"), exist_ok=True)

    cocos = {s: {"images": [], "annotations": [], "categories": [{"id": 1, "name": "ball"}]} for s in ("train2017", "val2017")}
    ann_id = 1
    for img_id, it in enumerate(items, start=1):
        split = "val2017" if clip_of(it["image"]) in val else "train2017"
        src = os.path.join(args.labels_dir, it["image"])
        image = cv2.imread(src)
        if image is None:
            print(f"skipping unreadable {src}")
            continue
        h, w = image.shape[:2]
        shutil.copyfile(src, os.path.join(args.dataset_dir, split, it["image"]))
        cocos[split]["images"].append({"id": img_id, "file_name": it["image"], "width": w, "height": h})
        for a in it["annotations"]:
            c = a["coordinates"]  # Create ML: centre x/y, width, height in pixels, top-left origin
            x, y = c["x"] - c["width"] / 2, c["y"] - c["height"] / 2
            cocos[split]["annotations"].append({
                "id": ann_id, "image_id": img_id, "category_id": 1, "iscrowd": 0,
                "bbox": [x, y, c["width"], c["height"]], "area": c["width"] * c["height"],
            })
            ann_id += 1

    for split, coco in cocos.items():
        with open(os.path.join(args.dataset_dir, "annotations", f"instances_{split}.json"), "w") as f:
            json.dump(coco, f)
        print(f"{split}: {len(coco['images'])} images, {len(coco['annotations'])} balls")


if __name__ == "__main__":
    main()
