"""Viewer-sim linter: replay a timeline like the engine and flag artifacts.

Classes:
  CONT-P   player track starts away from where they were last rendered
  CONT-B   ball track starts away from where it was last rendered
  LOOP     loop boundary teleports (end state != start state)
  ALONE    a fade moves the ball with no companion alongside
  COLLIDE  moving players pass within 0.7m of another player
  STALL    an action phase where nothing meaningfully moves
  SPEED    implied speed outside the style's plausible band
  CAPTION  empty or consecutively duplicated captions
  FACE     receiver faces away from an arriving feed
  RHYTHM   four unequal movements are flattened to the same duration
  RELEASE  ball launches away from every player and rebound surface
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


def _closest_approach(a, b):
    """Minimum separation for tracks sharing the renderer's easing curve.

    Easing changes *when* a crossing happens, not the minimum separation.
    Solving relative motion catches crossings between sampled frames too.
    """
    r = [a[0][j] - b[0][j] for j in (0, 1)]
    v = [a[1][j] - a[0][j] - b[1][j] + b[0][j] for j in (0, 1)]
    vv = sum(x * x for x in v)
    k = max(0.0, min(1.0, -sum(x * y for x, y in zip(r, v)) / vv)) if vv else 0.5
    return k, math.hypot(r[0] + k * v[0], r[1] + k * v[1])


def lint(drill: dict[str, Any], loops: int = 2) -> list[str]:
    anim = drill.get("animation") or {}
    phases_all = anim.get("phases") or []
    if not phases_all:
        return ["NOANIM: drill has no timeline"]
    elements = drill.get("diagram", {}).get("elements", [])
    home = {e["label"]: [float(e["x"]), float(e["y"])]
            for e in elements if e.get("type") == "player"}
    walls = [[float(e["x"]), float(e["y"])] for e in elements
             if e.get("type") == "wall"]
    goal_boxes = []
    for e in elements:
        if e.get("type") == "goal":
            half = float(e.get("width") or 7.32) / 2
            goal_boxes.append((float(e["x"]), float(e["y"]), half))
    main = [p for p in phases_all if p.get("kind") != "outcome"]
    outs = [p for p in phases_all if p.get("kind") == "outcome"]
    if not main:
        return ["NOANIM: outcomes need a main timeline to branch from"]
    first_ball = next((p["tracks"][BALL][0] for p in main
                       if BALL in p.get("tracks", {})), None)
    opening = {lbl: list(xy) for lbl, xy in home.items()}
    opening.update({lbl: list(tr[0]) for lbl, tr in main[0].get("tracks", {}).items()})
    if first_ball is not None:
        opening[BALL] = list(first_ball)

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
                    f"({last[lbl][0]:.1f},{last[lbl][1]:.1f}) — begin this "
                    f"track at exactly those coordinates")
        # aloneness (fades only — kicks fly alone legitimately)
        if kind == "fade" and BALL in tracks and _d(*tracks[BALL]) > 1.5:
            bt = tracks[BALL]
            carried = any(l != BALL and _d(t2[0], bt[0]) < 1.8
                          and _d(t2[1], bt[1]) < 1.8
                          for l, t2 in tracks.items())
            if not carried:
                findings.append(
                    f"ALONE {cid} phase{pi}: ball travels {_d(*bt):.0f}m "
                    "unaccompanied in a reset — a player must carry it "
                    "(give the collector a track along the same path)")
        # Stationary players remain on the pitch even with no current track.
        # Reset handovers may end together; flag crossings through a body,
        # rather than intentional contact at the beginning/end of a leg.
        player_tracks = {l: tracks.get(l, [last[l], last[l]]) for l in home}
        labs = list(player_tracks)
        for x in range(len(labs)):
            for y in range(x + 1, len(labs)):
                if max(_d(*player_tracks[labs[x]]), _d(*player_tracks[labs[y]])) < 1e-6:
                    continue  # a held contact beat is not a path crossing
                k, separation = _closest_approach(player_tracks[labs[x]],
                                                  player_tracks[labs[y]])
                if 0 < k < 1 and separation < 0.7:
                    findings.append(
                        f"COLLIDE {cid} phase{pi}: {labs[x]} and "
                        f"{labs[y]} merge mid-phase — keep them at "
                        "least 0.8m apart (stop arm's length short)")
        # A receiver must see an incoming feed before it reaches their feet.
        # Use arrival positions for moving receivers too. A carrier is already
        # next to the ball at launch, and has different facing requirements.
        bt = tracks.get(BALL)
        if kind in ("action", "outcome") and bt and _d(*bt) > 1.0:
            origins = [tr[0] for tr in player_tracks.values()] + walls
            if not any(_d(bt[0], xy) <= 1.8 for xy in origins):
                findings.append(f"RELEASE {cid} phase{pi}: ball moves without "
                                "a player or wall at its starting point")
        carried = bt and any(_d(bt[0], tr[0]) <= 1.8 and _d(bt[1], tr[1]) <= 1.8
                             for tr in player_tracks.values())
        if kind == "action" and bt and _d(*bt) > 2.0 and not carried:
            for lbl, tr in player_tracks.items():
                xy = tr[1]
                if _d(bt[1], xy) > 1.3 or _d(bt[0], tr[0]) <= 1.8:
                    continue
                facing = (p.get("hips") or {}).get(lbl)
                if facing is None:
                    continue
                incoming = [bt[0][0] - xy[0], bt[0][1] - xy[1]]
                n = math.hypot(*incoming) * math.hypot(*facing)
                if n > 0 and (facing[0] * incoming[0] + facing[1] * incoming[1]) / n < 0:
                    findings.append(f"FACE {cid} phase{pi}: {lbl} faces away from the arriving ball")
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

    # Every escape must be judged, including a third or fourth choice.
    for loop in range(max(1, loops, len(outs))):
        seq = list(main)
        if outs:
            seq.append(outs[loop % len(outs)])
        # Repeated equal-distance passes can deliberately have a steady beat.
        # Flag timing flattened across substantially different distances;
        # pauses and resets break the run.
        same_pace = 0
        for pi, p in enumerate(seq):
            moving = p.get("kind") == "action" and max(
                (_d(*tr) for tr in p.get("tracks", {}).values()), default=0) > 0.5
            if moving and pi and p["d"] == seq[pi - 1].get("d") \
                    and seq[pi - 1].get("kind") == "action" \
                    and max((_d(*tr) for tr in seq[pi - 1].get("tracks", {}).values()),
                            default=0) > 0.5:
                same_pace += 1
            else:
                same_pace = 0
            if same_pace >= 3:
                lengths = [max(_d(*tr) for tr in q.get("tracks", {}).values())
                           for q in seq[pi - 3:pi + 1]]
                if max(lengths) >= 2 * min(lengths):
                    findings.append(f"RHYTHM {cid} phase{pi}: four unequal moving actions "
                                    "have identical duration — vary the timing")
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
        for lbl, xy in opening.items():
            if lbl in last and _d(xy, last[lbl]) > 1e-4:
                findings.append(
                    f"LOOP {cid}: {lbl} teleports {_d(xy, last[lbl]):.3f}m "
                    f"at the loop boundary — the final phase must return "
                    f"{lbl} to ({xy[0]:.1f},{xy[1]:.1f}), where the "
                    "film opens")
        if loop == 0 and not outs:
            break  # deterministic without rotation — one loop suffices
    # dedupe
    seen, out = set(), []
    for f in findings:
        if f not in seen:
            seen.add(f)
            out.append(f)
    return out
