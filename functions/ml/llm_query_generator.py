"""
LLM-powered YouTube search query generator for personalized soccer training recommendations
"""

import logging
from typing import Dict, List, Optional
import json

logger = logging.getLogger(__name__)

class LLMQueryGenerator:
    """Generate personalized YouTube search queries using OpenAI's LLM"""
    
    def __init__(self, openai_api_key: Optional[str] = None):
        self.client = None
        
        if openai_api_key:
            try:
                import openai
                self.client = openai.OpenAI(api_key=openai_api_key)
                logger.info("🤖 LLM Query Generator initialized with OpenAI")
            except ImportError:
                logger.warning("⚠️ OpenAI library not available")
            except Exception as e:
                logger.warning(f"⚠️ Failed to initialize OpenAI client: {e}")
        else:
            logger.info("🔄 LLM Query Generator running without OpenAI (fallback mode)")
    
    def generate_search_queries(self, player_profile: Dict, limit: int = 5) -> List[str]:
        """Generate personalized YouTube search queries using LLM"""
        try:
            if not self.client:
                logger.info("🔄 LLM not available, using fallback queries")
                return self._generate_fallback_queries(player_profile, limit)
            
            logger.info(f"🤖 Generating {limit} LLM-powered search queries")
            
            # Build prompt for LLM
            prompt = self._build_search_query_prompt(player_profile, limit)
            
            # Call OpenAI API
            response = self.client.chat.completions.create(
                model="gpt-4o-mini",  # Fast and cost-effective
                messages=[
                    {
                        "role": "system",
                        "content": "You are an expert soccer coach and YouTube content strategist. Generate highly specific, effective YouTube search queries that will find the best training videos for soccer players."
                    },
                    {
                        "role": "user", 
                        "content": prompt
                    }
                ],
                temperature=0.7,  # Some creativity but not too random
                max_tokens=300
            )
            
            # Parse response
            content = response.choices[0].message.content.strip()
            queries = self._parse_llm_response(content, limit)
            
            logger.info(f"✅ Generated {len(queries)} LLM queries: {queries}")
            return queries
            
        except Exception as e:
            logger.warning(f"⚠️ LLM query generation failed: {e}")
            return self._generate_fallback_queries(player_profile, limit)
    
    def _build_search_query_prompt(self, player_profile: Dict, limit: int) -> str:
        """Build a detailed prompt for LLM query generation"""
        
        # Extract player info
        position = player_profile.get('position', 'player')
        age = player_profile.get('age', 16)
        experience = player_profile.get('experienceLevel', 'intermediate')
        goals = player_profile.get('goals', [])
        style = player_profile.get('playingStyle', '')
        role_model = player_profile.get('playerRoleModel', '')
        
        prompt = f"""Generate {limit} highly specific YouTube search queries for a soccer player with this profile:

Position: {position}
Age: {age} years old
Experience Level: {experience}
Training Goals: {', '.join(goals) if goals else 'General improvement'}
Playing Style: {style}
Role Model: {role_model}

Requirements:
1. Each query should be 3-8 words
2. Focus on skills relevant to the player's position and goals
3. Include training/tutorial/drill keywords when appropriate
4. Consider the experience level (beginner/intermediate/advanced)
5. Make queries specific enough to find quality training content
6. Mix of queries for different content types:
   - Quick tip queries (for YouTube Shorts): include words like "quick", "tip", "tricks", "seconds"
   - Detailed tutorial queries (for longer videos): include "tutorial", "drill", "training", "complete"
7. Avoid overly generic terms

Return ONLY the search queries, one per line, no numbering or extra text.

Examples for reference:
- "midfielder passing accuracy drills" (longer video)
- "Kevin De Bruyne ball control techniques" (detailed tutorial)
- "quick first touch tips" (YouTube Short)
- "{position} skills in 60 seconds" (YouTube Short)
- "youth soccer finishing drills" (longer video)
- "fast footwork tricks" (YouTube Short)
"""
        
        return prompt
    
    def _parse_llm_response(self, content: str, limit: int) -> List[str]:
        """Parse LLM response into clean search queries"""
        lines = [line.strip() for line in content.split('\n') if line.strip()]
        
        queries = []
        for line in lines[:limit]:
            # Remove numbering, bullet points, quotes
            query = line.strip()
            for prefix in ['1.', '2.', '3.', '4.', '5.', '6.', '-', '*', '"', "'"]:
                if query.startswith(prefix):
                    query = query[len(prefix):].strip()
            
            if query and len(query) > 5:  # Valid query
                queries.append(query)
        
        # Ensure we have enough queries
        while len(queries) < limit:
            queries.extend(self._generate_fallback_queries({}, limit - len(queries)))
        
        return queries[:limit]
    
    def _generate_fallback_queries(self, player_profile: Dict, limit: int = 5) -> List[str]:
        """Generate fallback queries when LLM is not available"""
        position = player_profile.get('position', 'player')
        experience = player_profile.get('experienceLevel', 'intermediate')
        
        # Mix of queries targeting both Shorts and longer videos
        base_queries = [
            f"{position} training drills",  # Longer videos
            f"soccer {experience} skills",  # Mixed
            f"quick {position} tips",  # Shorts
            "ball control exercises",  # Longer videos
            "fast footwork tricks",  # Shorts
            "passing accuracy drills",  # Longer videos
            "first touch tips seconds",  # Shorts
            "soccer fitness workout",  # Longer videos
            f"{position} skills in 60 seconds",  # Shorts
            "youth soccer techniques",  # Mixed
            "quick soccer tips",  # Shorts
            "soccer tricks tutorial"  # Mixed
        ]
        
        return base_queries[:limit]