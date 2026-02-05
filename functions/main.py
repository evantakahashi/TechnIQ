"""
TechnIQ ML Recommendation Engine - Firebase Functions
Provides collaborative filtering and content-based recommendations for soccer training
"""

import json
import logging
import os
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional
import traceback

from firebase_admin import initialize_app, firestore, auth
from firebase_functions import https_fn

# Import our ML recommendation engines
from ml.youtube_recommendations import create_youtube_ml_engine
from lightweight_recommendations import create_lightweight_recommendations

# Initialize Firebase
db = None
try:
    initialize_app()
    db = firestore.client()
    print("✅ Firebase initialized successfully")
except Exception as e:
    print(f"⚠️ Firebase initialization deferred: {e}")
    # Firebase will be initialized when the function is called in production

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# MARK: - Main Recommendation Endpoints

@https_fn.on_request()
def get_youtube_recommendations(req: https_fn.Request) -> https_fn.Response:
    """
    Get personalized YouTube video recommendations based on player profile and collaborative filtering
    
    Expected request body:
    {
        "user_id": "string",
        "player_profile": {
            "position": "midfielder",
            "age": 16,
            "experienceLevel": "intermediate",
            "goals": ["improve ball control", "increase speed"],
            "playingStyle": "attacking",
            "playerRoleModel": "Kevin De Bruyne"
        },
        "limit": 5
    }
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )
        
        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)
        
        # Firebase Auth token verification (required in production)
        auth_header = req.headers.get('Authorization')
        authenticated_user_uid = None
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"

        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                authenticated_user_uid = decoded_token['uid']
                logger.info(f"🔐 Authenticated user: {authenticated_user_uid}")
            except Exception as e:
                logger.warning(f"⚠️ Auth token verification failed: {e}")
                if not allow_unauth:
                    return https_fn.Response(
                        json.dumps({"error": "Invalid authentication token"}),
                        status=401,
                        headers={
                            'Content-Type': 'application/json',
                            'Access-Control-Allow-Origin': '*'
                        }
                    )
                logger.info("📝 Proceeding as unauthenticated (ALLOW_UNAUTHENTICATED=true)")
        else:
            if not allow_unauth:
                logger.warning("⚠️ No auth token provided, rejecting request")
                return https_fn.Response(
                    json.dumps({"error": "Authentication required"}),
                    status=401,
                    headers={
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*'
                    }
                )
            logger.info("📝 No auth token provided, proceeding as unauthenticated (ALLOW_UNAUTHENTICATED=true)")
        
        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)
        
        user_id = request_data.get('user_id')
        player_profile = request_data.get('player_profile', {})
        # Force limit to 1 - only generate one recommendation at a time (v2)
        limit = 1
        
        if not user_id or not player_profile:
            return https_fn.Response("Missing user_id or player_profile", status=400)
        
        logger.info(f"🎥 Generating single YouTube recommendation for user: {user_id} (v2 - enhanced duplicate detection)")
        
        # Get API keys from environment variables
        youtube_api_key = os.environ.get('YOUTUBE_API_KEY')
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        
        logger.info(f"🔑 YouTube API key available: {bool(youtube_api_key)}")
        logger.info(f"🔑 OpenAI API key available: {bool(openai_api_key)}")
        
        if not youtube_api_key or youtube_api_key == 'YOUR_YOUTUBE_API_KEY_HERE':
            return https_fn.Response("YouTube API key not configured", status=500)
        
        # Get user's existing exercises to prevent duplicates
        existing_exercises = get_existing_exercises(user_id)
        
        # Create YouTube ML engine with LLM query generation
        youtube_engine = create_youtube_ml_engine(youtube_api_key, openai_api_key)
        
        # Get user's training history for collaborative filtering
        user_history = get_user_training_history(user_id)
        
        # Generate personalized YouTube recommendations with duplicate filtering
        recommendations = youtube_engine.get_personalized_youtube_recommendations(
            player_profile=player_profile,
            user_history=user_history,
            existing_exercises=existing_exercises,
            limit=limit
        )
        
        # Format response
        response_data = {
            "user_id": user_id,
            "recommendations": recommendations,
            "algorithm": "youtube_collaborative_filtering",
            "generated_at": datetime.now().isoformat(),
            "model_version": "1.0.0",
            "player_profile": player_profile
        }
        
        logger.info(f"✅ Generated {len(recommendations)} YouTube recommendations for {user_id}")
        return https_fn.Response(
            json.dumps(response_data),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error in get_youtube_recommendations: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

@https_fn.on_request(timeout_sec=540)
def generate_custom_drill(req: https_fn.Request) -> https_fn.Response:
    """
    Generate personalized drill using AI based on player profile and requirements
    
    Expected request body:
    {
        "user_id": "string",
        "player_profile": {
            "name": "Player Name",
            "age": 16,
            "position": "midfielder",
            "experienceLevel": "intermediate",
            "skillGoals": ["improve ball control"],
            "weaknesses": ["under pressure"],
            "playingStyle": "attacking"
        },
        "requirements": {
            "skill_description": "improve first touch under pressure",
            "category": "technical",
            "difficulty": "intermediate",
            "equipment": ["ball", "cones"],
            "number_of_players": 1
        }
    }
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )
        
        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Firebase Auth token verification
        auth_header = req.headers.get('Authorization')
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                logger.info(f"🔐 Authenticated user: {decoded_token['uid']}")
            except Exception as e:
                if not allow_unauth:
                    return https_fn.Response(json.dumps({"error": "Invalid authentication token"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})
        elif not allow_unauth:
            return https_fn.Response(json.dumps({"error": "Authentication required"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        user_id = request_data.get('user_id')
        player_profile = request_data.get('player_profile', {})
        requirements = request_data.get('requirements', {})
        session_context = request_data.get('session_context', {})
        drill_feedback = request_data.get('drill_feedback', [])
        field_size = request_data.get('field_size', 'medium')

        if not all([user_id, player_profile, requirements]):
            return https_fn.Response("Missing required fields", status=400)

        logger.info(f"🤖 Generating custom drill for user: {user_id} (4-phase pipeline)")
        logger.info(f"📝 Skill description: {requirements.get('skill_description', '')}")
        logger.info(f"📐 Field size: {field_size}")
        logger.info(f"📊 Session context: {len(session_context.get('recent_exercises', []))} recent exercises")
        logger.info(f"📊 Drill feedback: {len(drill_feedback)} previous drill ratings")

        # Get OpenAI API key from environment variables
        openai_api_key = os.environ.get('OPENAI_API_KEY')

        if not openai_api_key:
            return https_fn.Response("OpenAI API key not configured", status=500)

        # Generate drill using 4-phase agentic pipeline
        drill_data = generate_drill_pipeline(player_profile, requirements, session_context, drill_feedback, field_size, openai_api_key)
        
        # Format response
        response_data = {
            "user_id": user_id,
            "drill": drill_data,
            "algorithm": "openai_custom_drill_generation",
            "generated_at": datetime.now().isoformat(),
            "model_version": "1.0.0",
            "requirements": requirements
        }
        
        logger.info(f"✅ Generated custom drill: {drill_data.get('name', 'Unknown')}")
        return https_fn.Response(
            json.dumps(response_data),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error in generate_custom_drill: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

def get_field_dimensions(field_size: str) -> Dict[str, int]:
    """Get field dimensions based on size selection"""
    sizes = {
        "small": {"width": 20, "length": 15},
        "medium": {"width": 30, "length": 20},
        "large": {"width": 50, "length": 30}
    }
    return sizes.get(field_size, sizes["medium"])


def parse_llm_json(content: str) -> Dict:
    """Extract and parse JSON from LLM response, stripping markdown fences"""
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1]
    return json.loads(content.strip())


def generate_drill_pipeline(player_profile: Dict, requirements: Dict, session_context: Dict, drill_feedback: list, field_size: str, openai_api_key: str) -> Dict:
    """4-phase agentic drill generation: Scout → Coach → Writer ⇄ Referee"""
    from openai import OpenAI
    client = OpenAI(api_key=openai_api_key)

    field_dims = get_field_dimensions(field_size)

    # === Phase 1: Scout ===
    logger.info("🔍 Phase 1: Scout - Analyzing player context...")
    focus_strategy = phase_scout(client, player_profile, session_context, drill_feedback, requirements)
    logger.info(f"🎯 Scout result: weakness='{focus_strategy.get('primary_weakness')}', archetype='{focus_strategy.get('drill_archetype')}'")

    # === Phase 2: Coach ===
    logger.info("📐 Phase 2: Coach - Designing spatial layout...")
    skeletal_plan = phase_coach(client, focus_strategy, requirements, field_dims)
    logger.info(f"📐 Coach result: pattern='{skeletal_plan.get('pattern_type')}', equipment={skeletal_plan.get('equipment_count')}")

    # === Phase 3 & 4: Writer ⇄ Referee (self-correction loop) ===
    best_drill = None
    best_score = 0
    revision_errors = []

    for attempt in range(3):
        logger.info(f"✍️ Phase 3: Writer - Attempt {attempt + 1}/3...")
        drill = phase_writer(client, skeletal_plan, focus_strategy, requirements, field_dims, revision_errors)

        logger.info(f"⚖️ Phase 4: Referee - Validating...")
        validation = phase_referee(client, drill, focus_strategy, requirements, field_dims)

        score = validation.get("score", 0)
        if score > best_score:
            best_score = score
            best_drill = drill

        if validation.get("verdict") == "VALID":
            logger.info(f"✅ Drill validated on attempt {attempt + 1} (score={score})")
            return drill

        # Collect errors for next attempt
        errors = validation.get("errors", [])
        revision_errors = [f"{e['check']}: {e['issue']}. Fix: {e['fix']}" for e in errors]
        logger.info(f"⚠️ Referee found {len(errors)} errors, retrying...")

    # After 3 failures: return best attempt with warnings
    logger.warning(f"⚠️ Returning best attempt after 3 tries (score={best_score})")
    if best_drill:
        best_drill["validationWarnings"] = revision_errors
    return best_drill or drill


def phase_scout(client, player_profile: Dict, session_context: Dict, drill_feedback: list, requirements: Dict) -> Dict:
    """Phase 1: Analyze player data, output Focus Strategy"""
    # Build context strings
    recent_exercises = session_context.get('recent_exercises', [])
    history_text = ""
    if recent_exercises:
        for ex in recent_exercises:
            history_text += f"- {ex.get('skill', 'Unknown')}: rated {ex.get('rating', 0)}/5"
            if ex.get('notes'):
                history_text += f" ({ex['notes']})"
            history_text += "\n"

    feedback_text = ""
    if drill_feedback:
        for fb in drill_feedback:
            feedback_text += f"- Rated {fb.get('rating', 0)}/5, difficulty: {fb.get('difficulty_feedback', 'appropriate')}, sentiment: {fb.get('feedback_type', 'Neutral')}"
            if fb.get('notes'):
                feedback_text += f", notes: {fb['notes']}"
            feedback_text += "\n"

    match_perf = player_profile.get('matchPerformance', {})
    match_text = ""
    if match_perf:
        weaknesses = match_perf.get('recentWeaknesses', [])
        strengths = match_perf.get('recentStrengths', [])
        if weaknesses:
            match_text += f"Match weaknesses (last {match_perf.get('matchCount', 0)} matches): {', '.join(weaknesses)}\n"
        if strengths:
            match_text += f"Match strengths: {', '.join(strengths)}\n"

    prompt = f"""Analyze this soccer player and identify their #1 weakness to target.

Player: {player_profile.get('name', 'Player')}, Age {player_profile.get('age', 'Unknown')}, {player_profile.get('position', 'Unknown')}, {player_profile.get('experienceLevel', 'intermediate')} level
Goals: {', '.join(player_profile.get('skillGoals', []))}
Self-identified weaknesses: {', '.join(player_profile.get('weaknesses', []))}
Request focus: {requirements.get('skill_description', '')}

Recent training ratings:
{history_text or 'No history available'}

Previous drill feedback:
{feedback_text or 'No feedback available'}

{match_text}

Return JSON:
{{"primary_weakness": "specific weakness description", "drill_archetype": "specific drill type that addresses it", "difficulty_calibration": "maintain|easier|harder", "reasoning": "brief explanation"}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are a soccer performance analyst. Identify the player's #1 weakness from their data and recommend a drill archetype. Weight the user's explicit request highest, then match weaknesses, then session ratings."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=500,
            temperature=0.3
        )
        return parse_llm_json(response.choices[0].message.content)
    except Exception as e:
        logger.warning(f"⚠️ Scout phase parse error: {e}, using defaults")
        return {
            "primary_weakness": requirements.get('skill_description', 'general technique'),
            "drill_archetype": "varied practice",
            "difficulty_calibration": "maintain",
            "reasoning": "Fallback: using user request as primary focus"
        }


def phase_coach(client, focus_strategy: Dict, requirements: Dict, field_dims: Dict) -> Dict:
    """Phase 2: Design spatial layout and mechanics"""
    equipment = requirements.get('equipment', [])
    equipment_list = ', '.join(equipment) if equipment else 'minimal equipment'
    num_players = requirements.get('number_of_players', 1)

    prompt = f"""Design a soccer drill layout for this focus:

Weakness: {focus_strategy.get('primary_weakness', '')}
Drill archetype: {focus_strategy.get('drill_archetype', '')}
Difficulty calibration: {focus_strategy.get('difficulty_calibration', 'maintain')}
Field: {field_dims['width']}m x {field_dims['length']}m
Equipment available: {equipment_list}
Category: {requirements.get('category', 'technical')}
Number of players: {num_players}

Weakness→Pattern guidance:
- Tight-space dribbling → cones 1-2m apart, zigzag/weave
- Weak foot passing → angled gates requiring weak foot
- First touch under pressure → receive + turn with defender cone behind
- Shooting accuracy → target zones with approach angles
- Speed/agility → ladder or sprint channels
- Ball control → close-quarter footwork, no cones needed

Wall equipment guidance (if wall is available):
- Wall is flat and reflects ball at angle of incidence (NOT directly back to passer)
- Player must position at correct angle to receive the rebound
- Example: Pass at 45° angle, ball rebounds at 45° opposite side
- Use wall for: one-touch passing, first touch work, weak foot practice

Return JSON:
{{"pattern_type": "zigzag|triangle|linear|gates|grid|free", "equipment_placement": [{{"type": "cone|goal|ball|player", "label": "A", "x": 0, "y": 0, "purpose": "start"}}], "field_dimensions": {{"width": {field_dims['width']}, "length": {field_dims['length']}}}, "movement_paths": [{{"from": "A", "to": "B", "action": "dribble|pass|run", "detail": "description"}}], "weakness_address": "how this layout targets the weakness", "equipment_count": {{"cones": 0, "ball": 1}}}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are a soccer drill architect. Design practical spatial layouts that directly address the identified weakness. Only use equipment the player has. Keep coordinates within field dimensions."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=600,
            temperature=0.4
        )
        return parse_llm_json(response.choices[0].message.content)
    except Exception as e:
        logger.warning(f"⚠️ Coach phase parse error: {e}, using minimal plan")
        return {
            "pattern_type": "linear",
            "equipment_placement": [{"type": "ball", "label": "Start", "x": field_dims["width"] // 2, "y": 2, "purpose": "start"}],
            "field_dimensions": field_dims,
            "movement_paths": [],
            "weakness_address": focus_strategy.get('primary_weakness', ''),
            "equipment_count": {"ball": 1}
        }


def phase_writer(client, skeletal_plan: Dict, focus_strategy: Dict, requirements: Dict, field_dims: Dict, revision_errors: list) -> Dict:
    """Phase 3: Create full CustomDrillResponse JSON"""
    equipment = requirements.get('equipment', [])
    difficulty = requirements.get('difficulty', 'intermediate')
    category = requirements.get('category', 'technical')
    num_players = requirements.get('number_of_players', 1)

    revision_text = ""
    if revision_errors:
        revision_text = "\n=== ERRORS TO FIX (from previous attempt) ===\n"
        for err in revision_errors:
            revision_text += f"- {err}\n"
        revision_text += "\nFix ALL listed errors in this attempt.\n"

    wall_guidance = ""
    if 'wall' in equipment:
        wall_guidance = """
WALL PHYSICS (IMPORTANT):
- Wall reflects ball at angle of incidence, NOT directly back to passer
- Player must position at correct angle to receive rebound
- Pass at 45° angle → ball rebounds 45° to opposite side
"""

    prompt = f"""Write a complete soccer drill using this blueprint.

Focus: {focus_strategy.get('primary_weakness', '')}
Archetype: {focus_strategy.get('drill_archetype', '')}
Layout: {json.dumps(skeletal_plan, indent=2)}
Field: {field_dims['width']}m x {field_dims['length']}m
Number of players: {num_players}
Difficulty: {difficulty}
Category: {category}
Equipment available: {', '.join(equipment) if equipment else 'minimal'}
{revision_text}{wall_guidance}
INSTRUCTION RULES:
- Each instruction = ONE action, imperative verb, 15-25 words
- Use: Dribble, Pass, Sprint, Control, Shoot, Turn, Set up, Place
- NO "Step 1:" prefixes
- Design for {num_players} player(s) - assign roles/positions if multiple

DIAGRAM RULES:
- All element x values must be 0 to {field_dims['width']}
- All element y values must be 0 to {field_dims['length']}
- element types: "cone", "player", "target", "goal", "ball"
- path styles: "dribble", "run", "pass"

Return ONLY valid JSON:
{{"name": "Short name (max 40 chars)", "description": "One sentence purpose.", "setup": "Dimensions. Equipment. Player start.", "instructions": ["Action 1", "Action 2", "Action 3", "Action 4"], "diagram": {{"field": {{"width": {field_dims['width']}, "length": {field_dims['length']}}}, "elements": [{{"type": "cone", "x": 0, "y": 0, "label": "A"}}], "paths": [{{"from": "A", "to": "B", "style": "dribble"}}]}}, "progressions": ["Easier: ...", "Harder: ..."], "coachingPoints": ["Point 1", "Point 2", "Point 3"], "estimatedDuration": 15, "difficulty": "{difficulty}", "category": "{category}", "targetSkills": ["skill1", "skill2"], "equipment": {json.dumps(equipment)}, "safetyNotes": "Brief safety note"}}"""

    response = client.chat.completions.create(
        model="gpt-4-turbo",
        messages=[
            {"role": "system", "content": "You are an expert soccer coach. Write complete, practical drills from blueprints. Each instruction must be ONE clear action with an imperative verb. Keep all coordinates within the specified field dimensions."},
            {"role": "user", "content": prompt}
        ],
        max_tokens=1500,
        temperature=0.6
    )
    return parse_llm_json(response.choices[0].message.content)


def programmatic_validate(drill: Dict, field_dims: Dict, requirements: Dict) -> List[Dict]:
    """Run programmatic checks before LLM referee"""
    errors = []

    # Schema completeness
    required_fields = ["name", "description", "setup", "instructions", "diagram", "difficulty", "category", "targetSkills", "equipment"]
    for field in required_fields:
        if field not in drill:
            errors.append({"check": "schema", "issue": f"Missing required field: {field}", "fix": f"Add '{field}' to response"})

    # Coordinate bounds
    diagram = drill.get("diagram", {})
    elements = diagram.get("elements", [])
    width = field_dims["width"]
    length = field_dims["length"]
    for el in elements:
        x = el.get("x", 0)
        y = el.get("y", 0)
        if x < 0 or x > width:
            errors.append({"check": "spatial", "issue": f"Element '{el.get('label', '?')}' x={x} exceeds width={width}", "fix": f"Set x to max {width}"})
        if y < 0 or y > length:
            errors.append({"check": "spatial", "issue": f"Element '{el.get('label', '?')}' y={y} exceeds length={length}", "fix": f"Set y to max {length}"})

    # Equipment match
    available = set(requirements.get('equipment', []))
    if available:
        drill_equipment = set(drill.get("equipment", []))
        extra = drill_equipment - available - {"none"}
        if extra:
            errors.append({"check": "equipment", "issue": f"Uses unavailable equipment: {', '.join(extra)}", "fix": f"Only use: {', '.join(available)}"})

    return errors


def phase_referee(client, drill: Dict, focus_strategy: Dict, requirements: Dict, field_dims: Dict) -> Dict:
    """Phase 4: Validate drill quality (hybrid: programmatic + LLM)"""
    # Run programmatic checks first
    prog_errors = programmatic_validate(drill, field_dims, requirements)
    if prog_errors:
        return {"verdict": "ERRORS", "errors": prog_errors, "score": 30}

    # LLM validation
    prompt = f"""Review this soccer drill for quality and correctness.

Drill JSON:
{json.dumps(drill, indent=2)}

Context:
- Target weakness: {focus_strategy.get('primary_weakness', '')}
- Field size: {field_dims['width']}m x {field_dims['length']}m
- Available equipment: {', '.join(requirements.get('equipment', []))}
- Difficulty: {requirements.get('difficulty', 'intermediate')}

Validate:
1. SPATIAL: All coordinates within {field_dims['width']}x{field_dims['length']}m?
2. EQUIPMENT: Only uses available equipment?
3. CLARITY: Instructions are imperative, 15-25 words, one action each?
4. RELEVANCE: Addresses '{focus_strategy.get('primary_weakness', '')}'?
5. SAFETY: Appropriate for the difficulty level?
6. REALISM: Would a real coach assign this?
7. SCHEMA: All required fields present with correct types?

Return JSON:
{{"verdict": "VALID or ERRORS", "errors": [{{"check": "category", "issue": "description", "fix": "suggestion"}}], "score": 0-100}}

If everything passes, return {{"verdict": "VALID", "errors": [], "score": 85-100}}"""

    try:
        response = client.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": "You are a soccer drill safety and logic checker. Be strict but fair. Only flag genuine issues that would make the drill confusing, unsafe, or ineffective. Score 85+ means production-ready."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=800,
            temperature=0.1
        )
        result = parse_llm_json(response.choices[0].message.content)
        # Ensure proper structure
        if "verdict" not in result:
            result["verdict"] = "VALID" if not result.get("errors") else "ERRORS"
        if "score" not in result:
            result["score"] = 85 if result["verdict"] == "VALID" else 50
        return result
    except Exception as e:
        logger.warning(f"⚠️ Referee parse error: {e}, passing drill")
        return {"verdict": "VALID", "errors": [], "score": 70}

def get_existing_exercises(user_id: str) -> List[Dict]:
    """Get user's existing exercises to prevent duplicate recommendations"""
    try:
        global db
        if not db:
            logger.warning("⚠️ Firestore not initialized, returning empty exercises list")
            return []
        
        logger.info(f"🔍 Fetching existing exercises for user {user_id}")
        
        # Query Firestore for player's exercises (assuming they're synced from Core Data)
        # We'll check both the player's profile and any exercises collection
        exercises = []
        
        try:
            # Search in the correct Firestore collections based on iOS app structure
            logger.info(f"🔍 Searching for player with firebaseUID: {user_id}")
            
            # Try different collection names where players might be stored
            player_collections = ['playerProfiles', 'players', 'users']
            player_doc = None
            player_data = None
            
            for collection_name in player_collections:
                try:
                    player_ref = db.collection(collection_name).where('firebaseUID', '==', user_id).limit(1)
                    players = player_ref.get()
                    if players:
                        player_doc = players[0]
                        player_data = player_doc.to_dict()
                        logger.info(f"✅ Found player in {collection_name}: {player_data.get('name', 'Unknown')} (ID: {player_doc.id})")
                        break
                except Exception as e:
                    logger.warning(f"⚠️ Could not check {collection_name}: {e}")
                    continue
            
            if player_doc:
                # Check for exercises in the training sessions (this is where YouTube exercises are likely stored)
                try:
                    # Get training sessions for this player
                    sessions_ref = db.collection('trainingSessions').where('playerId', '==', player_doc.id)
                    session_docs = sessions_ref.get()
                    logger.info(f"🔍 Found {len(session_docs)} training sessions")
                    
                    total_exercises = 0
                    for session_doc in session_docs:
                        session_data = session_doc.to_dict()
                        session_exercises = session_data.get('exercises', [])
                        
                        for exercise_data in session_exercises:
                            # Look for YouTube video information
                            youtube_id = (exercise_data.get('youtubeVideoID') or 
                                        exercise_data.get('youtube_video_id') or 
                                        exercise_data.get('videoId') or '')
                            
                            is_youtube = (exercise_data.get('isYouTubeContent', False) or 
                                        exercise_data.get('is_youtube_content', False) or
                                        bool(youtube_id))
                            
                            if is_youtube and youtube_id:  # Only include YouTube exercises
                                exercise_record = {
                                    'id': session_doc.id + '_' + str(exercises.__len__()),
                                    'name': exercise_data.get('exerciseName', '') or exercise_data.get('name', ''),
                                    'youtube_video_id': youtube_id,
                                    'is_youtube_content': is_youtube,
                                    'title': exercise_data.get('exerciseName', '') or exercise_data.get('name', '') or exercise_data.get('title', ''),
                                    'category': exercise_data.get('category', ''),
                                    'created_at': session_data.get('date')
                                }
                                exercises.append(exercise_record)
                                total_exercises += 1
                                logger.info(f"📹 Found YouTube exercise in session: {exercise_record['name']} (Video ID: {youtube_id})")
                    
                    # Also check the exercises collection directly
                    exercises_ref = db.collection('exercises').where('playerId', '==', player_doc.id)
                    exercise_docs = exercises_ref.get()
                    logger.info(f"🔍 Found {len(exercise_docs)} exercises in exercises collection")
                    
                    for exercise_doc in exercise_docs:
                        exercise_data = exercise_doc.to_dict()
                        
                        youtube_id = (exercise_data.get('youtubeVideoID') or 
                                    exercise_data.get('youtube_video_id') or 
                                    exercise_data.get('videoId') or '')
                        
                        is_youtube = (exercise_data.get('isYouTubeContent', False) or 
                                    exercise_data.get('is_youtube_content', False) or
                                    bool(youtube_id))
                        
                        if is_youtube and youtube_id:
                            exercise_record = {
                                'id': exercise_doc.id,
                                'name': exercise_data.get('name', ''),
                                'youtube_video_id': youtube_id,
                                'is_youtube_content': is_youtube,
                                'title': exercise_data.get('name', '') or exercise_data.get('title', ''),
                                'category': exercise_data.get('category', ''),
                                'created_at': exercise_data.get('createdAt')
                            }
                            exercises.append(exercise_record)
                            total_exercises += 1
                            logger.info(f"📹 Found YouTube exercise in exercises collection: {exercise_record['name']} (Video ID: {youtube_id})")
                    
                    logger.info(f"✅ Total YouTube exercises found: {total_exercises}")
                    
                except Exception as e:
                    logger.warning(f"⚠️ Could not fetch training sessions/exercises: {e}")
            else:
                logger.warning(f"⚠️ No player found with firebaseUID: {user_id}")
                
                # Debug: show what players exist
                for collection_name in player_collections:
                    try:
                        all_players = db.collection(collection_name).limit(5).get()
                        logger.info(f"🔍 Found {len(all_players)} players in {collection_name}")
                        for player in all_players:
                            player_data = player.to_dict()
                            logger.info(f"🔍 Player in {collection_name}: {player_data.get('name', 'Unknown')} - UID: {player_data.get('firebaseUID', 'None')}")
                    except Exception as e:
                        logger.warning(f"⚠️ Could not check {collection_name}: {e}")
            
            logger.info(f"✅ Returning {len(exercises)} existing YouTube exercises for duplicate prevention")
            return exercises
            
        except Exception as e:
            logger.warning(f"⚠️ Could not fetch from exercises collection: {e}")
            # Fallback: return empty list to allow recommendations
            return []
        
    except Exception as e:
        logger.error(f"❌ Error getting existing exercises: {str(e)}")
        logger.error(traceback.format_exc())
        return []

def get_user_training_history(user_id: str, days: int = 30) -> List[Dict]:
    """Get user's recent training history from Firestore"""
    try:
        global db
        if not db:
            logger.warning("⚠️ Firestore not initialized, returning empty history")
            return []
        
        # Calculate date range
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        logger.info(f"🔍 Fetching training history for user {user_id} from {start_date.strftime('%Y-%m-%d')} to {end_date.strftime('%Y-%m-%d')}")
        
        # Query Firestore for training sessions
        sessions_ref = db.collection('training_sessions')
        query = sessions_ref.where('playerId', '==', user_id) \
                           .where('date', '>=', start_date) \
                           .where('date', '<=', end_date) \
                           .order_by('date', direction=firestore.Query.DESCENDING) \
                           .limit(50)  # Limit to most recent 50 sessions
        
        sessions = query.get()
        
        if not sessions:
            logger.info(f"📭 No training sessions found for user {user_id}")
            return []
        
        history = []
        
        for session_doc in sessions:
            session_data = session_doc.to_dict()
            
            # Process each exercise in the session
            exercises = session_data.get('exercises', [])
            
            for exercise in exercises:
                exercise_record = {
                    'session_id': session_doc.id,
                    'exercise_id': exercise.get('exerciseId', ''),
                    'exercise_name': exercise.get('exerciseName', 'Unknown Exercise'),
                    'category': exercise.get('category', 'General'),
                    'difficulty': exercise.get('difficulty', 3),
                    'rating': exercise.get('performanceRating', 3),
                    'duration': exercise.get('duration', 0),
                    'target_skills': exercise.get('targetSkills', []),
                    'completion_percentage': exercise.get('completionPercentage', 100),
                    'enjoyment_rating': exercise.get('enjoymentRating', 3),
                    'perceived_difficulty': exercise.get('perceivedDifficulty', 5),
                    'technical_execution': exercise.get('technicalExecution', 3),
                    'completed_at': session_data.get('date'),
                    
                    # Session context
                    'session_type': session_data.get('sessionType', 'Training'),
                    'session_intensity': session_data.get('intensity', 5),
                    'session_location': session_data.get('location', ''),
                    'session_rating': session_data.get('overallRating', 3),
                    'weather_conditions': session_data.get('weatherConditions', ''),
                    'energy_level_before': session_data.get('energyLevelBefore', 5),
                    'energy_level_after': session_data.get('energyLevelAfter', 5),
                    'perceived_exertion': session_data.get('perceivedExertion', 5)
                }
                
                history.append(exercise_record)
        
        logger.info(f"✅ Retrieved {len(history)} exercise records from {len(sessions)} training sessions")
        return history
        
    except Exception as e:
        logger.error(f"❌ Error getting user training history from Firestore: {str(e)}")
        logger.error(traceback.format_exc())
        
        # Return empty history on error rather than mock data
        return []

@https_fn.on_request()
def get_advanced_recommendations(req: https_fn.Request) -> https_fn.Response:
    """
    Get advanced collaborative filtering recommendations with SVD and match percentages
    
    Expected request body:
    {
        "user_id": "string",
        "player_profile": {
            "position": "midfielder",
            "age": 16,
            "experienceLevel": "intermediate",
            "goals": ["improve ball control"],
            "playingStyle": "attacking"
        },
        "candidate_exercises": ["exercise_1", "exercise_2", ...],
        "limit": 5
    }
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )
        
        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Firebase Auth token verification
        auth_header = req.headers.get('Authorization')
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                logger.info(f"🔐 Authenticated user: {decoded_token['uid']}")
            except Exception as e:
                if not allow_unauth:
                    return https_fn.Response(json.dumps({"error": "Invalid authentication token"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})
        elif not allow_unauth:
            return https_fn.Response(json.dumps({"error": "Authentication required"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        user_id = request_data.get('user_id')
        player_profile = request_data.get('player_profile', {})
        candidate_exercises = request_data.get('candidate_exercises', [])
        limit = min(request_data.get('limit', 5), 10)  # Cap at 10
        
        if not user_id or not player_profile:
            return https_fn.Response("Missing user_id or player_profile", status=400)
        
        logger.info(f"🧠 Generating advanced recommendations for user: {user_id} (SVD + Collaborative Filtering)")
        
        # Get comprehensive training data from Firestore
        try:
            # Collect training history from multiple users for collaborative filtering
            all_user_history = get_collaborative_training_data(limit_users=100)
            
            # Get user profiles for content-based features
            user_profiles = get_user_profiles(limit_users=50)
            
            # Get exercise catalog with features
            exercise_catalog = get_exercise_catalog()
            
            # Add current user's profile to the mix
            user_profiles[user_id] = player_profile
            
            logger.info(f"📊 Training data: {len(all_user_history)} sessions, {len(user_profiles)} users, {len(exercise_catalog)} exercises")
            
        except Exception as e:
            logger.warning(f"⚠️ Error fetching training data: {e}")
            # Fallback to empty data - engine will handle gracefully
            all_user_history = []
            user_profiles = {user_id: player_profile}
            exercise_catalog = {}
        
        # Create lightweight recommendations
        try:
            # Get candidate exercises if not provided
            if not candidate_exercises and exercise_catalog:
                candidate_exercises = list(exercise_catalog.keys())[:20]
            elif not candidate_exercises:
                # Default exercise set
                candidate_exercises = ['Ball Control', 'Passing Accuracy', 'Endurance Run', 'First Touch', 'Shooting Accuracy', 'Dribbling Skills']
            
            # Generate recommendations using lightweight engine
            recommendations = create_lightweight_recommendations(
                user_sessions=all_user_history,
                all_exercises=candidate_exercises,
                exercise_metadata=exercise_catalog,
                target_user_id=user_id
            )
            
        except Exception as e:
            logger.error(f"❌ Lightweight engine failed: {e}")
            # Fallback to basic recommendations
            recommendations = generate_fallback_recommendations(
                user_id, player_profile, candidate_exercises, limit
            )
        
        # Format response
        response_data = {
            "user_id": user_id,
            "recommendations": recommendations,
            "algorithm": "lightweight_collaborative_filtering",
            "generated_at": datetime.now().isoformat(),
            "model_version": "2.0.0",
            "player_profile": player_profile,
            "data_stats": {
                "training_sessions": len(all_user_history),
                "user_profiles": len(user_profiles),
                "exercise_catalog": len(exercise_catalog)
            }
        }
        
        logger.info(f"✅ Generated {len(recommendations)} advanced recommendations for {user_id}")
        return https_fn.Response(
            json.dumps(response_data),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
        
    except Exception as e:
        logger.error(f"❌ Error in get_advanced_recommendations: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

def get_collaborative_training_data(limit_users: int = 100) -> List[Dict]:
    """Get training data from multiple users for collaborative filtering"""
    try:
        global db
        if not db:
            return []
        
        logger.info(f"🔍 Fetching collaborative training data from {limit_users} users...")
        
        # Get training sessions from multiple users
        sessions_ref = db.collection('trainingSessions').limit(limit_users * 10)  # Get more sessions
        sessions = sessions_ref.get()
        
        training_data = []
        
        for session_doc in sessions:
            try:
                session_data = session_doc.to_dict()
                
                # Extract user info
                user_id = session_data.get('firebaseUID') or session_data.get('playerId')
                if not user_id:
                    continue
                
                # Extract exercises with ratings and performance data
                exercises = session_data.get('exercises', [])
                
                for exercise in exercises:
                    exercise_record = {
                        'user_id': user_id,
                        'exercise_id': exercise.get('exerciseId') or exercise.get('name'),
                        'name': exercise.get('exerciseName') or exercise.get('name'),
                        'category': exercise.get('category', ''),
                        'difficulty': exercise.get('difficulty', 3),
                        'rating': exercise.get('performanceRating') or exercise.get('rating'),
                        'completion_percentage': exercise.get('completionPercentage', 100),
                        'duration': exercise.get('duration', 0),
                        'technical_execution': exercise.get('technicalExecution'),
                        'enjoyment_rating': exercise.get('enjoymentRating'),
                        'perceived_difficulty': exercise.get('perceivedDifficulty'),
                        'completed_at': session_data.get('date'),
                        'exercises': [exercise],  # Keep original structure
                        
                        # Session context
                        'session_intensity': session_data.get('intensity', 5),
                        'session_rating': session_data.get('overallRating', 3),
                        'session_type': session_data.get('sessionType', 'Training')
                    }
                    training_data.append(exercise_record)
                    
            except Exception as e:
                logger.warning(f"⚠️ Error processing session {session_doc.id}: {e}")
                continue
        
        logger.info(f"✅ Collected {len(training_data)} training records from {len(sessions)} sessions")
        return training_data
        
    except Exception as e:
        logger.error(f"❌ Error getting collaborative training data: {e}")
        return []

def get_user_profiles(limit_users: int = 50) -> Dict[str, Dict]:
    """Get user profiles for content-based features"""
    try:
        global db
        if not db:
            return {}
        
        logger.info(f"🔍 Fetching user profiles from {limit_users} users...")
        
        user_profiles = {}
        
        # Try different collection names
        for collection_name in ['playerProfiles', 'players', 'users']:
            try:
                profiles_ref = db.collection(collection_name).limit(limit_users)
                profiles = profiles_ref.get()
                
                for profile_doc in profiles:
                    try:
                        profile_data = profile_doc.to_dict()
                        user_id = profile_data.get('firebaseUID') or profile_doc.id
                        
                        if user_id:
                            user_profiles[user_id] = {
                                'position': profile_data.get('position', ''),
                                'experienceLevel': profile_data.get('experienceLevel', 'intermediate'),
                                'age': profile_data.get('age', 18),
                                'goals': profile_data.get('goals', []),
                                'playingStyle': profile_data.get('playingStyle', ''),
                                'playerRoleModel': profile_data.get('playerRoleModel', '')
                            }
                    except Exception as e:
                        logger.warning(f"⚠️ Error processing profile {profile_doc.id}: {e}")
                        continue
                        
                if user_profiles:  # Found some profiles, use this collection
                    break
                    
            except Exception as e:
                logger.warning(f"⚠️ Could not access {collection_name}: {e}")
                continue
        
        logger.info(f"✅ Collected {len(user_profiles)} user profiles")
        return user_profiles
        
    except Exception as e:
        logger.error(f"❌ Error getting user profiles: {e}")
        return {}

def get_exercise_catalog() -> Dict[str, Dict]:
    """Get exercise catalog with features for content-based filtering"""
    try:
        global db
        if not db:
            return {}
        
        logger.info("🔍 Fetching exercise catalog...")
        
        exercise_catalog = {}
        
        # Get exercises from the exercises collection
        exercises_ref = db.collection('exercises').limit(500)
        exercises = exercises_ref.get()
        
        for exercise_doc in exercises:
            try:
                exercise_data = exercise_doc.to_dict()
                exercise_id = exercise_data.get('exerciseId') or exercise_data.get('name') or exercise_doc.id
                
                if exercise_id:
                    exercise_catalog[exercise_id] = {
                        'name': exercise_data.get('name', ''),
                        'description': exercise_data.get('description', ''),
                        'category': exercise_data.get('category', ''),
                        'difficulty': exercise_data.get('difficulty', 3),
                        'duration': exercise_data.get('duration', 0),
                        'target_skills': exercise_data.get('targetSkills', []),
                        'equipment': exercise_data.get('equipment', [])
                    }
            except Exception as e:
                logger.warning(f"⚠️ Error processing exercise {exercise_doc.id}: {e}")
                continue
        
        logger.info(f"✅ Collected {len(exercise_catalog)} exercises in catalog")
        return exercise_catalog
        
    except Exception as e:
        logger.error(f"❌ Error getting exercise catalog: {e}")
        return {}

def generate_fallback_recommendations(
    user_id: str, 
    player_profile: Dict, 
    candidate_exercises: List[str], 
    limit: int
) -> List[Dict]:
    """Generate basic fallback recommendations when SVD fails"""
    try:
        logger.info(f"🔧 Generating fallback recommendations for {user_id}")
        
        recommendations = []
        
        # Basic position-based and experience-based scoring
        position = player_profile.get('position', '').lower()
        experience = player_profile.get('experienceLevel', 'intermediate').lower()
        goals = player_profile.get('goals', [])
        
        for i, exercise_id in enumerate(candidate_exercises[:limit]):
            # Basic scoring based on keywords
            base_score = 60  # Base match percentage
            
            # Position bonus
            if position and position in exercise_id.lower():
                base_score += 10
                
            # Goal alignment
            for goal in goals:
                if goal.lower() in exercise_id.lower():
                    base_score += 15
                    
            # Experience level adjustment
            if experience == 'beginner':
                base_score += 5  # Boost for beginners
            elif experience == 'advanced':
                base_score += 10  # Higher confidence for advanced
                
            # Add some randomness to avoid identical scores
            import random
            base_score += random.randint(-5, 5)
            
            match_percentage = min(95, max(30, base_score))
            
            recommendations.append({
                'exercise_id': exercise_id,
                'match_percentage': match_percentage,
                'svd_score': match_percentage / 20.0,  # Convert to 1-5 scale
                'content_score': match_percentage / 20.0,
                'confidence': 0.5,
                'hybrid_score': match_percentage / 20.0,
                'reason': 'Recommended based on your profile'
            })
        
        # Sort by match percentage
        recommendations.sort(key=lambda x: x['match_percentage'], reverse=True)
        
        logger.info(f"✅ Generated {len(recommendations)} fallback recommendations")
        return recommendations
        
    except Exception as e:
        logger.error(f"❌ Error generating fallback recommendations: {e}")
        return []

# MARK: - Training Plan Generation

@https_fn.on_request()
def generate_training_plan(req: https_fn.Request) -> https_fn.Response:
    """
    Generate AI-powered training plan using Vertex AI Gemini

    Expected request body:
    {
        "user_id": "string",
        "player_profile": {
            "position": "midfielder",
            "age": 16,
            "experienceLevel": "intermediate",
            "goals": ["improve ball control", "increase speed"]
        },
        "duration_weeks": 6,
        "difficulty": "Intermediate",
        "category": "Technical",
        "focus_areas": ["Passing", "Vision"],
        "target_role": "Midfielder"
    }
    """
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return https_fn.Response(
                "",
                status=200,
                headers={
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            )

        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Firebase Auth token verification
        auth_header = req.headers.get('Authorization')
        allow_unauth = os.environ.get("ALLOW_UNAUTHENTICATED", "false") == "true"
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                logger.info(f"🔐 Authenticated user: {decoded_token['uid']}")
            except Exception as e:
                if not allow_unauth:
                    return https_fn.Response(json.dumps({"error": "Invalid authentication token"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})
        elif not allow_unauth:
            return https_fn.Response(json.dumps({"error": "Authentication required"}), status=401, headers={'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'})

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        # Extract request parameters
        user_id = request_data.get('user_id')
        player_profile = request_data.get('player_profile', {})
        duration_weeks = request_data.get('duration_weeks', 6)
        difficulty = request_data.get('difficulty', 'Intermediate')
        category = request_data.get('category', 'Technical')
        focus_areas = request_data.get('focus_areas', [])
        target_role = request_data.get('target_role')

        # Schedule preferences (Phase 2)
        preferred_days = request_data.get('preferred_days', [])
        rest_days = request_data.get('rest_days', [])

        if not user_id or not player_profile:
            return https_fn.Response("Missing user_id or player_profile", status=400)

        logger.info(f"🏋️ Generating {duration_weeks}-week {difficulty} training plan for {user_id}")
        logger.info(f"📝 Category: {category}, Focus: {', '.join(focus_areas)}")
        if preferred_days:
            logger.info(f"📅 Preferred training days: {', '.join(preferred_days)}")
        if rest_days:
            logger.info(f"😴 Required rest days: {', '.join(rest_days)}")

        # Build AI prompt
        player_goals = ', '.join(player_profile.get('goals', []))
        focus_areas_str = ', '.join(focus_areas) if focus_areas else 'general improvement'
        position = player_profile.get('position', 'player')
        age = player_profile.get('age', 16)
        experience = player_profile.get('experienceLevel', 'intermediate')

        # Build schedule preferences text
        schedule_prefs_text = ""
        if preferred_days:
            schedule_prefs_text += f"- Preferred Training Days: {', '.join(preferred_days)}\n"
        if rest_days:
            schedule_prefs_text += f"- Required Rest Days: {', '.join(rest_days)}\n"

        prompt = f"""You are a professional soccer coach. Create a {duration_weeks}-week {difficulty} training plan for a {position} focused on {category} skills.

Player Details:
- Age: {age}
- Experience: {experience}
- Position: {position}
- Goals: {player_goals}
{f'- Target Role: {target_role}' if target_role else ''}
{f'- Focus Areas: {focus_areas_str}' if focus_areas else ''}
{schedule_prefs_text}
Return ONLY valid JSON matching this exact structure (no markdown, no code blocks):
{{
  "name": "Plan Name",
  "description": "Brief description",
  "difficulty": "{difficulty}",
  "category": "{category}",
  "target_role": "{target_role or ''}",
  "weeks": [
    {{
      "week_number": 1,
      "focus_area": "Week theme",
      "notes": "Week notes",
      "days": [
        {{
          "day_number": 1,
          "day_of_week": "Monday",
          "is_rest_day": false,
          "sessions": [
            {{
              "session_type": "Technical",
              "duration": 45,
              "intensity": 3,
              "notes": "Session notes",
              "suggested_exercise_names": ["Wall Passing", "Cone Weaving"]
            }}
          ]
        }}
      ]
    }}
  ]
}}

IMPORTANT REQUIREMENTS:
- Include ALL 7 days per week (Monday through Sunday)
- Use progressive difficulty (periodization)
- Include 2-4 exercises per session
- Match exercise names to: Wall Passing, Triangle Passing, Cone Weaving, Dribbling Course, First Touch Practice, Juggling, Passing Gates, Speed Ladder, Sprints, Interval Run, Yoga Flow, Foam Rolling
- Session types: Technical, Physical, Tactical, Recovery
- Duration: 30-90 minutes
- Intensity: 1-5 scale
{f'- MUST mark these days as rest days (is_rest_day: true, sessions: []): {", ".join(rest_days)}' if rest_days else '- Include 1-2 rest days per week (is_rest_day: true)'}
{f'- PRIORITIZE training sessions on these days: {", ".join(preferred_days)}' if preferred_days else ''}
- Return ONLY the JSON object, no extra text"""

        # Use OpenAI as fallback (more reliable setup)
        # Get OpenAI API key from environment
        openai_api_key = os.environ.get('OPENAI_API_KEY')

        if not openai_api_key:
            return https_fn.Response(
                json.dumps({"error": "OpenAI API key not configured"}),
                status=500,
                headers={
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                }
            )

        # Call OpenAI GPT-4
        from openai import OpenAI
        client = OpenAI(api_key=openai_api_key)

        logger.info("🤖 Calling OpenAI GPT-4...")
        response = client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are an expert soccer coach specializing in personalized training plans. Return ONLY valid JSON, no markdown formatting."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=4000,
            temperature=0.7
        )

        response_text = response.choices[0].message.content

        logger.info(f"📄 AI Response length: {len(response_text)} characters")

        # Parse JSON (remove markdown code blocks if present)
        json_text = response_text.strip()
        if '```json' in json_text:
            json_text = json_text.split('```json')[1].split('```')[0].strip()
        elif '```' in json_text:
            json_text = json_text.split('```')[1].split('```')[0].strip()

        # Parse to JSON
        plan_data = json.loads(json_text)

        logger.info(f"✅ Generated plan: {plan_data.get('name', 'Unknown')}")
        logger.info(f"📊 Plan structure: {len(plan_data.get('weeks', []))} weeks")

        # Return to app
        return https_fn.Response(
            json.dumps(plan_data),
            status=200,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )

    except Exception as e:
        logger.error(f"❌ Error in generate_training_plan: {str(e)}")
        logger.error(traceback.format_exc())
        return https_fn.Response(
            json.dumps({"error": str(e)}),
            status=500,
            headers={
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        )
