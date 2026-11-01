import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/services/smart_alerts_service.dart';

void main() {
  setUp(() {
    SmartAlertsService.resetThrottlingForTesting();
  });

  group('SmartAlertsService Poor-Performance Caregiver Alerts', () {
    test('Repeated struggle creates critical alert and notification with patient name (Aditi)', () async {
      final capturedNotifications = <Map<String, dynamic>>[];

      final service = SmartAlertsService(
        notifyHandler: ({required int id, required String title, required String body, String? payload}) async {
          capturedNotifications.add({
            'id': id,
            'title': title,
            'body': body,
          });
        },
      );

      final mockSessions = [
        {
          'gameId': 'memory_match',
          'gameCategory': 'Memory & Recognition',
          'accuracyPercentage': 40,
          'score': 40,
          'timestamp': DateTime.now(),
        },
        {
          'gameId': 'memory_match',
          'gameCategory': 'Memory & Recognition',
          'accuracyPercentage': 35,
          'score': 35,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
        {
          'gameId': 'memory_match',
          'gameCategory': 'Memory & Recognition',
          'accuracyPercentage': 45,
          'score': 45,
          'timestamp': DateTime.now().subtract(const Duration(hours: 4)),
        },
      ];

      final alerts = await service.generateAlertsForPatient(
        'patient_aditi_123',
        patientName: 'Aditi',
        mockSessions: mockSessions,
      );

      // Verify Critical SmartAlert
      final criticalAlerts = alerts.where((a) => a.severity == 'critical').toList();
      expect(criticalAlerts.length, 1);
      final alert = criticalAlerts.first;
      expect(alert.title, 'Patient Aditi needs attention');
      expect(alert.message, 'Aditi had lower accuracy across the last 3 activities and needs attention.');
      expect(alert.patientId, 'patient_aditi_123');

      // Verify Notification delivered to caregiver
      expect(capturedNotifications.length, 1);
      expect(capturedNotifications.first['title'], 'Patient Aditi needs attention');
      expect(capturedNotifications.first['body'], 'Aditi had lower accuracy across the last 3 activities.');
      expect(capturedNotifications.first['id'], 'patient_aditi_123'.hashCode);
    });

    test('Unusual performance drop creates warning alert with patient name and game title (Aditi - Memory Match)', () async {
      final service = SmartAlertsService();

      final mockSessions = [
        {
          'gameId': 'memory_match',
          'gameCategory': 'Memory & Recognition',
          'score': 50,
          'accuracyPercentage': 50,
          'timestamp': DateTime.now(),
        },
        {
          'gameId': 'memory_match',
          'gameCategory': 'Memory & Recognition',
          'score': 90,
          'accuracyPercentage': 90,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];

      final alerts = await service.generateAlertsForPatient(
        'patient_aditi_123',
        patientName: 'Aditi',
        mockSessions: mockSessions,
      );

      final warningAlerts = alerts.where((a) => a.severity == 'warning').toList();
      expect(warningAlerts.length, 1);
      final alert = warningAlerts.first;
      expect(alert.title, 'Unusual Performance Change: Aditi');
      expect(alert.message, 'Aditi had a low score in Memory Match.');
    });

    test('Works dynamically with other patient names and games (Rahul - Focus Finder)', () async {
      final capturedNotifications = <Map<String, dynamic>>[];

      final service = SmartAlertsService(
        notifyHandler: ({required int id, required String title, required String body, String? payload}) async {
          capturedNotifications.add({
            'title': title,
            'body': body,
          });
        },
      );

      final mockSessions = [
        {
          'gameId': 'face_recall',
          'gameCategory': 'Memory & Recognition',
          'score': 40,
          'accuracyPercentage': 30,
          'timestamp': DateTime.now(),
        },
        {
          'gameId': 'face_recall',
          'gameCategory': 'Memory & Recognition',
          'score': 85,
          'accuracyPercentage': 40,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
        {
          'gameId': 'face_recall',
          'gameCategory': 'Memory & Recognition',
          'score': 90,
          'accuracyPercentage': 35,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
      ];

      final alerts = await service.generateAlertsForPatient(
        'patient_rahul_456',
        patientName: 'Rahul',
        mockSessions: mockSessions,
      );

      // Both repeated struggle and score drop
      final criticalAlert = alerts.firstWhere((a) => a.severity == 'critical');
      expect(criticalAlert.title, 'Patient Rahul needs attention');
      expect(criticalAlert.message, 'Rahul had lower accuracy across the last 3 activities and needs attention.');

      final warningAlert = alerts.firstWhere((a) => a.severity == 'warning');
      expect(warningAlert.title, 'Unusual Performance Change: Rahul');
      expect(warningAlert.message, 'Rahul had a low score in Face Recall.');

      expect(capturedNotifications.length, 1);
      expect(capturedNotifications.first['title'], 'Patient Rahul needs attention');
      expect(capturedNotifications.first['body'], 'Rahul had lower accuracy across the last 3 activities.');
    });

    test('Patient name already prefixed with "Patient" is not duplicated ("Patient Maya")', () async {
      final service = SmartAlertsService();

      final mockSessions = [
        {
          'gameId': 'pattern_path',
          'gameCategory': 'Problem Solving',
          'accuracyPercentage': 20,
          'score': 20,
          'timestamp': DateTime.now(),
        },
        {
          'gameId': 'pattern_path',
          'gameCategory': 'Problem Solving',
          'accuracyPercentage': 25,
          'score': 25,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
        {
          'gameId': 'pattern_path',
          'gameCategory': 'Problem Solving',
          'accuracyPercentage': 30,
          'score': 30,
          'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        },
      ];

      final alerts = await service.generateAlertsForPatient(
        'patient_maya_789',
        patientName: 'Patient Maya',
        mockSessions: mockSessions,
      );

      final criticalAlert = alerts.firstWhere((a) => a.severity == 'critical');
      expect(criticalAlert.title, 'Patient Maya needs attention');
      expect(criticalAlert.message, 'Patient Maya had lower accuracy across the last 3 activities and needs attention.');
    });

    test('Gracefully falls back to "Patient" when no name is available', () async {
      final service = SmartAlertsService();

      final mockSessions = [
        {
          'gameId': 'memory_recall',
          'gameCategory': 'Memory Recall',
          'score': 20,
          'accuracyPercentage': 20,
          'timestamp': DateTime.now(),
        },
        {
          'gameId': 'memory_recall',
          'gameCategory': 'Memory Recall',
          'score': 80,
          'accuracyPercentage': 80,
          'timestamp': DateTime.now().subtract(const Duration(hours: 1)),
        },
      ];

      final alerts = await service.generateAlertsForPatient(
        'patient_unknown',
        patientName: null,
        mockSessions: mockSessions,
      );

      final warningAlert = alerts.firstWhere((a) => a.severity == 'warning');
      expect(warningAlert.title, 'Unusual Performance Change: Patient');
      expect(warningAlert.message, 'Patient had a low score in Memory Recall.');
    });

    test('Inactivity gap and empty sessions include patient name', () async {
      final service = SmartAlertsService();

      // Empty sessions
      final emptyAlerts = await service.generateAlertsForPatient(
        'patient_1',
        patientName: 'Anita',
        mockSessions: [],
      );
      expect(emptyAlerts.length, 1);
      expect(emptyAlerts.first.title, 'No Recent Activity: Anita');
      expect(emptyAlerts.first.message, 'Anita has not completed any activities recently.');

      // Inactivity gap (last session 5 days ago)
      final gapAlerts = await service.generateAlertsForPatient(
        'patient_1',
        patientName: 'Anita',
        mockSessions: [
          {
            'gameId': 'memory_match',
            'gameCategory': 'Memory & Recognition',
            'score': 80,
            'accuracyPercentage': 90,
            'timestamp': DateTime.now().subtract(const Duration(days: 5)),
          }
        ],
      );
      final gapAlert = gapAlerts.firstWhere((a) => a.title.contains('Activity Gap'));
      expect(gapAlert.title, 'Activity Gap: Anita');
      expect(gapAlert.message, contains('No sessions completed by Anita in the last'));
    });

    test('Notification throttling is preserved (does not duplicate within 1 hour)', () async {
      int notifyCount = 0;
      final service = SmartAlertsService(
        notifyHandler: ({required int id, required String title, required String body, String? payload}) async {
          notifyCount++;
        },
      );

      final lowSessions = [
        {'gameId': 'memory_match', 'accuracyPercentage': 30, 'score': 30, 'timestamp': DateTime.now()},
        {'gameId': 'memory_match', 'accuracyPercentage': 30, 'score': 30, 'timestamp': DateTime.now()},
        {'gameId': 'memory_match', 'accuracyPercentage': 30, 'score': 30, 'timestamp': DateTime.now()},
      ];

      // First run: fires notification
      await service.generateAlertsForPatient('p1', patientName: 'Aditi', mockSessions: lowSessions);
      expect(notifyCount, 1);

      // Second run immediately: throttled
      await service.generateAlertsForPatient('p1', patientName: 'Aditi', mockSessions: lowSessions);
      expect(notifyCount, 1);

      // Reset test throttling: fires again
      SmartAlertsService.resetThrottlingForTesting();
      await service.generateAlertsForPatient('p1', patientName: 'Aditi', mockSessions: lowSessions);
      expect(notifyCount, 2);
    });
  });
}
