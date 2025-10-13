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
        
        # Optional Firebase Auth token verification (for testing, allow unauthenticated)
        auth_header = req.headers.get('Authorization')
        authenticated_user_uid = None
        
        if auth_header and auth_header.startswith('Bearer '):
            try:
                id_token = auth_header.split('Bearer ')[1]
                decoded_token = auth.verify_id_token(id_token)
                authenticated_user_uid = decoded_token['uid']
                logger.info(f"🔐 Authenticated user: {authenticated_user_uid}")
            except Exception as e:
                logger.warning(f"⚠️ Auth token verification failed: {e}")
                logger.info("📝 Proceeding as unauthenticated for testing")
        else:
            logger.info("📝 No auth token provided, proceeding as unauthenticated")
        
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

@https_fn.on_request()
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
            "duration": 30,
            "focus_area": "individual"
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
        
        request_data = req.get_json()
        if not request_data:
            return https_fn.Response("Invalid JSON", status=400)
        
        user_id = request_data.get('user_id')
        player_profile = request_data.get('player_profile', {})
        requirements = request_data.get('requirements', {})
        
        if not all([user_id, player_profile, requirements]):
            return https_fn.Response("Missing required fields", status=400)
        
        logger.info(f"🤖 Generating custom drill for user: {user_id}")
        logger.info(f"📝 Skill description: {requirements.get('skill_description', '')}")
        
        # Get OpenAI API key from environment variables
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        
        logger.info(f"🔑 OpenAI API key available: {bool(openai_api_key)}")
        
        if not openai_api_key:
            return https_fn.Response("OpenAI API key not configured", status=500)
        
        # Generate drill using OpenAI
        drill_data = generate_drill_with_ai(player_profile, requirements, openai_api_key)
        
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

def generate_drill_with_ai(player_profile: Dict, requirements: Dict, openai_api_key: str) -> Dict:
    """Generate custom drill using OpenAI GPT"""
    try:
        from openai import OpenAI
        client = OpenAI(api_key=openai_api_key)
        
        # Build context prompt
        skill_description = requirements.get('skill_description', '')
        category = requirements.get('category', 'technical')
        difficulty = requirements.get('difficulty', 'intermediate')
        equipment = requirements.get('equipment', [])
        duration = requirements.get('duration', 30)
        focus_area = requirements.get('focus_area', 'individual')
        
        player_context = f"""
Player Profile:
- Name: {player_profile.get('name', 'Player')}
- Age: {player_profile.get('age', 'Unknown')}
- Position: {player_profile.get('position', 'Unknown')}
- Experience: {player_profile.get('experienceLevel', 'intermediate')}
- Playing Style: {player_profile.get('playingStyle', 'Unknown')}
- Role Model: {player_profile.get('playerRoleModel', 'N/A')}
- Goals: {', '.join(player_profile.get('skillGoals', []))}
- Weaknesses: {', '.join(player_profile.get('weaknesses', []))}
"""
        
        equipment_list = ', '.join(equipment) if equipment else 'minimal equipment'
        
        prompt = f"""You are an expert soccer/football coach. Create a highly detailed training drill based on the following requirements:

{player_context}

Drill Requirements:
- Focus: {skill_description}
- Category: {category}
- Difficulty: {difficulty}
- Available Equipment: {equipment_list}
- Duration: {duration} minutes
- Training Setup: {focus_area}

IMPORTANT: Create VERY detailed and specific instructions. For the setup, include exact field dimensions, cone placement, and any equipment positioning. For instructions, provide step-by-step actions that tell the player exactly what to do for each repetition or sequence.

Please provide a response in the following JSON format:
{{
    "name": "Concise drill name (max 50 characters)",
    "description": "Brief 2-3 sentence overview of the drill and its purpose",
    "setup": "Set up a 10x10 meter square area using four cones. Place a ball at the starting position. Ensure there is a clear, safe space around the area with no obstacles or tripping hazards. Carson should start at the bottom left cone.",
    "instructions": [
        "Standing at the bottom left cone, Carson should dribble the ball to the top left cone in a straight line. Aim to keep the ball close, taking small touches with the inside of the foot.",
        "From the top left cone, dribble diagonally to the bottom right cone while maintaining close ball control.",
        "At the bottom right cone, perform a sharp turn and dribble back to the starting position.",
        "Repeat the sequence 5 times, focusing on smooth transitions between movements."
    ],
    "progressions": [
        "Easier: Increase cone spacing to 12x12 meters to allow more time between touches",
        "Harder: Add a defender applying light pressure or reduce the area to 8x8 meters"
    ],
    "coachingPoints": [
        "Keep your head up between touches to scan the area",
        "Use the inside of your foot for better control when changing direction",
        "Focus on quick, light touches rather than heavy kicks"
    ],
    "estimatedDuration": {duration},
    "difficulty": "{difficulty}",
    "category": "{category}",
    "targetSkills": [
        "Primary skill being developed",
        "Secondary skills involved"
    ],
    "equipment": {json.dumps(equipment)},
    "safetyNotes": "Ensure the training area is free of hazards and maintain proper spacing"
}}

CRITICAL: Make the setup and instructions extremely detailed and specific, but write them naturally without prefixes like "Detailed step 1:" or "Step 1:". Just write clear, direct instructions as shown in the example above. Include exact measurements, specific actions, and clear sequences."""
        
        # Call OpenAI API
        response = client.chat.completions.create(
            model="gpt-4",
            messages=[
                {"role": "system", "content": "You are an expert soccer coach specializing in personalized training drills."},
                {"role": "user", "content": prompt}
            ],
            max_tokens=1500,
            temperature=0.7
        )
        
        # Parse response
        content = response.choices[0].message.content
        
        # Extract JSON from response (remove any markdown formatting)
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0]
        elif "```" in content:
            content = content.split("```")[1]
        
        drill_data = json.loads(content.strip())
        
        logger.info(f"🎯 Generated drill: {drill_data.get('name', 'Unknown')}")
        return drill_data
        
    except Exception as e:
        logger.error(f"❌ Error generating drill with AI: {str(e)}")
        logger.error(traceback.format_exc())
        raise e  # Re-raise the exception instead of using fallback

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
