"""Deterministic geometry rubric — the objective half of drill judging.
Extracted from the session A/B harness; the subjective half is judge_rubric.md.
"""
import math


# ---------- deterministic geometry rubric (100 pts) ----------
def seg_point_dist(a, b, p):
    ax, ay = a; bx, by = b; px, py = p
    dx, dy = bx - ax, by - ay
    L2 = dx * dx + dy * dy
    if L2 == 0:
        return math.dist(a, p)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / L2))
    return math.dist((ax + t * dx, ay + t * dy), p)


def score_geometry(drill):
    dg = drill.get("diagram") or {}
    f = dg.get("field") or {}
    W, L = f.get("width") or 0, f.get("length") or 0
    els = {e.get("label"): e for e in dg.get("elements") or []}
    paths = dg.get("paths") or []
    checks = {}

    goals = [e for e in els.values() if e.get("type") == "goal"]
    # 1. goal on a field edge (within 2.5m) — mid-pitch goals look unscoreable (20)
    if goals:
        ok = all(min(g["x"], W - g["x"], g["y"], L - g["y"]) <= 2.5 for g in goals)
        checks["goal_on_edge"] = 20 if ok else 0
    else:
        checks["goal_on_edge"] = 20  # n/a

    # 2. shots: 4-25m and approach from in-field toward the goal's edge (20)
    shots = [p for p in paths if p.get("style") in ("shoot", "shot")]
    if shots:
        good = 0
        for p in shots:
            a, b = els.get(p.get("from")), els.get(p.get("to"))
            if not a or not b:
                continue
            d = math.dist((a["x"], a["y"]), (b["x"], b["y"]))
            if not (4 <= d <= 25):
                continue
            if goals and b.get("type") == "goal":
                # approach vector must roughly point at the nearest edge of the goal
                edge = min((("x0", b["x"]), ("x1", W - b["x"]), ("y0", b["y"]), ("y1", L - b["y"])),
                           key=lambda kv: kv[1])[0]
                vx, vy = b["x"] - a["x"], b["y"] - a["y"]
                toward = {"x0": vx < 0, "x1": vx > 0, "y0": vy < 0, "y1": vy > 0}[edge]
                if not toward:
                    continue
            good += 1
        checks["shot_geometry"] = round(20 * good / len(shots))
    else:
        checks["shot_geometry"] = 20  # n/a for non-shooting drills

    # 3. no movement path passes through the goalmouth or over cones (20)
    movers = [p for p in paths if p.get("style") in ("dribble", "run")]
    bad = 0
    for p in movers:
        a, b = els.get(p.get("from")), els.get(p.get("to"))
        if not a or not b:
            continue
        seg = ((a["x"], a["y"]), (b["x"], b["y"]))
        for g in goals:
            if els.get(p.get("to")) is g:
                continue
            if seg_point_dist(*seg, (g["x"], g["y"])) < 1.2:
                bad += 1; break
        else:
            for c in els.values():
                if c.get("type") == "cone" and c is not a and c is not b:
                    if seg_point_dist(*seg, (c["x"], c["y"])) < 0.4:
                        bad += 1; break
    checks["clean_paths"] = max(0, 20 - 10 * bad)

    # 4. all declared elements used by some step (15)
    used = set()
    for p in paths:
        used.add(p.get("from")); used.add(p.get("to"))
    unused = [l for l, e in els.items() if l not in used and e.get("type") != "wall"]
    checks["no_dead_props"] = max(0, 15 - 5 * len(unused))

    # 5. no overlapping elements (<0.8m apart) and everything in bounds (15)
    coords = [(e["x"], e["y"]) for e in els.values()]
    overlap = any(0 < math.dist(a, b) < 0.8 for i, a in enumerate(coords) for b in coords[i + 1:])
    oob = any(not (0 <= x <= W and 0 <= y <= L) for x, y in coords)
    checks["spacing_bounds"] = 15 - (8 if overlap else 0) - (7 if oob else 0)

    # 6. worker actually repeats work: >=6 steps and worker appears in >=60% (10)
    workers = {l for l, e in els.items() if e.get("type") == "player" and e.get("role") == "worker"}
    winv = sum(1 for p in paths if p.get("from") in workers or p.get("to") in workers)
    checks["work_density"] = 10 if (len(paths) >= 6 and winv >= 0.6 * len(paths)) else (5 if len(paths) >= 4 else 0)

    return checks, sum(checks.values())
