"""
Lightweight recommendation engine that doesn't require external ML libraries.
Uses simple collaborative filtering and content-based approaches.
"""
import math
from typing import Dict, List, Tuple, Any
from collections import defaultdict

class LightweightRecommendationEngine:
    def __init__(self):
        self.user_exercise_scores = defaultdict(dict)
        self.exercise_features = {}
        self.user_similarities = {}
    
    def calculate_user_similarity(self, user1_scores: Dict, user2_scores: Dict) -> float:
        """Calculate cosine similarity between two users based on exercise scores."""
        common_exercises = set(user1_scores.keys()) & set(user2_scores.keys())
        
        if len(common_exercises) < 2:
            return 0.0
        
        # Calculate cosine similarity
        dot_product = sum(user1_scores[ex] * user2_scores[ex] for ex in common_exercises)
        norm1 = math.sqrt(sum(user1_scores[ex] ** 2 for ex in common_exercises))
        norm2 = math.sqrt(sum(user2_scores[ex] ** 2 for ex in common_exercises))
        
        if norm1 == 0 or norm2 == 0:
            return 0.0
        
        return dot_product / (norm1 * norm2)
    
    def calculate_exercise_score(self, session_data: Dict) -> float:
        """Calculate a score for how well a user performed an exercise."""
        completion_rate = session_data.get('completionRate', 0.5)
        duration_minutes = session_data.get('duration', 0) / 60.0
        technical_execution = session_data.get('technicalExecution', 3) / 5.0
        
        # Normalize duration (assume 30 minutes is ideal)
        duration_score = min(duration_minutes / 30.0, 1.0)
        
        # Weighted combination
        score = (completion_rate * 0.4 + 
                duration_score * 0.3 + 
                technical_execution * 0.3)
        
        return max(0.1, min(1.0, score))
    
    def build_user_profiles(self, user_sessions: List[Dict]) -> None:
        """Build user profiles from session data."""
        for session in user_sessions:
            user_id = session.get('userId')
            exercise_name = session.get('exerciseName', 'Unknown')
            
            if not user_id:
                continue
            
            score = self.calculate_exercise_score(session)
            
            # Update user's exercise scores (take average if multiple sessions)
            if exercise_name in self.user_exercise_scores[user_id]:
                current_score = self.user_exercise_scores[user_id][exercise_name]
                self.user_exercise_scores[user_id][exercise_name] = (current_score + score) / 2
            else:
                self.user_exercise_scores[user_id][exercise_name] = score
    
    def get_collaborative_recommendations(self, target_user_id: str, all_exercises: List[str], limit: int = 10) -> List[Tuple[str, float]]:
        """Get collaborative filtering recommendations."""
        if target_user_id not in self.user_exercise_scores:
            return []
        
        target_scores = self.user_exercise_scores[target_user_id]
        
        # Find similar users
        similar_users = []
        for user_id, user_scores in self.user_exercise_scores.items():
            if user_id != target_user_id:
                similarity = self.calculate_user_similarity(target_scores, user_scores)
                if similarity > 0.1:  # Minimum similarity threshold
                    similar_users.append((user_id, similarity))
        
        # Sort by similarity
        similar_users.sort(key=lambda x: x[1], reverse=True)
        
        # Get exercise recommendations from similar users
        exercise_scores = defaultdict(list)
        
        for user_id, similarity in similar_users[:5]:  # Top 5 similar users
            user_scores = self.user_exercise_scores[user_id]
            for exercise, score in user_scores.items():
                if exercise not in target_scores:  # Not already done by target user
                    weighted_score = score * similarity
                    exercise_scores[exercise].append(weighted_score)
        
        # Calculate final scores
        recommendations = []
        for exercise, scores in exercise_scores.items():
            if exercise in all_exercises:
                avg_score = sum(scores) / len(scores)
                recommendations.append((exercise, avg_score))
        
        # Sort by score and return top recommendations
        recommendations.sort(key=lambda x: x[1], reverse=True)
        return recommendations[:limit]
    
    def get_content_based_recommendations(self, target_user_id: str, all_exercises: List[str], exercise_metadata: Dict, limit: int = 10) -> List[Tuple[str, float]]:
        """Get content-based recommendations."""
        if target_user_id not in self.user_exercise_scores:
            return []
        
        target_scores = self.user_exercise_scores[target_user_id]
        
        # Calculate user preferences by skill type
        skill_preferences = defaultdict(list)
        for exercise, score in target_scores.items():
            if exercise in exercise_metadata:
                skill_type = exercise_metadata[exercise].get('skillType', 'General')
                skill_preferences[skill_type].append(score)
        
        # Average preferences by skill type
        avg_skill_preferences = {}
        for skill, scores in skill_preferences.items():
            avg_skill_preferences[skill] = sum(scores) / len(scores)
        
        # Recommend exercises based on preferred skills
        recommendations = []
        for exercise in all_exercises:
            if exercise not in target_scores and exercise in exercise_metadata:
                skill_type = exercise_metadata[exercise].get('skillType', 'General')
                difficulty = exercise_metadata[exercise].get('difficultyLevel', 1)
                
                # Base score from skill preference
                base_score = avg_skill_preferences.get(skill_type, 0.5)
                
                # Adjust for difficulty (prefer exercises slightly above current level)
                user_avg_difficulty = sum(exercise_metadata.get(ex, {}).get('difficultyLevel', 1) 
                                        for ex in target_scores.keys() if ex in exercise_metadata) / max(len(target_scores), 1)
                
                difficulty_bonus = 0.1 if difficulty == int(user_avg_difficulty) + 1 else 0
                
                final_score = base_score + difficulty_bonus
                recommendations.append((exercise, final_score))
        
        recommendations.sort(key=lambda x: x[1], reverse=True)
        return recommendations[:limit]
    
    def generate_recommendations(self, target_user_id: str, all_exercises: List[str], 
                               exercise_metadata: Dict, limit: int = 3) -> List[Dict]:
        """Generate hybrid recommendations combining collaborative and content-based approaches."""
        
        collab_recs = self.get_collaborative_recommendations(target_user_id, all_exercises, limit * 2)
        content_recs = self.get_content_based_recommendations(target_user_id, all_exercises, exercise_metadata, limit * 2)
        
        # Combine recommendations with weights
        exercise_scores = {}
        
        # Collaborative filtering (70% weight)
        for exercise, score in collab_recs:
            exercise_scores[exercise] = score * 0.7
        
        # Content-based (30% weight)
        for exercise, score in content_recs:
            if exercise in exercise_scores:
                exercise_scores[exercise] += score * 0.3
            else:
                exercise_scores[exercise] = score * 0.3
        
        # Sort by final scores
        final_recommendations = sorted(exercise_scores.items(), key=lambda x: x[1], reverse=True)
        
        # Format recommendations
        formatted_recs = []
        for i, (exercise, score) in enumerate(final_recommendations[:limit]):
            # Convert score to percentage (with some realistic variation)
            base_percentage = min(95, max(45, score * 100))
            # Add some variation to make it more realistic
            variation = (-5 + (i * 3)) if i < 3 else 0
            match_percentage = int(base_percentage + variation)
            
            # Generate reason based on score source
            if exercise in [ex for ex, _ in collab_recs[:3]]:
                reason = "Similar players have improved with this drill"
            else:
                reason = "Matches your skill development pattern"
            
            formatted_recs.append({
                'exerciseName': exercise,
                'matchPercentage': match_percentage,
                'reason': reason,
                'confidenceScore': score
            })
        
        return formatted_recs

def create_lightweight_recommendations(user_sessions: List[Dict], all_exercises: List[str], 
                                     exercise_metadata: Dict, target_user_id: str) -> List[Dict]:
    """Main function to create recommendations."""
    engine = LightweightRecommendationEngine()
    
    # Build user profiles
    engine.build_user_profiles(user_sessions)
    
    # Generate recommendations
    recommendations = engine.generate_recommendations(target_user_id, all_exercises, exercise_metadata)
    
    # Fallback to default recommendations if no personalized ones available
    if not recommendations:
        default_exercises = ['Ball Control', 'Passing Accuracy', 'Endurance Run']
        recommendations = []
        for i, exercise in enumerate(default_exercises[:3]):
            recommendations.append({
                'exerciseName': exercise,
                'matchPercentage': 85 - (i * 5),  # 85%, 80%, 75%
                'reason': 'Foundational skill for all players',
                'confidenceScore': 0.8 - (i * 0.1)
            })
    
    return recommendations