import 'package:hive_flutter/hive_flutter.dart';
import '../../core/models/game_session.dart';
import '../../core/models/family_member_model.dart';
import '../../core/services/notification_service.dart';

class HiveService {
  static const String sessionBoxName = 'game_sessions';
  static const String qTableBoxName = 'q_table';
  static const String profileBoxName = 'user_profile';
  static const String familyMembersBoxName = 'family_members';

  Future<void> initBoxes() async {
    await Hive.openBox(sessionBoxName);
    await Hive.openBox(qTableBoxName);
    await Hive.openBox(profileBoxName);
    await Hive.openBox(familyMembersBoxName);
  }

  // --- Game Sessions ---
  Future<void> saveGameSession(GameSession session) async {
    final box = Hive.box(sessionBoxName);
    // Use the session ID as the key and store the map representation
    await box.put(session.id, session.toMap());

    // Patient completed a game session, cancel today's evening reminder!
    NotificationService().cancelEveningReminder();
  }

  List<GameSession> getAllGameSessions() {
    final box = Hive.box(sessionBoxName);
    List<GameSession> sessions = [];
    for (var key in box.keys) {
      try {
        final rawMap = box.get(key);
        if (rawMap != null && rawMap is Map) {
          final map = Map<String, dynamic>.from(rawMap);
          sessions.add(GameSession.fromMap(map));
        }
      } catch (e) {
        // Skip malformed/corrupted local session entry
      }
    }
    // Sort by timestamp descending
    sessions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sessions;
  }

  Future<void> clearGameSessions() async {
    final box = Hive.box(sessionBoxName);
    await box.clear();
  }

  // --- Q-Table ---
  Future<void> saveQTable(Map<String, Map<String, double>> qTable) async {
    final box = Hive.box(qTableBoxName);
    // Convert to a format Hive can easily store (String to dynamic map)
    Map<String, dynamic> serializableTable = {};
    qTable.forEach((state, actions) {
      serializableTable[state] = actions;
    });
    await box.put('current_table', serializableTable);
  }

  Map<String, Map<String, double>> loadQTable() {
    final box = Hive.box(qTableBoxName);
    final data = box.get('current_table');
    if (data == null) return {};

    Map<String, Map<String, double>> qTable = {};
    (data as Map).forEach((state, actions) {
      Map<String, double> actionMap = {};
      (actions as Map).forEach((action, qValue) {
        actionMap[action.toString()] = (qValue as num).toDouble();
      });
      qTable[state.toString()] = actionMap;
    });
    return qTable;
  }

  // --- Profile ---
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    final box = Hive.box(profileBoxName);
    await box.put('profile', profileData);
  }

  Map<String, dynamic>? getUserProfile() {
    final box = Hive.box(profileBoxName);
    final data = box.get('profile');
    if (data != null) {
      return Map<String, dynamic>.from(data);
    }
    return null;
  }

  // --- Daily Persistent Game Difficulties (Option 1: Daily Fresh Ladder) ---
  Future<void> saveGameDifficulty(String gameId, int difficulty) async {
    final box = Hive.box(profileBoxName);
    final now = DateTime.now();
    // Save difficulty keyed by today's date
    await box.put('diff_${gameId}_${now.year}_${now.month}_${now.day}', difficulty);
    // Also save all-time highest level reached
    int currentBest = getBestLevelAllTime(gameId);
    if (difficulty > currentBest) {
      await box.put('best_diff_$gameId', difficulty);
    }
  }

  /// Saves difficulty for a specific elder/patient (e.g. screened by ASHA in PHC Network)
  Future<void> saveGameDifficultyForPatient(String patientId, String gameId, int difficulty) async {
    if (!Hive.isBoxOpen(profileBoxName)) return;
    final box = Hive.box(profileBoxName);
    final now = DateTime.now();
    await box.put('diff_patient_${patientId}_${gameId}_${now.year}_${now.month}_${now.day}', difficulty);
    await box.put('latest_diff_patient_${patientId}_$gameId', difficulty);
  }

  /// Gets difficulty for a specific elder/patient in PHC Network
  int getGameDifficultyForPatient(String patientId, String gameId) {
    if (!Hive.isBoxOpen(profileBoxName)) return 1;
    final box = Hive.box(profileBoxName);
    final now = DateTime.now();
    final todayDiff = box.get('diff_patient_${patientId}_${gameId}_${now.year}_${now.month}_${now.day}');
    if (todayDiff != null && todayDiff is int) {
      return todayDiff;
    }
    final latestDiff = box.get('latest_diff_patient_${patientId}_$gameId');
    if (latestDiff != null && latestDiff is int) {
      return latestDiff;
    }
    return 1;
  }

  int getGameDifficulty(String gameId) {
    final now = DateTime.now();
    // Check if user played any sessions today
    final todaySessions = getAllGameSessions().where((s) =>
      s.gameId == gameId &&
      s.timestamp.year == now.year &&
      s.timestamp.month == now.month &&
      s.timestamp.day == now.day
    ).toList();

    // If fresh day (no games played yet today), reset to Level 1!
    if (todaySessions.isEmpty) {
      return 1;
    }

    // If played today, continue from today's saved ladder progress
    final box = Hive.box(profileBoxName);
    final todayDiff = box.get('diff_${gameId}_${now.year}_${now.month}_${now.day}');
    if (todayDiff != null && todayDiff is int) {
      return todayDiff;
    }

    return todaySessions.first.difficultyLevel;
  }

  int getBestLevelAllTime(String gameId) {
    final box = Hive.box(profileBoxName);
    final best = box.get('best_diff_$gameId');
    if (best != null && best is int) return best;
    
    final sessions = getAllGameSessions().where((s) => s.gameId == gameId).toList();
    if (sessions.isEmpty) return 1;
    return sessions.map((s) => s.difficultyLevel).reduce((a, b) => a > b ? a : b);
  }

  // --- General Settings ---
  Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(profileBoxName);
    await box.put('setting_$key', value);
  }

  T getSetting<T>(String key, T defaultValue) {
    final box = Hive.box(profileBoxName);
    final val = box.get('setting_$key');
    if (val != null && val is T) return val;
    return defaultValue;
  }

  // --- Family Members (Face Recall) ---
  Future<void> saveFamilyMembers(List<FamilyMember> members) async {
    final box = Hive.box(familyMembersBoxName);
    final List<Map<String, dynamic>> maps = members.map((m) => m.toMap()).toList();
    await box.put('members_list', maps);
  }

  List<FamilyMember> getFamilyMembers() {
    final box = Hive.box(familyMembersBoxName);
    final raw = box.get('members_list');
    if (raw != null && raw is List && raw.isNotEmpty) {
      return raw
          .map((item) => FamilyMember.fromMap(Map<String, dynamic>.from(item as Map)))
          .where((m) => !m.isDefaultAsset && !m.imageBase64.startsWith('assets/'))
          .toList();
    }
    return [];
  }

  bool hasCustomFamilyMembers() {
    final box = Hive.box(familyMembersBoxName);
    final raw = box.get('members_list');
    if (raw != null && raw is List && raw.isNotEmpty) {
      return raw.any((item) => !(item['isDefaultAsset'] as bool? ?? false) && !(item['imageBase64'] as String? ?? '').startsWith('assets/'));
    }
    return false;
  }
}
