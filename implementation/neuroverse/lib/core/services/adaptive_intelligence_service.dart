import '../models/game_session.dart';
import 'q_learning_service.dart';

class AdaptiveIntelligenceService {
  final QLearningService qLearningService;

  AdaptiveIntelligenceService(this.qLearningService);

  /// Analyzes a completed GameSession, updates the Q-Learning model, 
  /// and returns the recommended difficulty level for the next session.
  int processSessionAndGetNextDifficulty(GameSession session) {
    // 1. Define Current State & Calculate Reward for Q-table tracking
    String currentState = _buildStateString(session.difficultyLevel, session.accuracyPercentage, session.completionTimeSeconds);
    double reward = _calculateReward(session.accuracyPercentage, session.completionTimeSeconds, session.hintsUsed);
    List<String> availableActions = _getAvailableActions(session.difficultyLevel);

    // 2. Direct Heuristic for actual gameplay progression (Guarantees Level Up on high accuracy)
    int nextDifficulty = session.difficultyLevel;
    String logicalAction = 'maintain';
    
    // Level up threshold: Memory games allow 66% (e.g. 1 mistake on Level 1 with 2 pairs)
    final int levelUpThreshold = (session.gameId == 'memory_match' ||
            session.gameId == 'memory_recall' ||
            session.gameId == 'face_recall')
        ? 66
        : 70;

    if (session.accuracyPercentage >= levelUpThreshold) {
      if (session.difficultyLevel < 10) {
        nextDifficulty = session.difficultyLevel + 1;
        logicalAction = 'increase';
      }
    } else if (session.accuracyPercentage < 50) {
      if (session.difficultyLevel > 1) {
        nextDifficulty = session.difficultyLevel - 1;
        logicalAction = 'decrease';
      }
    }

    // 3. Update Q-Table to simulate AI learning the best actions
    qLearningService.updateQValue(currentState, logicalAction, reward, currentState, availableActions);

    return nextDifficulty;
  }

  String _buildStateString(int difficulty, int accuracy, int time) {
    String accuracyBucket = accuracy >= 66 ? "HIGH" : (accuracy >= 50 ? "MED" : "LOW");
    String timeBucket = time < 30 ? "FAST" : (time < 60 ? "AVG" : "SLOW");
    return "D${difficulty}_A${accuracyBucket}_T$timeBucket";
  }

  double _calculateReward(int accuracy, int time, int hints) {
    double reward = 0;
    // High accuracy is good
    if (accuracy >= 66) reward += 2;
    else if (accuracy < 50) reward -= 2;

    // Fast completion is good
    if (time < 30) reward += 1;
    else if (time > 60) reward -= 1;

    // Penalize hints
    reward -= (hints * 0.5);

    return reward;
  }

  List<String> _getAvailableActions(int currentDifficulty) {
    List<String> actions = ['maintain'];
    if (currentDifficulty < 10) actions.add('increase');
    if (currentDifficulty > 1) actions.add('decrease');
    return actions;
  }
}
