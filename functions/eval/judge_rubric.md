# Drill Judge Rubric (calibrated to the product owner's demonstrated standards)

> Judge in Evan's voice: read `evan_voice.md` FIRST — it is the full feedback corpus
> (RLHF-style) with ranked priors, his skill definitions, and the agreement log.
> This file is the distilled checklist; that file is the reward model.

A drill is judged as a kid reads it: literally, step by step, diagram-first.
Verdicts: GOLDEN (showcase exemplar) / OK (hand to a kid as-is; style nits only) / BAD.

## Automatic BAD (any one of these)
1. Ball possession untraceable at ANY step (passes a ball they don't have, phantom ball after a shot, ball not visibly at the carrier's feet at start).
2. The advertised skill is not what the steps train (e.g., "under pressure" with no pressure source; "turn" with no turn; heading rendered as foot passes).
3. A scored target the ball never visits (decorative gates/goals), or a target that is geometrically wrong (gate outside the goal mouth, target behind a wall, backward finish through the course).
4. Duel/contest choreographed instead of rules-based; or the illustrated attack does not engage the opponent (drives to a cone, players never meet, defender not between attacker and target).
5. Any redundant or contradictory movement (run+dribble to same spot; exits the exit then returns; "rest jog" that the diagram scores as a rep).
6. Physically impossible or unsafe: cone rebounds, wall serving bouncing balls, keeper distributing into own goal, header volume >15 or serves >8m, U13 heading/contact.
7. Confusing furniture: multiple balls drawn; elements no step references; roles that don't add up ("pressing pair" of one).
8. Internal contradiction between coaching points and the diagram (coaching names distances/serves/targets the layout doesn't show), or raw coordinates leaked into coaching text.

## OK requires ALL of
- Every step traceable with one ball; collect-and-return or handover explicit.
- Trains exactly the requested skill at the requested age/level; distances sane for the age.
- Repeating cycle with real volume; countable target; warm-up first; sets/rest stated; progression/regression present.
- Diagram reads like a coach's whiteboard: targets on the action line, goals on the edge with boxes, choices shown (or-arrows) where play is live.

## GOLDEN additionally
- You would showcase it: nothing to edit, coaching cues specific and age-tuned, the layout teaches the skill by geometry alone.

## Judge behavior
- Compute, don't vibe: distances from coordinates, rep math from coaching text, element-usage sets.
- One confirmed automatic-BAD ends deliberation — verdict BAD with the specific defect named.
- Skepticism default: if a step's purpose can't be explained in one sentence, that's a defect.
