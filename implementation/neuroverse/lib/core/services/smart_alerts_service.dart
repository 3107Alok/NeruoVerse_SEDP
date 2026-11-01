import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/local/hive_service.dart';
import 'notification_service.dart';

class SmartAlert {
  final String title;
  final String message;
  final String severity; // 'info', 'warning', 'critical'
  final DateTime timestamp;
  final String patientId;
  final String? id;
  final String? type;
  final String? patientPhone;
  final String? mapsUrl;

  SmartAlert({
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.patientId,
    this.id,
    this.type,
    this.patientPhone,
    this.mapsUrl,
  });
}

class SmartAlertsService {
  final FirebaseFirestore? _firestore;
  final Future<void> Function({
    required int id,
    required String title,
    required String body,
    String? payload,
  })? _notifyHandler;
  static DateTime? _lastCriticalNotificationTime;

  SmartAlertsService({
    FirebaseFirestore? firestore,
    Future<void> Function({
      required int id,
      required String title,
      required String body,
      String? payload,
    })? notifyHandler,
  })  : _firestore = firestore,
        _notifyHandler = notifyHandler;

  @visibleForTesting
  static void resetThrottlingForTesting() {
    _lastCriticalNotificationTime = null;
  }

  String _formatGameTitle(String? gameId, String? category) {
    if (gameId != null) {
      final lower = gameId.toLowerCase().trim();
      if (lower == 'memory_match' || lower == 'memory match') return 'Memory Match';
      if (lower == 'face_recall' || lower == 'face recall') return 'Face Recall';
      if (lower == 'pattern_path' || lower == 'pattern path') return 'Pattern Path';
      if (lower == 'memory_recall' || lower == 'memory recall') return 'Memory Recall';
    }
    if (category != null && category.trim().isNotEmpty) {
      return category.trim();
    }
    return 'cognitive game';
  }

  Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (_notifyHandler != null) {
      await _notifyHandler(id: id, title: title, body: body);
    } else {
      try {
        await NotificationService().showNotification(
          id: id,
          title: title,
          body: body,
        );
      } catch (e) {
        debugPrint('SmartAlertsService: Notification error: $e');
      }
    }
  }

  Future<List<SmartAlert>> generateAlertsForPatient(
    String patientId, {
    String? patientName,
    List<Map<String, dynamic>>? mockSessions,
  }) async {
    List<SmartAlert> alerts = [];

    // 1. Resolve patient name dynamically from provided data, Firestore, or local Hive
    String name = (patientName != null && patientName.trim().isNotEmpty)
        ? patientName.trim()
        : '';

    if (name.isEmpty) {
      try {
        final fs = _firestore ?? FirebaseFirestore.instance;
        final userDoc = await fs.collection('users').doc(patientId).get();
        final data = userDoc.data();
        if (data != null && data['name'] != null && data['name'].toString().trim().isNotEmpty) {
          name = data['name'].toString().trim();
        }
      } catch (e) {
        debugPrint('SmartAlertsService: Could not fetch patient name from Firestore: $e');
      }
    }

    if (name.isEmpty) {
      try {
        final localProfile = HiveService().getUserProfile();
        if (localProfile != null && localProfile['name'] != null && localProfile['name'].toString().trim().isNotEmpty) {
          name = localProfile['name'].toString().trim();
        }
      } catch (_) {}
    }

    if (name.isEmpty) {
      name = 'Patient';
    }

    final String patientTitle = name.toLowerCase().startsWith('patient') ? name : 'Patient $name';

    // 2. Fetch last 10 sessions (or use mockSessions if injected)
    List<Map<String, dynamic>> sessions = [];
    if (mockSessions != null) {
      sessions = List<Map<String, dynamic>>.from(mockSessions);
    } else {
      try {
        final fs = _firestore ?? FirebaseFirestore.instance;
        final snapshot = await fs
            .collection('users')
            .doc(patientId)
            .collection('game_sessions')
            .orderBy('timestamp', descending: true)
            .limit(10)
            .get();

        sessions = snapshot.docs.map((doc) => doc.data()).toList();
      } catch (e) {
        debugPrint('SmartAlertsService: Could not fetch game sessions: $e');
      }
    }

    if (sessions.isEmpty) {
      alerts.add(SmartAlert(
        title: 'No Recent Activity: $name',
        message: '$name has not completed any activities recently.',
        severity: 'info',
        timestamp: DateTime.now(),
        patientId: patientId,
      ));
      return alerts;
    }

    // 1. Repeated Inactivity (e.g. last session was > 3 days ago)
    DateTime? lastSessionTime;
    final rawTs = sessions.first['timestamp'];
    if (rawTs is Timestamp) {
      lastSessionTime = rawTs.toDate();
    } else if (rawTs is String) {
      lastSessionTime = DateTime.tryParse(rawTs);
    } else if (rawTs is int) {
      lastSessionTime = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is DateTime) {
      lastSessionTime = rawTs;
    }
    lastSessionTime ??= DateTime.now();
    final daysSinceLastSession = DateTime.now().difference(lastSessionTime).inDays;

    if (daysSinceLastSession >= 3) {
      alerts.add(SmartAlert(
        title: 'Activity Gap: $name',
        message: 'No sessions completed by $name in the last $daysSinceLastSession days. Consider sending a reminder.',
        severity: 'warning',
        timestamp: DateTime.now(),
        patientId: patientId,
      ));
    }

    // 2. Repeated Struggle (Low accuracy across last 3 sessions)
    if (sessions.length >= 3) {
      int consecutiveLowAccuracy = 0;
      for (int i = 0; i < 3; i++) {
        if ((sessions[i]['accuracyPercentage'] ?? 100) < 50) {
          consecutiveLowAccuracy++;
        }
      }

      if (consecutiveLowAccuracy >= 3) {
        alerts.add(SmartAlert(
          title: '$patientTitle needs attention',
          message: '$name had lower accuracy across the last 3 activities and needs attention.',
          severity: 'critical',
          timestamp: lastSessionTime,
          patientId: patientId,
        ));

        // Trigger Critical Notification (Throttle to once per hour & respect caregiver settings)
        bool criticalAlertsEnabled = true;
        try {
          criticalAlertsEnabled = HiveService().getSetting<bool>('notif_critical_alerts', true);
        } catch (_) {}

        if (criticalAlertsEnabled &&
            (_lastCriticalNotificationTime == null ||
                DateTime.now().difference(_lastCriticalNotificationTime!).inHours >= 1)) {
          await _sendNotification(
            id: patientId.hashCode,
            title: '$patientTitle needs attention',
            body: '$name had lower accuracy across the last 3 activities.',
          );
          _lastCriticalNotificationTime = DateTime.now();
        }
      }
    }

    // 3. Unusual Decline (Significant drop in score between last two sessions of same game)
    if (sessions.length >= 2) {
      final latest = sessions[0];
      // find previous session of same game
      final previous = sessions.skip(1).firstWhere(
            (s) => s['gameId'] == latest['gameId'],
            orElse: () => {},
          );

      if (previous.isNotEmpty) {
        int latestScore = latest['score'] ?? 0;
        int previousScore = previous['score'] ?? 0;

        if (previousScore - latestScore > 30) {
          final gameTitle = _formatGameTitle(latest['gameId'], latest['gameCategory']);
          alerts.add(SmartAlert(
            title: 'Unusual Performance Change: $name',
            message: '$name had a low score in $gameTitle.',
            severity: 'warning',
            timestamp: lastSessionTime,
            patientId: patientId,
          ));
        }
      }
    }

    return alerts;
  }
}
