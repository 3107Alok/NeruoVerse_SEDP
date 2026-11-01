import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}

  debugPrint('FCM background message received: ${message.messageId}');

  final title = message.notification?.title ??
      message.data['title']?.toString() ??
      '🚨 NeuroVerse Alert';
  final body = message.notification?.body ??
      message.data['body']?.toString() ??
      'Emergency update received. Open NeuroVerse to view.';
  final payload = message.data['payload']?.toString() ??
      message.data['type']?.toString() ??
      'fcm_alert';

  try {
    final notifId = (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() % 1000000;
    await NotificationService().showNotification(
      id: notifId,
      title: title,
      body: body,
      payload: payload,
    );
  } catch (e) {
    debugPrint('Error showing local notification from background FCM: $e');
  }
}

class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _initialized = false;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      // 1. Request notification permissions (for Android 13+ and iOS)
      final settings = await _fcm.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );
      debugPrint('FCM Authorization status: ${settings.authorizationStatus}');

      // 2. Set foreground presentation options
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Get device token and save to Firestore
      final token = await _fcm.getToken();
      if (token != null) {
        debugPrint('FCM Device Token: $token');
        await _saveTokenToFirestore(token);
      }

      // 4. Listen for token refresh
      _tokenRefreshSub = _fcm.onTokenRefresh.listen((newToken) async {
        debugPrint('FCM Token refreshed: $newToken');
        await _saveTokenToFirestore(newToken);
      });

      // 5. Re-save token whenever user auth changes
      _authSub = _auth.authStateChanges().listen((user) async {
        if (user != null) {
          final t = await _fcm.getToken();
          if (t != null) {
            await _saveTokenToFirestore(t, uid: user.uid);
          }
        }
      });

      // 6. Handle foreground push messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM foreground message received: ${message.data}');
        final title = message.notification?.title ??
            message.data['title']?.toString() ??
            'NeuroVerse Alert';
        final body = message.notification?.body ??
            message.data['body']?.toString() ??
            '';
        final payload = message.data['payload']?.toString() ??
            message.data['type']?.toString();

        if (title.isNotEmpty || body.isNotEmpty) {
          NotificationService().showNotification(
            id: (message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch).abs() % 1000000,
            title: title,
            body: body,
            payload: payload,
          );
        }
      });

      // 7. Handle notification click when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM Notification opened from background: ${message.data}');
      });

      // 8. Handle notification click when app launched from terminated state
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM Initial message launched app: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('FcmService init error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token, {String? uid}) async {
    try {
      final user = _auth.currentUser;
      final targetUid = uid ?? user?.uid;
      if (targetUid == null) return;

      await _firestore.collection('users').doc(targetUid).set({
        'fcmToken': token,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'lastFcmUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('FCM Token saved to Firestore for user: $targetUid');
    } catch (e) {
      debugPrint('Error saving FCM token to Firestore: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _tokenRefreshSub?.cancel();
    _authSub?.cancel();
  }
}
