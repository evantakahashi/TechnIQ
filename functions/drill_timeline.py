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
_SPEED = {"pass": 42, "throw": 42, "toss": 46, "shoot": 28, "shot": 28,
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


_NOT_TECHNIQUE = ("target:", "per set", "one ball", "progression",
                  "regression", "warm", "swap", "count", "sets", "score")


def _cue_for(style: str, coaching: list[str], used: set) -> str | None:
    """Only TECHNIQUE lines may narrate a phase — never volume/plumbing."""
    keys = _VERB_CUE_KEYS.get(style, ())
    for i, c in enumerate(coaching):
        if i in used:
            continue
        low = c.lower()
        if any(b in low for b in _NOT_TECHNIQUE) or any(ch.isdigit() for ch in c):
            continue
        if any(k in low for k in keys):
            used.add(i)
            clause = c.split(" — ")[0].split(";")[0].split(".")[0]
            return clause.strip()
    return None


def _situational(style, src, dst, by_label):
    dt = by_label.get(dst, {}).get("type")
    if style in ("pass", "toss", "throw"):
        return f"Feed comes in from {src} — be set"
    if style == "receive":
        return "First touch — take it across your body"
    if style == "dribble":
        return f"Drive the ball to {dst}" if dt in ("cone", "gate") \
            else f"Work it back to {dst}"
    if style in ("shoot", "shot"):
        return "Finish — low and firm through the target"
    if style == "header":
        return "Attack the ball — head it up and away"
    if style == "run":
        return "Move to your spot — set before the ball"
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
    last_ball_style: str | None = None
    phases: list[dict[str, Any]] = []
    i = 0
    while i < len(ordered):
        p = ordered[i]
        style, src, dst = p.get("style"), p.get("from"), p.get("to")
        f = [p["fx"], p["fy"]]
        t = [p["tx"], p["ty"]]

        # ---- resets compile leg-by-leg: the ball is BROUGHT, never rolls
        # ---- home alone (collect -> bring it back -> back to your spot)
        if p.get("reset"):
            j = i
            while j < len(ordered) and ordered[j].get("reset"):
                r = ordered[j]
                st, rsrc = r.get("style"), r.get("from")
                rf = [r["fx"], r["fy"]]
                rt = [r["tx"], r["ty"]]
                leg_tracks: dict[str, list] = {}
                label = "Reset"
                if st == "run" and rsrc in players:
                    leg_tracks[rsrc] = [list(pos.get(rsrc, rf)), rt]
                    pos[rsrc] = list(rt)
                    if ball_pos and _dist(tuple(ball_pos), tuple(rt)) < 2.0:
                        label = "Collect it — quick jog"
                    else:
                        label = "Back to your spot"
                elif st == "dribble" and rsrc in players:
                    leg_tracks[rsrc] = [list(pos.get(rsrc, rf)), rt]
                    b0 = list(ball_pos) if ball_pos else rf
                    leg_tracks[BALL] = [b0, rt]  # together — it's carried
                    pos[rsrc] = list(rt)
                    ball_pos = list(rt)
                    label = "Bring it back"
                elif st == "receive":
                    # handover: ball switches hands where they stand
                    rcv = pos.get(rsrc)
                    if rcv is not None:
                        ball_pos = list(rcv)
                    j += 1
                    continue
                else:
                    j += 1
                    continue
                gd = max((_dist(tuple(tr[0]), tuple(tr[1]))
                          for tr in leg_tracks.values()), default=0)
                if gd > 0.4:
                    phases.append({"d": int(max(420, min(2600, gd * 85))),
                                   "tracks": leg_tracks, "hips": {},
                                   "label": label, "ease": "lin",
                                   "kind": "fade", "step": r.get("step")})
                j += 1
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

        # Anticipation: a still beat before every serve — the receiver scans.
        if style in ("pass", "toss", "throw") \
                and by_label.get(dst, {}).get("type") == "player" \
                and (not phases or phases[-1]["kind"] == "fade"
                     or BALL not in phases[-1]["tracks"]):
            pressure = next((e for e in elements
                             if e.get("type") in ("mannequin", "defender")
                             or (e.get("type") == "player"
                                 and e.get("role") == "defender")), None)
            rp = pos.get(dst, t)
            if pressure is not None:
                eye_v = _norm(pressure["x"] - rp[0], pressure["y"] - rp[1])
                a_lab = "Ball is coming — check your shoulder, find the pressure"
            else:
                eye_v = _norm(f[0] - rp[0], f[1] - rp[1])
                a_lab = f"Ball is coming — be set, eyes on {src}"
            still = {lbl: [list(xy), list(xy)] for lbl, xy in pos.items()}
            if ball_pos:
                still[BALL] = [list(ball_pos), list(ball_pos)]
            phases.append({"d": 550, "tracks": still, "hips": dict(),
                           "eye": {dst: eye_v}, "label": a_lab,
                           "ease": "lin", "kind": "action",
                           "step": merged_step})

        if style in ("run", "dribble"):
            t_end = list(t)
            if style == "run" and by_label.get(dst, {}).get("type") == "player":
                # close to arm's length, never into the body
                gap = _dist(tuple(f), tuple(t))
                if gap > 1.6:
                    u = _norm(t[0] - f[0], t[1] - f[1])
                    t_end = [t[0] - u[0] * 1.1, t[1] - u[1] * 1.1]
            tracks[src] = [list(pos.get(src, f)), t_end]
            pos[src] = list(t_end)
            hips[src] = _norm(t[0] - f[0], t[1] - f[1])
            if style == "dribble":
                b0 = list(ball_pos) if ball_pos \
                    and _dist(tuple(ball_pos), tuple(f)) < 2.5 else f
                tracks[BALL] = [b0, t_end]
                ball_pos = list(t_end)
        if style == "toss" and src == dst:
            spot = list(ball_pos) if ball_pos else list(pos.get(src, f))
            phases.append({"d": 650,
                           "tracks": {BALL: [spot, spot],
                                      src: [list(pos.get(src, f)), list(pos.get(src, f))]},
                           "hips": {}, "label": "Toss it up — soft, just above head height",
                           "ease": "out", "kind": "tossup", "step": merged_step})
            i += 1
            continue
        if style in ("shoot", "shot") and phases \
                and phases[-1]["kind"] == "action" \
                and BALL in phases[-1]["tracks"]:
            bp = list(ball_pos) if ball_pos else list(f)
            sp = list(pos.get(src, f))
            plant = {src: [sp, sp], BALL: [bp, bp]}
            phases.append({"d": 300, "tracks": plant,
                           "hips": {src: _norm(t[0]-sp[0], t[1]-sp[1])},
                           "label": "Plant beside the ball — head still",
                           "ease": "lin", "kind": "action",
                           "step": merged_step})
        if style in ("pass", "toss", "throw", "shoot", "shot", "header"):
            last_ball_style = style
            t_ball = t
            if by_label.get(dst, {}).get("type") == "player" \
                    and style in ("pass", "toss", "throw"):
                d = _dist(tuple(f), tuple(t))
                if d > 1.6:  # land the feed a meter short — the touch finishes it
                    k = (d - 1.0) / d
                    t_ball = [f[0] + (t[0] - f[0]) * k,
                              f[1] + (t[1] - f[1]) * k]
            b0 = list(ball_pos) if ball_pos \
                and _dist(tuple(ball_pos), tuple(f)) < 2.5 else f
            tracks[BALL] = [b0, t_ball]
            ball_pos = list(t_ball)
            hips[src] = _norm(t[0] - f[0], t[1] - f[1])
            if by_label.get(dst, {}).get("type") == "player":
                # receiver squares up to the incoming ball
                hips[dst] = _norm(f[0] - pos.get(dst, t)[0],
                                  f[1] - pos.get(dst, t)[1])
            for lbl, xy in pos.items():
                if lbl in (src, dst) or lbl in tracks:
                    continue  # actors already move
                # breathe with the FACING only — position sway caused pops
                hips.setdefault(lbl, _norm(t[0] - xy[0], t[1] - xy[1]))
        if style == "receive":
            # a THROWN ball is CAUGHT (sticks in the hands); a passed ball is
            # touched on — carried into a control point on the exit side
            start = list(ball_pos) if ball_pos else list(f)
            base_pt = list(pos.get(src, t))
            if last_ball_style in ("throw", "toss") \
                    and by_label.get(dst, {}).get("type") == "wall":
                arrive = base_pt
                tracks[BALL] = [start, arrive]
                ball_pos = list(arrive)
                hips[src] = _norm(start[0] - base_pt[0], start[1] - base_pt[1])
                phases.append({"d": _dur("receive",
                                         _dist(tuple(start), tuple(arrive))),
                               "tracks": tracks, "hips": hips,
                               "label": _cue_for("throw", coaching, used_cues)
                               or "Catch it clean — soft hands, eyes through the ball",
                               "ease": "out", "kind": "action",
                               "step": merged_step})
                i += 1
                continue
            nxt_move = next((q for q in ordered[i + 1:]
                             if q.get("from") == src
                             and q.get("style") in ("dribble", "run", "pass",
                                                    "shoot", "shot")), None)
            if nxt_move is not None:
                ex = _norm(nxt_move["tx"] - base_pt[0],
                           nxt_move["ty"] - base_pt[1])
            else:
                ex = _norm(base_pt[0] - start[0], base_pt[1] - start[1])
            arrive = [base_pt[0] + ex[0] * 0.7, base_pt[1] + ex[1] * 0.7]
            tracks[BALL] = [start, arrive]
            ball_pos = arrive
            hips[src] = _norm(start[0] - base_pt[0], start[1] - base_pt[1])

        if sync is not None:
            s_style, s_src = sync.get("style"), sync.get("from")
            sf = [sync["fx"], sync["fy"]]
            st = [sync["tx"], sync["ty"]]
            if s_style in ("run", "dribble"):
                st_end = list(st)
                if s_style == "run" and by_label.get(sync.get("to"), {}) \
                        .get("type") == "player" \
                        and _dist(tuple(sf), tuple(st)) > 1.6:
                    u = _norm(st[0] - sf[0], st[1] - sf[1])
                    st_end = [st[0] - u[0] * 1.1, st[1] - u[1] * 1.1]
                tracks[s_src] = [sf, st_end]
                pos[s_src] = list(st_end)
                hips[s_src] = _norm(st[0] - sf[0], st[1] - sf[1])
                if s_style == "dribble":
                    tracks.setdefault(BALL, [sf, st])
            elif s_style in ("pass", "toss", "throw"):
                b0 = list(ball_pos) if ball_pos \
                    and _dist(tuple(ball_pos), tuple(sf)) < 2.5 else sf
                st_ball = st
                if by_label.get(sync.get("to"), {}).get("type") == "player":
                    dd = _dist(tuple(b0), tuple(st))
                    if dd > 1.6:  # land the feed short — the touch finishes it
                        kk = (dd - 1.0) / dd
                        st_ball = [b0[0] + (st[0] - b0[0]) * kk,
                                   b0[1] + (st[1] - b0[1]) * kk]
                tracks[BALL] = [b0, st_ball]
                ball_pos = list(st_ball)
                hips[s_src] = _norm(st[0] - sf[0], st[1] - sf[1])
                rcv = sync.get("to")
                if rcv in pos:
                    hips[rcv] = _norm(sf[0] - pos[rcv][0], sf[1] - pos[rcv][1])
            i += 1  # consumed

        dist = max(_dist(tuple(f), tuple(t)),
                   _dist(tuple(tracks[BALL][0]), tuple(tracks[BALL][1]))
                   if BALL in tracks else 0)
        cue = _cue_for(style, coaching, used_cues)
        src_el = by_label.get(src, {})
        role = f" ({src_el.get('role')})" if src_el.get("role") else ""
        base = _situational(style, src, dst, by_label) or \
            f"{src}{role} {_PLAIN.get(style, 'moves to')} {dst}"
        steps_lit = [merged_step] + ([sync.get("step")] if sync is not None else [])
        phases.append({
            "d": _dur(style, dist),
            "tracks": tracks, "hips": hips,
            "label": cue or base, "ease": _EASE.get(style, "lin"),
            "kind": "action", "step": merged_step, "steps": steps_lit,
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
    # seamless loop: glide home whenever the loop's end-state differs from
    # its start-state (a trailing fade may still strand someone off-spawn).
    # Drills WITH rotating outcomes skip this — the engine appends the glide
    # after the escape plays.
    home = {e["label"]: [float(e["x"]), float(e["y"])]
            for e in elements if e.get("type") == "player"}

    def _start_state():
        st = dict(home)
        first = phases[0] if phases else {"tracks": {}}
        out = {}
        for lbl, hx in st.items():
            tr = first.get("tracks", {}).get(lbl)
            out[lbl] = list(tr[0]) if tr else list(hx)
        return out
    first_ball = next((ph["tracks"][BALL][0] for ph in phases
                       if BALL in ph.get("tracks", {})), None)
    starts = _start_state()
    mismatch = any(_dist(tuple(pos.get(l, starts[l])), tuple(starts[l])) > 0.6
                   for l in starts)
    if first_ball is not None and ball_pos is not None:
        mismatch = mismatch or _dist(tuple(ball_pos), tuple(first_ball)) > 0.6
    if phases and mismatch and not outcomes:
        ball_stray = (first_ball is not None and ball_pos is not None
                      and _dist(tuple(ball_pos), tuple(first_ball)) > 0.6)
        carrier = None
        if ball_stray:
            carrier = min(home, key=lambda l: _dist(
                tuple(pos.get(l, home[l])), tuple(ball_pos)), default=None)
        if ball_stray and carrier is not None and _dist(
                tuple(pos.get(carrier, home[carrier])), tuple(ball_pos)) > 1.6:
            # leg 1: nearest player collects; everyone else heads home
            leg1 = {carrier: [list(pos.get(carrier, home[carrier])),
                              list(ball_pos)]}
            for lbl in home:
                if lbl != carrier:
                    hx = starts[lbl]
                    leg1[lbl] = [list(pos.get(lbl, hx)), list(hx)]
                    pos[lbl] = list(hx)
            g1 = max(_dist(tuple(tr[0]), tuple(tr[1])) for tr in leg1.values())
            phases.append({"d": int(max(420, min(2600, g1 * 85))),
                           "tracks": leg1, "hips": {},
                           "label": "Collect it — quick jog",
                           "ease": "lin", "kind": "fade", "step": None})
            pos[carrier] = list(ball_pos)
        end_tracks = {}
        for lbl in home:
            hx = starts[lbl]
            end_tracks[lbl] = [list(pos.get(lbl, hx)), list(hx)]
        if ball_stray:
            end_tracks[BALL] = [list(ball_pos), list(first_ball)]
        gd = max((_dist(tuple(tr[0]), tuple(tr[1]))
                  for tr in end_tracks.values()), default=0)
        if gd > 0.5:
            phases.append({"d": int(max(500, min(2600, gd * 85))),
                           "tracks": end_tracks, "hips": {},
                           "label": "Bring it back — go again",
                           "ease": "lin", "kind": "fade", "step": None})

    def _max_move(ph):
        return max((_dist(tuple(tr[0]), tuple(tr[1]))
                    for tr in ph["tracks"].values()), default=0.0)
    phases = [ph for ph in phases
              if ph["kind"] != "action" or _max_move(ph) > 0.35]
    return {"phases": phases}
