"""Weakness-category rule packs. Injected into the drill-gen prompt."""
from __future__ import annotations

from typing import Any

RULE_PACKS: dict[str, dict[str, Any]] = {
    "Dribbling": {
        "primary_action": "carry the ball past a defender or through a gate under time pressure, change pace or direction to beat opposition",
        "verb_keywords": ["dribble", "carry", "beat", "turn", "cut", "feint", "accelerate"],
        "must_include": ["worker with ball", "beatable target (defender or tight gate)", "end-line or finishing target"],
        "must_avoid": ["isolated cone slalom with no opposition and no end target", "passive walking between cones"],
        "success_metric": "≥70% of reps beat the defender/gate cleanly and arrive at the end target with the ball under control",
        "perception_action_cue": "worker scans for defender body shape; attacks front foot to force the turn",
    },
    "Passing": {
        "primary_action": "play a weighted, accurate pass between teammates under passive or active pressure, then reposition for the return",
        "verb_keywords": ["pass", "receive", "play", "open up", "support"],
        "must_include": ["≥2 players exchanging passes", "directional target or rotating position", "receiver repositioning between passes"],
        "must_avoid": ["two stationary players exchanging passes in a straight line with no off-ball movement"],
        "success_metric": "≥80% of passes arrive to the receiver's correct foot in ≤2 seconds with pressure applied",
        "perception_action_cue": "passer looks up before the pass; receiver opens body to next option before the ball arrives",
    },
    "Shooting": {
        "primary_action": "strike on goal after a setup touch, with server service or a defender closing to force a quick decision",
        "verb_keywords": ["shoot", "strike", "finish", "drive", "curl", "place"],
        "must_include": ["goal element", "setup touch before the strike", "server feed OR defender pressure"],
        "must_avoid": ["stationary ball placed in front of empty goal", "unlimited time with no pressure or service"],
        "success_metric": "≥60% of shots on target within 2 seconds of the final touch",
        "perception_action_cue": "scan keeper/goal before the final touch; plant foot next to ball, head still at contact",
    },
    "First Touch": {
        "primary_action": "receive a moving ball while a server feeds and a defender closes, control it directionally, play forward in ≤2 touches",
        "verb_keywords": ["receive", "control", "touch", "cushion", "redirect", "turn"],
        "must_include": ["server who passes the ball in", "pressure source (active defender or tight time window)", "directional exit (gate, goal, or second player)"],
        "must_avoid": ["stationary receive with no pressure", "ground ball only — must vary service (bouncing, driven, lofted)"],
        "success_metric": "≥70% of receptions exit forward toward the target within 2 touches",
        "perception_action_cue": "server varies ball height and pace; worker scans over shoulder before reception to locate pressure",
    },
    "Defending": {
        "primary_action": "close down an attacker, deny the forward pass or dribble line, win or delay the ball until cover arrives",
        "verb_keywords": ["close", "press", "jockey", "block", "tackle", "intercept", "recover"],
        "must_include": ["attacker with ball", "defender worker", "target the attacker is trying to reach (goal, line, gate)"],
        "must_avoid": ["defender as a passive cone — must actively close and react", "1v1 with no objective for either player"],
        "success_metric": "≥60% of reps, defender wins the ball OR delays the attacker ≥3 seconds without fouling",
        "perception_action_cue": "defender reads attacker's hips and touch; closes on the outside, forces them onto weaker foot",
    },
    "Speed & Agility": {
        "primary_action": "accelerate, decelerate, and change direction around cones or a defender while keeping the ball under control",
        "verb_keywords": ["accelerate", "sprint", "cut", "change direction", "burst", "dribble"],
        "must_include": ["multiple change-of-direction points (cones, gates, or defender)", "clear end line or finishing target", "explosive start or burst cue"],
        "must_avoid": ["jogging through a flat line of cones", "no change-of-pace demand"],
        "success_metric": "each rep completed in ≤6 seconds at full intent; no loss of ball control on direction changes",
        "perception_action_cue": "low hips into cuts; explosive push off the outside foot, eyes up between changes",
    },
}


def get_rule_pack(category: str) -> dict[str, Any] | None:
    """Case-insensitive lookup. Returns None for uncovered categories."""
    if not category:
        return None
    needle = category.strip().lower()
    for name, pack in RULE_PACKS.items():
        if name.lower() == needle:
            return pack
    return None
