import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/profile/edit_profile_screen.dart';

class FakeHiveService extends HiveService {
  Map<String, dynamic>? savedProfile;

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    savedProfile = profile;
  }
}

void main() {
  Widget createTestWidget({
    required Widget child,
    required AppProvider appProvider,
    FakeHiveService? hiveService,
  }) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => hiveService ?? FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('EditProfileScreen UI & Responsiveness Tests', () {
    testWidgets('Renders Edit Profile page with initial values and Save button', (tester) async {
      final appProvider = AppProvider();
      appProvider.userName = 'Anita Sharma';
      appProvider.userAge = '68';
      appProvider.userGender = 'Female';
      appProvider.caretakerName = 'Rahul Sharma';

      await tester.pumpWidget(createTestWidget(
        child: const EditProfileScreen(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Check AppBar and Hero card
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Profile Settings'), findsOneWidget);
      expect(find.text('AS'), findsOneWidget); // Initials for Anita Sharma

      // Check Form inputs
      expect(find.text('Anita Sharma'), findsOneWidget);
      expect(find.text('68'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Check Action Button
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Shows validation errors when required fields are cleared', (tester) async {
      final appProvider = AppProvider();
      appProvider.userName = 'Test Name';
      appProvider.userAge = '70';

      await tester.pumpWidget(createTestWidget(
        child: const EditProfileScreen(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Clear name and age
      final nameFinder = find.widgetWithText(TextFormField, 'Test Name');
      await tester.enterText(nameFinder, '');

      final ageFinder = find.widgetWithText(TextFormField, '70');
      await tester.enterText(ageFinder, '');

      // Scroll to and tap Save Changes
      final saveBtnFinder = find.text('Save Changes');
      await tester.ensureVisible(saveBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Expect validation error messages
      expect(find.text('Please enter your name'), findsOneWidget);
      expect(find.text('Please enter age'), findsOneWidget);
    });

    testWidgets('Renders verified auto-synced tile when caregiver is linked', (tester) async {
      final appProvider = AppProvider();
      appProvider.userName = 'Grandpa Joe';
      appProvider.userAge = '75';

      await tester.pumpWidget(createTestWidget(
        child: const EditProfileScreen(
          linkedCaregiverName: 'Dr. Emily Watson',
        ),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Should render linked caregiver tile
      expect(find.text('Dr. Emily Watson'), findsOneWidget);
      expect(find.text('Auto-synced from linked caregiver account'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);

      // Caretaker textfield shouldn't be rendered
      expect(find.text('Caretaker Name (Optional)'), findsNothing);
    });

    testWidgets('Saving valid changes updates AppProvider and FakeHiveService', (tester) async {
      final appProvider = AppProvider();
      appProvider.userName = 'Old Name';
      appProvider.userAge = '65';
      final fakeHive = FakeHiveService();

      await tester.pumpWidget(createTestWidget(
        child: const EditProfileScreen(),
        appProvider: appProvider,
        hiveService: fakeHive,
      ));
      await tester.pumpAndSettle();

      // Enter new name and age
      final nameFinder = find.widgetWithText(TextFormField, 'Old Name');
      await tester.enterText(nameFinder, 'New Senior');

      final ageFinder = find.widgetWithText(TextFormField, '65');
      await tester.enterText(ageFinder, '69');

      // Scroll to and tap Save Changes
      final saveBtnFinder = find.text('Save Changes');
      await tester.ensureVisible(saveBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verify Provider was updated
      expect(appProvider.userName, 'New Senior');
      expect(appProvider.userAge, '69');
      expect(fakeHive.savedProfile?['name'], 'New Senior');
      expect(fakeHive.savedProfile?['age'], '69');
    });

    testWidgets('Responsive test: no RenderFlex overflow with 320px software keyboard', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
      });

      final appProvider = AppProvider();
      appProvider.userName = 'Keyboard User';
      appProvider.userAge = '72';

      await tester.pumpWidget(createTestWidget(
        child: const EditProfileScreen(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Simulate soft keyboard opening (320px height)
      tester.view.viewInsets = const FakeViewPadding(bottom: 320 * 2.0);
      await tester.pump();

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);

      // Scroll to reveal and tap Save Changes button
      final saveBtnFinder = find.text('Save Changes');
      await tester.ensureVisible(saveBtnFinder);
      await tester.pump();
      expect(saveBtnFinder, findsOneWidget);
    });
  });
}
