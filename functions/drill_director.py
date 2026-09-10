"""Director pass: a model EDITS the compiled timeline — as data, within rails.

The compiler stages competently by rule; the director makes it a story:
per-drill captions, pacing, an inserted beat where the drill's point lives.
The director may ONLY touch whitelisted fields — movement tracks are
immutable, so the ball-continuity guarantees survive by construction.

Editable per phase:  d (300..2600ms), label (<=90 chars), eye, hips.
Insertable:          still "beat" phases (<=800ms) between existing phases.
Everything else:     ignored on merge.
"""
from __future__ import annotations

import json
import math
import re
from typing import Any, Callable

_DIRECTOR_PROMPT = """You are directing a short looping animation of a youth soccer drill.
The choreography (who moves where) is FIXED. You direct pacing and narration only.

DRILL: {name}
SKILL: {skill}
The player markers: {cast}
COACHING POINTS (source material for narration):
{coaching}

CURRENT TIMELINE — one line per phase: [index] kind duration_ms "caption":
{timeline}

Rewrite the direction. Reply with ONLY a JSON array, one object per edit:
  {{"i": <phase index>, "d": <new ms 300-2600>, "label": "<caption, <=90 chars>"}}
  {{"insert_after": <phase index>, "d": <ms <=800>, "label": "<caption>"}}   (a still beat)

Direction rules:
- Narrate to "you" (the worker). Name the story of THIS drill: what to feel, see, decide.
- The drill's key moment (the turn, the touch, the save) gets a slightly longer phase
  and the sharpest caption. Plumbing (resets) stays brisk.
- Captions never contain numbers, sets, or reps — technique and perception only.
- At most 2 inserted beats. Edit only phases that need it. No other fields."""


def _cast(drill: dict[str, Any]) -> str:
    out = []
    for e in drill.get("diagram", {}).get("elements", []):
        if e.get("type") == "player":
            nm = e.get("display_label") or (
                "You" if e.get("role") == "worker" else e.get("role", "player"))
            out.append(f"{e['label']}={nm}")
    return ", ".join(out)


def direct_timeline(drill: dict[str, Any], timeline: dict[str, Any],
                    llm_call: Callable[[str], str]) -> dict[str, Any]:
    phases = [dict(p) for p in timeline.get("phases", [])]
    lines = [f'[{i}] {p["kind"]} {p["d"]}ms "{p.get("label", "")}"'
             for i, p in enumerate(phases)]
    prompt = _DIRECTOR_PROMPT.format(
        name=drill.get("name") or drill.get("_case", {}).get("id", "drill"),
        skill=drill.get("_case", {}).get("request", {}).get(
            "skill_description", ""),
        cast=_cast(drill),
        coaching="\n".join(f"- {c}" for c in
                           (drill.get("coaching_points") or [])[:9]),
        timeline="\n".join(lines),
    )
    raw = llm_call(prompt)
    m = re.search(r"\[.*\]", raw, re.S)
    if not m:
        return timeline  # no parse — keep the compiled cut
    try:
        edits = json.loads(m.group(0))
    except ValueError:
        return timeline

    inserts: list[tuple[int, dict[str, Any]]] = []
    for e in edits:
        if not isinstance(e, dict):
            continue
        if "insert_after" in e:
            idx = e.get("insert_after")
            if not isinstance(idx, int) or not 0 <= idx < len(phases):
                continue
            anchor = phases[idx]
            still = {lbl: [tr[1], tr[1]] for lbl, tr in
                     anchor.get("tracks", {}).items()}
            inserts.append((idx, {
                "d": int(max(300, min(800, e.get("d", 550)))),
                "tracks": still, "hips": anchor.get("hips", {}),
                "label": str(e.get("label", ""))[:90],
                "ease": "lin", "kind": "action", "step": anchor.get("step"),
            }))
            continue
        idx = e.get("i")
        if not isinstance(idx, int) or not 0 <= idx < len(phases):
            continue
        if isinstance(e.get("d"), (int, float)):
            mx = max((math.hypot(tr[1][0] - tr[0][0], tr[1][1] - tr[0][1])
                      for tr in phases[idx].get("tracks", {}).values()),
                     default=0.0)
            floor = max(300, int(mx * (85 if phases[idx].get("kind") == "fade"
                                       else 30)))
            phases[idx]["d"] = int(max(floor, min(2600, e["d"])))
        if isinstance(e.get("label"), str) and e["label"].strip():
            lab = e["label"].strip()[:90]
            if not any(ch.isdigit() for ch in lab):
                phases[idx]["label"] = lab
    for idx, ph in sorted(inserts, key=lambda x: -x[0])[:2]:
        phases.insert(idx + 1, ph)

    # referee: movement untouched by construction; sanity-check continuity
    last = None
    for p in phases:
        tr = p.get("tracks", {}).get("__ball__")
        if tr is None:
            continue
        if last is not None and p.get("kind") == "action" \
                and math.hypot(tr[0][0] - last[0], tr[0][1] - last[1]) > 0.25:
            return timeline  # a bad merge slipped through — keep compiled cut
        last = tr[1]
    return {"phases": phases}
