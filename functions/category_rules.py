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
        "must_include": ["≥2 players exchanging passes", "explicit one-touch/two-touch tag on every pass step", "the cone-gate pattern: a cone in FRONT of each player — receive on one side of your cone, touch across, release on the other side (this shows the touches spatially)"],
        "must_avoid": ["two stationary players exchanging passes in a straight line with no off-ball movement"],
        "success_metric": "≥80% of passes arrive to the receiver's correct foot in ≤2 seconds with pressure applied",
        "perception_action_cue": "passer looks up before the pass; receiver opens body to next option before the ball arrives",
    },
    "Shooting": {
        "primary_action": "strike on goal after a setup touch, at volume — a repeating strike cycle with a target that defines success; a QUICK TURN means receiving with BACK TO GOAL from a server, turning with the ball, then finishing — not a cone skill-move",
        "verb_keywords": ["shoot", "strike", "finish", "drive", "curl", "place"],
        "must_include": ["goal element on the field edge", "target gate or cone inside the goal for accuracy", "ball supply: a one-ball collect-and-return loop, pre-placed balls, or a server feed", "setup touch before the strike"],
        "must_avoid": ["a single strike with no stated way to continue (no collect-and-return loop, no supply)", "stationary ball placed in front of empty goal with no target", "identical presentation every rep — vary rolling toward, away, and across"],
        "success_metric": "≥60% of strikes through the target within 2 seconds of the final touch, counted out loud",
        "perception_action_cue": "glance at the target between the prep touch and the strike; plant foot beside the ball, head still at contact",
    },
    "Weak Foot": {
        "primary_action": "repeated weak-foot execution forced by geometry and rules — approach angle, ball presentation, and target placement all open the weak-foot side",
        "verb_keywords": ["strike", "finish", "pass", "place", "prep touch"],
        "must_include": ["layout that presents the ball to the weak-foot side (cut in from the strong side / ball rolling to the weak side)", "rule that only weak-foot executions count", "target gate or zone", "a one-ball collect-and-return loop"],
        "must_avoid": ["a layout where the player can quietly use the strong foot every rep", "one-shot sequences with no volume"],
        "success_metric": "≥60% of weak-foot-only reps hit the target; a strong-foot touch on the final action counts as a miss",
        "perception_action_cue": "prep touch pushes the ball across the body into the weak-foot zone; eyes up at the target between touch and strike",
    },
    "First Touch": {
        "primary_action": "receive a moving ball while a server feeds and a defender closes, control it directionally, play forward in ≤2 touches",
        "verb_keywords": ["receive", "control", "touch", "cushion", "redirect", "turn"],
        "must_include": ["server who passes the ball in", "UNDER PRESSURE means pressure from BEHIND: a defender or mannequin at the receiver's back so they must react and take the first touch in the optimal direction away from it", "directional exit (gate, goal, or second player)"],
        "must_avoid": ["stationary receive with no pressure", "'bouncing ball' touch trained off a wall — walls return ground balls; BOUNCING touch = ball tossed up (self or server) and a DIRECT first touch through one of several gates around the receiver, then dribble on", "pretending a cone can serve or rebound"],
        "success_metric": "≥70% of receptions exit forward toward the target within 2 touches",
        "perception_action_cue": "server varies ball height and pace; worker scans over shoulder before reception to locate pressure",
    },
    "Defending": {
        "primary_action": "close down an attacker, deny the forward pass or dribble line, win or delay the ball until cover arrives; pressers ALWAYS engage the ball carrier — never run to cones; defensive HEADERS return to the server for one-ball flow (variation: an attacker on the defender's back contests)",
        "verb_keywords": ["close", "press", "jockey", "block", "tackle", "intercept", "recover"],
        "must_include": ["attacker starting WITH the ball (no pointless opening pass exchange)", "defender worker", "target the attacker is trying to reach (goal, line, gate)"],
        "must_avoid": ["defender as a passive cone — must actively close and react", "1v1 with no objective for either player", "choreographing the duel — script only the serve and engage (4-8 steps), put outcomes and decision rules in coaching points"],
        "success_metric": "≥60% of reps, defender wins the ball OR delays the attacker ≥3 seconds without fouling",
        "perception_action_cue": "defender reads attacker's hips and touch; closes on the outside, forces them onto weaker foot",
    },
    "Goalkeeping": {
        "primary_action": "react and save off a SERVER's throws/strikes — self-thrown wall rebounds cannot test reactions (the keeper knows where their own throw goes, and angled walls bounce away)",
        "verb_keywords": ["throw", "save", "parry", "catch", "distribute", "set"],
        "must_include": ["a server/thrower for any REACTION work (2 players)", "solo GK drills limited to footwork/handling patterns, honestly labeled", "hand actions use 'throws to'"],
        "must_avoid": ["self-throw wall rebounds sold as reaction training", "targets behind the wall", "foot-pass language for hand throws"],
        "success_metric": "≥70% of rebounds held clean or parried wide of the danger zone; count catches out loud",
        "perception_action_cue": "set feet before the rebound arrives; hands ready at hip height, eyes through the ball into the catch",
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


# Real weakness labels rarely match pack names exactly ("Shooting Accuracy",
# "Dribbling Skills", "Weak Foot"...). Exact-match lookup silently dropped the
# packs — the richest guidance in the prompt — for most requests.
_PACK_ALIASES: dict[str, str] = {
    "shooting accuracy": "Shooting", "finishing": "Shooting",
    "weak foot": "Weak Foot", "weaker foot": "Weak Foot",
    "striking": "Shooting", "crossing": "Shooting",
    "passing accuracy": "Passing", "one touch passing": "Passing",
    "dribbling skills": "Dribbling", "ball control": "Dribbling", "close control": "Dribbling",
    "first touch": "First Touch", "receiving": "First Touch",
    "defending 1v1": "Defending", "tackling": "Defending",
    "goalkeeping": "Goalkeeping", "goalkeeper": "Goalkeeping", "saves": "Goalkeeping", "handling": "Goalkeeping",
    "speed": "Speed & Agility", "agility": "Speed & Agility", "quick feet": "Speed & Agility",
    "stamina": "Speed & Agility", "endurance": "Speed & Agility",
}


def get_rule_pack(category: str) -> dict[str, Any] | None:
    """Tolerant lookup: exact name, alias, then substring. None if uncovered."""
    if not category:
        return None
    needle = category.strip().lower()
    # Weak foot is cross-cutting: "weak foot finishing accuracy" must hit the
    # Weak Foot pack, not lose to the "finishing" alias by insertion order.
    if "weak foot" in needle or "weak-foot" in needle or "weaker foot" in needle:
        return RULE_PACKS["Weak Foot"]
    for name, pack in RULE_PACKS.items():
        if name.lower() == needle:
            return pack
    if needle in _PACK_ALIASES:
        return RULE_PACKS[_PACK_ALIASES[needle]]
    for alias, name in _PACK_ALIASES.items():
        if alias in needle or needle in alias:
            return RULE_PACKS[name]
    for name, pack in RULE_PACKS.items():
        if name.lower() in needle:
            return pack
    return None
