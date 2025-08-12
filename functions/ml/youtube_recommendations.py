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
        limit: int = 5
    ) -> List[Dict]:
        """Get personalized YouTube recommendations using collaborative filtering + LLM queries"""
        try:
            if not self.youtube:
                logger.error("❌ YouTube API not available")
                return []
            
            logger.info(f"🎥 Generating {limit} personalized YouTube recommendations")
            
            # Generate LLM-powered search queries
            search_queries = self.query_generator.generate_search_queries(
                player_profile, 
                limit=min(8, limit * 2)  # Get more queries than needed
            )
            
            recommendations = []
            seen_video_ids = set()
            
            # Search for videos using generated queries
            for query in search_queries:
                if len(recommendations) >= limit:
                    break
                
                try:
                    videos = self._search_youtube_videos(query, max_results=3)
                    
                    for video in videos:
                        if len(recommendations) >= limit:
                            break
                        
                        video_id = video.get('id', {}).get('videoId')
                        if video_id and video_id not in seen_video_ids:
                            seen_video_ids.add(video_id)
                            
                            # Calculate relevance score
                            relevance_score = self._calculate_video_relevance(
                                video, player_profile, user_history
                            )
                            
                            recommendation = {
                                'video_id': video_id,
                                'title': video.get('snippet', {}).get('title', ''),
                                'description': video.get('snippet', {}).get('description', ''),
                                'thumbnail_url': video.get('snippet', {}).get('thumbnails', {}).get('medium', {}).get('url', ''),
                                'channel_title': video.get('snippet', {}).get('channelTitle', ''),
                                'published_at': video.get('snippet', {}).get('publishedAt', ''),
                                'relevance_score': relevance_score,
                                'search_query': query,
                                'recommendation_reason': self._generate_recommendation_reason(video, player_profile)
                            }
                            
                            recommendations.append(recommendation)
                            
                except Exception as e:
                    logger.warning(f"⚠️ Search failed for query '{query}': {e}")
                    continue
            
            # Sort by relevance score
            recommendations.sort(key=lambda x: x['relevance_score'], reverse=True)
            
            logger.info(f"✅ Generated {len(recommendations)} YouTube recommendations")
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
                videoDuration='medium',  # 4-20 minutes
                safeSearch='moderate'
            ).execute()
            
            return search_response.get('items', [])
            
        except Exception as e:
            logger.error(f"❌ YouTube search failed for '{query}': {e}")
            return []
    
    def _calculate_video_relevance(
        self, 
        video: Dict, 
        player_profile: Dict, 
        user_history: List[Dict]
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
            
            return min(score, 1.0)  # Cap at 1.0
            
        except Exception as e:
            logger.warning(f"⚠️ Error calculating video relevance: {e}")
            return 0.5  # Default score
    
    def _generate_recommendation_reason(self, video: Dict, player_profile: Dict) -> str:
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
            
            if not reasons:
                reasons.append("Recommended for your skill level")
            
            return " • ".join(reasons)
            
        except Exception as e:
            logger.warning(f"⚠️ Error generating recommendation reason: {e}")
            return "Recommended for you"

def create_youtube_ml_engine(youtube_api_key: str, openai_api_key: Optional[str] = None) -> YouTubeMLEngine:
    """Factory function to create YouTube ML engine"""
    return YouTubeMLEngine(youtube_api_key, openai_api_key)