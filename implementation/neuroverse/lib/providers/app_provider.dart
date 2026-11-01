import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models/game_session.dart';
import '../data/local/hive_service.dart';
import '../core/services/reminder_service.dart';
import '../core/services/notification_service.dart';
class AppProvider extends ChangeNotifier {
  String? currentUserRole; // 'patient', 'caregiver', 'admin'
  String? userName;
  String? userAge;
  String? userGender;
  String? userLanguage;
  String? voiceLanguage;
  String? caretakerName;
  bool isDarkMode = false;
  bool isDataSynced = true;
  bool isAudioEffectsEnabled = true; // Sync state: true = Green (synced), false = Orange (pending)
  
  // Notification & Alert preferences
  bool dailySummaries = true;
  bool criticalAlerts = true;
  bool inactivityReminders = true;

  // Navigation hint session guard (shown once on initial app launch)
  bool hasShownGamesHintThisSession = false;

  void markGamesHintShown() {
    hasShownGamesHintThisSession = true;
  }

  // Game Progress State
  List<GameSession> gameHistory = [];
  final HiveService? _hiveService;

  AppProvider({HiveService? hiveService}) : _hiveService = hiveService {
    if (_hiveService != null) {
      loadProfile();
      loadProgress();
      loadSettings();
    }
  }

  void loadProfile() {
    final hive = _hiveService;
    if (hive == null) return;
    final profile = hive.getUserProfile();
    if (profile != null) {
      userName = profile['name']?.toString();
      userAge = profile['age']?.toString();
      userGender = profile['gender']?.toString();
      userLanguage = profile['language']?.toString() ?? 'English';
      voiceLanguage = profile['voiceLanguage']?.toString() ?? profile['language']?.toString() ?? 'English';
      caretakerName = profile['caretakerName']?.toString();
      currentUserRole = profile['role']?.toString();
      notifyListeners();
    }
  }

  void clearUserProfile() {
    userName = null;
    userAge = null;
    userGender = null;
    caretakerName = null;
    currentUserRole = null;
    notifyListeners();
  }

  void loadProgress() {
    final hive = _hiveService;
    if (hive == null) return;
    gameHistory = hive.getAllGameSessions();
    notifyListeners();
  }

  void loadSettings() {
    final hive = _hiveService;
    if (hive == null) return;
    isDarkMode = hive.getSetting<bool>('dark_mode', false);
    isAudioEffectsEnabled = hive.getSetting<bool>('audio_effects_enabled', true);
    dailySummaries = hive.getSetting<bool>('notif_daily_summary', true);
    criticalAlerts = hive.getSetting<bool>('notif_critical_alerts', true);
    inactivityReminders = hive.getSetting<bool>('notif_inactivity', true);
    notifyListeners();
  }

  Future<void> clearProgress() async {
    final hive = _hiveService;
    if (hive == null) return;
    await hive.clearGameSessions();
    gameHistory.clear();
    notifyListeners();
  }

  void setRole(String role) {
    currentUserRole = role;
    notifyListeners();
  }

  void setSyncStatus(bool synced) {
    isDataSynced = synced;
    notifyListeners();
  }

  void toggleTheme() {
    isDarkMode = !isDarkMode;
    _hiveService?.saveSetting('dark_mode', isDarkMode);
    notifyListeners();
  }

  void setAudioEffectsEnabled(bool value) {
    isAudioEffectsEnabled = value;
    _hiveService?.saveSetting('audio_effects_enabled', value);
    notifyListeners();
  }

  void setDarkMode(bool value) {
    isDarkMode = value;
    _hiveService?.saveSetting('dark_mode', isDarkMode);
    notifyListeners();
  }

  void setDailySummaries(bool value) {
    dailySummaries = value;
    _hiveService?.saveSetting('notif_daily_summary', value);
    notifyListeners();
  }

  void setCriticalAlerts(bool value) {
    criticalAlerts = value;
    _hiveService?.saveSetting('notif_critical_alerts', value);
    notifyListeners();
  }

  void setInactivityReminders(bool value) {
    inactivityReminders = value;
    _hiveService?.saveSetting('notif_inactivity', value);
    notifyListeners();
  }

  void setUserProfile(String name, String age, String gender, String language, {String? voiceLanguage, String? caretakerName}) {
    userName = name;
    userAge = age;
    userGender = gender;
    userLanguage = language;
    if (voiceLanguage != null) {
      this.voiceLanguage = voiceLanguage;
    } else if (this.voiceLanguage == null || this.voiceLanguage!.isEmpty) {
      this.voiceLanguage = language;
    }
    if (caretakerName != null) {
      this.caretakerName = caretakerName;
    }
    notifyListeners();
  }

  Future<void> setAppLanguage(String language) async {
    userLanguage = language;
    notifyListeners();
    
    // Save to local Hive
    if (_hiveService != null) {
      final currentProfile = _hiveService.getUserProfile() ?? {};
      currentProfile['language'] = language;
      await _hiveService.saveUserProfile(currentProfile);
    }

    // Sync to Firestore if authenticated
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'language': language,
        }, SetOptions(merge: true));

        // Seamlessly refresh scheduled reminders in the newly selected language
        if (currentUserRole == null || currentUserRole == 'patient') {
          ReminderService().syncAndSchedulePatientReminders(uid).catchError((_) {});
          NotificationService().scheduleDailyReminders().catchError((_) {});
        }
      }
    } catch (_) {}
  }

  Future<void> setVoiceLanguage(String language) async {
    voiceLanguage = language;
    notifyListeners();
    
    // Save to local Hive
    if (_hiveService != null) {
      final currentProfile = _hiveService.getUserProfile() ?? {};
      currentProfile['voiceLanguage'] = language;
      await _hiveService.saveUserProfile(currentProfile);
    }

    // Sync to Firestore if authenticated
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'voiceLanguage': language,
        }, SetOptions(merge: true));
      }
    } catch (_) {}
  }
}
