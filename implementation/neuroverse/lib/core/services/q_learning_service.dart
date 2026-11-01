import 'dart:math';

/// A lightweight, on-device implementation of Q-Learning.
class QLearningService {
  final double alpha; // Learning rate
  final double gamma; // Discount factor
  final double epsilon; // Exploration rate

  // Q-Table structure: Map<State, Map<Action, Q-Value>>
  // In our case, State could be represented as a combined string, e.g., "DiffLevel_PerfBucket"
  // Action could be "increase", "maintain", "decrease"
  Map<String, Map<String, double>> qTable = {};

  QLearningService({
    this.alpha = 0.1,
    this.gamma = 0.9,
    this.epsilon = 0.2, // 20% exploration for new users
  });

  /// Get the best action for a given state
  String chooseAction(String state, List<String> availableActions) {
    if (availableActions.isEmpty) return 'maintain';

    // Exploration
    if (Random().nextDouble() < epsilon) {
      return availableActions[Random().nextInt(availableActions.length)];
    }

    // Exploitation
    _initializeStateIfNeeded(state, availableActions);
    
    double maxQ = double.negativeInfinity;
    String bestAction = availableActions.first;

    qTable[state]!.forEach((action, qValue) {
      if (qValue > maxQ) {
        maxQ = qValue;
        bestAction = action;
      }
    });

    return bestAction;
  }

  /// Update Q-Value based on the reward received
  void updateQValue(String state, String action, double reward, String nextState, List<String> nextAvailableActions) {
    _initializeStateIfNeeded(state, [action]);
    _initializeStateIfNeeded(nextState, nextAvailableActions);

    double currentQ = qTable[state]![action] ?? 0.0;
    
    // Find max Q for next state
    double maxNextQ = 0.0;
    if (qTable[nextState]!.isNotEmpty) {
      maxNextQ = qTable[nextState]!.values.reduce(max);
    }

    // Bellman equation
    double newQ = currentQ + alpha * (reward + gamma * maxNextQ - currentQ);
    qTable[state]![action] = newQ;
  }

  void _initializeStateIfNeeded(String state, List<String> actions) {
    if (!qTable.containsKey(state)) {
      qTable[state] = {};
      // Initialize with 0.0 (or a sensible default to avoid cold start issues completely)
      for (var action in actions) {
        qTable[state]![action] = 0.1; // Small positive default to encourage exploring unvisited state-actions
      }
    } else {
      for (var action in actions) {
        if (!qTable[state]!.containsKey(action)) {
             qTable[state]![action] = 0.1;
        }
      }
    }
  }

  // TODO: Add methods to load and save qTable from/to Hive
}
