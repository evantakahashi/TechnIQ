"""Compile validated drill steps into a phase timeline (the animation format).

Modeled on the phase structure Fable produced unconstrained: each phase has a
duration, concurrent movement tracks (ball + any players), a facing (hips)
vector per player, a timed coaching caption, and an easing tag. The DSL stays
the validated source of truth; this is a deterministic view of it.

Timeline schema (attached to drill["animation"]):
  { "phases": [
      { "d": 900,                     # ms
        "tracks": {"__ball__": [[x,y],[x,y]], "P1": [[x,y],[x,y]]},
        "hips":   {"P1": [dx,dy]},    # unit-ish facing vector
        "label":  "First touch — cushion across your body",
        "ease":   "out" | "lin",
        "kind":   "action" | "fade" | "outcome",
        "step":   3                    # source step, for arrow highlighting
      }, ... ] }

Fade phases teleport: tracks give [from,to] but the renderer snaps at the
midpoint behind an opacity dip (hidden resets stay hidden).
"""
from __future__ import annotations

import math
from typing import Any

BALL = "__ball__"

# ms per meter by action, with floors/caps — a 3m touch snaps, a 20m jog lopes
_SPEED = {"pass": 34, "throw": 34, "toss": 46, "shoot": 26, "shot": 26,
          "header": 40, "dribble": 95, "run": 80, "receive": 46}
_FLOOR, _CAP = 420, 2100
_EASE = {"pass": "lin", "throw": "lin", "toss": "out", "shoot": "lin",
         "shot": "lin", "header": "out", "dribble": "out", "run": "out",
         "receive": "out"}

_VERB_CUE_KEYS = {
    "pass": ("pass", "serve", "feed", "weight"),
    "receive": ("touch", "cushion", "control", "receive", "chest"),
    "dribble": ("touch", "close", "dribbl", "cut", "turn", "shield"),
    "shoot": ("strike", "finish", "shot", "plant", "laces", "corner"),
    "shot": ("strike", "finish", "shot", "plant", "laces", "corner"),
    "run": ("run", "spot", "scan", "set", "sprint", "recover"),
    "toss": ("toss", "serve", "drop"),
    "throw": ("throw", "catch", "hands"),
    "header": ("head", "attack the ball", "forehead", "neck"),
}
_PLAIN = {"pass": "passes to", "dribble": "dribbles to", "run": "runs to",
          "shoot": "shoots at", "shot": "shoots at", "receive": "receives from",
          "throw": "throws to", "toss": "tosses to", "header": "heads to"}


def _dist(a: tuple, b: tuple) -> float:
    return math.hypot(b[0] - a[0], b[1] - a[1])


def _dur(style: str, dist: float) -> int:
    ms = _SPEED.get(style, 80) * dist
    return int(max(_FLOOR, min(_CAP, ms)))


def _norm(dx: float, dy: float) -> list[float]:
    n = math.hypot(dx, dy)
    return [round(dx / n, 3), round(dy / n, 3)] if n > 1e-6 else [1.0, 0.0]


def _cue_for(style: str, coaching: list[str], used: set) -> str | None:
    keys = _VERB_CUE_KEYS.get(style, ())
    for i, c in enumerate(coaching):
        if i in used:
            continue
        low = c.lower()
        if any(k in low for k in keys):
            used.add(i)
            # keep captions one clause long
            clause = c.split(" — ")[0].split(";")[0].split(".")[0]
            return clause.strip()
    return None


def compile_timeline(drill: dict[str, Any]) -> dict[str, Any]:
    diagram = drill.get("diagram") or {}
    elements = diagram.get("elements") or []
    paths = [p for p in (diagram.get("paths") or []) if p.get("fx") is not None]
    coaching = [c for c in (drill.get("coaching_points") or [])
                if "warm" not in c.lower()]
    by_label = {e.get("label"): e for e in elements}
    players = {e["label"] for e in elements if e.get("type") == "player"}

    # live positions through the sequence
    pos: dict[str, list[float]] = {
        e["label"]: [float(e["x"]), float(e["y"])]
        for e in elements if e.get("type") == "player"}
    ball_pos: list[float] | None = None
    for e in elements:
        if e.get("type") == "ball":
            ball_pos = [float(e["x"]), float(e["y"])]
            break

    ordered = sorted((p for p in paths if not p.get("alt")),
                     key=lambda x: x.get("step", 0))
    outcomes = [p for p in paths if p.get("alt")
                and p.get("style") in ("dribble", "run", "shoot", "shot")]
    used_cues: set = set()
    phases: list[dict[str, Any]] = []
    i = 0
    while i < len(ordered):
        p = ordered[i]
        style, src, dst = p.get("style"), p.get("from"), p.get("to")
        f = [p["fx"], p["fy"]]
        t = [p["tx"], p["ty"]]

        # ---- hidden resets collapse into ONE fade phase ----
        if p.get("reset"):
            j = i
            while j < len(ordered) and ordered[j].get("reset"):
                r = ordered[j]
                if r.get("style") in ("run", "dribble") and r["from"] in players:
                    pos[r["from"]] = [r["tx"], r["ty"]]
                j += 1
            # ball lands wherever the next ball action starts
            nxt_ball = next(
                ([q["fx"], q["fy"]] for q in ordered[j:]
                 if q.get("style") in ("pass", "toss", "throw", "shoot",
                                       "shot", "header", "dribble")),
                ball_pos)
            ball_pos = nxt_ball
            tracks = {lbl: [list(xy), list(xy)] for lbl, xy in pos.items()}
            if ball_pos:
                tracks[BALL] = [list(ball_pos), list(ball_pos)]
            phases.append({"d": 650, "tracks": tracks, "hips": {},
                           "label": "…reset — next rep", "ease": "lin",
                           "kind": "fade", "step": p.get("step")})
            i = j
            continue

        tracks: dict[str, list] = {}
        hips: dict[str, list] = {}

        def face_all_toward_ball(target_xy):
            for lbl, xy in pos.items():
                hips[lbl] = _norm(target_xy[0] - xy[0], target_xy[1] - xy[1])

        merged_step = p.get("step")
        nxt = ordered[i + 1] if i + 1 < len(ordered) else None
        sync = nxt if (nxt and nxt.get("sync")) else None

        if style in ("run", "dribble"):
            tracks[src] = [f, t]
            pos[src] = list(t)
            hips[src] = _norm(t[0] - f[0], t[1] - f[1])
            if style == "dribble":
                tracks[BALL] = [f, t]
                ball_pos = list(t)
        if style in ("pass", "toss", "throw", "shoot", "shot", "header"):
            tracks[BALL] = [f, t]
            ball_pos = list(t)
            hips[src] = _norm(t[0] - f[0], t[1] - f[1])
            if by_label.get(dst, {}).get("type") == "player":
                # receiver squares up to the incoming ball
                hips[dst] = _norm(f[0] - pos.get(dst, t)[0],
                                  f[1] - pos.get(dst, t)[1])
        if style == "receive":
            # micro-touch: the last meter of the ball's travel into control
            arrive = list(pos.get(src, f))
            start = ball_pos or t
            tracks[BALL] = [list(start), arrive]
            ball_pos = arrive
            hips[src] = _norm(start[0] - arrive[0], start[1] - arrive[1])

        if sync is not None:
            s_style, s_src = sync.get("style"), sync.get("from")
            sf = [sync["fx"], sync["fy"]]
            st = [sync["tx"], sync["ty"]]
            if s_style in ("run", "dribble"):
                tracks[s_src] = [sf, st]
                pos[s_src] = list(st)
                hips[s_src] = _norm(st[0] - sf[0], st[1] - sf[1])
                if s_style == "dribble":
                    tracks.setdefault(BALL, [sf, st])
            elif s_style in ("pass", "toss", "throw"):
                tracks[BALL] = [sf, st]
                ball_pos = list(st)
                hips[s_src] = _norm(st[0] - sf[0], st[1] - sf[1])
            i += 1  # consumed

        dist = max(_dist(tuple(f), tuple(t)),
                   _dist(tuple(tracks[BALL][0]), tuple(tracks[BALL][1]))
                   if BALL in tracks else 0)
        cue = _cue_for(style, coaching, used_cues)
        src_el = by_label.get(src, {})
        role = f" ({src_el.get('role')})" if src_el.get("role") else ""
        base = f"{src}{role} {_PLAIN.get(style, 'moves to')} {dst}"
        phases.append({
            "d": _dur(style, dist),
            "tracks": tracks, "hips": hips,
            "label": cue or base, "ease": _EASE.get(style, "lin"),
            "kind": "action", "step": merged_step,
        })
        i += 1

    # duel outcomes: alternating escape phases, played one per loop
    for oc in outcomes:
        f = [oc["fx"], oc["fy"]]
        t = [oc["tx"], oc["ty"]]
        tr = {oc["from"]: [f, t]}
        if oc.get("style") in ("dribble",):
            tr[BALL] = [f, t]
        phases.append({
            "d": _dur(oc.get("style", "dribble"), _dist(tuple(f), tuple(t))),
            "tracks": tr, "hips": {oc["from"]: _norm(t[0]-f[0], t[1]-f[1])},
            "label": f"…or {oc['from']} breaks to {oc['to']}",
            "ease": "out", "kind": "outcome", "step": oc.get("step"),
        })
    return {"phases": phases}
