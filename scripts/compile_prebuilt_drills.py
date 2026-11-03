#!/usr/bin/env python3
"""Compile the 10 pre-built drills into Swift.

Source of truth: scripts/prebuilt_drills/drills.json (hand-written content + DSL).
Each DSL runs through the same deterministic pipeline the drill generator uses
(parse_dsl -> post_process -> crop -> annotate -> repair -> validate_drill ->
compile_timeline; no LLM), then everything is written to
TechnIQ/Models/PrebuiltDrillCatalog+Generated.swift.

Usage:
  python3 scripts/compile_prebuilt_drills.py          # regenerate the Swift file
  python3 scripts/compile_prebuilt_drills.py --check  # exit 1 if the Swift file is stale

Fails loudly (exit 1) on any content or validator error.
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FUNCTIONS = ROOT / "functions"
DRILLS_JSON = ROOT / "scripts" / "prebuilt_drills" / "drills.json"
SWIFT_OUT = ROOT / "TechnIQ" / "Models" / "PrebuiltDrillCatalog+Generated.swift"

if str(FUNCTIONS) not in sys.path:
    sys.path.insert(0, str(FUNCTIONS))

from dsl_parser import parse_dsl  # noqa: E402
from drill_post_processor import (  # noqa: E402
    annotate_path_positions,
    crop_field_to_content,
    post_process_drill,
    repair_short_passes,
)
from drill_timeline import compile_timeline  # noqa: E402
from drill_validator import validate_drill  # noqa: E402

PLAYER_AGE = 13
CATEGORIES = {"Technical", "Physical", "Tactical"}
KINDS = {"completions", "benchmark", "reps"}
BENCHMARKS = {"juggling", "wallPasses30", "toeTaps30"}
REQUIRED = ("key", "name", "category", "difficulty", "description", "targetSkills",
            "durationMinutes", "steps", "coachingPoint", "cue", "equipment", "space",
            "unlockCriteria", "dsl", "filmLabels")


class ContentError(ValueError):
    pass


def _field_for(diagram: dict) -> dict:
    """Pitch big enough for the authored coordinates; a goal sits on the far edge."""
    elements = diagram["elements"]
    goals = [e for e in elements if e["type"] == "goal"]
    others = [e for e in elements if e["type"] != "goal"]
    width = max([20.0] + [e["x"] + 3 for e in others] + [e["x"] for e in goals])
    length = max([15.0] + [e["y"] + 2 for e in elements])
    return {"width": float(math.ceil(width)), "length": float(math.ceil(length))}


def check_content(d: dict) -> None:
    key = d.get("key", "?")
    for field in REQUIRED:
        if field not in d:
            raise ContentError(f"{key}: missing {field}")
    if d["category"] not in CATEGORIES:
        raise ContentError(f"{key}: category {d['category']!r}")
    if not 1 <= int(d["difficulty"]) <= 5:
        raise ContentError(f"{key}: difficulty out of range")
    if not 3 <= len(d["steps"]) <= 6:
        raise ContentError(f"{key}: needs 3-6 steps, has {len(d['steps'])}")
    for text_field in ("coachingPoint", "cue", "space", "description", "name"):
        if not str(d[text_field]).strip():
            raise ContentError(f"{key}: empty {text_field}")
    if not d["equipment"] or not all(str(e).strip() for e in d["equipment"]):
        raise ContentError(f"{key}: equipment")
    if any("," in str(e) for e in d["equipment"]):
        raise ContentError(f"{key}: equipment items are stored comma-joined; no commas inside an item")
    if len(d["cue"].split()) > 10:
        raise ContentError(f"{key}: cue longer than 10 words")
    blob = json.dumps(d).lower()
    if "follow standard" in blob or "protocol" in blob:
        raise ContentError(f"{key}: placeholder text")
    uc = d["unlockCriteria"]
    if uc.get("kind") not in KINDS or int(uc.get("times", 0)) < 1:
        raise ContentError(f"{key}: unlockCriteria")
    if uc["kind"] == "benchmark" and uc.get("benchmark") not in BENCHMARKS:
        raise ContentError(f"{key}: unlockCriteria benchmark")
    if uc["kind"] != "completions" and int(uc.get("target", 0)) < 1:
        raise ContentError(f"{key}: unlockCriteria target")


def compile_drill(d: dict) -> tuple[dict, dict]:
    """Run one drill's DSL through the deterministic pipeline -> (diagram, animation)."""
    drill = parse_dsl(d["dsl"])
    drill["diagram"]["field"] = _field_for(drill["diagram"])
    drill["equipment"] = list(d["equipment"])
    drill["category"] = d["category"].lower()
    drill["is_duel"] = bool(d.get("isDuel"))
    drill, _warnings = post_process_drill(drill, player_age=PLAYER_AGE)
    crop_field_to_content(drill)
    annotate_path_positions(drill)
    repair_short_passes(drill)
    validate_drill(drill)
    animation = compile_timeline(drill)
    phases = animation.get("phases") or []
    if not phases:
        raise ContentError(f"{d['key']}: compiled film has no phases")
    # Hand-written captions replace the compiler's generic ones (which name
    # elements like "C1"); a count mismatch means the DSL changed shape.
    labels = d["filmLabels"]
    if len(labels) != len(phases) or not all(str(x).strip() for x in labels):
        raise ContentError(f"{d['key']}: filmLabels needs {len(phases)} captions, has {len(labels)}")
    for phase, label in zip(phases, labels):
        phase["label"] = label
    if not drill["diagram"].get("elements"):
        raise ContentError(f"{d['key']}: diagram has no elements")
    return drill["diagram"], animation


def load_drills() -> list[dict]:
    drills = json.loads(DRILLS_JSON.read_text(encoding="utf-8"))
    if len(drills) != 10:
        raise ContentError(f"expected 10 drills, found {len(drills)}")
    keys = [d.get("key") for d in drills]
    names = [d.get("name") for d in drills]
    if len(set(keys)) != len(keys) or len(set(names)) != len(names):
        raise ContentError("duplicate key or name")
    for d in drills:
        check_content(d)
    return drills


def _swift_string(value: str) -> str:
    out = []
    for ch in value:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append("\\u{%x}" % ord(ch))
        else:
            out.append(ch)
    return '"' + "".join(out) + '"'


def _swift_list(values: list[str], indent: str) -> str:
    if not values:
        return "[]"
    inner = ",\n".join(indent + "    " + _swift_string(v) for v in values)
    return "[\n" + inner + "\n" + indent + "]"


def _compact(obj) -> str:
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def render_swift(drills: list[dict]) -> str:
    entries = []
    ind = "        "
    for d in drills:
        diagram, animation = compile_drill(d)
        uc = d["unlockCriteria"]
        bench = f".{uc['benchmark']}" if uc.get("benchmark") else "nil"
        video = _swift_string(d["videoClip"]) if d.get("videoClip") else "nil"
        entries.append(
            f"{ind}PrebuiltDrill(\n"
            f"{ind}    key: {_swift_string(d['key'])},\n"
            f"{ind}    name: {_swift_string(d['name'])},\n"
            f"{ind}    category: {_swift_string(d['category'])},\n"
            f"{ind}    difficulty: {int(d['difficulty'])},\n"
            f"{ind}    summary: {_swift_string(d['description'])},\n"
            f"{ind}    targetSkills: {_swift_list(d['targetSkills'], ind + '    ')},\n"
            f"{ind}    durationMinutes: {int(d['durationMinutes'])},\n"
            f"{ind}    steps: {_swift_list(d['steps'], ind + '    ')},\n"
            f"{ind}    coachingPoint: {_swift_string(d['coachingPoint'])},\n"
            f"{ind}    cue: {_swift_string(d['cue'])},\n"
            f"{ind}    equipment: {_swift_list(d['equipment'], ind + '    ')},\n"
            f"{ind}    space: {_swift_string(d['space'])},\n"
            f"{ind}    unlockCriteria: UnlockCriteria(kind: .{uc['kind']}, target: {int(uc.get('target', 0))}, "
            f"times: {int(uc['times'])}, benchmark: {bench}),\n"
            f"{ind}    videoClip: {video},\n"
            f"{ind}    dsl: {_swift_string(d['dsl'])},\n"
            f"{ind}    diagramJSON: {_swift_string(_compact(diagram))},\n"
            f"{ind}    animationJSON: {_swift_string(_compact(animation))}\n"
            f"{ind})"
        )
    body = ",\n".join(entries)
    return (
        "// GENERATED by scripts/compile_prebuilt_drills.py from scripts/prebuilt_drills/drills.json.\n"
        "// Do not edit by hand: change the JSON and rerun the script.\n"
        "// swiftlint:disable line_length\n\n"
        "import Foundation\n\n"
        "extension PrebuiltDrillCatalog {\n"
        "    static let all: [PrebuiltDrill] = [\n"
        f"{body}\n"
        "    ]\n"
        "}\n"
        "// swiftlint:enable line_length\n"
    )


def main(argv: list[str]) -> int:
    try:
        swift = render_swift(load_drills())
    except Exception as exc:  # content, DSL parse or validator failure
        print(f"compile_prebuilt_drills: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1
    if "--check" in argv:
        current = SWIFT_OUT.read_text(encoding="utf-8") if SWIFT_OUT.exists() else ""
        if current != swift:
            print("PrebuiltDrillCatalog+Generated.swift is stale: run "
                  "python3 scripts/compile_prebuilt_drills.py", file=sys.stderr)
            return 1
        print("up to date")
        return 0
    SWIFT_OUT.write_text(swift, encoding="utf-8")
    print(f"wrote {SWIFT_OUT.relative_to(ROOT)} ({len(swift)} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
