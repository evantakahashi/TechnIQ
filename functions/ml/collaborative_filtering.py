"""
Advanced Collaborative Filtering Recommendation Engine with SVD
Matrix factorization-based recommendation system for personalized soccer training
"""

import numpy as np
import logging
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime, timedelta
from scipy.sparse import csr_matrix
from scipy.sparse.linalg import svds
import json

logger = logging.getLogger(__name__)

class AdvancedRecommendationEngine:
    """SVD-based collaborative filtering with hybrid content-based scoring"""
    
    def __init__(self, n_factors: int = 50, regularization: float = 0.02):
        """
        Initialize the recommendation engine
        
        Args:
            n_factors: Number of latent factors for SVD (50-100 recommended)
            regularization: L2 regularization parameter to prevent overfitting
        """
        self.n_factors = min(n_factors, 50)  # Keep reasonable for small datasets
        self.regularization = regularization
        
        # Model components
        self.user_factors = None
        self.item_factors = None  
        self.user_biases = None
        self.item_biases = None
        self.global_mean = 0.0
        
        # Mappings
        self.user_to_index = {}
        self.index_to_user = {}
        self.exercise_to_index = {}
        self.index_to_exercise = {}
        
        # Training data
        self.interaction_matrix = None
        self.is_trained = False
        
        # Content features for hybrid approach
        self.exercise_features = {}
        self.user_profiles = {}
        
        logger.info(f"🧠 Advanced Recommendation Engine initialized (factors={n_factors}, reg={regularization})")
    
    def prepare_training_data(
        self, 
        user_history: List[Dict], 
        user_profiles: Dict[str, Dict],
        exercise_catalog: Dict[str, Dict]
    ) -> Tuple[csr_matrix, Dict, Dict]:
        """
        Prepare user-exercise interaction matrix from training history
        
        Args:
            user_history: List of training session data
            user_profiles: User profile information  
            exercise_catalog: Exercise metadata and features
            
        Returns:
            Sparse interaction matrix, user mappings, exercise mappings
        """
        try:
            logger.info("🔧 Preparing training data for SVD...")
            
            # Store for hybrid recommendations
            self.user_profiles = user_profiles
            self.exercise_features = exercise_catalog
            
            # Build user and exercise vocabularies
            users = set()
            exercises = set()
            
            for session in user_history:
                user_id = session.get('user_id') or session.get('firebaseUID')
                if user_id:
                    users.add(user_id)
                    
                # Extract exercises from session
                session_exercises = session.get('exercises', [])
                for exercise in session_exercises:
                    exercise_id = exercise.get('exercise_id') or exercise.get('name')
                    if exercise_id:
                        exercises.add(exercise_id)
            
            # Create index mappings
            self.user_to_index = {user: idx for idx, user in enumerate(sorted(users))}
            self.index_to_user = {idx: user for user, idx in self.user_to_index.items()}
            
            self.exercise_to_index = {ex: idx for idx, ex in enumerate(sorted(exercises))}
            self.index_to_exercise = {idx: ex for ex, idx in self.exercise_to_index.items()}
            
            n_users = len(users)
            n_exercises = len(exercises)
            
            logger.info(f"📊 Matrix dimensions: {n_users} users × {n_exercises} exercises")
            
            # Build interaction matrix with ratings
            row_indices = []
            col_indices = []
            ratings = []
            
            # Aggregate multiple ratings per user-exercise pair
            user_exercise_ratings = {}  # (user_idx, exercise_idx) -> [ratings]
            
            for session in user_history:
                user_id = session.get('user_id') or session.get('firebaseUID')
                if not user_id or user_id not in self.user_to_index:
                    continue
                    
                user_idx = self.user_to_index[user_id]
                session_date = session.get('completed_at') or session.get('date')
                
                session_exercises = session.get('exercises', [])
                for exercise in session_exercises:
                    exercise_id = exercise.get('exercise_id') or exercise.get('name')
                    if not exercise_id or exercise_id not in self.exercise_to_index:
                        continue
                        
                    exercise_idx = self.exercise_to_index[exercise_id]
                    
                    # Calculate implicit rating from multiple factors
                    rating = self._calculate_implicit_rating(exercise, session)
                    
                    # Apply temporal weighting (recent activities more important)
                    if session_date:
                        try:
                            if isinstance(session_date, str):
                                date_obj = datetime.fromisoformat(session_date.replace('Z', '+00:00'))
                            else:
                                date_obj = session_date
                            
                            days_ago = (datetime.now().replace(tzinfo=date_obj.tzinfo) - date_obj).days
                            temporal_weight = np.exp(-days_ago / 30.0)  # Decay over 30 days
                            rating *= temporal_weight
                        except:
                            pass
                    
                    # Store rating for aggregation
                    key = (user_idx, exercise_idx)
                    if key not in user_exercise_ratings:
                        user_exercise_ratings[key] = []
                    user_exercise_ratings[key].append(rating)
            
            # Aggregate ratings (weighted average)
            for (user_idx, exercise_idx), rating_list in user_exercise_ratings.items():
                # Weight recent ratings more heavily
                weights = np.exp(np.linspace(-1, 0, len(rating_list)))  # Recent = higher weight
                weighted_rating = np.average(rating_list, weights=weights)
                
                row_indices.append(user_idx)
                col_indices.append(exercise_idx)
                ratings.append(weighted_rating)
            
            # Create sparse matrix
            self.interaction_matrix = csr_matrix(
                (ratings, (row_indices, col_indices)), 
                shape=(n_users, n_exercises)
            )
            
            # Calculate global statistics
            self.global_mean = np.mean(ratings) if ratings else 2.5
            
            logger.info(f"✅ Training data prepared: {len(ratings)} interactions, mean rating: {self.global_mean:.2f}")
            return self.interaction_matrix, self.user_to_index, self.exercise_to_index
            
        except Exception as e:
            logger.error(f"❌ Error preparing training data: {e}")
            raise e
    
    def _calculate_implicit_rating(self, exercise_data: Dict, session_data: Dict) -> float:
        """
        Calculate implicit rating from user interaction data
        
        Args:
            exercise_data: Exercise performance data
            session_data: Session context data
            
        Returns:
            Implicit rating score (1.0 to 5.0)
        """
        try:
            # Base rating from explicit feedback if available
            explicit_rating = exercise_data.get('rating') or exercise_data.get('performanceRating')
            if explicit_rating and explicit_rating > 0:
                return max(1.0, min(5.0, float(explicit_rating)))
            
            # Calculate from implicit signals
            score = 2.5  # Neutral starting point
            
            # Completion rate boost
            completion = exercise_data.get('completion_percentage', 100)
            if completion >= 100:
                score += 1.0
            elif completion >= 80:
                score += 0.5
            elif completion < 50:
                score -= 0.5
            
            # Duration vs expected (engagement indicator)
            duration = exercise_data.get('duration', 0)
            if duration > 0:
                expected_duration = exercise_data.get('expected_duration', duration)
                duration_ratio = duration / max(expected_duration, 1)
                if 0.8 <= duration_ratio <= 1.2:  # Completed in expected time
                    score += 0.3
                elif duration_ratio > 1.5:  # Took much longer (might indicate difficulty)
                    score -= 0.2
            
            # Technical execution rating
            technical = exercise_data.get('technical_execution') or exercise_data.get('technicalExecution')
            if technical:
                score += (float(technical) - 3.0) * 0.3  # Scale -0.6 to +0.6
            
            # Enjoyment rating
            enjoyment = exercise_data.get('enjoyment_rating') or exercise_data.get('enjoymentRating')
            if enjoyment:
                score += (float(enjoyment) - 3.0) * 0.2  # Scale -0.4 to +0.4
            
            # Perceived difficulty vs actual difficulty
            perceived_diff = exercise_data.get('perceived_difficulty') or exercise_data.get('perceivedDifficulty')
            actual_diff = exercise_data.get('difficulty', 3)
            if perceived_diff and actual_diff:
                diff_delta = float(actual_diff) - float(perceived_diff)
                if -1 <= diff_delta <= 0:  # Exercise was appropriately challenging
                    score += 0.2
                elif diff_delta < -2:  # Too easy
                    score -= 0.3
                elif diff_delta > 2:  # Too hard
                    score -= 0.4
            
            # Session context
            session_rating = session_data.get('session_rating') or session_data.get('overallRating')
            if session_rating:
                score += (float(session_rating) - 3.0) * 0.1  # Small influence
            
            # Frequency boost (repeated exercises indicate preference)
            # This would be calculated at the aggregation level
            
            return max(1.0, min(5.0, score))
            
        except Exception as e:
            logger.warning(f"⚠️ Error calculating implicit rating: {e}")
            return 2.5
    
    def train_model(self) -> bool:
        """
        Train the SVD model on interaction matrix
        
        Returns:
            True if training successful, False otherwise
        """
        try:
            if self.interaction_matrix is None:
                logger.error("❌ No training data available")
                return False
                
            logger.info("🎯 Training SVD model...")
            
            # Get matrix dimensions
            n_users, n_exercises = self.interaction_matrix.shape
            
            # Ensure we don't have more factors than the smaller matrix dimension
            actual_factors = min(self.n_factors, min(n_users, n_exercises) - 1)
            
            if actual_factors < 1:
                logger.warning("⚠️ Insufficient data for SVD, using fallback")
                return False
            
            # Perform SVD decomposition
            U, sigma, Vt = svds(self.interaction_matrix.astype(np.float32), k=actual_factors)
            
            # Store factors (note: svds returns factors in reverse order)
            self.user_factors = U[:, ::-1]  # Shape: (n_users, n_factors)
            self.item_factors = Vt[::-1, :].T  # Shape: (n_exercises, n_factors)
            
            # Calculate biases
            self.user_biases = np.array([
                self.interaction_matrix[i, :].mean() - self.global_mean 
                for i in range(n_users)
            ])
            
            self.item_biases = np.array([
                self.interaction_matrix[:, j].mean() - self.global_mean 
                for j in range(n_exercises)
            ])
            
            # Handle NaN biases (for users/exercises with no ratings)
            self.user_biases = np.nan_to_num(self.user_biases)
            self.item_biases = np.nan_to_num(self.item_biases)
            
            self.is_trained = True
            
            logger.info(f"✅ SVD model trained successfully with {actual_factors} factors")
            return True
            
        except Exception as e:
            logger.error(f"❌ Error training SVD model: {e}")
            self.is_trained = False
            return False
    
    def predict_rating(self, user_id: str, exercise_id: str) -> float:
        """
        Predict rating for user-exercise pair using trained SVD model
        
        Args:
            user_id: User identifier
            exercise_id: Exercise identifier
            
        Returns:
            Predicted rating (1.0 to 5.0)
        """
        try:
            if not self.is_trained:
                return self.global_mean
                
            if user_id not in self.user_to_index or exercise_id not in self.exercise_to_index:
                return self.global_mean
                
            user_idx = self.user_to_index[user_id]
            exercise_idx = self.exercise_to_index[exercise_id]
            
            # SVD prediction: global_mean + user_bias + item_bias + user_factors * item_factors
            prediction = (
                self.global_mean +
                self.user_biases[user_idx] +
                self.item_biases[exercise_idx] +
                np.dot(self.user_factors[user_idx], self.item_factors[exercise_idx])
            )
            
            return max(1.0, min(5.0, float(prediction)))
            
        except Exception as e:
            logger.warning(f"⚠️ Error predicting rating: {e}")
            return self.global_mean
    
    def get_recommendations(
        self, 
        user_id: str, 
        candidate_exercises: List[str],
        n_recommendations: int = 5,
        include_reasons: bool = True
    ) -> List[Dict]:
        """
        Get personalized recommendations with match percentages
        
        Args:
            user_id: Target user ID
            candidate_exercises: List of exercise IDs to score
            n_recommendations: Number of recommendations to return
            include_reasons: Whether to include recommendation reasoning
            
        Returns:
            List of recommendation dictionaries with match percentages
        """
        try:
            recommendations = []
            
            for exercise_id in candidate_exercises:
                # Get SVD prediction
                svd_score = self.predict_rating(user_id, exercise_id)
                
                # Get content-based score for hybrid approach
                content_score = self._calculate_content_similarity(user_id, exercise_id)
                
                # Calculate confidence based on available data
                confidence = self._calculate_recommendation_confidence(user_id, exercise_id)
                
                # Hybrid score: combine SVD and content-based
                hybrid_score = (svd_score * 0.7 + content_score * 0.3)
                
                # Convert to percentage match (0-100%)
                match_percentage = self._score_to_percentage(hybrid_score, confidence)
                
                recommendation = {
                    'exercise_id': exercise_id,
                    'match_percentage': round(match_percentage, 0),
                    'svd_score': round(svd_score, 2),
                    'content_score': round(content_score, 2),
                    'confidence': round(confidence, 2),
                    'hybrid_score': round(hybrid_score, 2)
                }
                
                if include_reasons:
                    recommendation['reason'] = self._generate_recommendation_reason(
                        user_id, exercise_id, svd_score, content_score, confidence
                    )
                
                recommendations.append(recommendation)
            
            # Sort by match percentage
            recommendations.sort(key=lambda x: x['match_percentage'], reverse=True)
            
            return recommendations[:n_recommendations]
            
        except Exception as e:
            logger.error(f"❌ Error generating recommendations: {e}")
            return []
    
    def _calculate_content_similarity(self, user_id: str, exercise_id: str) -> float:
        """Calculate content-based similarity score"""
        try:
            if user_id not in self.user_profiles or exercise_id not in self.exercise_features:
                return 2.5
                
            user_profile = self.user_profiles[user_id]
            exercise = self.exercise_features[exercise_id]
            
            score = 2.5
            
            # Position matching
            user_position = user_profile.get('position', '').lower()
            exercise_description = exercise.get('description', '').lower()
            if user_position and user_position in exercise_description:
                score += 0.5
            
            # Goals alignment
            user_goals = user_profile.get('goals', [])
            for goal in user_goals:
                if goal.lower() in exercise_description:
                    score += 0.3
            
            # Experience level matching
            user_experience = user_profile.get('experienceLevel', '').lower()
            exercise_difficulty = exercise.get('difficulty', 3)
            
            experience_difficulty_map = {'beginner': 2, 'intermediate': 3, 'advanced': 4}
            expected_difficulty = experience_difficulty_map.get(user_experience, 3)
            
            if abs(exercise_difficulty - expected_difficulty) <= 1:
                score += 0.4
            elif abs(exercise_difficulty - expected_difficulty) > 2:
                score -= 0.3
            
            # Category preferences (could be learned from history)
            exercise_category = exercise.get('category', '').lower()
            # This could be enhanced with learned category preferences
            
            return max(1.0, min(5.0, score))
            
        except Exception as e:
            logger.warning(f"⚠️ Error calculating content similarity: {e}")
            return 2.5
    
    def _calculate_recommendation_confidence(self, user_id: str, exercise_id: str) -> float:
        """Calculate confidence in recommendation based on available data"""
        try:
            confidence = 0.5  # Base confidence
            
            # User data availability
            if user_id in self.user_to_index:
                user_idx = self.user_to_index[user_id]
                user_interactions = self.interaction_matrix[user_idx, :].nnz
                # More interactions = higher confidence
                confidence += min(0.3, user_interactions / 20.0)
            
            # Exercise data availability  
            if exercise_id in self.exercise_to_index:
                exercise_idx = self.exercise_to_index[exercise_id]
                exercise_interactions = self.interaction_matrix[:, exercise_idx].nnz
                # More ratings = higher confidence
                confidence += min(0.2, exercise_interactions / 10.0)
            
            return min(1.0, confidence)
            
        except Exception as e:
            logger.warning(f"⚠️ Error calculating confidence: {e}")
            return 0.5
    
    def _score_to_percentage(self, score: float, confidence: float) -> float:
        """Convert hybrid score to match percentage (0-100%)"""
        try:
            # Normalize score from 1-5 range to 0-1
            normalized_score = (score - 1.0) / 4.0
            
            # Apply confidence weighting
            adjusted_score = normalized_score * confidence + 0.5 * (1 - confidence)
            
            # Convert to percentage with some stretching for better UX
            percentage = adjusted_score * 85 + 15  # Maps to 15-100% range
            
            return max(0, min(100, percentage))
            
        except Exception as e:
            logger.warning(f"⚠️ Error converting score to percentage: {e}")
            return 50.0
    
    def _generate_recommendation_reason(
        self, 
        user_id: str, 
        exercise_id: str, 
        svd_score: float,
        content_score: float,
        confidence: float
    ) -> str:
        """Generate human-readable recommendation reason"""
        try:
            reasons = []
            
            if svd_score > 4.0:
                reasons.append("Players with similar preferences loved this")
            elif svd_score > 3.5:
                reasons.append("Based on your training patterns")
            
            if content_score > 4.0:
                reasons.append("Perfect match for your goals")
            elif content_score > 3.5:
                reasons.append("Aligns with your position and experience")
            
            if confidence > 0.8:
                reasons.append("High confidence recommendation")
            elif confidence < 0.5:
                reasons.append("New exercise worth exploring")
            
            if not reasons:
                reasons.append("Recommended for your development")
            
            return " • ".join(reasons[:2])  # Max 2 reasons for brevity
            
        except Exception as e:
            logger.warning(f"⚠️ Error generating reason: {e}")
            return "Recommended for you"


def create_advanced_recommendation_engine(
    user_history: List[Dict],
    user_profiles: Dict[str, Dict],
    exercise_catalog: Dict[str, Dict],
    n_factors: int = 50,
    regularization: float = 0.02
) -> AdvancedRecommendationEngine:
    """
    Factory function to create and train recommendation engine
    
    Args:
        user_history: Training session history
        user_profiles: User profile data
        exercise_catalog: Exercise metadata
        n_factors: Number of SVD latent factors
        regularization: L2 regularization parameter
        
    Returns:
        Trained recommendation engine
    """
    try:
        logger.info("🚀 Creating advanced recommendation engine...")
        
        # Create engine
        engine = AdvancedRecommendationEngine(n_factors, regularization)
        
        # Prepare training data
        interaction_matrix, user_mappings, exercise_mappings = engine.prepare_training_data(
            user_history, user_profiles, exercise_catalog
        )
        
        # Train model
        training_success = engine.train_model()
        
        if training_success:
            logger.info("✅ Advanced recommendation engine ready")
        else:
            logger.warning("⚠️ SVD training failed, engine will use fallback methods")
        
        return engine
        
    except Exception as e:
        logger.error(f"❌ Error creating recommendation engine: {e}")
        raise e