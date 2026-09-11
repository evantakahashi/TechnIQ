"""Authored animation: the model writes the phase timeline itself — every
track, beat, and caption — the way it does unconstrained in chat. The machine
referees: viewer-sim lint + fidelity-to-drill checks, one retry with findings,
then fallback to the rule-compiled cut.

This is the convergence point of the whole investigation: freeform authorship
(where the felt quality lives) inside validated rails (where the app lives).
"""
from __future__ import annotations

import json
import math
import re
from typing import Any, Callable

from drill_timeline import compile_timeline
from drill_director import direct_timeline
from drill_critic import critique
from eval.anim_lint import lint

BALL = "__ball__"

_SCHEMA_EXAMPLE = '''{"phases":[
 {"d":600,"tracks":{"__ball__":[[3,7.5],[3,7.5]],"P1":[[3,7.5],[3,7.5]]},
  "hips":{"P1":[1,0]},"eye":{"P1":[0.9,0.44]},
  "label":"Ball's coming — check your shoulder","ease":"lin","kind":"action","step":1},
 {"d":840,"tracks":{"__ball__":[[3,7.5],[9.1,7.3]],"P2":[[10.5,9],[9.6,7.9]]},
  "hips":{"P2":[-0.99,0.1]},
  "label":"Meet it — cushion across your body","ease":"out","kind":"action","step":1},
 {"d":1100,"tracks":{"__ball__":[[9.1,7.3],[3.2,7.4]],"P2":[[9.6,7.9],[3.9,7.6]]},
  "hips":{},"label":"Bring it back — that's your rest","ease":"lin","kind":"fade","step":2}
]}'''

AUTHOR_STATIC = """You are animating a youth soccer drill as a short looping film.
You author EVERY movement: the ball's flights and touches, each player's runs, the
timing, the facing, the narration. This is the same craft as your best hand-made
drill animations. All coordinates are METERS on the field given below.

OUTPUT: ONLY a JSON object {"phases": [...]}. Phase schema (all coords meters):
""" + _SCHEMA_EXAMPLE + """
- tracks: "__ball__" plus any player labels; [from,to] each. Untracked = stands still.
- kind: "action" | "fade" (reset plumbing — brisk, ball always accompanied) | "tossup"
  (self-toss: ball pulses in place) | "outcome" (a dashed or-branch escape, at the END).
- step: the source step number (arrows highlight from it).

CRAFT (your own style, made explicit):
- A still anticipation beat before serves; "eye" shows where they scan.
- Feeds land ~1m short; the receiver's TOUCH carries the ball on, angled to the exit.
- A short plant beat before strikes. Key moment of the drill breathes longest.
- Micro-shape movement: touches break across the body; receivers arrive ON the ball;
  defenders lean and arrive at arm's length, never into bodies.
- PACING (ms per meter): pass/throw ~42, shot ~28, dribble ~95, run ~80, fade ~85.
  Never faster. Phases 300-2600ms.
- Resets: the ball is BROUGHT by someone, never rolls home alone; captions coach
  ("Bring it back — that's your rest").
- The loop must END exactly at its starting state (positions AND ball).
- Captions: second person, technique and perception, no numbers.
"""

_AUTHOR_TAIL = """
THE DRILL (fixed — your film must faithfully show these actions in order):
Field: {W}x{L} meters (x 0-{W}, y 0-{L}).
Cast: {cast}
Elements: {elements}
Steps (fx,fy -> tx,ty are the true positions):
{steps}
Coaching voice (mine for captions): {coaching}

{n_phases_hint} phases feels right for this drill. Reply with the JSON only."""


def _fidelity(drill: dict[str, Any], timeline: dict[str, Any]) -> list[str]:
    """The film must actually show the drill: every visible step's endpoint
    is visited by the right thing (ball for ball actions, actor for moves)."""
    problems = []
    phases = timeline.get("phases") or []

    def visited(label: str, target: tuple[float, float]) -> bool:
        for p in phases:
            tr = p.get("tracks", {}).get(label)
            if tr and math.hypot(tr[1][0] - target[0],
                                 tr[1][1] - target[1]) < 2.0:
                return True
        return False

    for p in drill.get("diagram", {}).get("paths", []):
        if p.get("alt") or p.get("reset") or p.get("fx") is None:
            continue
        tgt = (p["tx"], p["ty"])
        style = p.get("style")
        if style in ("pass", "toss", "throw", "shoot", "shot", "header"):
            if not visited(BALL, tgt):
                problems.append(f"step {p.get('step')}: the ball never reaches "
                                f"{p.get('to')} at ({tgt[0]:.0f},{tgt[1]:.0f})")
        elif style in ("run", "dribble"):
            if not visited(p.get("from"), tgt):
                problems.append(f"step {p.get('step')}: {p.get('from')} never "
                                f"gets to {p.get('to')}")
    return problems


def _sanitize(timeline: dict[str, Any], drill: dict[str, Any]) -> dict[str, Any] | None:
    phases = timeline.get("phases")
    if not isinstance(phases, list) or not phases:
        return None
    labels = {e.get("label") for e in
              drill.get("diagram", {}).get("elements", [])} | {BALL}
    clean = []
    for p in phases:
        if not isinstance(p, dict):
            return None
        tracks = p.get("tracks")
        if not isinstance(tracks, dict):
            return None
        t2 = {}
        for lbl, tr in tracks.items():
            if lbl not in labels:
                continue  # unknown actor — drop the track, keep the phase
            try:
                t2[lbl] = [[float(tr[0][0]), float(tr[0][1])],
                           [float(tr[1][0]), float(tr[1][1])]]
            except (TypeError, ValueError, IndexError):
                return None
        kind = p.get("kind") if p.get("kind") in \
            ("action", "fade", "tossup", "outcome") else "action"
        # pacing is physics, not art: raise the duration until the fastest
        # track obeys the speed cap for this phase kind (never fail on it)
        vmax = {"fade": 13.0, "outcome": 11.0, "action": 36.0,
                "tossup": 36.0}[kind]
        mx = max((math.hypot(tr[1][0] - tr[0][0], tr[1][1] - tr[0][1])
                  for tr in t2.values()), default=0.0)
        d_min = int(mx / vmax * 1000) + 1 if mx > 0.5 else 300
        clean.append({
            "d": int(max(300, max(d_min, min(2600, p.get("d", 700))))),
            "tracks": t2,
            "hips": p.get("hips") or {},
            "eye": p.get("eye") or None,
            "label": str(p.get("label", ""))[:90],
            "ease": p.get("ease") if p.get("ease") in ("lin", "out") else "lin",
            "kind": kind,
            "step": p.get("step"),
        })
    return {"phases": clean}


def author_timeline(drill: dict[str, Any],
                    llm_call: Callable[[str], str]) -> dict[str, Any]:
    diagram = drill.get("diagram", {})
    field = diagram.get("field", {})
    els = "; ".join(
        f"{e.get('type')} {e.get('label')} ({e.get('x'):.0f},{e.get('y'):.0f})"
        + (f" w={e.get('width')}" if e.get('width') else "")
        for e in diagram.get("elements", []))
    cast = ", ".join(
        f"{e['label']}={'You' if e.get('role') == 'worker' else (e.get('display_label') or e.get('role', 'player'))}"
        for e in diagram.get("elements", []) if e.get("type") == "player")
    steps = "\n".join(
        f"  s{p.get('step')}{' [reset]' if p.get('reset') else (' [or]' if p.get('alt') else '')}: "
        f"{p.get('from')} {p.get('verb') or p.get('style')} {p.get('to')} "
        f"({p.get('fx'):.1f},{p.get('fy'):.1f})->({p.get('tx'):.1f},{p.get('ty'):.1f})"
        for p in diagram.get("paths", []) if p.get("fx") is not None)
    coaching = " | ".join((drill.get("coaching_points") or [])[:6])
    n_paths = sum(1 for p in diagram.get("paths", []) if not p.get("alt"))
    prompt = AUTHOR_STATIC + _AUTHOR_TAIL.format(
        W=int(field.get("width", 20)), L=int(field.get("length", 15)),
        cast=cast, elements=els, steps=steps, coaching=coaching,
        n_phases_hint=max(6, min(18, n_paths + 3)))

    findings_prev: list[str] = []
    best = None
    for attempt in range(2):
        p = prompt if not findings_prev else (
            prompt + "\n\nYOUR PREVIOUS CUT HAD THESE DEFECTS — fix them:\n"
            + "\n".join(f"- {f}" for f in findings_prev[:10]))
        raw = llm_call(p)
        m = re.search(r"\{.*\}", raw, re.S)
        if not m:
            continue
        try:
            tl = _sanitize(json.loads(m.group(0)), drill)
        except ValueError:
            continue
        if tl is None:
            continue
        probe = dict(drill)
        probe["animation"] = tl
        findings = lint(probe) + _fidelity(drill, tl)
        crit = {"blockers": [], "notes": []}
        if not findings:
            crit = critique(drill, tl, llm_call)  # the sense referee
            findings = list(crit["blockers"])
        if not findings:
            if attempt == 0 and crit["notes"]:
                # one polish retake on taste notes — the noted cut still ships
                best = tl
                findings_prev = crit["notes"]
                continue
            tl["authored"] = True
            return tl
        findings_prev = findings
    if best is not None:
        best["authored"] = True  # noted but sound — ship the authored cut
        return best
    # referee couldn't clear it — the rule-compiled cut is the safe fallback
    return direct_timeline(drill, compile_timeline(drill), llm_call)
