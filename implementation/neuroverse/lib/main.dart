import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'providers/app_provider.dart';

// Services
import 'data/local/hive_service.dart' as app_hive;
import 'core/services/q_learning_service.dart';
import 'core/services/adaptive_intelligence_service.dart';
import 'data/remote/firebase_auth_service.dart';
import 'data/remote/firestore_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/voice_service.dart';
import 'core/services/reminder_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/firebase_link_service.dart';
import 'core/services/fcm_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Force portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 2. Initialize Firebase with resilient try-catch & register FCM background handler
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // 3. Initialize Hive Local Storage with fallback
  final hiveService = app_hive.HiveService();
  try {
    await Hive.initFlutter();
    await hiveService.initBoxes();
  } catch (e) {
    debugPrint('Hive initialization notice: $e');
  }

  // 4. Instantiate Core App Services
  final qLearningService = QLearningService();
  final adaptiveService = AdaptiveIntelligenceService(qLearningService);
  final firestoreService = FirestoreService();
  final authService = FirebaseAuthService();
  final syncService = SyncService(hiveService);
  final voiceService = VoiceService();
  final reminderService = ReminderService();
  final notificationService = NotificationService();
  final firebaseLinkService = FirebaseLinkService(notificationService);
  final fcmService = FcmService();

  // 5. Initialize background native plugins asynchronously so runApp never blocks
  final isAudioSaved = hiveService.getSetting<bool>('audio_effects_enabled', true);
  voiceService.setAudioEnabled(isAudioSaved);
  voiceService.init().catchError((e) => debugPrint('VoiceService init notice: $e'));
  reminderService.init().catchError((e) => debugPrint('ReminderService init notice: $e'));
  notificationService.init().catchError((e) => debugPrint('NotificationService init notice: $e'));
  fcmService.init().catchError((e) => debugPrint('FcmService init notice: $e'));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider(hiveService: hiveService)),
        Provider<app_hive.HiveService>.value(value: hiveService),
        Provider<QLearningService>.value(value: qLearningService),
        Provider<AdaptiveIntelligenceService>.value(value: adaptiveService),
        Provider<FirestoreService>.value(value: firestoreService),
        Provider<FirebaseAuthService>.value(value: authService),
        Provider<SyncService>.value(value: syncService),
        Provider<VoiceService>.value(value: voiceService),
        Provider<ReminderService>.value(value: reminderService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<FirebaseLinkService>.value(value: firebaseLinkService),
        Provider<FcmService>.value(value: fcmService),
      ],
      child: const NeuroVerseApp(),
    ),
  );
}
