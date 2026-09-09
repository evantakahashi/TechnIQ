# Evan's Drill-Judging Voice (the reward model)

This is an RLHF-style corpus: every piece of drill feedback Evan has given, verbatim,
plus what it teaches. Before Evan reviews any batch, Claude pre-rates every drill USING
THIS DOC, in Evan's voice. After Evan's ratings land, log agreement below, and append
every miss as a new prior. Over rounds, Claude's ratings must converge on Evan's.

## Protocol (every review round)
1. Claude rates first — verdict (golden/ok/bad) + a comment phrased like Evan's.
2. Evan rates on the page. Claude never sees his ratings before locking its own.
3. Compare. Log round agreement in the table at the bottom.
4. Every disagreement → a new numbered prior here, quoting his words.
5. Priors feed the pipeline (validators / packs / prompt) — this doc is the judge;
   `judge_rubric.md` is the distilled checklist; `golden/labels.json` gates deploys.

## The calibration gap (why this doc exists)
Blind round, same four drills:
- Claude: gk-wall "ok 95 — states the honest limit well" → **Evan: bad** — "i think this
  needs another player... they need to work on diving and such. if its about reactions,
  another player needs to shoot or throw."
- Claude: first-touch "ok 87 — closest to the pattern you prescribed" → **Evan: bad** —
  "passing to a cone, no one is there. you need a partner so this wouldnt work"
- Claude: shoot-turn = my winning pick → **Evan: bad** — "doesnt work on turning at all.
  also i dont like how the player dribbles from the gate back to the cone."

Pattern of every miss: Claude credits *intent, structure, honesty about limits*. Evan
checks *whether it functions on real grass*. A drill that documents its own limitation
is still a bad drill. Judge the drill, not the effort.

---

## Verbatim corpus

### Round 1 (first review page — "all of them are bad")
- crossing: "it says wirker dribbles to c1 and also runs to c1, which is confusing.
  2. also while p2 has the ball, it says p1 passes p2 the ball, which is confusing.
  there are more mistakes i think that i did not mention"
- defend-1v1: "confusing since why does p1 run to p2, and then in the next step it says
  p2 dribbles to p1. it should be in the same step, like (they approach eachother).
  also for this drill it shouldnt be limited to instructions, like it should be a high
  level of what can happen, since there are many possibilities for this drill."
- first-touch: "i like the idea of this, but the instructions are super bad. like it
  says dribble to just a bunch of cones and goals, which is confusing, also why are
  there multiple valls placed everywhere."
- shoot-turn: "also unclear, there is only one ball, but after shooting the ball, the
  drill thinks there is another ball waiting."

### Round 2 ("i have a feeling that the model may not be pretrained on enough soccer")
- crossing (ok): "decent, but i dont think that it is good that p1 has to run to a ball
  each time. they shouldjust have the balls by their side, as they are not the one doing
  the active reps. they should be switching ater. also g1 and g2 are not in the goal as
  they should be. this should look like an actual soccer field with 18 and 6 yd boxes,
  etc. also this is not clear if the attacker should be taking the shot in one touch or
  two touches."
- defend-1v1 (bad): "it doesnt say whether or not the player has to shoot in the goals
  or dribble. also i dont think instructions or steps are necessary for this one. it
  should just be guidelines. like for example, Player 1 attacks player 2 and they try
  to dribble through one of the gates. after 3 consecutive attacks, they can switch."
- first-touch-solo (bad): "the wall is the wrong way. i like this idea though. it needs
  to be a little more structured, and also the wall will not play a bouncing ball back."
- first-touch (bad, wrong skill): "this is not first touch under pressure. first touch
  under pressure means you are receiving from a player and are exploding out of pressure."

### Labels round (his verdicts recorded in golden/labels.json)
- speed-ball golden: "solid, no complaints — would like foot/surface variations"
- defend-1v1 ok: "pretty solid; interception could be a variation"
- heading-def ok: "good idea; variation: contested header; header back to server for one ball"
- shoot-turn ok: "OK but not a turn — a turn is back-to-goal receive; this is a
  skill-move-and-shoot"
- first-touch-solo bad: "works turning, not bouncing-ball touch; bouncing = toss up,
  direct touch through a gate on any of 4 sides"
- passing-pair bad: "must SHOW one vs two touches; gate redundant — cones in front,
  receive one side touch across pass"
- 2v-pressing bad: "terrible — why does the other player run to a cone; not game realistic"

### Animation rounds
- "the animation is aligned with the instructions which is good, but the animation is
  inaccurate... it shows a ball going to the cone instead of the player. the animations
  should be more rich and should actually show the player dribbling with the ball,
  passing, etc. it should make sense."
- crossing: "slight improvement needed in the animation, the ball should technicaly be
  at player 1's feet, but it isnt. it looks like the ball moves on its own. let's not
  introduce confusion by placing multiple balls on the pitch i think. also the gates are
  still outside the goal, make them inside."
- defend-1v1: "this is not bad, but i feel like something needs to happen simultanously,
  like p1 should be moving towards c1 while p2 is dribbling, otherwise it doesn;t make sense.."
- first-touch-solo: "once again the ball starts from somewhre random and moves on its own. fix this"
- "the steps are too confusing, like why does the player in drill 1 run after the ball
  in the goal after. after they shoot, it should reset to the beginning with the other
  variation... also for some of the drills... the field is way too big for the drills,
  like there is a ton of green grass for the drill being so small."
- crossing A/B: "it should show a pass to cone two while the player is runnign to cone
  two... i think that the pass should come in at the same time as the run." / "why is
  the player running into the goal after the shot and dribbling it. not a good drill
  and confusing."

### Blind A/B final round
- first-touch A (bad): "this is bad because the player is passing to a cone, no one is
  there. you need a partner so this wouldnt work"
- first-touch B (bad): "the concept is good, but the ball passes it self. it needs
  another player. the ball can never pass itself"
- gk-wall A (bad): "i think this needs another player, this drill isnt so good. another
  player should shoot on the goalie or should throw the ball to them. they need to work
  on diving and such. if its about reactions, another player needs to shoot or throw."
- gk-wall B (bad): "okay this is just one touch passing against a rebounder and doesnt
  have anything to do wiht hands."
- passing-pair A (ok): "this is okay but should not include any cones at all. there
  needs to be some variation, maybe one plater is moving side to side, or between cones
  and doing one touch passes in between cones."
- shoot-turn A (bad): "okay this is fine but doesnt work on turning at all. also i dont
  like how the player dribbles from the gate back to the cone."
- shoot-turn B: "this is fine but not game realistic. devent drill"
- weakfoot A: "again the player shouldnt dribble from the gate after shooting."
- weakfoot B (ok): "this is fine but not game realistic really. it would be more like
  they are dribbling from wide inwards and then shooting instead of the reverse."
- golden with no comment: crossing A, tight-dribble A+B, u8-dribble A+B.

### On-skill regen round (first round judged WITH this doc)
- first-touch: "a better more realistic variation is if a player receives from another
  player, and then they take a touch into one of the four gates, the gates should be
  closer. right now it just looks like the player passes through some gate, which works
  on passing accuracy but not first touch at all."
- gk-wall: "this is a very simple drill, not bad but i feel like needs improvements or
  variation. for example another human throwing to the goalie in net while they work on
  footwork. this is juist one example."
- shoot-turn: "again this did not factor in my feedback, a TURN is if a defender
  receives with their back turned to goal, and then they can turn with the ball while
  receiving it and shoot."
- weakfoot: "this is kind of okay but unrealistic, the person should dribble, maybe take
  a touch to the left or right of the cone, and finish either far or near post. the
  player shouldnt be shooting right when they get to the cone. needs to introduce like a
  sudden touch inside towards the left or right and finish."

### Golden set v3.2 round (4 goldens, 0 bads — positional nits remain)
- 2v-pressing: "not bad but needs to show dribbler getting past defenders."
- first-touch-solo: "not bad but player should be in the middle of the gates not this far away."
- first-touch: "i think this is good but g4 is unecessary, ideally it should be in fromt of p2."
- gk-wall: "confusing"
- passing-pair: "not bad, but maybe p1 should be standing in or slightly behind g1, and passing from there."
- shoot-turn: "not bad" / speed-ball: "decent" / tight-dribble: golden "good"
- heading-def: GOLDEN / u8-dribble: GOLDEN
- weakfoot-finish: GOLDEN — "AMAZING, although layout is pretty big"

### Meta-feedback (how to judge)
- "okay now you need to get better at judging these drills. you judge them too high for
  what they are. i want you to be able to singhle out bad drills and notice what is
  wrong with them"
- "look at the drills, they didnt address my feedback at all"
- "still didnt follow my feedback"

---

## Priors, ranked (what Evan checks, in order)

1. **Game realism is the master test.** "not game realistic" kills a structurally
   perfect drill. Ask: does this movement pattern exist in a real match? would a real
   coach lay out these cones? Attackers move TOWARD goal ("dribbling from wide inwards
   and then shooting instead of the reverse"); nobody dribbles back out of a gate/goal
   after finishing; nobody runs to a cone as their job in a pressing drill.
2. **Somebody must be there.** A pass needs a real receiver (partner or wall — never a
   cone: "no one is there"), a GK needs someone shooting/throwing at them, pressure
   needs a pressure source. If the requested skill NEEDS a partner and the request is
   solo, the honest answer is a different-but-real solo drill for that skill — not a
   simulation. A drill that admits "this doesn't really train X" is still bad.
3. **Ball physics, literally.** One ball drawn. It starts at the worker's feet. It never
   moves on its own, never passes itself, never duplicates after a shot. Every ball
   movement has a cause a kid can see. Servers keep staged balls "by their side."
4. **The skill trained = the skill named, by HIS definitions:**
   - turn = receive with back to goal, turn with the ball, finish
   - first touch under pressure = receive FROM A PLAYER with pressure behind, explode away
   - bouncing-ball touch = ball tossed/kicked up, DIRECT touch through a gate on any of 4 sides
   - GK reactions = a partner shoots/throws; keeper dives/saves — hands, not feet
   - clearance headers = upfield/wide, back to server for one-ball flow
   - crossing = wide delivery for a finisher; finisher told 1-touch or 2-touch
5. **Duels are guidelines, not scripts.** "Player 1 attacks player 2 and they try to
   dribble through one of the gates. after 3 consecutive attacks, they can switch." —
   that's the whole spec. Script only the serve and engage; simultaneous movement
   (attacker + defender in the same beat), outcomes in coaching.
6. **After the action, reset — invisibly.** "after they shoot, it should reset to the
   beginning with the other variation." Fetching/walk-backs are plumbing, never shown,
   never scored as reps.
7. **No furniture.** Every element must be used by a step. No decorative cones ("should
   not include any cones at all" for pair passing), no unused gates, no "c1c2".
8. **Presentation counts.** Field cropped to content (no "ton of green grass"), goals on
   the edge with 18/6-yard boxes, gates INSIDE the goal mouth, touch counts shown
   (1T/2T), variations shown (foot/surface, side-to-side), simultaneous actions
   animated together.

9. **Partner-required skills get the partner — realism wins over the request.** If the
   skill needs a feed/opponent (pressure receiving, turns, GK reactions), generate the
   2-player version even when the request says solo ("a player receives from another
   player"). Don't fake it solo; a kid can grab a friend or parent.
10. **A first touch is a TOUCH, not a pass.** The redirect after receiving goes through
   a CLOSE gate (2-4m). A long redirect "works on passing accuracy but not first touch
   at all."
11. **Setup touch before the strike.** Never shoot from on top of the cone — "a sudden
   touch inside towards the left or right", THEN finish near or far post.
12. **Simple bases need real variations.** A plain solo base can be ok, but must carry
   partner/progression variations ("another human throwing to the goalie in net while
   they work on footwork").

13. **Element placement is part of the drill.** Receiver stands at the CENTER of a
   gate ring; exit gates fan IN FRONT (never behind); the lane-gate server stands
   in/behind the gate and passes through it; duels must SHOW the beat (animate an
   escape); walls rebound like mirrors — the catcher stands on the reflected line.
14. **Layouts stay tight.** "AMAZING, although layout is pretty big" — trim dead
   grass even on great drills.

## Voice guide (phrase critiques like him)
- Blunt, lowercase, short. Concede then kill: "the concept is good, but…", "i like this
  idea though", "this is fine but not game realistic."
- Narrate the confusion first-person as a kid reading the diagram: "why does the player
  run to a cone", "which is confusing", "no one is there."
- Name elements: p1, c1, g1. Never scores or rubric-speak — verdict + plain reasons.
- Golden = nothing to say (his goldens have empty comments). If you're writing praise
  paragraphs, it's not golden — find the flaw or say nothing.
- Default skeptical: the first round he rated, ALL were bad. When unsure between two
  verdicts, pick the lower.

## Agreement log
| Round | Drills both rated | Verdict match | Misses (all Claude-too-high?) |
|---|---|---|---|
| Blind A/B (baseline, pre-doc) | 11 | ~5/11 | yes — Claude 87-95 on four Evan-bads |
| On-skill regens (first with doc) | 4 | 3/4 direction | no — the miss was too LOW (gk-wall: Claude bad, Evan "not bad, needs variation"). Don't overcorrect simple-but-functional to bad. |
| Golden set v3.2 | 13 | ~9/13 direction | mixed: heading-def Claude ok → Evan GOLDEN (too low); weakfoot golden↔golden MATCH; 2v/gk-wall slightly high. Recurring lesson: Evan judges the animated whole; positional nits don't sink a drill, missing beats do. |
| next round | — | — | — |
