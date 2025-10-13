"""
YouTube-based recommendation engine with collaborative filtering and LLM query generation
"""

import logging
import json
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
# import numpy as np  # Removed for lighter deployment

from .llm_query_generator import LLMQueryGenerator

logger = logging.getLogger(__name__)

class YouTubeMLEngine:
    """YouTube recommendation engine with collaborative filtering and LLM-powered queries"""
    
    def __init__(self, youtube_api_key: str, openai_api_key: Optional[str] = None):
        self.youtube_api_key = youtube_api_key
        self.query_generator = LLMQueryGenerator(openai_api_key)
        
        # Initialize YouTube API client
        try:
            from googleapiclient.discovery import build
            self.youtube = build('youtube', 'v3', developerKey=youtube_api_key)
            logger.info("✅ YouTube API client initialized")
        except Exception as e:
            logger.error(f"❌ Failed to initialize YouTube API: {e}")
            self.youtube = None
    
    def get_personalized_youtube_recommendations(
        self, 
        player_profile: Dict, 
        user_history: List[Dict], 
        existing_exercises: List[Dict] = None,
        limit: int = 1
    ) -> List[Dict]:
        """Get personalized YouTube recommendations using collaborative filtering + LLM queries"""
        try:
            if not self.youtube:
                logger.error("❌ YouTube API not available")
                return []
            
            logger.info(f"🎥 Generating {limit} personalized YouTube recommendations (with duplicate filtering)")
            
            # Extract existing video IDs and titles for duplicate checking
            existing_video_ids = set()
            existing_titles = set()
            if existing_exercises:
                for exercise in existing_exercises:
                    if exercise.get('youtube_video_id'):
                        existing_video_ids.add(exercise['youtube_video_id'])
                    if exercise.get('title'):
                        existing_titles.add(exercise['title'].lower().strip())
                
                logger.info(f"🚫 Filtering against {len(existing_video_ids)} existing video IDs and {len(existing_titles)} titles")
            
            # Generate LLM-powered search queries - get more to account for filtering
            search_queries = self.query_generator.generate_search_queries(
                player_profile, 
                limit=min(10, limit * 5)  # Get many more queries to account for duplicate filtering
            )
            
            recommendations = []
            seen_video_ids = set()
            
            # Search for videos using generated queries
            for query in search_queries:
                if len(recommendations) >= limit:
                    break
                
                try:
                    # Get more videos per query to increase chances of finding non-duplicates
                    videos = self._search_youtube_videos(query, max_results=5)
                    
                    for video in videos:
                        if len(recommendations) >= limit:
                            break
                        
                        video_id = video.get('id', {}).get('videoId')
                        video_title = video.get('snippet', {}).get('title', '').lower().strip()
                        
                        # Skip if we've already seen this video ID or it's a duplicate
                        if video_id in seen_video_ids:
                            continue
                        
                        # Skip if this video already exists as an exercise
                        if video_id in existing_video_ids:
                            logger.info(f"🚫 Skipping duplicate video ID: {video_id}")
                            continue
                        
                        # Skip if title matches an existing exercise (fuzzy matching)
                        is_title_duplicate = False
                        for existing_title in existing_titles:
                            if self._titles_are_similar(video_title, existing_title):
                                logger.info(f"🚫 Skipping similar title: '{video_title}' (similar to '{existing_title}')")
                                is_title_duplicate = True
                                break
                        
                        if is_title_duplicate:
                            continue
                        
                        # This is a new, unique recommendation
                        seen_video_ids.add(video_id)
                        
                        # Get video details including duration
                        video_details = self._get_video_details(video_id)
                        
                        # Calculate relevance score (now includes Shorts-specific logic)
                        relevance_score = self._calculate_video_relevance(
                            video, player_profile, user_history, video_details, query
                        )
                        
                        recommendation = {
                            'video_id': video_id,
                            'title': video.get('snippet', {}).get('title', ''),
                            'description': video.get('snippet', {}).get('description', ''),
                            'thumbnail_url': video.get('snippet', {}).get('thumbnails', {}).get('medium', {}).get('url', ''),
                            'channel_title': video.get('snippet', {}).get('channelTitle', ''),
                            'published_at': video.get('snippet', {}).get('publishedAt', ''),
                            'duration': video_details.get('duration', 'Unknown'),
                            'duration_seconds': video_details.get('duration_seconds', 0),
                            'is_short': video_details.get('is_short', False),
                            'view_count': video_details.get('view_count', 0),
                            'relevance_score': relevance_score,
                            'final_score': relevance_score,  # For compatibility with iOS app
                            'search_query': query,
                            'reasoning': self._generate_recommendation_reason(video, player_profile, video_details),
                            'recommendation_reason': self._generate_recommendation_reason(video, player_profile, video_details),
                            'engagement_score': min(relevance_score + 0.1, 1.0)  # Slightly boost engagement score
                        }
                        
                        recommendations.append(recommendation)
                        logger.info(f"✅ Found new recommendation: '{video.get('snippet', {}).get('title', '')}'")
                        
                except Exception as e:
                    logger.warning(f"⚠️ Search failed for query '{query}': {e}")
                    continue
            
            # Sort by relevance score
            recommendations.sort(key=lambda x: x['relevance_score'], reverse=True)
            
            if not recommendations:
                logger.warning("⚠️ No new YouTube recommendations found (all were duplicates)")
            else:
                logger.info(f"✅ Generated {len(recommendations)} unique YouTube recommendations")
            
            return recommendations[:limit]
            
        except Exception as e:
            logger.error(f"❌ Error in get_personalized_youtube_recommendations: {e}")
            return []
    
    def _search_youtube_videos(self, query: str, max_results: int = 5) -> List[Dict]:
        """Search YouTube for videos matching the query"""
        try:
            search_response = self.youtube.search().list(
                q=query,
                part='id,snippet',
                maxResults=max_results,
                type='video',
                order='relevance',
                # videoDuration removed to include YouTube Shorts (≤60s) and longer videos
                safeSearch='moderate'
            ).execute()
            
            return search_response.get('items', [])
            
        except Exception as e:
            logger.error(f"❌ YouTube search failed for '{query}': {e}")
            return []
    
    def _get_video_details(self, video_id: str) -> Dict:
        """Get detailed video information including duration and view count"""
        try:
            if not video_id:
                return {}
                
            # Get video details from YouTube API
            video_response = self.youtube.videos().list(
                part='contentDetails,statistics',
                id=video_id
            ).execute()
            
            items = video_response.get('items', [])
            if not items:
                return {}
            
            video_data = items[0]
            content_details = video_data.get('contentDetails', {})
            statistics = video_data.get('statistics', {})
            
            # Parse ISO 8601 duration format (PT#M#S)
            duration_str = content_details.get('duration', 'PT0S')
            duration_seconds = self._parse_youtube_duration(duration_str)
            
            # Format human-readable duration
            if duration_seconds <= 60:
                formatted_duration = f"{duration_seconds}s"
            else:
                minutes = duration_seconds // 60
                seconds = duration_seconds % 60
                if seconds > 0:
                    formatted_duration = f"{minutes}:{seconds:02d}"
                else:
                    formatted_duration = f"{minutes}:00"
            
            # Determine if it's a YouTube Short (≤60 seconds)
            is_short = duration_seconds <= 60
            
            return {
                'duration': formatted_duration,
                'duration_seconds': duration_seconds,
                'is_short': is_short,
                'view_count': int(statistics.get('viewCount', 0))
            }
            
        except Exception as e:
            logger.warning(f"⚠️ Could not get video details for {video_id}: {e}")
            return {}
    
    def _parse_youtube_duration(self, duration: str) -> int:
        """Parse YouTube's ISO 8601 duration format (PT#M#S) to seconds"""
        try:
            # Remove 'PT' prefix
            if duration.startswith('PT'):
                duration = duration[2:]
            
            total_seconds = 0
            
            # Parse hours
            if 'H' in duration:
                hours_str = duration.split('H')[0]
                total_seconds += int(hours_str) * 3600
                duration = duration.split('H')[1]
            
            # Parse minutes
            if 'M' in duration:
                minutes_str = duration.split('M')[0]
                total_seconds += int(minutes_str) * 60
                duration = duration.split('M')[1]
            
            # Parse seconds
            if 'S' in duration:
                seconds_str = duration.split('S')[0]
                total_seconds += int(seconds_str)
            
            return total_seconds
            
        except Exception as e:
            logger.warning(f"⚠️ Could not parse duration '{duration}': {e}")
            return 0
    
    def _calculate_video_relevance(
        self, 
        video: Dict, 
        player_profile: Dict, 
        user_history: List[Dict],
        video_details: Dict = None,
        search_query: str = ""
    ) -> float:
        """Calculate relevance score for a video based on player profile and history"""
        try:
            score = 0.0
            
            title = video.get('snippet', {}).get('title', '').lower()
            description = video.get('snippet', {}).get('description', '').lower()
            content = f"{title} {description}"
            
            # Position relevance
            position = player_profile.get('position', '').lower()
            if position in content:
                score += 0.3
            
            # Goals relevance
            goals = player_profile.get('goals', [])
            for goal in goals:
                if goal.lower() in content:
                    score += 0.2
            
            # Experience level relevance
            experience = player_profile.get('experienceLevel', '').lower()
            experience_keywords = {
                'beginner': ['beginner', 'basic', 'youth', 'kids'],
                'intermediate': ['intermediate', 'advanced', 'pro'],
                'advanced': ['advanced', 'professional', 'elite', 'pro']
            }
            
            for keyword in experience_keywords.get(experience, []):
                if keyword in content:
                    score += 0.15
            
            # Role model relevance
            role_model = player_profile.get('playerRoleModel', '').lower()
            if role_model and role_model in content:
                score += 0.25
            
            # Training keywords boost
            training_keywords = ['drill', 'training', 'exercise', 'technique', 'tutorial', 'practice']
            for keyword in training_keywords:
                if keyword in content:
                    score += 0.1
                    break
            
            # NEW: Training history relevance - analyze what user has been working on
            if user_history:
                # Get recent skill focus areas from training history
                recent_skills = []
                skill_performance = {}  # skill -> average rating
                category_frequency = {}  # category -> count
                
                for exercise in user_history:
                    # Collect skills user has been training
                    skills = exercise.get('target_skills', [])
                    recent_skills.extend(skills)
                    
                    # Track performance by skill
                    rating = exercise.get('rating', 3)
                    for skill in skills:
                        if skill not in skill_performance:
                            skill_performance[skill] = []
                        skill_performance[skill].append(rating)
                    
                    # Track category frequency
                    category = exercise.get('category', '').lower()
                    category_frequency[category] = category_frequency.get(category, 0) + 1
                
                # Boost videos that target skills user has been working on
                for skill in set(recent_skills):
                    if skill.lower() in content:
                        # Higher boost for skills with lower performance
                        avg_performance = sum(skill_performance.get(skill, [3])) / len(skill_performance.get(skill, [3]))
                        performance_boost = (5 - avg_performance) / 10  # 0.0 to 0.4 boost
                        score += 0.15 + performance_boost
                
                # Boost videos in categories user trains frequently (shows engagement)
                most_trained_category = max(category_frequency, key=category_frequency.get) if category_frequency else ''
                if most_trained_category and most_trained_category in content:
                    score += 0.1
                
                # Boost videos that might help with improvement areas
                # Find skills with consistently low ratings
                improvement_skills = []
                for skill, ratings in skill_performance.items():
                    avg_rating = sum(ratings) / len(ratings)
                    if avg_rating < 3.5 and len(ratings) >= 2:  # Multiple low-rated sessions
                        improvement_skills.append(skill)
                
                for skill in improvement_skills:
                    if skill.lower() in content:
                        score += 0.2  # Higher boost for improvement areas
            
            # Channel authority (simplified)
            channel = video.get('snippet', {}).get('channelTitle', '').lower()
            authority_channels = ['soccer', 'football', 'fifa', 'nike', 'adidas', 'academy']
            for auth_channel in authority_channels:
                if auth_channel in channel:
                    score += 0.1
                    break
            
            # Recency bonus
            try:
                published = video.get('snippet', {}).get('publishedAt', '')
                if published:
                    pub_date = datetime.fromisoformat(published.replace('Z', '+00:00'))
                    days_old = (datetime.now().replace(tzinfo=pub_date.tzinfo) - pub_date).days
                    if days_old < 365:  # Within a year
                        score += 0.1 * (1 - days_old / 365)
            except:
                pass
            
            # NEW: YouTube Shorts-specific scoring
            if video_details:
                is_short = video_details.get('is_short', False)
                
                # Analyze search query to determine content type preference
                query_lower = search_query.lower()
                quick_keywords = ['quick', 'tip', 'tips', 'trick', 'tricks', 'fast', 'short', 'seconds', 'minute']
                detailed_keywords = ['tutorial', 'drill', 'training', 'practice', 'session', 'walkthrough', 'guide', 'complete']
                
                # Check if query suggests preference for quick content (Shorts)
                wants_quick = any(keyword in query_lower for keyword in quick_keywords)
                wants_detailed = any(keyword in query_lower for keyword in detailed_keywords)
                
                if is_short:
                    # Boost Shorts for quick tip queries
                    if wants_quick or 'technique' in content:
                        score += 0.2
                        logger.debug(f"🎬 Shorts boost (+0.2) for quick content: {video.get('snippet', {}).get('title', '')}")
                    
                    # Slight boost for technique demonstration (visual learning)
                    if any(tech_word in content for tech_word in ['technique', 'skill', 'move', 'footwork']):
                        score += 0.1
                        
                    # Shorts are great for motivation and tips
                    if any(motivational in content for motivational in ['motivation', 'inspire', 'mindset', 'confidence']):
                        score += 0.15
                        
                else:  # Standard video (>60 seconds)
                    # Boost longer videos for detailed instruction queries
                    if wants_detailed or 'drill' in content:
                        score += 0.2
                        logger.debug(f"🎥 Long-form boost (+0.2) for detailed content: {video.get('snippet', {}).get('title', '')}")
                    
                    # Longer videos better for complex topics
                    if any(complex_word in content for complex_word in ['tactic', 'formation', 'strategy', 'analysis']):
                        score += 0.15
                
                # Duration-based scoring adjustments
                duration_seconds = video_details.get('duration_seconds', 0)
                if 30 <= duration_seconds <= 120:  # Sweet spot for skill demonstrations
                    if any(skill_word in content for skill_word in ['skill', 'technique', 'move', 'control']):
                        score += 0.1
                        
                # View count consideration (popularity indicates quality)
                view_count = video_details.get('view_count', 0)
                if view_count > 100000:  # 100k+ views
                    score += 0.05
                elif view_count > 1000000:  # 1M+ views
                    score += 0.1
            
            return min(score, 1.0)  # Cap at 1.0
            
        except Exception as e:
            logger.warning(f"⚠️ Error calculating video relevance: {e}")
            return 0.5  # Default score
    
    def _generate_recommendation_reason(self, video: Dict, player_profile: Dict, video_details: Dict = None) -> str:
        """Generate a human-readable reason for the recommendation"""
        try:
            position = player_profile.get('position', 'player')
            goals = player_profile.get('goals', [])
            
            reasons = []
            
            title = video.get('snippet', {}).get('title', '').lower()
            
            if position.lower() in title:
                reasons.append(f"Perfect for {position}s")
            
            if goals:
                for goal in goals[:2]:  # Max 2 goals
                    if goal.lower() in title:
                        reasons.append(f"Helps with {goal}")
            
            if 'drill' in title or 'training' in title:
                reasons.append("Great training content")
            
            # Add Shorts-specific reasons
            if video_details and video_details.get('is_short', False):
                duration = video_details.get('duration', '')
                if 'tip' in title or 'trick' in title:
                    reasons.append(f"Quick tip ({duration})")
                elif 'technique' in title:
                    reasons.append(f"Technique demo ({duration})")
                else:
                    reasons.append(f"Short & focused ({duration})")
            elif video_details:
                duration = video_details.get('duration', '')
                if duration and duration != 'Unknown':
                    if 'tutorial' in title or 'guide' in title:
                        reasons.append(f"Detailed tutorial ({duration})")
            
            if not reasons:
                if video_details and video_details.get('is_short', False):
                    reasons.append("Quick skills video")
                else:
                    reasons.append("Recommended for your skill level")
            
            return " • ".join(reasons)
            
        except Exception as e:
            logger.warning(f"⚠️ Error generating recommendation reason: {e}")
            return "Recommended for you"
    
    def _titles_are_similar(self, title1: str, title2: str, threshold: float = 0.8) -> bool:
        """Check if two titles are similar enough to be considered duplicates"""
        try:
            # Simple similarity check based on common words
            title1_words = set(title1.lower().split())
            title2_words = set(title2.lower().split())
            
            # Remove common words that don't add meaning
            stop_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by', 'from', 'as', 'is', 'was', 'are', 'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could', 'should', 'may', 'might', 'must', 'shall', 'can'}
            title1_words = title1_words - stop_words
            title2_words = title2_words - stop_words
            
            if not title1_words or not title2_words:
                return False
            
            # Calculate Jaccard similarity
            intersection = len(title1_words.intersection(title2_words))
            union = len(title1_words.union(title2_words))
            
            if union == 0:
                return False
            
            similarity = intersection / union
            return similarity >= threshold
            
        except Exception as e:
            logger.warning(f"⚠️ Error comparing titles: {e}")
            return False

def create_youtube_ml_engine(youtube_api_key: str, openai_api_key: Optional[str] = None) -> YouTubeMLEngine:
    """Factory function to create YouTube ML engine"""
    return YouTubeMLEngine(youtube_api_key, openai_api_key)