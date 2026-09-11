"""
TechnIQ ML Recommendation Engine - Firebase Functions
Provides collaborative filtering and content-based recommendations for soccer training
"""

import json
import logging
import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Any, Optional, Tuple
import traceback

from firebase_admin import initialize_app, firestore, auth
from firebase_functions import https_fn

# Import our ML recommendation engines
from ml.youtube_recommendations import create_youtube_ml_engine
from lightweight_recommendations import create_lightweight_recommendations

# Register Firestore moderation triggers (auto-hide reported community content).
# Imported for the decorator side effects so `firebase deploy` picks them up.
from moderation_triggers import (  # noqa: F401
    hide_reported_post,
    hide_reported_comment,
    hide_reported_drill,
)

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

# MARK: - Security & Request Helpers

# Standard response headers. CORS is intentionally omitted: this backend serves the
# native iOS app (URLSession), not browsers, so no page legitimately calls it
# cross-origin. See .claude/rules/firebase.md.
_JSON_HEADERS = {"Content-Type": "application/json"}

# Reject request bodies larger than this before any prompt construction.
MAX_REQUEST_BYTES = 100_000

# Per-field caps for values interpolated into LLM prompts.
MAX_STR_LEN = 500
MAX_LIST_ITEMS = 20
MAX_LIST_ITEM_LEN = 200

# Per-uid daily request quotas (Firestore-backed, day-bucketed).
RATE_LIMIT_LLM = 10          # drill / plan / recommendation / coaching generation
RATE_LIMIT_LIGHTWEIGHT = 50  # non-LLM or cheap endpoints

_PROFILE_STR_FIELDS = (
    "position", "playingStyle", "experienceLevel", "playerRoleModel",
    "name", "style", "dominant_foot", "experience",
)
_PROFILE_LIST_FIELDS = ("goals", "weaknesses", "skillGoals")


def _emulator() -> bool:
    """True only inside the Firebase Functions emulator (local dev)."""
    return os.environ.get("FUNCTIONS_EMULATOR") == "true"


def _new_request_id() -> str:
    return uuid.uuid4().hex[:12]


_PATH_STYLE_VERBS = {
    "pass": "passes to", "dribble": "dribbles to", "shot": "shoots at",
    "shoot": "shoots at", "run": "runs to", "receive": "receives from",
    "throw": "throws to", "toss": "tosses to", "header": "heads to",
}


# Keyword → skill tag for analytics. First match wins, so more specific
# skills (finishing, weak foot) come before broad ones (ball control).
_SKILL_TAG_RULES: list[tuple[tuple[str, ...], str]] = [
    (("weak foot", "weaker foot"), "Weak Foot"),
    (("goalkeeper", "goalkeeping", "save", "catch", "handling", "distribution"), "Goalkeeping"),
    (("finish", "shooting", "shot", "striking", "strike", "volley"), "Shooting Accuracy"),
    (("cross", "crossing"), "Crossing"),
    (("head", "heading", "aerial", "clearance"), "Heading"),
    (("defend", "defending", "1v1", "tackle", "jockey", "press"), "Defending"),
    (("pass", "passing", "one touch", "one-touch"), "Passing Accuracy"),
    (("dribbl", "close control", "quick feet", "footwork", "ladder"), "Dribbling Skills"),
    (("first touch", "receiving", "cushion", "trap"), "First Touch"),
    (("speed", "agility", "faster", "sprint", "endurance", "stamina", "fitness"), "Speed & Agility"),
]


def _skill_tags_from_description(desc: str) -> list:
    text = desc.lower()
    tags = [tag for kws, tag in _SKILL_TAG_RULES if any(k in text for k in kws)]
    return tags[:3] or ["Ball Control"]


def _drill_display_name(focus_label: str) -> str:
    """A kid-facing title from the raw request text ('sharper one touch passing…' -> 'Sharper One Touch Passing')."""
    words = [w for w in focus_label.strip().rstrip(".!?").split() if w]
    trimmed: list[str] = []
    for w in words:
        trimmed.append(w)
        if len(" ".join(trimmed)) > 42:
            break
    title = " ".join(trimmed).title()
    if len(words) <= 2:
        title += " Drill"
    return title or "Custom Drill"


def _synthesize_setup(drill: Dict) -> str:
    elements = (drill.get("diagram") or {}).get("elements") or []
    counts: Dict[str, int] = {}
    for el in elements:
        t = el.get("type") or "item"
        counts[t] = counts.get(t, 0) + 1
    if not counts:
        return "See diagram."
    order = ["player", "ball", "cone", "goal", "gate", "wall", "server", "defender"]
    parts = []
    for t in order + [t for t in counts if t not in order]:
        if t in counts:
            n = counts.pop(t)
            parts.append(f"{n} {t}{'s' if n != 1 else ''}")
    return "Set up as shown in the diagram: " + ", ".join(parts) + "."


def _synthesize_instructions(drill: Dict) -> list:
    diagram = drill.get("diagram") or {}
    elements = {e.get("label"): e for e in diagram.get("elements") or []}
    steps = []
    for p in sorted(diagram.get("paths") or [], key=lambda x: x.get("step", 0)):
        if p.get("reset") or p.get("alt"):
            continue  # resets are hidden mechanics; alts render as or-arrows
        verb = _PATH_STYLE_VERBS.get(p.get("style"), "moves to")
        src = elements.get(p.get("from"), {})
        src_name = src.get("label") or p.get("from")
        role = src.get("role")
        who = f"{src_name} ({role})" if role else src_name
        # No "Step N:" prefix — the app numbers the list itself.
        steps.append(f"{who} {verb} {p.get('to')}.")
    return steps or ["Follow the diagram."]


def _json_response(body: Dict, status: int = 200) -> https_fn.Response:
    return https_fn.Response(json.dumps(body), status=status, headers=_JSON_HEADERS)


def _error_response(message: str, status: int, request_id: Optional[str] = None) -> https_fn.Response:
    body = {"error": message}
    if request_id:
        body["request_id"] = request_id
    return https_fn.Response(json.dumps(body), status=status, headers=_JSON_HEADERS)


def _preflight_response() -> https_fn.Response:
    # No CORS headers: native-app-only backend. Kept so any stray OPTIONS gets a clean 204.
    return https_fn.Response("", status=204, headers={})


def verify_request_uid(req: https_fn.Request) -> Tuple[Optional[str], Optional[https_fn.Response]]:
    """Verify the Firebase ID token.

    Returns (uid, None) when authenticated. Inside the emulator, returns
    (None, None) so local calls without a token proceed. In production, returns
    (None, <401 response>) on a missing or invalid token.
    """
    auth_header = req.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        try:
            id_token = auth_header.split("Bearer ")[1]
            decoded_token = auth.verify_id_token(id_token)
            uid = decoded_token["uid"]
            logger.info(f"🔐 Authenticated user: {uid}")
            return uid, None
        except Exception as e:
            logger.warning(f"⚠️ Auth token verification failed: {e}")
            if _emulator():
                return None, None
            return None, _error_response("Invalid authentication token", 401)
    if _emulator():
        return None, None
    logger.warning("⚠️ No auth token provided, rejecting request")
    return None, _error_response("Authentication required", 401)


def enforce_user_match(request_data: Dict, uid: Optional[str]) -> Optional[https_fn.Response]:
    """IDOR guard: reject when the body user_id doesn't match the authenticated uid.

    The admin SDK bypasses Firestore rules, so the token uid must be the source of
    truth for all data access. Callers should treat `uid` as authoritative after this.
    """
    if uid is None:
        return None  # emulator / local unauthenticated path
    body_user_id = request_data.get("user_id")
    if body_user_id and body_user_id != uid:
        logger.warning(f"🚫 user_id mismatch: body={body_user_id} token={uid}")
        return _error_response("user_id does not match authenticated user", 403)
    return None


def request_too_large(req: https_fn.Request) -> bool:
    """True when the request body exceeds MAX_REQUEST_BYTES."""
    try:
        length = req.content_length
        if length is not None:
            return length > MAX_REQUEST_BYTES
        return len(req.get_data(cache=True)) > MAX_REQUEST_BYTES
    except Exception:
        return False


def _clip_str(value: Any, max_len: int = MAX_STR_LEN) -> Any:
    if isinstance(value, str) and len(value) > max_len:
        return value[:max_len]
    return value


def _clip_list(value: Any, max_items: int = MAX_LIST_ITEMS, item_len: int = MAX_LIST_ITEM_LEN) -> Any:
    if not isinstance(value, list):
        return value
    return [_clip_str(v, item_len) if isinstance(v, str) else v for v in value[:max_items]]


def sanitize_profile(profile: Any) -> Dict:
    """Clip string/list fields of a player_profile that get interpolated into prompts."""
    if not isinstance(profile, dict):
        return {}
    out = dict(profile)
    for field in _PROFILE_STR_FIELDS:
        if field in out:
            out[field] = _clip_str(out[field])
    for field in _PROFILE_LIST_FIELDS:
        if field in out:
            out[field] = _clip_list(out[field])
    return out


def _rate_limit_bucket() -> str:
    return datetime.now(timezone.utc).strftime("%Y%m%d")


@firestore.transactional
def _rate_limit_txn(transaction, doc_ref, endpoint: str, limit: int, day: str) -> bool:
    snapshot = doc_ref.get(transaction=transaction)
    data = snapshot.to_dict() if (snapshot and snapshot.exists) else {}
    counts = data.get("counts", {}) if data.get("day") == day else {}
    current = counts.get(endpoint, 0)
    if current >= limit:
        return False
    counts[endpoint] = current + 1
    transaction.set(doc_ref, {"day": day, "counts": counts, "updatedAt": firestore.SERVER_TIMESTAMP})
    return True


def enforce_rate_limit(uid: Optional[str], endpoint: str, limit: int) -> Optional[https_fn.Response]:
    """Per-uid daily quota. Returns a 429 response when exceeded, else None.

    Fails OPEN (returns None) on any limiter-internal error — logged loudly — so a
    Firestore hiccup never takes down the endpoint.
    """
    if uid is None or not db:
        return None
    try:
        day = _rate_limit_bucket()
        doc_ref = db.collection("rateLimits").document(uid)
        allowed = _rate_limit_txn(db.transaction(), doc_ref, endpoint, limit, day)
        if not allowed:
            logger.warning(f"🚦 Rate limit hit: uid={uid} endpoint={endpoint} limit={limit}/day")
            return _error_response(
                f"Daily limit reached for this feature ({limit}/day). Please try again tomorrow.",
                429,
            )
        return None
    except Exception as e:
        logger.error(f"🚨 Rate limiter error (failing OPEN) endpoint={endpoint}: {e}")
        return None


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
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Firebase Auth token verification (required in production)
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        # Token uid is the source of truth for data access (admin SDK bypasses rules).
        user_id = uid or request_data.get('user_id')
        player_profile = sanitize_profile(request_data.get('player_profile', {}))
        # Force limit to 1 - only generate one recommendation at a time (v2)
        limit = 1

        if not user_id or not player_profile:
            return https_fn.Response("Missing user_id or player_profile", status=400)

        rate_error = enforce_rate_limit(uid, "youtube_recommendations", RATE_LIMIT_LLM)
        if rate_error:
            return rate_error

        logger.info(f"🎥 Generating single YouTube recommendation for user: {user_id} (v2 - enhanced duplicate detection)")
        
        # Get API keys from environment variables
        youtube_api_key = os.environ.get('YOUTUBE_API_KEY')
        anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')

        logger.info(f"🔑 YouTube API key available: {bool(youtube_api_key)}")
        logger.info(f"🔑 Anthropic API key available: {bool(anthropic_api_key)}")
        
        if not youtube_api_key or youtube_api_key == 'YOUR_YOUTUBE_API_KEY_HERE':
            return https_fn.Response("YouTube API key not configured", status=500)
        
        # Get user's existing exercises to prevent duplicates
        existing_exercises = get_existing_exercises(user_id)
        
        # Create YouTube ML engine with LLM query generation
        youtube_engine = create_youtube_ml_engine(youtube_api_key, anthropic_api_key)
        
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
        return _json_response(response_data, 200)

    except Exception as e:
        logger.exception(f"❌ Error in get_youtube_recommendations [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)

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
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Firebase Auth token verification
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        rate_error = enforce_rate_limit(uid, "custom_drill", RATE_LIMIT_LLM)
        if rate_error:
            return rate_error

        player_profile = sanitize_profile(request_data.get("player_profile", {}))
        requirements = request_data.get("requirements", {})

        # Weakness precedence: request-specific signals beat static profile.
        selected_weaknesses = _clip_list(requirements.get("selected_weaknesses") or [])
        skill_description = _clip_str((requirements.get("skill_description") or "").strip())
        if selected_weaknesses and isinstance(selected_weaknesses[0], dict) and selected_weaknesses[0].get("category"):
            weakness = _clip_str(selected_weaknesses[0]["category"])
        elif player_profile.get("weaknesses"):
            weakness = _clip_str(player_profile["weaknesses"][0])
        else:
            weakness = "Ball Control"

        # Periodization source of truth: requirements.difficulty wins, then profile, then default.
        # The iOS app sends capitalized levels ("Beginner"); every downstream rule
        # (quality carve-outs, exemplar filtering) compares lowercase.
        level = str(
            requirements.get("difficulty")
            or player_profile.get("experienceLevel")
            or "intermediate"
        ).strip().lower()
        age = max(4, min(int(player_profile.get("age") or 14), 99))
        position = _clip_str(player_profile.get("position", "midfielder"))
        equipment = _clip_list(requirements.get("equipment", ["ball", "cones"]))
        category = _clip_str(requirements.get("category", "technical"))
        number_of_players = max(1, min(int(requirements.get("number_of_players") or 2), 22))
        field_size = _clip_str(request_data.get("field_size", "small"))
        recent_drill_names = _clip_list(requirements.get("recent_drill_names") or [])
        playing_style = _clip_str(player_profile.get("playingStyle", ""))
        skill_goals = _clip_list(player_profile.get("skillGoals") or [])

        # Initialize Anthropic client
        anthropic_api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not anthropic_api_key:
            return _error_response("Service temporarily unavailable", 500, request_id)

        from anthropic import Anthropic
        client = Anthropic(api_key=anthropic_api_key)

        from drill_generator import generate_drill, DrillGenerationFailed, SYSTEM_PROMPT
        from drill_animator import author_timeline

        def _llm_call(prompt: str) -> str:
            # opus-4-8 won the 2026-09-06 model A/B: geometry 80.8 vs 71.7
            # (sonnet-4-6), 6/6 reliability, ~4x faster wall-clock via fewer
            # retries — see scratchpad model_ab results in session notes.
            #
            # Prompt caching: static rulebook in a cached system block; the
            # per-request body gets its own breakpoint so retries 2-5 (same
            # body, errors appended at the tail) read it from cache.
            body = prompt
            system = None
            from drill_animator import AUTHOR_STATIC
            for prefix in (SYSTEM_PROMPT, AUTHOR_STATIC):
                if prompt.startswith(prefix):
                    system = [{"type": "text", "text": prefix,
                               "cache_control": {"type": "ephemeral"}}]
                    body = prompt[len(prefix):].lstrip("\n")
                    break
            marker = "PRIOR ATTEMPT ERRORS"
            if system and marker in body:
                head, tail = body.split(marker, 1)
                content = [{"type": "text", "text": head,
                            "cache_control": {"type": "ephemeral"}},
                           {"type": "text", "text": marker + tail}]
            else:
                content = [{"type": "text", "text": body}]
            msg = client.messages.create(
                model="claude-opus-4-8",
                max_tokens=1500,
                **({"system": system} if system else {}),
                messages=[{"role": "user", "content": content}],
            )
            u = msg.usage
            cr = getattr(u, "cache_read_input_tokens", 0) or 0
            cw = getattr(u, "cache_creation_input_tokens", 0) or 0
            logger.info(f"💰 drill-gen tokens in={u.input_tokens} out={u.output_tokens} "
                        f"cache_read={cr} cache_write={cw} "
                        f"est=${(u.input_tokens*5 + cr*0.5 + cw*6.25 + u.output_tokens*25)/1e6:.4f}")
            return msg.content[0].text

        # Validate request data
        if not player_profile or not requirements:
            return _error_response("player_profile and requirements are required", 400, request_id)

        try:
            drill = generate_drill(
                {
                    "weakness": weakness,
                    "experience_level": level,
                    "player_age": age,
                    "position": position,
                    "equipment": equipment,
                    "skill_description": skill_description,
                    "selected_weaknesses": selected_weaknesses,
                    "category": category,
                    "number_of_players": number_of_players,
                    "field_size": field_size,
                    "recent_drill_names": recent_drill_names,
                    "playing_style": playing_style,
                    "skill_goals": skill_goals,
                },
                llm_call=_llm_call,
            )

            # Animation: compile the phase timeline, then let the model direct
            # pacing + narration within rails (movement immutable, refereed).
            try:
                drill["animation"] = author_timeline(drill, _llm_call)
            except Exception as anim_err:  # animation is enhancement, never fatal
                logger.warning(f"animation pass failed: {anim_err}")
                try:
                    from drill_timeline import compile_timeline
                    drill["animation"] = compile_timeline(drill)
                except Exception:
                    pass
        except DrillGenerationFailed as e:
            logger.error(f"Drill generation failed [{request_id}]: {e}")
            return _error_response("Drill generation failed", 500, request_id)

        if "coaching_points" in drill:
            drill["coachingPoints"] = drill.pop("coaching_points")
        else:
            drill.setdefault("coachingPoints", [])

        focus_label = skill_description or weakness
        duration_minutes = max(5, min(int(requirements.get("duration_minutes") or 15), 90))
        drill.setdefault("name", _drill_display_name(focus_label))
        solo = "Solo" if number_of_players == 1 else f"{number_of_players}-player"
        drill.setdefault(
            "description",
            f"{solo} {duration_minutes}-minute session targeting {focus_label}.",
        )
        drill.setdefault("setup", _synthesize_setup(drill))
        drill.setdefault("instructions", _synthesize_instructions(drill))
        raw_vars = drill.get("variations") or []
        drill["variations"] = [
            {"name": (v.split(" — ")[0] if " — " in v else v)[:40],
             "description": v, "modification": v}
            for v in raw_vars if isinstance(v, str)
        ][:4]
        drill.setdefault("estimatedDuration", duration_minutes)
        drill.setdefault("difficulty", level)
        drill.setdefault("category", "technical")
        if skill_description:
            drill.setdefault("targetSkills", _skill_tags_from_description(skill_description))
        else:
            drill.setdefault("targetSkills", [weakness])

        return _json_response({
            "drill": drill,
            "generated_at": datetime.now().isoformat(),
        }, 200)
    except Exception as e:
        logger.exception(f"generate_custom_drill failed [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)

def parse_llm_json(content: str) -> Dict:
    """Extract and parse JSON from LLM response, stripping markdown fences"""
    if "```json" in content:
        content = content.split("```json")[1].split("```")[0]
    elif "```" in content:
        content = content.split("```")[1]
    return json.loads(content.strip())


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
        
        # Query Firestore for training sessions. Collection is 'trainingSessions'
        # (camelCase) to match the rest of the codebase; filter by firebaseUID since
        # that is the value the caller passes (the token uid). Requires the
        # firebaseUID+date composite index in firestore.indexes.json.
        sessions_ref = db.collection('trainingSessions')
        query = sessions_ref.where('firebaseUID', '==', user_id) \
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
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Firebase Auth token verification
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        rate_error = enforce_rate_limit(uid, "advanced_recommendations", RATE_LIMIT_LIGHTWEIGHT)
        if rate_error:
            return rate_error

        # Token uid is the source of truth for data access (admin SDK bypasses rules).
        user_id = uid or request_data.get('user_id')
        player_profile = sanitize_profile(request_data.get('player_profile', {}))
        candidate_exercises = _clip_list(request_data.get('candidate_exercises', []), max_items=50)
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
        return _json_response(response_data, 200)

    except Exception as e:
        logger.exception(f"❌ Error in get_advanced_recommendations [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)

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
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        # Parse request
        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Firebase Auth token verification
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        rate_error = enforce_rate_limit(uid, "training_plan", RATE_LIMIT_LLM)
        if rate_error:
            return rate_error

        # Extract request parameters (token uid authoritative; prompt-bound fields capped)
        user_id = uid or request_data.get('user_id')
        player_profile = sanitize_profile(request_data.get('player_profile', {}))
        try:
            duration_weeks = max(1, min(int(request_data.get('duration_weeks', 6)), 12))
        except (TypeError, ValueError):
            duration_weeks = 6
        difficulty = _clip_str(request_data.get('difficulty', 'Intermediate'))
        category = _clip_str(request_data.get('category', 'Technical'))
        focus_areas = _clip_list(request_data.get('focus_areas', []))
        target_role = _clip_str(request_data.get('target_role'))

        # Schedule preferences (Phase 2)
        preferred_days = _clip_list(request_data.get('preferred_days', []))
        rest_days = _clip_list(request_data.get('rest_days', []))

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

        # Get Anthropic API key from environment
        anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')

        if not anthropic_api_key:
            return _error_response("Service temporarily unavailable", 500, request_id)

        # Call Claude Sonnet
        from anthropic import Anthropic
        client = Anthropic(api_key=anthropic_api_key)

        logger.info("🤖 Calling Claude Sonnet...")
        response = client.messages.create(
            model="claude-sonnet-4-6",
            system="You are an expert soccer coach specializing in personalized training plans. Return ONLY valid JSON, no markdown formatting.",
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_tokens=4000,
            temperature=0.7
        )

        response_text = response.content[0].text

        logger.info(f"📄 AI Response length: {len(response_text)} characters")

        # Parse JSON (remove markdown code blocks if present)
        json_text = response_text.strip()
        if '```json' in json_text:
            json_text = json_text.split('```json')[1].split('```')[0].strip()
        elif '```' in json_text:
            json_text = json_text.split('```')[1].split('```')[0].strip()

        # Parse to JSON
        plan_data = json.loads(json_text)

        # Deterministically enforce schedule prefs — the model treats them as
        # suggestions (live test: Mon/Wed/Sat preference still produced 6
        # training days). A kid who picked 3 days must get 3 days.
        _enforce_schedule_prefs(plan_data, preferred_days, rest_days)

        logger.info(f"✅ Generated plan: {plan_data.get('name', 'Unknown')}")
        logger.info(f"📊 Plan structure: {len(plan_data.get('weeks', []))} weeks")

        # Return to app
        return _json_response(plan_data, 200)

    except Exception as e:
        logger.exception(f"❌ Error in generate_training_plan [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)


def _enforce_schedule_prefs(plan_data, preferred_days, rest_days) -> None:
    """Force plan days to honor the user's picked training/rest days in place.

    - Any day named in rest_days becomes a rest day.
    - If preferred_days is non-empty, every day NOT in it becomes a rest day.
    Day-name matching is case-insensitive; unnamed days are left untouched.
    """
    preferred = {d.strip().lower() for d in (preferred_days or []) if isinstance(d, str)}
    rest = {d.strip().lower() for d in (rest_days or []) if isinstance(d, str)}
    if not preferred and not rest:
        return
    for week in plan_data.get("weeks") or []:
        for day in week.get("days") or []:
            name = str(day.get("day_of_week") or "").strip().lower()
            if not name:
                continue
            if name in rest or (preferred and name not in preferred):
                day["is_rest_day"] = True
                day["sessions"] = []


@https_fn.on_request(timeout_sec=60)
def get_daily_coaching(req: https_fn.Request) -> https_fn.Response:
    """
    Generate daily coaching recommendation based on player context.
    Returns focus area, reasoning, recommended drill, tips, and AI insights.
    """
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Auth verification
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        rate_error = enforce_rate_limit(uid, "daily_coaching", RATE_LIMIT_LLM)
        if rate_error:
            return rate_error

        player_profile = sanitize_profile(request_data.get('player_profile', {}))
        recent_sessions = request_data.get('recent_sessions', [])[:20]
        category_balance = request_data.get('category_balance', {})
        active_plan = request_data.get('active_plan', {})
        streak_days = request_data.get('streak_days', 0)
        days_since_last = request_data.get('days_since_last_session', 0)
        total_sessions = request_data.get('total_sessions', 0)

        logger.info(f"🎯 Generating daily coaching for user with {len(recent_sessions)} recent sessions")

        anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not anthropic_api_key:
            return _error_response("Service temporarily unavailable", 500, request_id)

        from anthropic import Anthropic
        client = Anthropic(api_key=anthropic_api_key)

        # Build session summary for prompt
        session_text = ""
        for s in recent_sessions[:10]:
            session_text += f"- {s.get('date', '?')}: {s.get('duration_minutes', 0)}min, rated {s.get('overall_rating', 0)}/5\n"
            for ex in s.get('exercises', []):
                session_text += f"  - {ex.get('name', '?')} ({ex.get('category', '?')}): skills={ex.get('skills', [])}, rated {ex.get('rating', 0)}/5\n"

        balance_text = f"Technical: {category_balance.get('technical', 0)}%, Physical: {category_balance.get('physical', 0)}%, Tactical: {category_balance.get('tactical', 0)}%"

        plan_text = ""
        if active_plan:
            plan_text = f"Active plan: {active_plan.get('name', 'Unknown')}, Week {active_plan.get('week', '?')}, {active_plan.get('progress', 0)*100:.0f}% complete"

        streak_text = f"Current streak: {streak_days} days. Days since last session: {days_since_last}. Total sessions: {total_sessions}."

        prompt = f"""Analyze this soccer player's recent training and provide today's coaching recommendation.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')} level
Style: {player_profile.get('style', 'unknown')}, Dominant foot: {player_profile.get('dominant_foot', 'unknown')}
Goals: {', '.join(player_profile.get('goals', []))}
Weaknesses: {', '.join(player_profile.get('weaknesses', []))}

Recent sessions (newest first):
{session_text or 'No sessions yet'}

Category balance: {balance_text}
{plan_text}
{streak_text}

Instructions:
1. Identify the ONE most important focus area based on skill rating trends, category imbalance, or neglected weaknesses
2. Provide 2-sentence reasoning with specific data points (e.g. "Your passing ratings dropped from 3.6 to 2.8")
3. Design a specific drill targeting this focus area, appropriate for the player's level
4. Give 1-3 actionable coaching tips
5. Generate 1-2 data-backed insights (celebrations for improvements, warnings for declines, recommendations for imbalances)
6. If streak > 3, include a brief motivational streak message

Return ONLY valid JSON:
{{"focus_area": "Passing", "reasoning": "Your passing ratings...", "recommended_drill": {{"name": "Short name", "description": "One sentence", "category": "technical", "difficulty": 3, "duration": 15, "steps": ["Step 1", "Step 2"], "equipment": ["ball", "cones"], "target_skills": ["passing", "first touch"], "is_from_library": false, "library_exercise_id": null}}, "additional_tips": ["Tip 1"], "streak_message": "5 days strong!", "insights": [{{"title": "Title", "description": "Description with data", "type": "celebration|recommendation|warning|pattern", "priority": 9, "actionable": "Optional action"}}]}}"""

        response = client.messages.create(
            model="claude-sonnet-4-6",
            system="You are an expert soccer coach providing daily personalized training guidance. Be concise, data-driven, and actionable. Focus on the most impactful improvement area.",
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_tokens=1200,
            temperature=0.4
        )

        result = parse_llm_json(response.content[0].text)

        logger.info(f"✅ Daily coaching generated: focus={result.get('focus_area', '?')}")
        return _json_response(result, 200)

    except Exception as e:
        logger.exception(f"❌ Error in get_daily_coaching [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)


@https_fn.on_request(timeout_sec=60)
def get_plan_adaptation(req: https_fn.Request) -> https_fn.Response:
    """
    Review a completed plan week and propose adaptations for the next week.
    """
    request_id = _new_request_id()
    try:
        if req.method == 'OPTIONS':
            return _preflight_response()

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        if request_too_large(req):
            return _error_response("Request too large", 400)

        # Auth verification
        uid, auth_error = verify_request_uid(req)
        if auth_error:
            return auth_error

        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)

        idor_error = enforce_user_match(request_data, uid)
        if idor_error:
            return idor_error

        rate_error = enforce_rate_limit(uid, "plan_adaptation", RATE_LIMIT_LLM)
        if rate_error:
            return rate_error

        player_profile = sanitize_profile(request_data.get('player_profile', {}))
        plan_structure = request_data.get('plan_structure', {})
        completed_week = request_data.get('completed_week', {})
        week_number = request_data.get('week_number', 1)

        logger.info(f"📊 Generating plan adaptation for week {week_number}")

        anthropic_api_key = os.environ.get('ANTHROPIC_API_KEY')
        if not anthropic_api_key:
            return _error_response("Service temporarily unavailable", 500, request_id)

        from anthropic import Anthropic
        client = Anthropic(api_key=anthropic_api_key)

        # Build context
        week_summary = ""
        sessions_completed = 0
        total_sessions = 0
        ratings = []

        for day in completed_week.get('days', []):
            for session in day.get('sessions', []):
                total_sessions += 1
                if session.get('completed', False):
                    sessions_completed += 1
                    if session.get('rating'):
                        ratings.append(session['rating'])
                week_summary += f"- Day {day.get('day_number', '?')}: {session.get('type', '?')}, "
                week_summary += f"{'completed' if session.get('completed') else 'skipped'}"
                if session.get('rating'):
                    week_summary += f", rated {session['rating']}/5"
                week_summary += "\n"
                for ex in session.get('exercises', []):
                    week_summary += f"  - {ex.get('name', '?')}: rated {ex.get('rating', '?')}/5, skills: {ex.get('skills', [])}\n"

        avg_rating = sum(ratings) / len(ratings) if ratings else 0

        prompt = f"""Review this completed training plan week and propose specific adaptations for next week.

Player: Age {player_profile.get('age', '?')}, {player_profile.get('position', '?')}, {player_profile.get('experience', 'intermediate')}
Plan: {plan_structure.get('name', 'Unknown')}
Week {week_number} completed: {sessions_completed}/{total_sessions} sessions, avg rating {avg_rating:.1f}/5

Week details:
{week_summary or 'No data'}

Next week's current plan:
{json.dumps(plan_structure.get('next_week', {}), indent=2)}

Instructions:
1. Summarize the week in 2-3 sentences (what went well, what needs work)
2. Propose 1-3 specific adaptations for next week based on performance data
3. Each adaptation should be one of: add_session, modify_difficulty, remove_session, swap_exercise
4. Be conservative — only propose changes backed by clear data signals

Return ONLY valid JSON:
{{"summary": "Week summary...", "adaptations": [{{"type": "modify_difficulty", "day": 2, "session_index": 0, "description": "Bump dribbling difficulty from 3 to 4", "old_difficulty": 3, "new_difficulty": 4, "drill": null}}, {{"type": "add_session", "day": 3, "session_index": null, "description": "Add passing drill", "old_difficulty": null, "new_difficulty": null, "drill": {{"name": "Wall Pass Combos", "description": "...", "category": "technical", "difficulty": 3, "duration": 15, "steps": ["Step 1"], "equipment": ["ball", "wall"], "target_skills": ["passing"], "is_from_library": false, "library_exercise_id": null}}}}]}}"""

        response = client.messages.create(
            model="claude-sonnet-4-6",
            system="You are a soccer training plan analyst. Review weekly performance data and propose minimal, data-driven adaptations. Be conservative — only change what the data clearly supports.",
            messages=[
                {"role": "user", "content": prompt}
            ],
            max_tokens=1000,
            temperature=0.3
        )

        result = parse_llm_json(response.content[0].text)

        logger.info(f"✅ Plan adaptation generated: {len(result.get('adaptations', []))} changes proposed")
        return _json_response(result, 200)

    except Exception as e:
        logger.exception(f"❌ Error in get_plan_adaptation [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)


@https_fn.on_request(timeout_sec=120)
def delete_account(req: https_fn.Request) -> https_fn.Response:
    """
    Permanently delete a user's account and all associated data.
    Anonymizes community posts, deletes Firestore docs, deletes Firebase Auth user.
    """
    request_id = _new_request_id()
    try:
        # Handle CORS preflight
        if req.method == 'OPTIONS':
            return _preflight_response()

        if req.method != 'POST':
            return https_fn.Response("Method not allowed", status=405)

        # Auth verification — REQUIRED, no emulator bypass for account deletion.
        auth_header = req.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return _error_response("Authentication required", 401)

        try:
            id_token = auth_header.split('Bearer ')[1]
            decoded_token = auth.verify_id_token(id_token)
            uid = decoded_token['uid']
            logger.info(f"🗑️ Account deletion requested by user: {uid}")
        except Exception as e:
            logger.warning(f"⚠️ delete_account token verification failed [{request_id}]: {e}")
            return _error_response("Invalid authentication token", 401)

        global db
        if not db:
            db = firestore.client()

        # Collect every player identity owned by this uid. Legacy top-level docs
        # (playerProfiles/players/trainingSessions/exercises) are keyed by generated
        # doc IDs and reference the owner via a firebaseUID field and/or a playerId
        # (Core Data UUID) field, so we need both to find all of the user's data.
        owned_player_ids = set()
        owned_profile_refs = []
        for collection_name in ('playerProfiles', 'players'):
            try:
                for doc in db.collection(collection_name).where('firebaseUID', '==', uid).stream():
                    owned_profile_refs.append(doc.reference)
                    owned_player_ids.add(doc.id)
                    pid = doc.to_dict().get('playerId')
                    if pid:
                        owned_player_ids.add(pid)
            except Exception as e:
                logger.warning(f"⚠️ Error querying {collection_name} by firebaseUID [{request_id}]: {e}")
        owned_player_ids.discard(uid)  # uid-keyed docs handled separately below

        # Step 1: Anonymize community posts and comments authored by this user.
        try:
            posts = db.collection('communityPosts').where('authorID', '==', uid).get()
            for post in posts:
                post.reference.update({
                    'authorID': 'deleted',
                    'authorName': 'Deleted User',
                    'authorProfileImageURL': '',
                    'authorAvatarState': None
                })
            logger.info(f"📝 Anonymized {len(posts)} community posts")
        except Exception as e:
            logger.warning(f"⚠️ Error anonymizing posts [{request_id}]: {e}")

        try:
            comments = db.collection_group('comments').where('authorID', '==', uid).get()
            for comment in comments:
                comment.reference.update({'authorID': 'deleted', 'authorName': 'Deleted User'})
            logger.info(f"📝 Anonymized {len(comments)} community comments")
        except Exception as e:
            logger.warning(f"⚠️ Error anonymizing comments [{request_id}]: {e}")

        # Step 2: Delete uid-keyed top-level documents.
        for collection_name in (
            'playerProfiles', 'players', 'mlRecommendations',
            'playerGoals', 'recommendationFeedback', 'cloudSyncStatus',
        ):
            try:
                db.collection(collection_name).document(uid).delete()
                logger.info(f"🗑️ Deleted {collection_name}/{uid}")
            except Exception as e:
                logger.warning(f"⚠️ Error deleting {collection_name}/{uid} [{request_id}]: {e}")

        # Step 3: Delete legacy profile docs found via firebaseUID (doc ID != uid).
        for ref in owned_profile_refs:
            try:
                ref.delete()
            except Exception as e:
                logger.warning(f"⚠️ Error deleting profile doc {ref.path} [{request_id}]: {e}")

        # Step 4: Batch-delete owned data in top-level collections keyed by
        # generated IDs, matched by firebaseUID and by each owned playerId.
        for collection_name in ('trainingSessions', 'exercises'):
            try:
                n = _batch_delete_query(db.collection(collection_name).where('firebaseUID', '==', uid))
                for pid in owned_player_ids:
                    n += _batch_delete_query(db.collection(collection_name).where('playerId', '==', pid))
                logger.info(f"🗑️ Deleted {n} docs from {collection_name}")
            except Exception as e:
                logger.warning(f"⚠️ Error deleting {collection_name} [{request_id}]: {e}")

        # Step 5: Delete user-authored community content.
        try:
            n = _batch_delete_query(db.collection('sharedDrills').where('authorID', '==', uid))
            logger.info(f"🗑️ Deleted {n} sharedDrills")
        except Exception as e:
            logger.warning(f"⚠️ Error deleting sharedDrills [{request_id}]: {e}")

        try:
            n = _batch_delete_query(db.collection('communityPlans').where('contributorUID', '==', uid))
            logger.info(f"🗑️ Deleted {n} communityPlans")
        except Exception as e:
            logger.warning(f"⚠️ Error deleting communityPlans [{request_id}]: {e}")

        # Step 6: Delete ML analytics keyed by owned playerIds (no firebaseUID field).
        for pid in owned_player_ids:
            try:
                _batch_delete_query(db.collection('mlAnalytics').where('playerId', '==', pid))
            except Exception as e:
                logger.warning(f"⚠️ Error deleting mlAnalytics for playerId={pid} [{request_id}]: {e}")

        # Step 7: Delete the user's rate-limit counter.
        try:
            db.collection('rateLimits').document(uid).delete()
        except Exception as e:
            logger.warning(f"⚠️ Error deleting rateLimits/{uid} [{request_id}]: {e}")

        # Step 8: Delete /users/{uid} and all subcollections.
        try:
            _delete_document_and_subcollections(db.collection('users').document(uid))
            logger.info(f"🗑️ Deleted users/{uid} and subcollections")
        except Exception as e:
            logger.warning(f"⚠️ Error deleting users/{uid} [{request_id}]: {e}")

        # Step 9: Delete Firebase Auth user LAST — if Firestore cleanup above failed,
        # the account still exists so the client can retry.
        try:
            auth.delete_user(uid)
            logger.info(f"🗑️ Deleted Firebase Auth user: {uid}")
        except Exception as e:
            logger.exception(f"❌ Error deleting auth user [{request_id}]: {e}")
            return _error_response("Failed to delete account", 500, request_id)

        logger.info(f"✅ Account deletion complete for user: {uid}")
        return _json_response({"success": True}, 200)

    except Exception as e:
        logger.exception(f"❌ Error in delete_account [{request_id}]: {e}")
        return _error_response("Internal error", 500, request_id)


def _delete_document_and_subcollections(doc_ref):
    """Recursively delete a document and all its subcollections."""
    for collection_ref in doc_ref.collections():
        for doc in collection_ref.get():
            _delete_document_and_subcollections(doc.reference)
    doc_ref.delete()


def _batch_delete_query(query, batch_size: int = 400) -> int:
    """Delete every document matching a query in batches. Returns the count deleted."""
    deleted = 0
    docs = list(query.limit(batch_size).stream())
    while docs:
        batch = db.batch()
        for doc in docs:
            batch.delete(doc.reference)
        batch.commit()
        deleted += len(docs)
        if len(docs) < batch_size:
            break
        docs = list(query.limit(batch_size).stream())
    return deleted
