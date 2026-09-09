"""Parser for the drill DSL. Produces dicts compatible with drill_post_processor."""
from __future__ import annotations

import re
from typing import Any

VERB_TO_STYLE = {
    "passes to": "pass",
    "dribbles to": "dribble",
    "runs to": "run",
    "shoots at": "shoot",
    "receives from": "receive",
    "throws to": "throw",    # GK distribution / hand serves
    "heads to": "header",    # aerial finish/clearance off a served ball
    "tosses to": "toss",     # underhand serve for heading/volley work
}

ELEMENT_KEYWORDS = {"cone", "gate", "ball", "goal", "player", "wall", "defender", "server", "mannequin"}


class DSLParseError(ValueError):
    """Raised when the DSL cannot be parsed."""

    def __init__(self, line_number: int, reason: str):
        self.line_number = line_number
        self.reason = reason
        super().__init__(f"line {line_number}: {reason}")


_COORD_RE = re.compile(r"\(\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\)")
_ELEMENT_RE = re.compile(
    r"^(?P<kind>cone|gate|ball|goal|player|wall|defender|server|mannequin)\s+(?P<id>\w+)\s+at\s+"
    r"(?P<coord>\([^)]+\))"
    r"(?:\s+width\s+(?P<width>\d+(?:\.\d+)?))?"
    r"(?:\s+role\s+\"(?P<role>[^\"]*)\")?"
    r"(?:\s+label\s+\"(?P<label>[^\"]*)\")?"
    r"\s*$"
)
_STEP_RE = re.compile(
    r"^step\s+(?P<num>\d+)\s*:\s*(?P<src>\w+)\s+(?P<verb>passes to|dribbles to|runs to|shoots at|receives from|throws to|heads to|tosses to)\s+(?P<dst>\w+)(?:\s+(?P<touch>one-touch|two-touch|first-time))?\s*$"
)
_POINT_RE = re.compile(r"^point\s*:\s*(?P<text>.+?)\s*$")
_VARIATION_RE = re.compile(r"^variation\s*:\s*(?P<text>.+?)\s*$")
_OPTION_RE = re.compile(
    r"^or\s*:\s*(?P<src>\w+)\s+(?P<verb>passes to|dribbles to|runs to|shoots at|receives from|throws to|heads to|tosses to)\s+(?P<dst>\w+)\s*$"
)


def parse_dsl(dsl: str) -> dict[str, Any]:
    """Parse DSL text into a drill dict ready for drill_post_processor."""
    if not dsl.strip():
        raise DSLParseError(1, "empty DSL")

    elements: list[dict[str, Any]] = []
    paths: list[dict[str, Any]] = []
    coaching_points: list[str] = []
    variations: list[str] = []
    seen_ids: set[str] = set()
    last_step = 0

    for idx, raw_line in enumerate(dsl.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue  # model's plan comment — kept in raw logs for debugging, not data

        head = line.split(None, 1)[0].rstrip(":")

        if head in ELEMENT_KEYWORDS:
            el = _parse_element(line, idx)
            if el["label"] in seen_ids:
                raise DSLParseError(idx, f"duplicate element id {el['label']}")
            seen_ids.add(el["label"])
            elements.append(el)
            continue

        if head == "step":
            path, step_num = _parse_step(line, idx)
            if step_num != last_step + 1:
                raise DSLParseError(
                    idx,
                    f"step numbers must be strictly increasing from 1; got {step_num} after {last_step}",
                )
            last_step = step_num
            paths.append(path)
            continue

        if head == "or":
            m = _OPTION_RE.match(line)
            if not m:
                raise DSLParseError(idx, "malformed option (or: X verb Y)")
            if last_step == 0:
                raise DSLParseError(idx, "or: must follow a step")
            paths.append({
                "from": m.group("src"),
                "to": m.group("dst"),
                "style": VERB_TO_STYLE[m.group("verb")],
                "step": last_step,
                "alt": True,
            })
            continue

        if head == "variation":
            mv = _VARIATION_RE.match(line)
            if not mv:
                raise DSLParseError(idx, "malformed variation")
            variations.append(mv.group("text"))
            continue

        if head == "point":
            m = _POINT_RE.match(line)
            if not m:
                raise DSLParseError(idx, "malformed point")
            coaching_points.append(m.group("text"))
            continue

        raise DSLParseError(idx, f"unknown statement: {head!r}")

    return {
        "diagram": {
            "field": {"width": 20, "length": 15},
            "elements": elements,
            "paths": paths,
        },
        "coaching_points": coaching_points,
        "variations": variations,
    }


def _parse_element(line: str, idx: int) -> dict[str, Any]:
    m = _ELEMENT_RE.match(line)
    if not m:
        raise DSLParseError(idx, "malformed element declaration")

    coord_match = _COORD_RE.match(m.group("coord"))
    if not coord_match:
        raise DSLParseError(idx, "malformed coordinate")

    el: dict[str, Any] = {
        "type": ("player" if m.group("kind") in ("defender", "server") else m.group("kind")),
        "x": float(coord_match.group(1)),
        "y": float(coord_match.group(2)),
        "label": m.group("id"),
    }
    if m.group("width") is not None:
        el["width"] = float(m.group("width"))
    if m.group("role") is not None:
        el["role"] = m.group("role")
    elif m.group("kind") in ("defender", "server"):
        el["role"] = m.group("kind")  # `defender D1 at (x,y)` shorthand
    if m.group("label") is not None:
        el["display_label"] = m.group("label")
    return el


def _parse_step(line: str, idx: int) -> tuple[dict[str, Any], int]:
    m = _STEP_RE.match(line)
    if not m:
        raise DSLParseError(idx, "malformed step")
    verb = m.group("verb")
    style = VERB_TO_STYLE.get(verb)
    if style is None:
        raise DSLParseError(idx, f"unknown verb {verb!r}")
    step_num = int(m.group("num"))
    path = {
        "from": m.group("src"),
        "to": m.group("dst"),
        "style": style,
        "step": step_num,
    }
    if m.group("touch"):
        path["touches"] = 1 if m.group("touch") in ("one-touch", "first-time") else 2
    return path, step_num
