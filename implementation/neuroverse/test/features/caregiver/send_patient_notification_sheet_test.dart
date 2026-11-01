import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
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
    List<String> patients = const ['patient_alpha', 'patient_beta'],
    ThemeMode themeMode = ThemeMode.light,
    AppProvider? appProvider,
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
        home: CaregiverMainScreen(
          initialPatients: patients,
          initialPendingCount: 0,
        ),
      ),
    );
  }

  Future<void> openNotificationSheet(
    WidgetTester tester, {
    List<String> patients = const ['patient_alpha', 'patient_beta'],
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await tester.pumpWidget(createTestWidget(patients: patients, themeMode: themeMode));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Scroll the main overview ListView to find the action card
    final actionCard = find.text('Send Patient Game Reminder');
    await tester.scrollUntilVisible(
      actionCard,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(actionCard, findsOneWidget);

    await tester.tap(actionCard);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  group('Send Patient Notification Bottom Sheet UI Tests', () {
    testWidgets('Opens sheet and renders modern header banner with close button', (tester) async {
      await openNotificationSheet(tester);

      expect(find.text('Send Patient Notification'), findsOneWidget);
      expect(find.text('Direct reminder to linked patients'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('Renders patient selection section with patient count, avatars, and Select All toggle', (tester) async {
      await openNotificationSheet(tester);

      expect(find.text('SELECT PATIENT(S)'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Deselect All'), findsOneWidget);

      // Check CheckboxListTile widgets are rendered for both patients
      expect(find.byType(CheckboxListTile), findsNWidgets(2));

      // Tap Deselect All
      await tester.tap(find.text('Deselect All'));
      await tester.pump();
      expect(find.text('Select All'), findsOneWidget);
      expect(find.text('0/2'), findsOneWidget);

      // Tap Select All
      await tester.tap(find.text('Select All'));
      await tester.pump();
      expect(find.text('Deselect All'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('Renders notification title preset dropdown and auto-fills message body', (tester) async {
      await openNotificationSheet(tester);

      expect(find.text('NOTIFICATION TITLE / PRESET'), findsOneWidget);
      expect(find.text('🎮 Time for Daily Brain Training!'), findsOneWidget);

      // Message body contains the default pre-filled text
      expect(find.textContaining('Please take 5 minutes to complete your daily brain exercises'), findsOneWidget);

      // Tap the dropdown to open presets
      await tester.tap(find.text('🎮 Time for Daily Brain Training!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify preset options are visible in the dropdown menu
      expect(find.text('🧠 Play Memory & Pattern Games').last, findsOneWidget);
      expect(find.text('⚡ Quick 5-Minute Brain Workout').last, findsOneWidget);
      expect(find.text('🧘 Mind Rest & Breathing Session').last, findsOneWidget);
      expect(find.text('✏️ Custom Reminder...').last, findsOneWidget);

      // Select '🧠 Play Memory & Pattern Games'
      await tester.tap(find.text('🧠 Play Memory & Pattern Games').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify message body updated
      expect(find.textContaining('Let\'s keep your memory sharp!'), findsOneWidget);
    });

    testWidgets('Reveals custom title text field when Custom Reminder is selected', (tester) async {
      await openNotificationSheet(tester);

      // Open dropdown and select Custom Reminder
      await tester.tap(find.text('🎮 Time for Daily Brain Training!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('✏️ Custom Reminder...').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify custom title input is rendered
      expect(find.widgetWithText(TextField, 'Enter custom reminder title...'), findsOneWidget);
    });

    testWidgets('Renders High Priority Notification card with toggle switch', (tester) async {
      await openNotificationSheet(tester);

      expect(find.text('High Priority Notification'), findsOneWidget);
      expect(find.text('Delivers immediate heads-up alert to patient device'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Toggle switch
      await tester.tap(switchFinder);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders Send Notification button with dynamic patient count', (tester) async {
      await openNotificationSheet(tester);

      // Deselect all while patient section is in view
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      // Scroll sheet body down
      await tester.drag(find.text('NOTIFICATION TITLE / PRESET'), const Offset(0, -150));
      await tester.pump();

      expect(find.text('Send Notification (0)'), findsOneWidget);

      // Scroll back up and Select All
      await tester.drag(find.text('High Priority Notification'), const Offset(0, 150));
      await tester.pump();

      await tester.tap(find.text('Select All'));
      await tester.pump();

      // Scroll down to verify updated count
      await tester.drag(find.text('NOTIFICATION TITLE / PRESET'), const Offset(0, -150));
      await tester.pump();

      expect(find.text('Send Notification (2)'), findsOneWidget);
    });

    for (final size in [
      const Size(320, 640),
      const Size(360, 800),
      const Size(375, 812),
      const Size(412, 915),
    ]) {
      testWidgets('Responsive across ${size.width.toInt()}x${size.height.toInt()} viewport without overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await openNotificationSheet(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Send Patient Notification'), findsOneWidget);
      });
    }

    testWidgets('Renders cleanly in Dark Mode', (tester) async {
      await openNotificationSheet(tester, themeMode: ThemeMode.dark);

      expect(tester.takeException(), isNull);
      expect(find.text('Send Patient Notification'), findsOneWidget);
      expect(find.text('Send Notification (2)'), findsOneWidget);
    });

    testWidgets('Provides bottom safe area clearance with simulated system bottom navigation inset', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await openNotificationSheet(tester);

      // Scroll to the Send Notification button
      final sendBtnFinder = find.widgetWithText(ElevatedButton, 'Send Notification (2)');
      await tester.scrollUntilVisible(
        sendBtnFinder,
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      expect(sendBtnFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
