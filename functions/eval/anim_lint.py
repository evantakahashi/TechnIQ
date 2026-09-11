"""Viewer-sim linter: replay a timeline like the engine and flag artifacts.

Classes:
  CONT-P   player track starts away from where they were last rendered
  CONT-B   ball track starts away from where it was last rendered
  LOOP     loop boundary teleports (end state != start state)
  ALONE    a fade moves the ball with no companion alongside
  COLLIDE  two players pass within 0.7m mid-phase
  STALL    an action phase where nothing meaningfully moves
  SPEED    implied speed outside the style's plausible band
  CAPTION  empty or consecutively duplicated captions
"""
from __future__ import annotations

import math
from typing import Any

BALL = "__ball__"

_SPEED_BAND = {  # m/s plausible bands by phase kind
    "fade": (1.0, 14.0),
    "outcome": (1.0, 12.0),
    "action": (0.0, 38.0),
    "homeglide": (1.0, 14.0),
}


def _d(a, b):
    return math.hypot(b[0] - a[0], b[1] - a[1])


def _lerp(a, b, k):
    return [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k]


def lint(drill: dict[str, Any], loops: int = 2) -> list[str]:
    anim = drill.get("animation") or {}
    phases_all = anim.get("phases") or []
    if not phases_all:
        return ["NOANIM: drill has no timeline"]
    elements = drill.get("diagram", {}).get("elements", [])
    home = {e["label"]: [float(e["x"]), float(e["y"])]
            for e in elements if e.get("type") == "player"}
    defenders = {e["label"] for e in elements if e.get("role") == "defender"}
    goal_boxes = []
    for e in elements:
        if e.get("type") == "goal":
            half = float(e.get("width") or 7.32) / 2
            goal_boxes.append((float(e["x"]), float(e["y"]), half))
    main = [p for p in phases_all if p.get("kind") != "outcome"]
    outs = [p for p in phases_all if p.get("kind") == "outcome"]
    first_ball = next((p["tracks"][BALL][0] for p in main
                       if BALL in p.get("tracks", {})), None)

    findings: list[str] = []
    last: dict[str, list[float]] = {lbl: list(xy) for lbl, xy in home.items()}
    seen_actor: set = set()
    prev_label = None
    cid = drill.get("_case", {}).get("id", "?")

    def run_phase(p, pi):
        nonlocal prev_label
        tracks = p.get("tracks", {})
        kind = p.get("kind", "action")
        dur = p.get("d", 0) / 1000.0
        # continuity in
        for lbl, tr in tracks.items():
            first_sight = lbl not in seen_actor
            seen_actor.add(lbl)
            tol = 1.2 if first_sight else 0.35  # staging licence at curtain-up
            if lbl in last and _d(tr[0], last[lbl]) > tol \
                    and kind not in ("homeglide",):
                tag = "CONT-B" if lbl == BALL else "CONT-P"
                where = ("their drawn marker" if first_sight
                         else "where they were")
                findings.append(
                    f"{tag} {cid} phase{pi} '{p.get('label','')[:34]}': "
                    f"{lbl} starts {_d(tr[0], last[lbl]):.1f}m from {where} "
                    f"({last[lbl][0]:.1f},{last[lbl][1]:.1f})")
        # aloneness (fades only — kicks fly alone legitimately)
        if kind == "fade" and BALL in tracks and _d(*tracks[BALL]) > 1.5:
            bt = tracks[BALL]
            carried = any(l != BALL and _d(t2[0], bt[0]) < 1.8
                          and _d(t2[1], bt[1]) < 1.8
                          for l, t2 in tracks.items())
            if not carried:
                findings.append(f"ALONE {cid} phase{pi}: ball travels "
                                f"{_d(*bt):.0f}m unaccompanied in a reset")
        # collisions mid-phase
        labs = [l for l in tracks if l != BALL]
        for x in range(len(labs)):
            for y in range(x + 1, len(labs)):
                if labs[x] in defenders and labs[y] in defenders:
                    continue  # a closing trap converges by design
                for k in (0.3, 0.5, 0.7):
                    pa = _lerp(*tracks[labs[x]], k)
                    pb = _lerp(*tracks[labs[y]], k)
                    if _d(pa, pb) < 0.7:
                        findings.append(
                            f"COLLIDE {cid} phase{pi}: {labs[x]} and "
                            f"{labs[y]} merge mid-phase")
                        break
                else:
                    continue
                break
        # stalls / speed
        mx = max((_d(*tr) for tr in tracks.values()), default=0.0)
        if kind == "action" and mx < 0.25 and not p.get("eye") \
                and p.get("kind") != "tossup" and p.get("d", 0) > 900:
            findings.append(f"STALL {cid} phase{pi}: "
                            f"'{p.get('label','')[:40]}' nothing moves")
        if dur > 0 and mx > 0.5:
            lo, hi = _SPEED_BAND.get(kind, (0.0, 32.0))
            v = mx / dur
            if not lo <= v <= hi:
                findings.append(f"SPEED {cid} phase{pi}: {v:.1f} m/s "
                                f"({kind}, '{p.get('label','')[:30]}')")
        # nobody lives inside the goal: a player track ENDING in a goal's
        # mouth box reads as "receiving the ball in the goal"
        for lbl, tr in tracks.items():
            if lbl == BALL or kind == "fade":
                continue  # fetching the ball out of the net is a reset, not play
            ex, ey = tr[1]
            for gx, gy, half in goal_boxes:
                if (abs(ex - gx) < 1.6 and abs(ey - gy) <= half) or \
                   (abs(ey - gy) < 1.6 and abs(ex - gx) <= half):
                    findings.append(
                        f"INGOAL {cid} phase{pi}: {lbl} ends up inside the "
                        f"goal mouth ('{p.get('label','')[:30]}')")
                    break
        # captions
        lab = (p.get("label") or "").strip()
        if not lab:
            findings.append(f"CAPTION {cid} phase{pi}: empty")
        elif lab == prev_label and kind == "action":
            findings.append(f"CAPTION {cid} phase{pi}: repeats '{lab[:36]}'")
        prev_label = lab
        # apply
        for lbl, tr in tracks.items():
            last[lbl] = list(tr[1])

    for loop in range(loops):
        seq = list(main)
        if outs:
            seq.append(outs[loop % len(outs)])
        for pi, p in enumerate(seq):
            run_phase(p, pi)
        if outs:
            # engine synthesizes the home glide lazily, AFTER the escape ran
            hg_tracks = {lbl: [list(last.get(lbl, hx)), list(hx)]
                         for lbl, hx in home.items()}
            if first_ball is not None and BALL in last:
                hg_tracks[BALL] = [list(last[BALL]), list(first_ball)]
            gmax = max((_d(*tr) for tr in hg_tracks.values()), default=0.0)
            hg = {"kind": "homeglide",
                  "d": max(500, min(2600, int(gmax * 85))),
                  "tracks": hg_tracks, "label": "Reset — swap and go again"}
            run_phase(hg, len(seq))
            seq.append(hg)
        # loop boundary teleports
        first = seq[0]
        for lbl, tr in first.get("tracks", {}).items():
            if lbl in last and _d(tr[0], last[lbl]) > 0.5:
                findings.append(
                    f"LOOP {cid}: {lbl} teleports {_d(tr[0], last[lbl]):.1f}m "
                    "at the loop boundary")
        if loop == 0 and not outs:
            break  # deterministic without rotation — one loop suffices
    # dedupe
    seen, out = set(), []
    for f in findings:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return out
