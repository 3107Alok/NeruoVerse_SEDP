class GameSession {
  final String id;
  final String gameId;
  final String patientId;
  final DateTime timestamp;
  final int difficultyLevel;
  final int score;
  final int accuracyPercentage;
  final int completionTimeSeconds;
  final int mistakes;
  final int hintsUsed;
  final bool isCompleted;
  
  // Advanced Analytics Fields
  final double? reactionTimeAverageMs;
  final double? cognitiveScore;
  final String? sessionMood;
  final String? gameCategory;

  GameSession({
    required this.id,
    required this.gameId,
    required this.patientId,
    required this.timestamp,
    required this.difficultyLevel,
    required this.score,
    required this.accuracyPercentage,
    required this.completionTimeSeconds,
    required this.mistakes,
    required this.hintsUsed,
    this.isCompleted = true,
    this.reactionTimeAverageMs,
    this.cognitiveScore,
    this.sessionMood,
    this.gameCategory,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gameId': gameId,
      'patientId': patientId,
      'timestamp': timestamp.toIso8601String(),
      'difficultyLevel': difficultyLevel,
      'score': score,
      'accuracyPercentage': accuracyPercentage,
      'completionTimeSeconds': completionTimeSeconds,
      'mistakes': mistakes,
      'hintsUsed': hintsUsed,
      'isCompleted': isCompleted,
      'reactionTimeAverageMs': reactionTimeAverageMs,
      'cognitiveScore': cognitiveScore,
      'sessionMood': sessionMood,
      'gameCategory': gameCategory,
    };
  }

  factory GameSession.fromMap(Map<String, dynamic> map) {
    DateTime parsedTimestamp;
    try {
      final rawTs = map['timestamp'];
      if (rawTs == null) {
        parsedTimestamp = DateTime.now();
      } else if (rawTs is DateTime) {
        parsedTimestamp = rawTs;
      } else if (rawTs is String) {
        parsedTimestamp = DateTime.tryParse(rawTs) ?? DateTime.now();
      } else {
        try {
          parsedTimestamp = (rawTs as dynamic).toDate();
        } catch (_) {
          parsedTimestamp = DateTime.now();
        }
      }
    } catch (_) {
      parsedTimestamp = DateTime.now();
    }

    return GameSession(
      id: map['id']?.toString() ?? '',
      gameId: map['gameId']?.toString() ?? '',
      patientId: map['patientId']?.toString() ?? '',
      timestamp: parsedTimestamp,
      difficultyLevel: (map['difficultyLevel'] as num?)?.toInt() ?? 1,
      score: (map['score'] as num?)?.toInt() ?? 0,
      accuracyPercentage: (map['accuracyPercentage'] as num?)?.toInt() ?? 0,
      completionTimeSeconds: (map['completionTimeSeconds'] as num?)?.toInt() ?? 0,
      mistakes: (map['mistakes'] as num?)?.toInt() ?? 0,
      hintsUsed: (map['hintsUsed'] as num?)?.toInt() ?? 0,
      isCompleted: map['isCompleted'] == true,
      reactionTimeAverageMs: (map['reactionTimeAverageMs'] as num?)?.toDouble(),
      cognitiveScore: (map['cognitiveScore'] as num?)?.toDouble(),
      sessionMood: map['sessionMood']?.toString(),
      gameCategory: map['gameCategory']?.toString(),
    );
  }
}
