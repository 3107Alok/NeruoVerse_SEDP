import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/caregiver/overview/caregiver_main_screen.dart';

import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';

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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  Widget createTestWidget({
    List<String> patients = const ['patient_alpha', 'patient_beta'],
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: CaregiverMainScreen(
          initialPatients: patients,
          initialPendingCount: 0,
        ),
      ),
    );
  }

  Future<void> openNotificationSheet(WidgetTester tester) async {
    tester.view.physicalSize = const Size(450, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createTestWidget());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final actionCard = find.text('Send Patient Game Reminder');
    await tester.scrollUntilVisible(
      actionCard,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await tester.tap(actionCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('Caregiver Send Reminder Type Selector Tests', () {
    testWidgets(
      'Renders REMINDER TYPE selector with Daily Activities, Medicine, and Hydration',
      (tester) async {
        await openNotificationSheet(tester);

        expect(find.text('REMINDER TYPE'), findsOneWidget);
        expect(find.text('Daily Activities'), findsOneWidget);
        expect(find.text('Medicine 💊'), findsOneWidget);
        expect(find.text('Hydration 💧'), findsOneWidget);
      },
    );

    testWidgets(
      'Defaults to Daily Activities and renders preset titles and message body',
      (tester) async {
        await openNotificationSheet(tester);

        expect(find.text('NOTIFICATION TITLE / PRESET'), findsOneWidget);
        expect(find.text('MESSAGE BODY'), findsOneWidget);
        expect(find.text('High Priority Notification'), findsOneWidget);
        expect(find.text('Send Notification (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching to Medicine reveals medicine fields and updates CTA button',
      (tester) async {
        await openNotificationSheet(tester);

        // Tap Medicine tab
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Check medicine fields
        expect(find.text('MEDICINE NAME'), findsOneWidget);
        expect(find.text('DOSE / QUANTITY'), findsOneWidget);
        expect(find.text('MEAL TIMING'), findsOneWidget);
        expect(find.text('START DATE'), findsOneWidget);
        expect(find.text('REMINDER TIME'), findsOneWidget);
        expect(find.text('REPEAT GAP'), findsOneWidget);
        expect(find.text('END DATE'), findsOneWidget);

        // Verify swapped 2-column layout:
        // Row 1: Left: START DATE, Right: END DATE
        // Row 2: Left: REMINDER TIME, Right: REPEAT GAP
        final startDatePos = tester.getTopLeft(find.text('START DATE'));
        final endDatePos = tester.getTopLeft(find.text('END DATE'));
        final reminderTimePos = tester.getTopLeft(find.text('REMINDER TIME'));
        final repeatGapPos = tester.getTopLeft(find.text('REPEAT GAP'));

        expect(startDatePos.dx, lessThan(endDatePos.dx), reason: 'START DATE must be to the left of END DATE');
        expect((startDatePos.dy - endDatePos.dy).abs(), lessThan(5.0), reason: 'START DATE and END DATE must be in the same row');
        expect(reminderTimePos.dx, lessThan(repeatGapPos.dx), reason: 'REMINDER TIME must be to the left of REPEAT GAP');
        expect((reminderTimePos.dy - repeatGapPos.dy).abs(), lessThan(5.0), reason: 'REMINDER TIME and REPEAT GAP must be in the same row');
        expect(startDatePos.dy, lessThan(reminderTimePos.dy), reason: 'Row 1 (START DATE) must be above Row 2 (REMINDER TIME)');
        expect(endDatePos.dy, lessThan(repeatGapPos.dy), reason: 'Row 1 (END DATE) must be above Row 2 (REPEAT GAP)');

        // Button should update
        expect(find.text('Schedule Medicine (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching to Hydration reveals water quantity and hydration fields with matching column order',
      (tester) async {
        await openNotificationSheet(tester);

        // Tap Hydration tab
        await tester.tap(find.text('Hydration 💧'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Check hydration fields
        expect(find.text('WATER QUANTITY'), findsOneWidget);
        expect(find.text('START DATE'), findsOneWidget);
        expect(find.text('FIRST REMINDER TIME'), findsOneWidget);
        expect(find.text('REPEAT GAP'), findsOneWidget);
        expect(find.text('END DATE'), findsOneWidget);

        // Verify swapped 2-column layout for Hydration:
        // Row 1: Left: START DATE, Right: END DATE
        // Row 2: Left: FIRST REMINDER TIME, Right: REPEAT GAP
        final startDatePos = tester.getTopLeft(find.text('START DATE'));
        final endDatePos = tester.getTopLeft(find.text('END DATE'));
        final firstReminderTimePos = tester.getTopLeft(find.text('FIRST REMINDER TIME'));
        final repeatGapPos = tester.getTopLeft(find.text('REPEAT GAP'));

        expect(startDatePos.dx, lessThan(endDatePos.dx), reason: 'START DATE must be to the left of END DATE');
        expect((startDatePos.dy - endDatePos.dy).abs(), lessThan(5.0), reason: 'START DATE and END DATE must be in the same row');
        expect(firstReminderTimePos.dx, lessThan(repeatGapPos.dx), reason: 'FIRST REMINDER TIME must be to the left of REPEAT GAP');
        expect((firstReminderTimePos.dy - repeatGapPos.dy).abs(), lessThan(5.0), reason: 'FIRST REMINDER TIME and REPEAT GAP must be in the same row');
        expect(startDatePos.dy, lessThan(firstReminderTimePos.dy), reason: 'Row 1 (START DATE) must be above Row 2 (FIRST REMINDER TIME)');
        expect(endDatePos.dy, lessThan(repeatGapPos.dy), reason: 'Row 1 (END DATE) must be above Row 2 (REPEAT GAP)');

        // Button should update
        expect(find.text('Schedule Hydration (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'When Medicine tab is selected, it becomes a dropdown selector and CATEGORY section is absent',
      (tester) async {
        await openNotificationSheet(tester);

        // Tap Medicine tab
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // CATEGORY label must NOT exist anywhere
        expect(find.text('CATEGORY'), findsNothing);

        // DropdownButton is integrated directly into the Medicine tab
        expect(find.byType(DropdownButton<String>), findsOneWidget);

        // Tap the integrated Medicine dropdown in the top row
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Both options exist in dropdown menu
        expect(find.text('Doctor Appointment 🩺'), findsOneWidget);
        expect(find.text('Medicine 💊'), findsWidgets);
      },
    );

    testWidgets(
      'Selecting Doctor Appointment replaces medicine fields with appointment fields and updates button',
      (tester) async {
        await openNotificationSheet(tester);

        // Tap Medicine tab
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Open integrated dropdown and pick Doctor Appointment
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Doctor Appointment 🩺').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Medicine-specific fields should be gone
        expect(find.text('MEDICINE NAME'), findsNothing);
        expect(find.text('DOSE / QUANTITY'), findsNothing);
        expect(find.text('MEAL TIMING'), findsNothing);
        expect(find.text('REPEAT GAP'), findsNothing);

        // Doctor Appointment fields must be visible
        expect(find.text('DOCTOR NAME'), findsOneWidget);
        expect(find.text('HOSPITAL / CLINIC NAME'), findsOneWidget);
        expect(find.text('APPOINTMENT DATE'), findsOneWidget);
        expect(find.text('APPOINTMENT TIME'), findsOneWidget);
        expect(find.text('OPTIONAL NOTES / DETAILS'), findsOneWidget);

        // Button should update
        expect(find.text('Schedule Doctor Appointment (2)'), findsOneWidget);

        // Verify top-level 3 tabs row still has Daily Activities and Hydration
        expect(find.text('Daily Activities'), findsOneWidget);
        expect(find.text('Hydration 💧'), findsOneWidget);
      },
    );

    testWidgets(
      'Switching between Medicine and Doctor Appointment toggles fields cleanly',
      (tester) async {
        await openNotificationSheet(tester);

        // Tap Medicine tab
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Switch to Doctor Appointment via integrated dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Doctor Appointment 🩺').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('DOCTOR NAME'), findsOneWidget);
        expect(find.text('MEDICINE NAME'), findsNothing);

        // Switch back to Medicine
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Medicine 💊').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('MEDICINE NAME'), findsOneWidget);
        expect(find.text('DOCTOR NAME'), findsNothing);
        expect(find.text('Schedule Medicine (2)'), findsOneWidget);
      },
    );

    testWidgets(
      'Renders cleanly without overflow on narrow 320px viewport with Doctor Appointment',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await openNotificationSheet(tester);

        // Tap Medicine tab
        await tester.tap(find.text('Medicine 💊'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Switch to Doctor Appointment via integrated dropdown
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Doctor Appointment 🩺').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(tester.takeException(), isNull);
        expect(find.text('Schedule Doctor Appointment (2)'), findsOneWidget);
      },
    );
  });
}
