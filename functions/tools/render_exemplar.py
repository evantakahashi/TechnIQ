"""CLI: render an exemplar from exemplars.json to a PNG + resolved JSON.

Usage:
    python -m tools.render_exemplar exemplars.json cone_weave_beginner_01
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Allow running as `python -m tools.render_exemplar` from functions/
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from dsl_parser import parse_dsl  # noqa: E402
from drill_post_processor import post_process_drill  # noqa: E402

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow is required: pip install Pillow", file=sys.stderr)
    raise

FIELD_W = 20.0
FIELD_L = 15.0
PX_PER_M = 40
PADDING = 40
COLORS = {
    "cone":   (255, 140, 0),   # orange
    "gate":   (0, 200, 180),   # teal
    "ball":   (220, 220, 220), # grey
    "goal":   (40, 120, 255),  # blue
    "player": (220, 40, 40),   # red
}
STEP_COLORS = [
    (30, 30, 200), (30, 150, 30), (200, 120, 30), (150, 30, 150),
    (30, 150, 200), (200, 30, 30), (60, 60, 60), (150, 80, 30),
]


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("exemplars_file", type=Path)
    p.add_argument("exemplar_id")
    p.add_argument("--out-dir", type=Path, default=Path("/tmp"))
    p.add_argument("--player-age", type=int, default=14, help="Player age (default: 14)")
    p.add_argument("--equipment", type=str, default="ball,cones,goals,partner",
                   help="Comma-separated equipment list (default: ball,cones,goals,partner)")
    args = p.parse_args()

    exemplars = json.loads(args.exemplars_file.read_text(encoding="utf-8"))
    match = next((e for e in exemplars if e["id"] == args.exemplar_id), None)
    if match is None:
        print(f"No exemplar with id {args.exemplar_id!r}", file=sys.stderr)
        return 1

    drill = parse_dsl(match["dsl"])
    drill["equipment"] = [e.strip() for e in args.equipment.split(",")]
    drill, warnings = post_process_drill(drill, player_age=args.player_age)
    for w in warnings:
        print(f"WARN: {w}", file=sys.stderr)

    png_path = args.out_dir / f"{args.exemplar_id}.png"
    json_path = args.out_dir / f"{args.exemplar_id}.json"

    _render_png(drill, png_path)
    json_path.write_text(json.dumps(drill, indent=2), encoding="utf-8")

    print(f"Wrote {png_path}")
    print(f"Wrote {json_path}")
    return 0


def _render_png(drill: dict, path: Path) -> None:
    elements = drill["diagram"]["elements"]
    paths = drill["diagram"]["paths"]

    width_px = int(FIELD_W * PX_PER_M + 2 * PADDING)
    height_px = int(FIELD_L * PX_PER_M + 2 * PADDING)
    img = Image.new("RGB", (width_px, height_px), (40, 90, 40))  # turf green
    draw = ImageDraw.Draw(img)

    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    # Draw field box
    draw.rectangle(
        [(PADDING, PADDING), (width_px - PADDING, height_px - PADDING)],
        outline=(230, 230, 230), width=2,
    )

    el_by_id = {e["label"]: e for e in elements}

    # Draw paths (before elements so they sit below markers)
    for idx, p in enumerate(sorted(paths, key=lambda p: p["step"])):
        src = el_by_id.get(p["from"])
        dst = el_by_id.get(p["to"])
        if src is None or dst is None:
            print(f"WARN: path step {p['step']} references unknown element {p['from']!r} → {p['to']!r}", file=sys.stderr)
            continue
        sx, sy = _to_px(src["x"], src["y"])
        dx, dy = _to_px(dst["x"], dst["y"])
        color = STEP_COLORS[idx % len(STEP_COLORS)]
        width = 3 if p["style"] == "pass" else 2
        draw.line([(sx, sy), (dx, dy)], fill=color, width=width)
        if font:
            mid = ((sx + dx) // 2, (sy + dy) // 2)
            draw.text(mid, f"{p['step']}.{p['style']}", fill=(255, 255, 255), font=font)

    # Draw elements
    for el in elements:
        x, y = _to_px(el["x"], el["y"])
        color = COLORS.get(el["type"], (200, 200, 200))
        r = 12 if el["type"] == "player" else 8
        draw.ellipse([(x - r, y - r), (x + r, y + r)], fill=color, outline=(0, 0, 0))
        if font:
            draw.text((x + r + 2, y - r), el["label"], fill=(255, 255, 255), font=font)

    img.save(path, "PNG")


def _to_px(x_m: float, y_m: float) -> tuple[int, int]:
    # DSL origin (0,0) at bottom-left; PNG origin top-left
    x_px = int(x_m * PX_PER_M + PADDING)
    y_px = int((FIELD_L - y_m) * PX_PER_M + PADDING)
    return x_px, y_px


if __name__ == "__main__":
    sys.exit(main())
