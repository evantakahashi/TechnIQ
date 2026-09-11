"""Critic model: a second pair of eyes that judges SENSE, not geometry.

The geometric linter catches physics (teleports, ghost balls); this referee
watches the film the way Evan does — "why is the player receiving the ball
in the goal", "the return is basic for an intermediate drill" — and returns
findings the author can fix. Experimental by design; findings feed the
authoring retry, never crash the pipeline.
"""
from __future__ import annotations

import json
import re
from typing import Any, Callable

BALL = "__ball__"

CRITIC_STATIC = """You are a youth soccer coach reviewing a drill's looping animation
as a harsh but fair critic. You judge SENSE and CRAFT, not geometry (a machine
already checked physics). The reviewer whose standards you apply says things like:
"why is the player receiving the ball in the goal — makes no sense", "the dribble
back is basic for an intermediate drill, it should have more nuance", "not game
realistic", "nothing shows it's a chest control".

Look for:
- Actions that make no soccer sense (standing/receiving inside the goal, serving
  from silly spots, movements no coach would ask for)
- The advertised skill not being what the film shows
- Reps that are flat/basic for the player's level — returns and resets can carry
  nuance (a touch through a gate on the way back) instead of a bare jog
- Captions that don't match what is happening

Reply with ONLY a JSON array. Each finding is {"blocker": true|false, "note": "<one
blunt sentence>"}. blocker=true ONLY for things that make no soccer sense or show
the wrong skill — a viewer would say "what? that's wrong" — AND that the animator
can fix by changing movement tracks, timing, or captions. The medium is a 2D
top-down film: ball HEIGHT cannot be drawn (captions and the toss-pulse carry it),
and the drill's steps/positions are FIXED data — never blocker either. blocker=false
for craft upgrades (flat reps, caption nits, missed nuance). [] = clean pass.
Max 4 findings. Do NOT invent geometry problems; judge meaning and craft."""


def _script(drill: dict[str, Any], timeline: dict[str, Any]) -> str:
    els = {e.get("label"): e for e in drill.get("diagram", {}).get("elements", [])}
    def near_what(x, y):
        best, bd = None, 3.5
        for lbl, e in els.items():
            try:
                d = ((e["x"] - x) ** 2 + (e["y"] - y) ** 2) ** 0.5
            except (KeyError, TypeError):
                continue
            if d < bd:
                best, bd = f"{e.get('type')} {lbl}", d
        return f" (near {best})" if best else ""
    lines = []
    for i, p in enumerate(timeline.get("phases", [])):
        moves = []
        for lbl, tr in p.get("tracks", {}).items():
            (x0, y0), (x1, y1) = tr
            dist = ((x1 - x0) ** 2 + (y1 - y0) ** 2) ** 0.5
            who = "ball" if lbl == BALL else lbl
            if dist < 0.3:
                moves.append(f"{who} stands at ({x0:.0f},{y0:.0f}){near_what(x0, y0)}")
            else:
                moves.append(f"{who} {dist:.0f}m to ({x1:.0f},{y1:.0f}){near_what(x1, y1)}")
        lines.append(f'[{i}] {p.get("kind")} "{p.get("label", "")}": ' + "; ".join(moves))
    return "\n".join(lines)


def critique(drill: dict[str, Any], timeline: dict[str, Any],
             llm_call: Callable[[str], str]) -> list[str]:
    req = drill.get("_case", {}).get("request", {})
    prompt = (CRITIC_STATIC + "\n\nDRILL: "
              + str(req.get("skill_description", drill.get("name", "")))
              + f" — {req.get('experience_level', '?')}, age {req.get('player_age', '?')}"
              + "\nELEMENTS: " + "; ".join(
                  f"{e.get('type')} {e.get('label')} ({e.get('x'):.0f},{e.get('y'):.0f})"
                  for e in drill.get("diagram", {}).get("elements", []))
              + "\n\nTHE FILM, phase by phase:\n" + _script(drill, timeline)
              + "\n\nFindings (JSON array only):")
    try:
        raw = llm_call(prompt)
        m = re.search(r"\[.*\]", raw, re.S)
        if not m:
            return {"blockers": [], "notes": []}
        out = json.loads(m.group(0))
        blockers, notes = [], []
        for f in out[:4]:
            if isinstance(f, dict):
                (blockers if f.get("blocker") else notes).append(
                    str(f.get("note", ""))[:160])
            elif isinstance(f, str):
                notes.append(f[:160])
        return {"blockers": blockers, "notes": notes}
    except Exception:
        return {"blockers": [], "notes": []}  # the critic never crashes the pipeline
