import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/core/services/smart_alerts_service.dart';
import 'package:neuroverse_app/features/caregiver/overview/caregiver_main_screen.dart';

class FakeHiveService extends HiveService {
  final Map<String, dynamic> _profile = {};

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    _profile.addAll(profileData);
  }

  @override
  Map<String, dynamic>? getUserProfile() {
    return _profile.isEmpty ? null : _profile;
  }
}

void main() {
  Widget createTestWidget({
    required Widget child,
    AppProvider? appProvider,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    final provider = appProvider ?? AppProvider();
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: provider),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: child,
      ),
    );
  }

  final testAlerts = [
    SmartAlert(
      title: 'Sudden Score Drop Detected',
      message: 'Significant decline observed in Focus Finder cognitive reaction speed.',
      severity: 'critical',
      timestamp: DateTime(2026, 9, 5, 14, 30),
      patientId: 'patient_001',
    ),
    SmartAlert(
      title: 'Extended Inactivity',
      message: 'No exercises completed in the past 48 hours for Memory Match.',
      severity: 'warning',
      timestamp: DateTime(2026, 9, 4, 10, 15),
      patientId: 'patient_002',
    ),
    SmartAlert(
      title: 'Baseline Update',
      message: 'Patient profile calibrated with new baseline parameters.',
      severity: 'info',
      timestamp: DateTime(2026, 9, 3, 9, 0),
      patientId: 'patient_001',
    ),
  ];

  group('Caregiver Alerts UI Redesign Tests', () {
    testWidgets('Renders redesigned header banner with Smart Alerts title and Live indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: testAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Smart Alerts'), findsWidgets);
      expect(find.text('Cognitive monitoring & telemetry updates'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);
    });

    testWidgets('Renders all alert cards with exact title, message, timestamp, and severity badges', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: testAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Critical Alert
      expect(find.text('Sudden Score Drop Detected'), findsOneWidget);
      expect(find.text('Significant decline observed in Focus Finder cognitive reaction speed.'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('5/9/2026'), findsOneWidget);

      // Check Warning Alert
      expect(find.text('Extended Inactivity'), findsOneWidget);
      expect(find.text('No exercises completed in the past 48 hours for Memory Match.'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('4/9/2026'), findsOneWidget);

      // Check Info Alert
      expect(find.text('Baseline Update'), findsOneWidget);
      expect(find.text('Patient profile calibrated with new baseline parameters.'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
      expect(find.text('3/9/2026'), findsOneWidget);
    });

    testWidgets('Renders empty state when there are no linked patients', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CaregiverMainScreen(
            initialTabIndex: 2,
            initialPatients: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No linked patients for alert monitoring.'), findsOneWidget);
      expect(find.text('Smart Alerts'), findsWidgets);
      expect(find.byIcon(Icons.notifications_none_rounded), findsWidgets);
    });

    testWidgets('Renders all-clear empty state when alerts list is empty', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('All patients are performing stably! No active alerts.'), findsOneWidget);
      expect(find.text('Smart Alerts'), findsWidgets);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('Renders correctly in dark mode', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          themeMode: ThemeMode.dark,
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: testAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Smart Alerts'), findsWidgets);
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
      expect(find.text('INFO'), findsOneWidget);
    });

    testWidgets('Responsive across small and large phone sizes with no overflow', (tester) async {
      // Small screen: 320x640
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        createTestWidget(
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: testAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smart Alerts'), findsWidgets);

      // Large screen: 412x915
      tester.view.physicalSize = const Size(412, 915);
      await tester.pumpWidget(
        createTestWidget(
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: testAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smart Alerts'), findsWidgets);
    });

    testWidgets('Renders poor-performance alerts with patient name (Patient Aditi needs attention, Aditi had a low score in Memory Match.)', (tester) async {
      final poorPerformanceAlerts = [
        SmartAlert(
          title: 'Patient Aditi needs attention',
          message: 'Aditi had lower accuracy across the last 3 activities and needs attention.',
          severity: 'critical',
          timestamp: DateTime(2026, 9, 6, 15, 0),
          patientId: 'patient_aditi',
        ),
        SmartAlert(
          title: 'Unusual Performance Change: Aditi',
          message: 'Aditi had a low score in Memory Match.',
          severity: 'warning',
          timestamp: DateTime(2026, 9, 6, 14, 30),
          patientId: 'patient_aditi',
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          child: CaregiverMainScreen(
            initialTabIndex: 2,
            mockAlerts: poorPerformanceAlerts,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Patient Aditi needs attention'), findsOneWidget);
      expect(find.text('Aditi had lower accuracy across the last 3 activities and needs attention.'), findsOneWidget);
      expect(find.text('CRITICAL'), findsOneWidget);

      expect(find.text('Unusual Performance Change: Aditi'), findsOneWidget);
      expect(find.text('Aditi had a low score in Memory Match.'), findsOneWidget);
      expect(find.text('WARNING'), findsOneWidget);
    });
  });
}
