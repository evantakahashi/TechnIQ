"""Parser for the drill DSL. Produces dicts compatible with drill_post_processor."""
from __future__ import annotations

import re
from typing import Any

# Canonical SEMANTIC classes — closed on purpose: possession tracking and
# every validator reason over these. The SURFACE vocabulary is open: models
# may use any verb and declare its class inline (`verb chips = passes`).
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

# Built-in synonym stems -> canonical style (surface flavor, same physics)
_VERB_SYNONYMS = {
    "chip": "pass", "clip": "pass", "loft": "pass", "slip": "pass",
    "slide": "pass", "roll": "pass", "play": "pass", "feed": "pass",
    "cross": "pass", "lay": "pass", "cutback": "pass", "cut back": "pass",
    "strike": "shoot", "fire": "shoot", "blast": "shoot", "finish": "shoot",
    "volley": "shoot", "smash": "shoot", "place": "shoot", "curl": "shoot",
    "carry": "dribble", "drive": "dribble", "take": "dribble",
    "weave": "dribble", "glide": "dribble", "shield": "dribble",
    "sprint": "run", "jog": "run", "move": "run", "shuffle": "run",
    "dart": "run", "check": "run", "press": "run", "close": "run",
    "cushion": "receive", "control": "receive", "trap": "receive",
    "catch": "receive", "collect": "receive", "gather": "receive",
    "chest": "receive", "flick": "header", "nod": "header",
    "lob": "toss", "serve": "toss", "punt": "throw", "bowl": "throw",
}
_CANON_STYLES = set(VERB_TO_STYLE.values())


def resolve_verb(phrase: str, declared: dict[str, str]) -> str | None:
    """Any surface verb -> canonical style, or None if unresolvable."""
    p = phrase.strip().lower()
    if p in VERB_TO_STYLE:
        return VERB_TO_STYLE[p]
    head = re.sub(r"\s+(to|at|from|into|through|past|off|on)$", "", p)
    head = head.rstrip("s")  # chips -> chip
    if head in declared:
        return declared[head]
    for stem, style in _VERB_SYNONYMS.items():
        if head.startswith(stem):
            return style
    return None

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
    r"^step\s+(?P<num>\d+)\s*:\s*(?P<src>\w+)\s+(?P<verb>[a-z][a-z \-]*?)\s+(?P<dst>\w+)(?:\s+(?P<touch>one-touch|two-touch|first-time))?\s*$"
)
_VERB_DECL_RE = re.compile(
    r"^verb\s+(?P<word>[a-z\-]+)\s*=\s*(?P<canon>[a-z]+)\s*$")
_POINT_RE = re.compile(r"^point\s*:\s*(?P<text>.+?)\s*$")
_VARIATION_RE = re.compile(r"^variation\s*:\s*(?P<text>.+?)\s*$")
_OPTION_RE = re.compile(
    r"^or\s*:\s*(?P<src>\w+)\s+(?P<verb>[a-z][a-z \-]*?)\s+(?P<dst>\w+)\s*$"
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
    declared_verbs: dict[str, str] = {}
    last_step = 0

    for idx, raw_line in enumerate(dsl.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue  # model's plan comment — kept in raw logs for debugging, not data
        vm = _VERB_DECL_RE.match(line)
        if vm:
            craw = vm.group("canon").lower()
            canon = (craw if craw in _CANON_STYLES
                     else craw.rstrip("s") if craw.rstrip("s") in _CANON_STYLES
                     else resolve_verb(craw + " to", {})
                     or resolve_verb(craw + " from", {})
                     or resolve_verb(craw + " at", {}))
            if canon is None:
                raise DSLParseError(idx, f"verb declaration maps to unknown "
                                    f"class {vm.group('canon')!r} — use one of "
                                    "passes/dribbles/runs/shoots/receives/"
                                    "throws/tosses/heads")
            declared_verbs[vm.group("word").lower().rstrip("s")] = canon
            continue

        head = line.split(None, 1)[0].rstrip(":")

        if head in ELEMENT_KEYWORDS:
            el = _parse_element(line, idx)
            if el["label"] in seen_ids:
                raise DSLParseError(idx, f"duplicate element id {el['label']}")
            seen_ids.add(el["label"])
            elements.append(el)
            continue

        if head == "step":
            path, step_num = _parse_step(line, idx, declared_verbs)
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
                raise DSLParseError(idx, f"malformed option {line!r} — format: `or: ID verb ID`")
            if last_step == 0:
                raise DSLParseError(idx, "or: must follow a step")
            ov = m.group("verb").strip()
            ostyle = resolve_verb(ov, declared_verbs)
            if ostyle is None:
                raise DSLParseError(idx, f"verb {ov!r} has no known meaning")
            paths.append({
                "from": m.group("src"),
                "to": m.group("dst"),
                "style": ostyle,
                "verb": ov,
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


def _parse_step(line: str, idx: int, declared_verbs: dict[str, str]) -> tuple[dict[str, Any], int]:
    m = _STEP_RE.match(line)
    if not m:
        raise DSLParseError(idx, f"malformed step {line!r} — format: `step N: ID verb ID`")
    verb = m.group("verb").strip()
    style = resolve_verb(verb, declared_verbs)
    if style is None:
        raise DSLParseError(
            idx, f"verb {verb!r} has no known meaning — declare it first "
            f"(`verb {verb.split()[0]} = passes|dribbles|runs|shoots|receives"
            f"|throws|tosses|heads`) or use a stock verb")
    step_num = int(m.group("num"))
    path = {
        "from": m.group("src"),
        "to": m.group("dst"),
        "style": style,
        "verb": verb,
        "step": step_num,
    }
    if m.group("touch"):
        path["touches"] = 1 if m.group("touch") in ("one-touch", "first-time") else 2
    return path, step_num
