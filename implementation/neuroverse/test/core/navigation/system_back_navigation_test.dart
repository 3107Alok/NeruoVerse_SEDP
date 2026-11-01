import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/core/models/game_session.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/core/services/sync_service.dart';
import 'package:neuroverse_app/features/role_selection/role_selection_screen.dart';
import 'package:neuroverse_app/features/onboarding/language_screen.dart';
import 'package:neuroverse_app/features/onboarding/setup_profile_screen.dart';
import 'package:neuroverse_app/features/onboarding/caregiver_setup_profile_screen.dart';
import 'package:neuroverse_app/features/patient/home/patient_main_screen.dart';
import 'package:neuroverse_app/features/caregiver/overview/caregiver_main_screen.dart';
import 'package:neuroverse_app/features/admin/dashboard/admin_main_screen.dart';

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

  @override
  int getGameDifficulty(String gameId) => 1;

  @override
  List<GameSession> getAllGameSessions() => [];
}

class FakeVoiceService extends VoiceService {
  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {}
  @override
  Future<void> stopSpeaking() async {}
}

Widget createTestApp({
  required Widget child,
  AppProvider? appProvider,
}) {
  final provider = appProvider ?? AppProvider();
  final hive = FakeHiveService();
  return MultiProvider(
    providers: [
      Provider<HiveService>.value(value: hive),
      ChangeNotifierProvider<AppProvider>.value(value: provider),
      Provider<VoiceService>(create: (_) => FakeVoiceService()),
      Provider<SyncService>(create: (_) => SyncService(hive)),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

PopScope findActivePopScope(WidgetTester tester) {
  final popScopes = tester.widgetList(find.byWidgetPredicate((w) => w is PopScope));
  return popScopes.first as PopScope;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Patient Main Screen System Back Navigation', () {
    testWidgets('System back navigates tab history and exits from Home tab', (tester) async {
      await tester.pumpWidget(createTestApp(child: const PatientMainScreen()));
      await tester.pump();

      // Initial state: Tab 0 (Home). Root PopScope canPop is true (app exits).
      expect(findActivePopScope(tester).canPop, isTrue);

      // Navigate to Games tab (Tab 1)
      await tester.tap(find.text('Games'));
      await tester.pump();

      expect(findActivePopScope(tester).canPop, isFalse);

      // Navigate to Progress tab (Tab 2)
      await tester.tap(find.text('Progress'));
      await tester.pump();

      expect(findActivePopScope(tester).canPop, isFalse);

      // Navigate to Profile tab (Tab 3)
      await tester.tap(find.text('Profile'));
      await tester.pump();

      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 1: Profile (3) -> Progress (2)
      final pop1 = await tester.binding.handlePopRoute();
      expect(pop1, isTrue);
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 2: Progress (2) -> Games (1)
      final pop2 = await tester.binding.handlePopRoute();
      expect(pop2, isTrue);
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 3: Games (1) -> Home (0)
      final pop3 = await tester.binding.handlePopRoute();
      expect(pop3, isTrue);
      await tester.pump();

      // Now at Home tab with empty history: canPop is true (exits app)
      expect(findActivePopScope(tester).canPop, isTrue);

      // Test direct selection of Home tab clears history
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      await tester.tap(find.text('Home'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isTrue);
    });
  });

  group('Caregiver Main Screen System Back Navigation', () {
    testWidgets('System back navigates tab history and exits from Overview tab', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      // Starts at Overview (0): canPop is true
      expect(findActivePopScope(tester).canPop, isTrue);

      // Switch to Patients tab (1)
      await tester.tap(find.text('Patients'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // Switch to Alerts tab (2)
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // Switch to Profile tab (3)
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 1: Profile (3) -> Alerts (2)
      final pop1 = await tester.binding.handlePopRoute();
      expect(pop1, isTrue);
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 2: Alerts (2) -> Patients (1)
      final pop2 = await tester.binding.handlePopRoute();
      expect(pop2, isTrue);
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 3: Patients (1) -> Overview (0)
      final pop3 = await tester.binding.handlePopRoute();
      expect(pop3, isTrue);
      await tester.pump();

      // Now at Overview tab with empty history: canPop is true
      expect(findActivePopScope(tester).canPop, isTrue);

      // Direct tap to Overview clears history
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      await tester.tap(find.text('Overview'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isTrue);
    });
  });

  group('Admin Console System Back Navigation', () {
    testWidgets('System back navigates tab history and exits from Dashboard', (tester) async {
      await tester.pumpWidget(createTestApp(child: const AdminMainScreen()));
      await tester.pump();

      // Starts at Dashboard (0): canPop is true
      expect(find.text('Admin Console'), findsOneWidget);
      expect(findActivePopScope(tester).canPop, isTrue);

      // Switch to Users tab (1)
      await tester.tap(find.text('Users'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // Switch to Analytics tab (2)
      await tester.tap(find.text('Analytics'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 1: Analytics (2) -> Users (1)
      final pop1 = await tester.binding.handlePopRoute();
      expect(pop1, isTrue);
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // System back 2: Users (1) -> Dashboard (0)
      final pop2 = await tester.binding.handlePopRoute();
      expect(pop2, isTrue);
      await tester.pump();

      // Now at Dashboard with empty history: canPop is true
      expect(findActivePopScope(tester).canPop, isTrue);

      // Direct selection of Dashboard clears history
      await tester.tap(find.text('Users'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      await tester.tap(find.text('Dashboard'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isTrue);
    });
  });

  group('Onboarding System Back Navigation Stack', () {
    testWidgets('RoleSelection pushes LanguageScreen, Back returns to RoleSelection', (tester) async {
      await tester.pumpWidget(createTestApp(child: const RoleSelectionScreen()));
      await tester.pump();

      expect(find.text('Who is using the app?'), findsOneWidget);

      // Tap "I am a Patient"
      await tester.tap(find.text('I am a Patient'));
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsOneWidget);

      // Press system back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Who is using the app?'), findsOneWidget);
    });

    testWidgets('RoleSelection pushes CaregiverSetupProfileScreen, Back returns to RoleSelection', (tester) async {
      await tester.pumpWidget(createTestApp(child: const RoleSelectionScreen()));
      await tester.pump();

      // Tap "I am a Caregiver"
      await tester.tap(find.text('I am a Caregiver'));
      await tester.pumpAndSettle();

      expect(find.byType(CaregiverSetupProfileScreen), findsOneWidget);

      // Press system back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();

      expect(find.text('Who is using the app?'), findsOneWidget);
    });

    testWidgets('LanguageScreen pushes SetupProfileScreen, Back returns to LanguageScreen', (tester) async {
      await tester.pumpWidget(createTestApp(child: const LanguageScreen()));
      await tester.pump();

      // Tap "Continue"
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(SetupProfileScreen), findsOneWidget);

      // Press system back
      final popped = await tester.binding.handlePopRoute();
      expect(popped, isTrue);
      await tester.pumpAndSettle();

      expect(find.byType(LanguageScreen), findsOneWidget);
    });

    testWidgets('Full Onboarding multi-level back stack: Role -> Language -> SetupProfile -> Back -> Back', (tester) async {
      await tester.pumpWidget(createTestApp(child: const RoleSelectionScreen()));
      await tester.pump();

      // 1. RoleSelection -> LanguageScreen
      await tester.tap(find.text('I am a Patient'));
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);

      // 2. LanguageScreen -> SetupProfileScreen
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.byType(SetupProfileScreen), findsOneWidget);

      // 3. Back from SetupProfileScreen -> LanguageScreen
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LanguageScreen), findsOneWidget);

      // 4. Back from LanguageScreen -> RoleSelectionScreen
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Who is using the app?'), findsOneWidget);
    });
  });

  group('Pushed Inner Route and Dialog Precedence', () {
    testWidgets('Inner pushed route pops first before root tab back-stack', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      // Switch to Patients tab
      await tester.tap(find.text('Patients'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // Push an inner screen on Navigator
      final BuildContext navContext = tester.element(find.byType(CaregiverMainScreen));
      Navigator.of(navContext).push(
        PageRouteBuilder(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, anim, secAnim) => const Scaffold(
            body: Center(child: Text('Inner Detail Screen')),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Inner Detail Screen'), findsOneWidget);

      // System back should pop the inner screen FIRST
      final poppedInner = await tester.binding.handlePopRoute();
      expect(poppedInner, isTrue);
      await tester.pump();

      // Inner screen is dismissed, CaregiverMainScreen is still on Patients tab
      expect(find.text('Inner Detail Screen'), findsNothing);
      expect(find.byType(CaregiverMainScreen), findsOneWidget);
      expect(findActivePopScope(tester).canPop, isFalse);

      // Next system back pops the Patients tab to Overview
      final poppedTab = await tester.binding.handlePopRoute();
      expect(poppedTab, isTrue);
      await tester.pump();

      expect(findActivePopScope(tester).canPop, isTrue);
    });

    testWidgets('Dialog pops first before root tab back-stack', (tester) async {
      await tester.pumpWidget(createTestApp(
        child: const CaregiverMainScreen(
          initialPatients: [],
          initialPendingCount: 0,
        ),
      ));
      await tester.pump();

      // Switch to Alerts tab
      await tester.tap(find.text('Alerts'));
      await tester.pump();
      expect(findActivePopScope(tester).canPop, isFalse);

      // Show dialog
      final BuildContext navContext = tester.element(find.byType(CaregiverMainScreen));
      showDialog(
        context: navContext,
        builder: (_) => const AlertDialog(title: Text('Test Dialog')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Test Dialog'), findsOneWidget);

      // System back should dismiss dialog first
      final poppedDialog = await tester.binding.handlePopRoute();
      expect(poppedDialog, isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Test Dialog'), findsNothing);
      expect(find.byType(CaregiverMainScreen), findsOneWidget);
      expect(findActivePopScope(tester).canPop, isFalse);
    });
  });
}
