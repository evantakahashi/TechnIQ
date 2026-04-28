"""
Side-by-side comparison: GPT-4-Turbo vs Claude Sonnet drill generation.
Run: python test_model_comparison.py
"""

import json
import os
import yaml

# Load API keys from .env.yaml
with open(os.path.join(os.path.dirname(__file__), '.env.yaml'), 'r') as f:
    env = yaml.safe_load(f)

OPENAI_KEY = env.get('OPENAI_API_KEY')
ANTHROPIC_KEY = env.get('ANTHROPIC_API_KEY')

# Test scenarios
TEST_CASES = [
    {
        "name": "Solo weak-foot passing with wall",
        "player": {
            "name": "Test Player", "age": 15, "position": "midfielder",
            "experienceLevel": "intermediate",
            "skillGoals": ["improve weak foot"],
            "weaknesses": ["weak foot passing"],
            "playingStyle": "possession"
        },
        "requirements": {
            "skill_description": "weak foot passing accuracy",
            "category": "technical", "difficulty": "intermediate",
            "equipment": ["ball", "cones", "wall"],
            "number_of_players": 1
        }
    },
    {
        "name": "1v1 dribbling under pressure",
        "player": {
            "name": "Test Player", "age": 17, "position": "winger",
            "experienceLevel": "advanced",
            "skillGoals": ["beat defenders 1v1"],
            "weaknesses": ["dribbling under pressure", "change of direction"],
            "playingStyle": "attacking"
        },
        "requirements": {
            "skill_description": "beating a defender 1v1 with skill moves",
            "category": "technical", "difficulty": "advanced",
            "equipment": ["ball", "cones"],
            "number_of_players": 1
        }
    },
    {
        "name": "First touch under pressure (2 players)",
        "player": {
            "name": "Test Player", "age": 14, "position": "striker",
            "experienceLevel": "beginner",
            "skillGoals": ["first touch", "composure"],
            "weaknesses": ["touch under pressure"],
            "playingStyle": "attacking"
        },
        "requirements": {
            "skill_description": "controlling the ball under pressure",
            "category": "technical", "difficulty": "beginner",
            "equipment": ["ball", "cones"],
            "number_of_players": 2
        }
    }
]

FIELD_DIMS = {"width": 20, "length": 30}


def run_openai(player, requirements):
    """Run Scout+Writer with GPT-4-Turbo (simplified 2-phase for comparison)"""
    from openai import OpenAI
    client = OpenAI(api_key=OPENAI_KEY)

    # Scout
    scout_prompt = f"""Analyze this soccer player and identify their #1 weakness to target.

Player: {player.get('name')}, Age {player.get('age')}, {player.get('position')}, {player.get('experienceLevel')} level
Goals: {', '.join(player.get('skillGoals', []))}
Self-identified weaknesses: {', '.join(player.get('weaknesses', []))}
Request focus: {requirements.get('skill_description', '')}

Return JSON:
{{"primary_weakness": "specific weakness", "drill_archetype": "specific drill type", "difficulty_calibration": "maintain", "reasoning": "brief"}}"""

    scout_resp = client.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": "You are a soccer performance analyst. Identify the player's #1 weakness and recommend a creative drill archetype."},
            {"role": "user", "content": scout_prompt}
        ],
        max_tokens=500, temperature=0.3
    )
    scout = json.loads(scout_resp.choices[0].message.content.strip().strip('```json').strip('```'))

    # Writer
    equipment = requirements.get('equipment', [])
    writer_prompt = f"""Write a complete soccer drill.

Focus: {scout.get('primary_weakness', '')}
Archetype: {scout.get('drill_archetype', '')}
Field: {FIELD_DIMS['width']}m x {FIELD_DIMS['length']}m
Players: {requirements.get('number_of_players', 1)}
Difficulty: {requirements.get('difficulty', 'intermediate')}
Equipment: {', '.join(equipment)}

INSTRUCTION RULES:
- Each instruction = ONE action, imperative verb, 15-25 words
- Design for {requirements.get('number_of_players', 1)} player(s)

DIAGRAM RULES:
- element types: "cone", "player", "target", "goal", "ball", "wall"
- path styles: "dribble", "run", "pass"
- Every path MUST include a "step" integer linking to instruction

Return ONLY valid JSON:
{{"name": "Short name", "description": "One sentence.", "setup": "Setup description.", "instructions": ["Action 1", "Action 2", "Action 3"], "diagram": {{"field": {{"width": {FIELD_DIMS['width']}, "length": {FIELD_DIMS['length']}}}, "elements": [{{"type": "cone", "x": 0, "y": 0, "label": "A"}}], "paths": [{{"from": "A", "to": "B", "style": "dribble", "step": 1}}]}}, "coachingPoints": ["Point 1", "Point 2"], "difficulty": "{requirements.get('difficulty')}", "category": "{requirements.get('category')}", "targetSkills": ["skill1"], "equipment": {json.dumps(equipment)}}}"""

    writer_resp = client.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": "You are an expert soccer coach. Write complete, practical drills. Be creative and specific."},
            {"role": "user", "content": writer_prompt}
        ],
        max_tokens=1500, temperature=0.7
    )
    return json.loads(writer_resp.choices[0].message.content.strip().strip('```json').strip('```'))


def run_anthropic(player, requirements):
    """Run Scout+Writer with Claude Sonnet"""
    from anthropic import Anthropic
    client = Anthropic(api_key=ANTHROPIC_KEY)

    # Scout
    scout_prompt = f"""Analyze this soccer player and identify their #1 weakness to target.

Player: {player.get('name')}, Age {player.get('age')}, {player.get('position')}, {player.get('experienceLevel')} level
Goals: {', '.join(player.get('skillGoals', []))}
Self-identified weaknesses: {', '.join(player.get('weaknesses', []))}
Request focus: {requirements.get('skill_description', '')}

Return JSON:
{{"primary_weakness": "specific weakness", "drill_archetype": "specific drill type", "difficulty_calibration": "maintain", "reasoning": "brief"}}"""

    scout_resp = client.messages.create(
        model="claude-sonnet-4-6",
        system="You are a soccer performance analyst. Identify the player's #1 weakness and recommend a creative drill archetype.",
        messages=[{"role": "user", "content": scout_prompt}],
        max_tokens=500, temperature=0.3
    )
    scout = json.loads(scout_resp.content[0].text.strip().strip('```json').strip('```'))

    # Writer (with realism constraints)
    equipment = requirements.get('equipment', [])
    writer_prompt = f"""Write a complete soccer drill.

Focus: {scout.get('primary_weakness', '')}
Archetype: {scout.get('drill_archetype', '')}
Field: {FIELD_DIMS['width']}m x {FIELD_DIMS['length']}m
Players: {requirements.get('number_of_players', 1)}
Difficulty: {requirements.get('difficulty', 'intermediate')}
Equipment: {', '.join(equipment)}

INSTRUCTION RULES:
- Each instruction = ONE action, imperative verb, 15-25 words
- Design for {requirements.get('number_of_players', 1)} player(s)

DIAGRAM RULES:
- element types: "cone", "player", "target", "goal", "ball", "wall"
- path styles: "dribble", "run", "pass"
- Every path MUST include a "step" integer linking to instruction

PHYSICAL REALISM RULES (CRITICAL):
- Players can ONLY pass to other players, NEVER to cones, markers, or empty space
- Every piece of equipment in the equipment list MUST appear as an element in the diagram
- If "wall" is in equipment, it MUST appear as a diagram element with type "wall"
- Movement paths must have a clear soccer purpose — no random or unnecessary runs
- Cones mark positions/gates, they do NOT receive passes or act as players
- If the drill requires multiple players, assign clear roles (attacker, defender, server)

Return ONLY valid JSON:
{{"name": "Short name", "description": "One sentence.", "setup": "Setup description.", "instructions": ["Action 1", "Action 2", "Action 3"], "diagram": {{"field": {{"width": {FIELD_DIMS['width']}, "length": {FIELD_DIMS['length']}}}, "elements": [{{"type": "cone", "x": 0, "y": 0, "label": "A"}}], "paths": [{{"from": "A", "to": "B", "style": "dribble", "step": 1}}]}}, "coachingPoints": ["Point 1", "Point 2"], "difficulty": "{requirements.get('difficulty')}", "category": "{requirements.get('category')}", "targetSkills": ["skill1"], "equipment": {json.dumps(equipment)}}}"""

    writer_resp = client.messages.create(
        model="claude-sonnet-4-6",
        system="You are an expert soccer coach. Write complete, practical drills. Be creative and specific.",
        messages=[{"role": "user", "content": writer_prompt}],
        max_tokens=1500, temperature=0.7
    )
    return json.loads(writer_resp.content[0].text.strip().strip('```json').strip('```'))


def print_drill(label, drill):
    print(f"\n{'='*60}")
    print(f"  {label}")
    print(f"{'='*60}")
    print(f"  Name: {drill.get('name', '?')}")
    print(f"  Description: {drill.get('description', '?')}")
    print(f"  Setup: {drill.get('setup', '?')}")
    print(f"\n  Instructions:")
    for i, inst in enumerate(drill.get('instructions', []), 1):
        print(f"    {i}. {inst}")
    print(f"\n  Coaching Points:")
    for pt in drill.get('coachingPoints', []):
        print(f"    - {pt}")
    print(f"\n  Target Skills: {drill.get('targetSkills', [])}")
    print(f"  Equipment: {drill.get('equipment', [])}")

    diagram = drill.get('diagram', {})
    elements = diagram.get('elements', [])
    paths = diagram.get('paths', [])
    print(f"\n  Diagram Elements ({len(elements)}):")
    for el in elements:
        print(f"    [{el.get('type')}] {el.get('label', '?')} at ({el.get('x')}, {el.get('y')})")
    print(f"\n  Diagram Paths ({len(paths)}):")
    for p in paths:
        print(f"    {p.get('from')} -> {p.get('to')} ({p.get('style')}) step={p.get('step')}")

    # Quality checks
    print(f"\n  --- Quality Checks ---")
    element_types = {el.get('type') for el in elements}
    has_wall_equip = 'wall' in drill.get('equipment', [])
    has_wall_elem = 'wall' in element_types
    if has_wall_equip and not has_wall_elem:
        print(f"  ❌ Wall in equipment but NOT in diagram!")
    elif has_wall_equip and has_wall_elem:
        print(f"  ✅ Wall in equipment AND diagram")

    # Check for passing to cones
    for p in paths:
        if p.get('style') == 'pass':
            target_label = p.get('to', '')
            target_el = next((e for e in elements if e.get('label') == target_label), None)
            if target_el and target_el.get('type') == 'cone':
                print(f"  ❌ Pass to cone '{target_label}'!")
            elif target_el and target_el.get('type') in ('player', 'wall'):
                print(f"  ✅ Pass to {target_el.get('type')} '{target_label}'")

    print()


if __name__ == "__main__":
    import sys

    # Install deps if needed
    try:
        import openai
    except ImportError:
        os.system(f"{sys.executable} -m pip install openai anthropic pyyaml -q")
        import openai

    try:
        import anthropic
    except ImportError:
        os.system(f"{sys.executable} -m pip install anthropic -q")

    for tc in TEST_CASES:
        print(f"\n{'#'*70}")
        print(f"  TEST: {tc['name']}")
        print(f"  Equipment: {tc['requirements']['equipment']}")
        print(f"  Players: {tc['requirements']['number_of_players']}")
        print(f"{'#'*70}")

        print("\n⏳ Running GPT-4-Turbo...")
        try:
            openai_drill = run_openai(tc['player'], tc['requirements'])
            print_drill("GPT-4-TURBO", openai_drill)
        except Exception as e:
            print(f"  ❌ OpenAI failed: {e}")

        print("\n⏳ Running Claude Sonnet...")
        try:
            claude_drill = run_anthropic(tc['player'], tc['requirements'])
            print_drill("CLAUDE SONNET", claude_drill)
        except Exception as e:
            print(f"  ❌ Anthropic failed: {e}")
