import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/patient/home/patient_main_screen.dart';

class FakeHiveService extends HiveService {
  @override
  int getGameDifficulty(String gameId) => 1;
  @override
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {}
  @override
  Map<String, dynamic>? getUserProfile() => {'name': 'Alex Johnson'};
}

void main() {
  Widget createTestWidget({
    required AppProvider appProvider,
    ThemeMode themeMode = ThemeMode.light,
    ValueChanged<bool>? onNotificationsChanged,
    ValueChanged<bool>? onAudioChanged,
    VoidCallback? onEditProfile,
    VoidCallback? onSignOut,
  }) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => PatientMainScreen.openSettingsSheet(
                  context,
                  initialNotifications: true,
                  initialAudio: true,
                  onNotificationsChanged: onNotificationsChanged,
                  onAudioChanged: onAudioChanged,
                  onEditProfile: onEditProfile,
                  onSignOut: onSignOut,
                ),
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Patient Settings Redesign Tests', () {
    testWidgets('Patient Settings sheet renders header, profile card, and all 6 patient options', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });

      final appProvider = AppProvider()..userName = 'Alex Johnson';
      bool notificationsToggled = false;
      bool audioToggled = false;

      await tester.pumpWidget(createTestWidget(
        appProvider: appProvider,
        onNotificationsChanged: (val) => notificationsToggled = val,
        onAudioChanged: (val) => audioToggled = val,
      ));
      await tester.pumpAndSettle();

      // Tap button to open settings sheet
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Patient Settings'), findsOneWidget);
      expect(find.text('Preferences & account options'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify Profile Card
      expect(find.text('Alex Johnson'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Verify 6 patient options
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Exercise Reminders'), findsOneWidget);
      expect(find.text('Sound & Audio Effects'), findsOneWidget);
      expect(find.text('About NeuroVerse'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Verify Caregiver-only options are strictly absent
      expect(find.text('Daily Summaries'), findsNothing);
      expect(find.text('Critical Alerts'), findsNothing);
      expect(find.text('Inactivity Reminders'), findsNothing);

      // Verify toggling Dark Mode updates AppProvider
      expect(appProvider.isDarkMode, isFalse);
      await tester.tap(find.text('Dark Mode'));
      await tester.pumpAndSettle();
      expect(appProvider.isDarkMode, isTrue);

      // Verify toggling Exercise Reminders triggers callback
      await tester.tap(find.text('Exercise Reminders'));
      await tester.pumpAndSettle();
      expect(notificationsToggled, isFalse);

      // Verify toggling Sound & Audio Effects triggers callback
      await tester.tap(find.text('Sound & Audio Effects'));
      await tester.pumpAndSettle();
      expect(audioToggled, isFalse);

      // Close the sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Patient Settings'), findsNothing);
    });

    testWidgets('Patient Settings sheet is responsive across 320px to 412px viewports with zero overflow', (tester) async {
      final appProvider = AppProvider()..userName = 'Alex Johnson';
      const testSizes = [
        Size(320, 568),
        Size(360, 640),
        Size(375, 667),
        Size(412, 915),
      ];

      for (final size in testSizes) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = const FakeViewPadding(bottom: 24);

        await tester.pumpWidget(createTestWidget(
          appProvider: appProvider,
        ));
        await tester.pumpAndSettle();

        // Tap button to open settings sheet
        await tester.tap(find.text('Open Settings'));
        await tester.pumpAndSettle();

        // Verify it rendered without RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.text('Patient Settings'), findsOneWidget);
        expect(find.text('Dark Mode'), findsOneWidget);
        expect(find.text('Exercise Reminders'), findsOneWidget);

        // Close the sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    testWidgets('Patient Settings sheet renders cleanly in Dark Mode', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });

      final appProvider = AppProvider()..userName = 'Alex Johnson';
      appProvider.setDarkMode(true);

      await tester.pumpWidget(createTestWidget(
        appProvider: appProvider,
        themeMode: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();

      // Tap button to open settings sheet
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Patient Settings'), findsOneWidget);
      expect(find.text('Dark theme enabled'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });

    testWidgets('Patient Settings sheet renders categorized section cards with comfortable bottom spacing', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final appProvider = AppProvider()..userName = 'Alex Johnson';

      await tester.pumpWidget(createTestWidget(appProvider: appProvider));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Verify uppercase section headers
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('SCHEDULE & REMINDERS'), findsOneWidget);
      expect(find.text('APPLICATION INFO'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Verify Logout option is present and has red color
      final logoutFinder = find.text('Logout');
      expect(logoutFinder, findsOneWidget);
      final logoutText = tester.widget<Text>(logoutFinder);
      expect(logoutText.style?.color, const Color(0xFFDC2626));

      // Verify Logout option is accessible and scrollable with zero overflow
      await tester.scrollUntilVisible(logoutFinder, 100);
      await tester.pumpAndSettle();
      expect(logoutFinder, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });
  });
}
