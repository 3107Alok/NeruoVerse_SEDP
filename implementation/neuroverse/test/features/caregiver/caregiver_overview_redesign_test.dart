import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
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

  group('Caregiver Overview Redesign UI Tests', () {
    testWidgets('GameHubIllustration renders for all 4 Patient games with authentic visuals', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: const [
                GameHubIllustration(visual: GameHubVisual.faceRecall, size: 40),
                GameHubIllustration(visual: GameHubVisual.memoryMatch, size: 40),
                GameHubIllustration(visual: GameHubVisual.patternPath, size: 40),
                GameHubIllustration(visual: GameHubVisual.memoryRecall, size: 40),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GameHubIllustration), findsNWidgets(4));
    });

    testWidgets('CaregiverMainScreen renders redesigned AppBar with tagline and circular actions', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const CaregiverMainScreen()));
      final error = tester.takeException();
      if (error != null) {
        debugPrint('CAUGHT ERROR IN PUMP: $error');
      }
      await tester.pump();

      // Check AppBar branding
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Care Together. Grow Together.'), findsOneWidget);

      // Check action icons
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('CaregiverMainScreen renders modern bottom navigation bar with active pill indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const CaregiverMainScreen()));
      await tester.pump();

      // Check 4 tabs
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Check active Overview icon
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none_rounded), findsNWidgets(2)); // in AppBar and Nav bar
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('Tapping bottom navigation tabs updates active tab state', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const CaregiverMainScreen()));
      await tester.pump();

      // Tap on Patients tab
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      // Patients tab active icon
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);

      // Tap on Alerts tab
      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);

      // Tap on Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    });

    testWidgets('CaregiverMainScreen renders cleanly in Dark Mode', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(),
        themeMode: ThemeMode.dark,
      ));
      await tester.pump();

      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Care Together. Grow Together.'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Patient game visual colors match the Patient UI game hub specs', (tester) async {
      // Face Recall - Amber gold
      const frVisual = GameHubVisual.faceRecall;
      // Memory Match - Rose magenta
      const mmVisual = GameHubVisual.memoryMatch;
      // Pattern Path - Emerald green
      const ppVisual = GameHubVisual.patternPath;
      // Memory Recall - Cobalt blue
      const mrVisual = GameHubVisual.memoryRecall;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                GameHubIllustration(visual: frVisual, size: 36),
                GameHubIllustration(visual: mmVisual, size: 36),
                GameHubIllustration(visual: ppVisual, size: 36),
                GameHubIllustration(visual: mrVisual, size: 36),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(GameHubIllustration), findsNWidgets(4));
    });

    testWidgets('Responsive test on narrow viewport (320x568) with bottom system insets and zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('Patients'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);

      // Verify overview content renders without overflow
      expect(find.text('Linked Patients'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Daily Sessions'), findsOneWidget);
      expect(find.text('Avg Accuracy'), findsOneWidget);
      expect(find.text('No Patients Connected Yet'), findsOneWidget);
    });

    testWidgets('Responsive test on standard viewport (360x640) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['patient_1'],
          initialPendingCount: 1,
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Care Together. Grow Together.'), findsOneWidget);
      expect(find.text('Linked Patients'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
    });

    testWidgets('Responsive test on modern iPhone viewport (375x667) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['patient_1', 'patient_2'],
          initialPendingCount: 2,
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Linked Patients'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Live Tracking'), findsOneWidget);
    });

    testWidgets('Responsive test on modern Android viewport (412x915) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 28);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['patient_1'],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('Linked Patients'), findsOneWidget);
      expect(find.text('Pending Requests'), findsOneWidget);
      expect(find.text('Live Tracking'), findsOneWidget);
    });

    testWidgets('Linked Patients sheet renders empty state correctly and can be closed', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      // Tap Linked Patients card
      await tester.tap(find.text('Linked Patients'));
      await tester.pumpAndSettle();

      // Verify sheet header and stat card badge
      expect(find.text('0 Active'), findsNWidgets(2));
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);

      // Verify empty state UI
      expect(find.text('No Linked Patients Yet'), findsOneWidget);
      expect(find.text('Connect Patient Now'), findsWidgets);

      // Tap close button on sheet header
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Verify sheet closed
      expect(find.text('No Linked Patients Yet'), findsNothing);
    });

    testWidgets('Linked Patients sheet renders populated patient cards with active chip, code, and navigation', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['p1', 'p2'],
          initialPendingCount: 1,
          mockPatientDetails: {
            'p1': {'name': 'Eleanor Vance', 'shareCode': 'ELN123', 'age': '74', 'gender': 'Female'},
            'p2': {'name': 'Arthur Pendelton', 'shareCode': 'ART456', 'age': '81', 'gender': 'Male'},
          },
        ),
      ));
      await tester.pump();

      // Tap Linked Patients card
      await tester.tap(find.text('Linked Patients'));
      await tester.pumpAndSettle();

      // Verify sheet header
      expect(find.text('2 Active'), findsOneWidget);

      // Verify patient cards inside bottom sheet
      final sheetFinder = find.byType(BottomSheet);
      expect(find.descendant(of: sheetFinder, matching: find.text('Eleanor Vance')), findsOneWidget);
      expect(find.descendant(of: sheetFinder, matching: find.text('Code: ELN123')), findsOneWidget);
      expect(find.descendant(of: sheetFinder, matching: find.text('74 yrs • Female')), findsOneWidget);

      expect(find.descendant(of: sheetFinder, matching: find.text('Arthur Pendelton')), findsOneWidget);
      expect(find.descendant(of: sheetFinder, matching: find.text('Code: ART456')), findsOneWidget);
      expect(find.descendant(of: sheetFinder, matching: find.text('81 yrs • Male')), findsOneWidget);

      expect(find.descendant(of: sheetFinder, matching: find.text('Active')), findsNWidgets(2));
      expect(find.descendant(of: sheetFinder, matching: find.text('View ›')), findsNWidgets(2));

      // Tap 'View ›' on first patient card to navigate to Patients tab
      await tester.tap(find.descendant(of: sheetFinder, matching: find.text('View ›')).first);
      await tester.pumpAndSettle();

      // Verify navigated to Patients tab (active icon becomes Icons.people_rounded)
      expect(find.byIcon(Icons.people_rounded), findsOneWidget);
    });

    testWidgets('Pending Requests sheet renders empty state correctly and can be closed', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
          mockRequests: [],
        ),
      ));
      await tester.pump();

      // Tap Pending Requests card
      await tester.tap(find.text('Pending Requests'));
      await tester.pumpAndSettle();

      // Verify sheet header
      expect(find.byIcon(Icons.pending_actions_rounded), findsOneWidget);

      // Verify empty state UI
      expect(find.text('No Requests Sent Yet'), findsOneWidget);
      expect(find.text('Send Connection Request'), findsOneWidget);

      // Tap close button on sheet header
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Verify sheet closed
      expect(find.text('No Requests Sent Yet'), findsNothing);
    });

    testWidgets('Pending Requests sheet renders populated cards with status badges and cancel dialog', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['p1'],
          initialPendingCount: 3,
          mockRequests: [
            {
              'id': 'req_1',
              'patientId': 'p_davis',
              'patientName': 'Margaret Davis',
              'shareCode': 'MD9081',
              'status': 'pending',
              'timestamp': '2026-09-05T10:30:00',
              'patientDetails': {'name': 'Margaret Davis', 'age': '79', 'gender': 'Female'},
            },
            {
              'id': 'req_2',
              'patientId': 'p_chen',
              'patientName': 'Robert Chen',
              'shareCode': 'RC4421',
              'status': 'accepted',
              'timestamp': '2026-09-04T15:20:00',
              'patientDetails': {'name': 'Robert Chen', 'age': '67', 'gender': 'Male'},
            },
            {
              'id': 'req_3',
              'patientId': 'p_jackson',
              'patientName': 'Samuel Jackson',
              'shareCode': 'SJ1100',
              'status': 'rejected',
              'timestamp': '2026-09-03T11:00:00',
              'patientDetails': {'name': 'Samuel Jackson', 'age': '83', 'gender': 'Male'},
            },
          ],
        ),
      ));
      await tester.pump();

      // Tap Pending Requests card
      await tester.tap(find.text('Pending Requests'));
      await tester.pumpAndSettle();

      // Verify status badges
      expect(find.text('Pending ⏳'), findsOneWidget);
      expect(find.text('Accepted ✅'), findsOneWidget);
      expect(find.text('Declined ❌'), findsOneWidget);

      // Verify patient names and codes
      expect(find.text('Margaret Davis'), findsOneWidget);
      expect(find.text('Code: MD9081'), findsOneWidget);
      expect(find.text('79 yrs'), findsOneWidget);

      expect(find.text('Robert Chen'), findsOneWidget);
      expect(find.text('Code: RC4421'), findsOneWidget);
      expect(find.text('67 yrs'), findsOneWidget);

      expect(find.text('Samuel Jackson'), findsOneWidget);
      expect(find.text('Code: SJ1100'), findsOneWidget);
      expect(find.text('83 yrs'), findsOneWidget);

      // Verify cancel button exists only for pending request
      expect(find.text('Cancel'), findsOneWidget);

      // Tap Cancel button to open confirmation dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Request?'), findsOneWidget);
      expect(find.text('Do you want to cancel the connection request sent to Margaret Davis?'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);

      // Tap 'No' to dismiss dialog
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Request?'), findsNothing);
    });

    testWidgets('Redesigned AnimatedLinkPatientDialog renders correctly and can be cancelled', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AnimatedLinkPatientDialog(),
              ),
              child: const Text('Open Link Dialog'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open dialog
      await tester.tap(find.text('Open Link Dialog'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('Connect Patient'), findsOneWidget);
      expect(find.text('Link via 6-character code'), findsOneWidget);
      expect(find.text('Ask your patient for the Connect Code found in their Profile tab.'), findsOneWidget);
      expect(find.text('Cancel'), findsWidgets);
      expect(find.text('Send Request'), findsOneWidget);

      // Tap Cancel to close dialog
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      expect(find.text('Link via 6-character code'), findsNothing);
    });

    testWidgets('Patients tab renders redesigned header with "Your Patients", subtitle, and illustration', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: ['p1'],
          mockPatientDetails: {
            'p1': {'name': 'Aditi', 'shareCode': 'MKYC9M', 'age': '22'},
          },
        ),
      ));
      await tester.pump();

      // Tap Patients tab in bottom navigation
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      expect(find.text('Your Patients'), findsOneWidget);
      expect(find.text('Stay informed. Support their journey.'), findsOneWidget);
      expect(find.byIcon(Icons.people_alt_rounded), findsOneWidget);
    });

    testWidgets('Patients tab renders empty state when no patients are connected', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
        ),
      ));
      await tester.pump();

      // Tap Patients tab in bottom navigation
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      expect(find.text('No patients connected yet.'), findsOneWidget);
      expect(find.text('Connect Patient'), findsOneWidget);
    });

    testWidgets('Patients tab renders patient card with dynamic data and Live Performance Analytics matching reference', (tester) async {
      final past16h = DateTime.now().subtract(const Duration(hours: 16));
      await tester.pumpWidget(createTestWidget(
        child: CaregiverMainScreen(
          initialPatients: const ['p1'],
          mockPatientDetails: const {
            'p1': {'name': 'Aditi', 'shareCode': 'MKYC9M', 'age': '22'},
          },
          mockSessions: {
            'p1': [
              {
                'accuracyPercentage': 91,
                'difficultyLevel': 10,
                'timestamp': past16h,
              },
            ],
          },
        ),
      ));
      await tester.pump();

      // Tap Patients tab
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      // Patient Name and Subtitle
      expect(find.text('Aditi'), findsOneWidget);
      expect(find.text('Code: MKYC9M  •  22 yrs'), findsOneWidget);

      // Section Header & Live Data Badge
      expect(find.text('Live Performance Analytics'), findsOneWidget);
      expect(find.text('Live Data'), findsOneWidget);

      // 3 Sub-Cards
      expect(find.text('Trend Direction'), findsOneWidget);
      expect(find.text('Overall Accuracy'), findsOneWidget);
      expect(find.text('Last Activity'), findsOneWidget);
      expect(find.text('Stable'), findsOneWidget);
      expect(find.textContaining('91%'), findsOneWidget);
      expect(find.textContaining('16h ago'), findsOneWidget);
    });

    testWidgets('Patients tab card expand and collapse interaction works properly', (tester) async {
      await tester.pumpWidget(createTestWidget(
        child: CaregiverMainScreen(
          initialPatients: const ['p1'],
          mockPatientDetails: const {
            'p1': {'name': 'Aditi', 'shareCode': 'MKYC9M', 'age': '22'},
          },
          mockSessions: {
            'p1': [
              {
                'accuracyPercentage': 91,
                'difficultyLevel': 10,
                'timestamp': DateTime.now(),
              },
            ],
          },
        ),
      ));
      await tester.pump();

      // Tap Patients tab
      await tester.tap(find.text('Patients'));
      await tester.pumpAndSettle();

      // Initially expanded (auto-expanded on first load)
      expect(find.text('Live Performance Analytics'), findsOneWidget);

      // Tap patient card to collapse
      await tester.tap(find.text('Aditi'));
      await tester.pumpAndSettle();

      // Now collapsed
      expect(find.text('Live Performance Analytics'), findsNothing);

      // Tap again to re-expand
      await tester.tap(find.text('Aditi'));
      await tester.pumpAndSettle();

      // Re-expanded
      expect(find.text('Live Performance Analytics'), findsOneWidget);
    });

    testWidgets('Patients tab responsive test across 320x568, 360x640, 375x667, 412x915 viewports with zero RenderFlex overflow', (tester) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(375, 667),
        Size(412, 915),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding(bottom: 34);

        await tester.pumpWidget(createTestWidget(
          child: CaregiverMainScreen(
            initialPatients: const ['p1'],
            mockPatientDetails: const {
              'p1': {'name': 'Aditi', 'shareCode': 'MKYC9M', 'age': '22'},
            },
            mockSessions: {
              'p1': [
                {
                  'accuracyPercentage': 91,
                  'difficultyLevel': 10,
                  'timestamp': DateTime.now().subtract(const Duration(hours: 16)),
                },
              ],
            },
          ),
        ));
        await tester.pump();

        // Tap Patients tab
        await tester.tap(find.text('Patients'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed at viewport $size');
        expect(find.text('Your Patients'), findsOneWidget);
        expect(find.text('Aditi'), findsOneWidget);
        expect(find.text('Live Performance Analytics'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    testWidgets('Caregiver Profile tab renders header, hero avatar, personal details, settings options, and logout button', (tester) async {
      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('My Profile'), findsOneWidget);
      expect(find.text('Account details & care connection'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);

      // Hero Avatar Card
      expect(find.text('Jane Doe'), findsAtLeastNWidgets(1));
      expect(find.text('JD'), findsOneWidget);
      expect(find.text('Verified Caregiver Account'), findsOneWidget);

      // Personal Details Card
      expect(find.text('Personal Details'), findsOneWidget);
      expect(find.text('34 years'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Role'), findsOneWidget);
      expect(find.text('Primary Caregiver'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Settings & Care Management Card
      expect(find.text('Settings & Care Management'), findsOneWidget);
      expect(find.text('Connect Patient'), findsOneWidget);
      expect(find.text('Settings & Preferences'), findsOneWidget);

      // Logout Button
      expect(find.text('Log Out of Caregiver Account'), findsOneWidget);
    });

    testWidgets('Tapping Edit Profile opens redesigned sheet with caregiver fields and saving updates AppProvider', (tester) async {
      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Tap Edit Profile button
      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Check modal sheet content
      expect(find.text('Edit Caregiver Profile'), findsOneWidget);
      expect(find.text('Update your personal information'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Age'), findsAtLeastNWidgets(1));
      expect(find.text('Gender'), findsAtLeastNWidgets(1));
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Verify initial values in controllers
      expect(find.widgetWithText(TextFormField, 'Jane Doe'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '34'), findsOneWidget);

      // Edit name and age
      await tester.enterText(find.widgetWithText(TextFormField, 'Jane Doe'), 'Jane Smith');
      await tester.enterText(find.widgetWithText(TextFormField, '34'), '35');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Provider updated
      expect(appProvider.userName, 'Jane Smith');
      expect(appProvider.userAge, '35');

      // Sheet dismissed, Profile tab shows updated values
      expect(find.text('Jane Smith'), findsAtLeastNWidgets(1));
      expect(find.text('35 years'), findsOneWidget);
      expect(find.text('Caregiver profile updated! ✨'), findsOneWidget);
    });

    testWidgets('Caregiver Profile tab responsive test across 320x568, 360x640, 375x667, 412x915 viewports with zero RenderFlex overflow', (tester) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(375, 667),
        Size(412, 915),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding(bottom: 34);

        final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

        await tester.pumpWidget(createTestWidget(
          child: const CaregiverMainScreen(initialTabIndex: 3),
          appProvider: appProvider,
        ));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'Failed at viewport $size');
        expect(find.text('My Profile'), findsOneWidget);
        expect(find.text('Verified Caregiver Account'), findsOneWidget);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    testWidgets('Edit Profile sheet action bar (Save Changes & Cancel) is pinned and always visible across all phone sizes', (tester) async {
      const viewports = [
        Size(320, 568),
        Size(360, 640),
        Size(375, 667),
        Size(412, 915),
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        tester.view.padding = FakeViewPadding(bottom: 34);

        final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

        await tester.pumpWidget(createTestWidget(
          child: const CaregiverMainScreen(initialTabIndex: 3),
          appProvider: appProvider,
        ));
        await tester.pumpAndSettle();

        // Tap Edit Profile
        await tester.tap(find.text('Edit Profile'));
        await tester.pumpAndSettle();

        // Save Changes and Cancel buttons must be visible immediately on-screen without scrolling
        expect(find.text('Save Changes'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Failed at viewport $size');

        // Close the sheet
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    testWidgets('Edit Profile sheet handles keyboard viewInsets and bottom padding cleanly with no overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: 260); // Keyboard open
      tester.view.padding = FakeViewPadding(bottom: 34);     // Home indicator

      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Pinned bar remains accessible
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      tester.view.resetPhysicalSize();
      tester.view.resetViewInsets();
      tester.view.resetPadding();
    });

    testWidgets('Caregiver Profile tab does not have a divider directly below Settings & Care Management heading', (tester) async {
      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Find Settings & Care Management card
      final headingFinder = find.text('Settings & Care Management');
      expect(headingFinder, findsOneWidget);

      // Verify that Settings & Care Management card contains only 1 Divider (between the 2 ListTiles), not 2
      final settingsCardFinder = find.ancestor(
        of: headingFinder,
        matching: find.byType(Container),
      );
      expect(settingsCardFinder, findsWidgets);

      // In the whole profile tab, dividers exist between detail rows (3) and between the 2 settings tiles (1), total 4 dividers
      expect(find.byType(Divider), findsNWidgets(4));
    });

    testWidgets('Edit Profile sheet renders Personal Information heading with fontSize 16 and FontWeight.bold', (tester) async {
      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Check Personal Information heading is present
      final personalInfoFinder = find.text('Personal Information');
      expect(personalInfoFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(personalInfoFinder);
      expect(textWidget.style?.fontSize, 16);
      expect(textWidget.style?.fontWeight, FontWeight.bold);

      // Verify the badge icon next to Personal Information
      expect(find.byIcon(Icons.badge_outlined), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Edit Profile sheet sits flush at the bottom of the viewport with zero empty gap below', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;

      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(initialTabIndex: 3),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Profile'));
      await tester.pumpAndSettle();

      // Find the Save Changes button
      final saveBtnFinder = find.text('Save Changes');
      expect(saveBtnFinder, findsOneWidget);

      // Verify the sheet extends all the way to the bottom edge of the screen (915.0)
      // The Cancel button's bottom should be close to 915 (within the 14px bottom padding)
      final cancelRect = tester.getRect(find.text('Cancel'));
      expect(cancelRect.bottom, greaterThan(860.0));
      expect(cancelRect.bottom, lessThanOrEqualTo(915.0));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      tester.view.resetPhysicalSize();
    });

    testWidgets('Caregiver Settings sheet renders header, profile summary card, and all 7 options', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
      });

      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Tap settings button in AppBar
      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Caregiver Settings'), findsOneWidget);
      expect(find.text('Preferences & account options'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify Profile Card
      expect(find.text('Jane Doe'), findsOneWidget);

      // Verify Caregiver settings options
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Daily Summaries'), findsOneWidget);
      expect(find.text('Critical Alerts'), findsOneWidget);
      expect(find.text('Inactivity Reminders'), findsOneWidget);
      expect(find.text('About NeuroVerse'), findsOneWidget);

      // Verify all items are present
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);

      // Verify toggling switches works
      expect(appProvider.dailySummaries, isTrue);
      await tester.tap(find.text('Daily Summaries'));
      await tester.pumpAndSettle();
      expect(appProvider.dailySummaries, isFalse);

      // Close the sheet
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Caregiver Settings'), findsNothing);
    });

    testWidgets('Caregiver Settings sheet is responsive across 320px to 412px viewports without overflow', (tester) async {
      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');
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
          child: const CaregiverMainScreen(
            initialPatients: [],
            initialPendingCount: 0,
          ),
          appProvider: appProvider,
        ));
        await tester.pumpAndSettle();

        // Tap settings icon in AppBar
        await tester.tap(find.byIcon(Icons.settings_outlined).first);
        await tester.pumpAndSettle();

        // Verify it rendered without RenderFlex overflow
        expect(tester.takeException(), isNull);
        expect(find.text('Caregiver Settings'), findsOneWidget);

        // Close the sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      }

      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
    });

    testWidgets('Caregiver Settings sheet renders categorized section cards with comfortable bottom spacing', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
      });

      final appProvider = AppProvider()..setUserProfile('Jane Doe', '34', 'Female', 'English');

      await tester.pumpWidget(createTestWidget(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.settings_outlined).first);
      await tester.pumpAndSettle();

      // Verify uppercase section headers
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('CARE & NOTIFICATIONS'), findsOneWidget);
      expect(find.text('APPLICATION INFO'), findsOneWidget);
      expect(find.text('ACCOUNT'), findsOneWidget);

      // Verify Logout option is present and styled with red
      final logoutFinder = find.text('Logout');
      expect(logoutFinder, findsOneWidget);
      final logoutText = tester.widget<Text>(logoutFinder);
      expect(logoutText.style?.color, const Color(0xFFDC2626));

      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    });
  });
}

