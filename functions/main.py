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

# Import our YouTube ML recommendation engine
from ml.youtube_recommendations import create_youtube_ml_engine

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
        limit = request_data.get('limit', 5)
        
        if not user_id or not player_profile:
            return https_fn.Response("Missing user_id or player_profile", status=400)
        
        logger.info(f"🎥 Generating YouTube recommendations for user: {user_id}")
        
        # Get API keys from environment/config
        youtube_api_key = os.environ.get('YOUTUBE_API_KEY')
        
        # Try to get OpenAI key from Firebase config or environment
        openai_api_key = None
        try:
            # Firebase Functions config format
            import firebase_functions
            config = firebase_functions.config
            openai_api_key = config.get('openai', {}).get('api_key')
        except:
            pass
        
        # Fallback to environment variable
        if not openai_api_key:
            openai_api_key = os.environ.get('OPENAI_API_KEY')
        
        if not youtube_api_key or youtube_api_key == 'YOUR_YOUTUBE_API_KEY_HERE':
            return https_fn.Response("YouTube API key not configured", status=500)
        
        # Create YouTube ML engine with LLM query generation
        youtube_engine = create_youtube_ml_engine(youtube_api_key, openai_api_key)
        
        # Get user's training history for collaborative filtering
        user_history = get_user_training_history(user_id)
        
        # Generate personalized YouTube recommendations
        recommendations = youtube_engine.get_personalized_youtube_recommendations(
            player_profile=player_profile,
            user_history=user_history,
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
        
        # Get OpenAI API key from environment
        openai_api_key = os.environ.get('OPENAI_API_KEY')
        
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
    "setup": "VERY detailed setup instructions - specify exact field dimensions (e.g., 20x20 meter area), cone placement, equipment positioning (rebounders, goals, etc.), starting positions. Be as specific as possible.",
    "instructions": [
        "Detailed step 1: Specify exactly what the player does (e.g., 'Complete 5 passes against the rebounder')",
        "Detailed step 2: Be specific about movements and actions (e.g., 'On the fifth pass, turn in any direction while scanning over your shoulder')", 
        "Detailed step 3: Include specific numbers, distances, or timing (e.g., 'Sprint 10 meters to the next cone')",
        "Continue with very specific, actionable steps that tell the player exactly what to do each repetition"
    ],
    "progressions": [
        "Specific easier variation with exact modifications",
        "Specific harder variation with exact modifications"
    ],
    "coachingPoints": [
        "Specific technique point with exact body positioning or movement",
        "Specific awareness point (e.g., 'Always scan your shoulders for defenders')",
        "Specific performance indicator to measure success"
    ],
    "estimatedDuration": {duration},
    "difficulty": "{difficulty}",
    "category": "{category}",
    "targetSkills": [
        "Primary skill being developed",
        "Secondary skills involved"
    ],
    "equipment": {json.dumps(equipment)},
    "safetyNotes": "Specific safety considerations if any"
}}

CRITICAL: Make the setup and instructions extremely detailed and specific. Think like you're writing instructions for someone who has never done this drill before. Include exact measurements, specific actions, and clear sequences. Avoid vague language - be as precise as possible about what the player should do in each step."""
        
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

def get_user_training_history(user_id: str, days: int = 30) -> List[Dict]:
    """Get user's recent training history"""
    try:
        # Simulate training history
        history = [
            {
                'exercise_id': f'ex_{user_id}_1',
                'exercise_name': 'Ball Control Drill',
                'category': 'Technical',
                'difficulty': 3,
                'rating': 4,
                'duration': 15,
                'target_skills': ['Ball Control', 'First Touch'],
                'completed_at': datetime.now() - timedelta(days=1)
            },
            {
                'exercise_id': f'ex_{user_id}_2',
                'exercise_name': 'Passing Accuracy',
                'category': 'Technical', 
                'difficulty': 2,
                'rating': 5,
                'duration': 20,
                'target_skills': ['Passing', 'Accuracy'],
                'completed_at': datetime.now() - timedelta(days=3)
            }
        ]
        
        return history
        
    except Exception as e:
        logger.error(f"❌ Error getting user training history: {str(e)}")
        return []
