"""CLI: render an exemplar from exemplars.json to a PNG + resolved JSON.

Usage:
    python -m tools.render_exemplar exemplars.json cone_weave_beginner_01
"""
from __future__ import annotations

import argparse
import json
import math
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
TOP_PADDING = 50
BOTTOM_PADDING = 120
SIDE_PADDING = 40
COLORS = {
    "cone":     (255, 140, 0),    # orange
    "gate":     (0, 200, 180),    # teal
    "ball":     (255, 255, 255),  # white
    "goal":     (40, 120, 255),   # blue
    "player":   (220, 40, 40),    # red (worker default)
    "defender": (140, 50, 200),   # dark purple (by role)
}
STEP_COLORS = [
    (30, 30, 200), (30, 150, 30), (200, 120, 30), (150, 30, 150),
    (30, 150, 200), (200, 30, 30), (60, 60, 60), (150, 80, 30),
]
SHOOT_COLOR = (220, 40, 40)


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

    _render_png(drill, png_path, exemplar_id=match["id"], archetype=match["archetype"])
    json_path.write_text(json.dumps(drill, indent=2), encoding="utf-8")

    print(f"Wrote {png_path}")
    print(f"Wrote {json_path}")
    return 0


def _draw_arrow(draw: ImageDraw.ImageDraw, src: tuple[int, int], dst: tuple[int, int],
                color: tuple[int, int, int], width: int) -> None:
    """Draw a line with a triangular arrowhead at dst."""
    draw.line([src, dst], fill=color, width=width)
    dx = dst[0] - src[0]
    dy = dst[1] - src[1]
    length = math.hypot(dx, dy)
    if length < 1:
        return
    ux, uy = dx / length, dy / length  # unit vector toward dst
    arrow_len = 12
    arrow_half = 5
    # Base of arrowhead
    base_x = dst[0] - ux * arrow_len
    base_y = dst[1] - uy * arrow_len
    # Perpendicular
    px, py = -uy, ux
    tip = dst
    left = (base_x + px * arrow_half, base_y + py * arrow_half)
    right = (base_x - px * arrow_half, base_y - py * arrow_half)
    draw.polygon([tip, left, right], fill=color)


def _draw_dashed_line(draw: ImageDraw.ImageDraw, src: tuple[int, int], dst: tuple[int, int],
                      color: tuple[int, int, int], width: int,
                      seg_len: int = 8, gap_len: int = 6) -> None:
    """Draw a dashed line from src to dst."""
    dx = dst[0] - src[0]
    dy = dst[1] - src[1]
    total = math.hypot(dx, dy)
    if total < 1:
        return
    ux, uy = dx / total, dy / total
    step = seg_len + gap_len
    d = 0.0
    while d < total:
        seg_end = min(d + seg_len, total)
        x0 = src[0] + ux * d
        y0 = src[1] + uy * d
        x1 = src[0] + ux * seg_end
        y1 = src[1] + uy * seg_end
        draw.line([(int(x0), int(y0)), (int(x1), int(y1))], fill=color, width=width)
        d += step


def _draw_dotted_line(draw: ImageDraw.ImageDraw, src: tuple[int, int], dst: tuple[int, int],
                      color: tuple[int, int, int], width: int,
                      seg_len: int = 2, gap_len: int = 6) -> None:
    """Draw a dotted line from src to dst."""
    _draw_dashed_line(draw, src, dst, color, width, seg_len=seg_len, gap_len=gap_len)


def _render_png(drill: dict, path: Path, exemplar_id: str = "", archetype: str = "") -> None:
    elements = drill["diagram"]["elements"]
    paths = drill["diagram"]["paths"]
    coaching_points = drill.get("coaching_points", [])

    width_px = int(FIELD_W * PX_PER_M + 2 * SIDE_PADDING)
    height_px = int(FIELD_L * PX_PER_M + TOP_PADDING + BOTTOM_PADDING)

    field_top = TOP_PADDING
    field_left = SIDE_PADDING

    img = Image.new("RGB", (width_px, height_px), (40, 90, 40))  # turf green
    draw = ImageDraw.Draw(img)

    # Title bar background
    draw.rectangle([(0, 0), (width_px, TOP_PADDING - 1)], fill=(20, 50, 20))

    try:
        font = ImageFont.load_default()
    except Exception:
        font = None

    # Title bar text
    if font and exemplar_id:
        title = f"{exemplar_id}  [{archetype}]"
        draw.text((8, 6), title, fill=(255, 230, 100), font=font)

    # Draw field box
    draw.rectangle(
        [(field_left, field_top),
         (field_left + int(FIELD_W * PX_PER_M), field_top + int(FIELD_L * PX_PER_M))],
        outline=(230, 230, 230), width=2,
    )

    el_by_id = {e["label"]: e for e in elements}

    # Draw paths (before elements so they sit below markers)
    for idx, p in enumerate(sorted(paths, key=lambda p: p["step"])):
        src = el_by_id.get(p["from"])
        dst = el_by_id.get(p["to"])
        if src is None or dst is None:
            print(f"WARN: path step {p['step']} references unknown element "
                  f"{p['from']!r} → {p['to']!r}", file=sys.stderr)
            continue
        sx, sy = _to_px(src["x"], src["y"], field_left, field_top)
        dx, dy = _to_px(dst["x"], dst["y"], field_left, field_top)
        verb = p.get("style", "pass")
        color = STEP_COLORS[idx % len(STEP_COLORS)]

        if verb == "shoot":
            _draw_arrow(draw, (sx, sy), (dx, dy), SHOOT_COLOR, 4)
        elif verb == "pass":
            _draw_arrow(draw, (sx, sy), (dx, dy), color, 3)
        elif verb == "dribble":
            _draw_dashed_line(draw, (sx, sy), (dx, dy), color, 3)
            _draw_arrow(draw, (sx, sy), (dx, dy), color, 3)
        elif verb == "run":
            _draw_dotted_line(draw, (sx, sy), (dx, dy), color, 2)
            _draw_arrow(draw, (sx, sy), (dx, dy), color, 2)
        elif verb == "receive":
            draw.line([(sx, sy), (dx, dy)], fill=color, width=2)
            _draw_arrow(draw, (sx, sy), (dx, dy), color, 2)
        else:
            _draw_arrow(draw, (sx, sy), (dx, dy), color, 2)

        # Step number circle at midpoint
        mid_x = (sx + dx) // 2
        mid_y = (sy + dy) // 2
        r = 10
        draw.ellipse([(mid_x - r, mid_y - r), (mid_x + r, mid_y + r)],
                     fill=(255, 255, 255), outline=(0, 0, 0), width=1)
        if font:
            label = str(p["step"])
            bbox = font.getbbox(label)
            lw = bbox[2] - bbox[0]
            lh = bbox[3] - bbox[1]
            draw.text((mid_x - lw // 2, mid_y - lh // 2), label,
                      fill=(0, 0, 0), font=font)

    # Draw elements
    for el in elements:
        x, y = _to_px(el["x"], el["y"], field_left, field_top)
        color = COLORS.get(el["type"], (200, 200, 200))

        if el["type"] == "ball":
            r = 6
            draw.ellipse([(x - r, y - r), (x + r, y + r)],
                         fill=(255, 255, 255), outline=(160, 160, 160), width=1)
        elif el["type"] == "gate":
            w = el.get("width", 2.0)
            cone_color = (255, 140, 0)  # orange
            r = 8
            # Two cone markers offset by ±width/2 on y-axis
            for offset_m in (-w / 2, w / 2):
                cx, cy = _to_px(el["x"], el["y"] + offset_m, field_left, field_top)
                draw.ellipse([(cx - r, cy - r), (cx + r, cy + r)],
                             fill=cone_color, outline=(0, 0, 0))
            # Label centered between the two cones, to the right
            if font:
                draw.text((x + r + 2, y - r), el["label"], fill=(255, 255, 255), font=font)
            continue  # skip the generic label draw below
        elif el["type"] == "goal":
            r = 8
            draw.ellipse([(x - r, y - r), (x + r, y + r)],
                         fill=color, outline=(0, 0, 0))
        else:
            r = 12
            role = el.get("role", "") if el["type"] == "player" else ""
            fill_color = COLORS["defender"] if role == "defender" else color
            draw.ellipse([(x - r, y - r), (x + r, y + r)],
                         fill=fill_color, outline=(0, 0, 0))
            # Role badge (W/S/D) inside player circle
            if font and el["type"] == "player":
                badge = {"worker": "W", "server": "S", "defender": "D"}.get(role, "")
                if badge:
                    bbox = font.getbbox(badge)
                    bw = bbox[2] - bbox[0]
                    bh = bbox[3] - bbox[1]
                    draw.text((x - bw // 2, y - bh // 2), badge,
                              fill=(255, 255, 255), font=font)

        # Element label to the right
        if font:
            draw.text((x + r + 2, y - r), el["label"], fill=(255, 255, 255), font=font)

    # Coaching points below field
    if font and coaching_points:
        cp_y = field_top + int(FIELD_L * PX_PER_M) + 8
        draw.text((field_left, cp_y), "Coaching points:", fill=(220, 220, 100), font=font)
        cp_y += 14
        for pt in coaching_points:
            text = f"• {pt}"
            draw.text((field_left, cp_y), text, fill=(230, 230, 230), font=font)
            cp_y += 13

    img.save(path, "PNG")


def _to_px(x_m: float, y_m: float, field_left: int = SIDE_PADDING,
           field_top: int = TOP_PADDING) -> tuple[int, int]:
    # DSL origin (0,0) at bottom-left; PNG origin top-left
    x_px = int(x_m * PX_PER_M + field_left)
    y_px = int((FIELD_L - y_m) * PX_PER_M + field_top)
    return x_px, y_px


if __name__ == "__main__":
    sys.exit(main())
