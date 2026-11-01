import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/phc_network/models/phc_patient_model.dart';
import 'package:neuroverse_app/features/phc_network/presentation/asha/asha_patient_games_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Widget createTestWidget({required PhcPatientModel patient, String lang = 'English'}) {
    final provider = AppProvider()..userLanguage = lang;
    return ChangeNotifierProvider<AppProvider>.value(
      value: provider,
      child: MaterialApp(
        home: AshaPatientGamesScreen(patient: patient),
      ),
    );
  }

  group('AshaPatientGamesScreen Tests', () {
    final testPatient = PhcPatientModel(
      id: 'P-TEST-99',
      name: 'Ramen Borah',
      age: 72,
      gender: 'Male',
      village: 'Majuli Cluster 1',
      houseNo: 'H-12',
      guardianName: 'Mridul Borah',
      guardianPhone: '+91 9876543211',
      baselineScore: 7,
      latestScore: 6,
      previousScore: 7,
      lastScreenedDate: DateTime.now().subtract(const Duration(days: 2)),
      status: 'due',
      riskLevel: 'mci_warning',
    );

    final screenedPatient = PhcPatientModel(
      id: 'P-TEST-100',
      name: 'Anjali Sharma',
      age: 68,
      gender: 'Female',
      village: 'Jorhat North',
      houseNo: 'JN-05',
      guardianName: 'Sunita Sharma',
      guardianPhone: '+91 9876543212',
      baselineScore: 8,
      latestScore: 8,
      previousScore: 8,
      lastScreenedDate: DateTime.now(),
      status: 'visited_today',
      riskLevel: 'normal',
    );

    testWidgets('Header strictly renders elder identification to prevent mismatch', (tester) async {
      await tester.pumpWidget(createTestWidget(patient: testPatient));
      await tester.pumpAndSettle();

      // Pinned elder name and details
      expect(find.text('Ramen Borah'), findsOneWidget);
      expect(find.textContaining('72 yrs · Male · Majuli Cluster 1'), findsOneWidget);
      expect(find.text('ID: P-TEST-99'), findsOneWidget);
      expect(find.text('Due for Daily Screening'), findsOneWidget);
      expect(find.textContaining('Active Elder Session'), findsOneWidget);
    });

    testWidgets('Displays screened status when elder was visited today', (tester) async {
      await tester.pumpWidget(createTestWidget(patient: screenedPatient));
      await tester.pumpAndSettle();

      expect(find.text('Anjali Sharma'), findsOneWidget);
      expect(find.text('ID: P-TEST-100'), findsOneWidget);
      expect(find.text('Screened Today (Score: 8/10)'), findsOneWidget);
    });

    testWidgets('Displays both Card Match and Object Finder with level and voice badge', (tester) async {
      await tester.pumpWidget(createTestWidget(patient: testPatient));
      await tester.pumpAndSettle();

      // Card Match (Memory Match)
      expect(find.text('Card Match'), findsOneWidget);
      expect(find.text('Match all pairs • Visual Memory'), findsOneWidget);

      // Object Finder (Memory Recall)
      expect(find.text('Object Finder'), findsOneWidget);
      expect(find.text('Find objects • Working Memory'), findsOneWidget);

      // Q-Learning Level badges & Voice Assisted badges
      expect(find.text('Level 1'), findsNWidgets(2)); // Default level 1 for both
      expect(find.text('Voice Assisted'), findsNWidgets(2));

      // Action buttons
      expect(find.text('Start Game with Elder'), findsNWidgets(2));
    });

    testWidgets('Renders localized strings in Hindi', (tester) async {
      await tester.pumpWidget(createTestWidget(patient: testPatient, lang: 'Hindi'));
      await tester.pumpAndSettle();

      expect(find.text('बुजुर्ग संज्ञानात्मक खेल'), findsOneWidget);
      expect(find.text('दैनिक जांच बाकी है'), findsOneWidget);
      expect(find.text('उपलब्ध स्क्रीनिंग खेल'), findsOneWidget);
      expect(find.text('स्तर 1'), findsNWidgets(2));
      expect(find.text('आवाज़ सहायता युक्त'), findsNWidgets(2));
      expect(find.text('बुजुर्ग के साथ खेल शुरू करें'), findsNWidgets(2));
    });

    test('PhcPatientModel maintains isolated PHC network status without touching user account', () {
      final elder = PhcPatientModel(
        id: 'P-1234',
        name: 'Hari Nath',
        age: 75,
        gender: 'Male',
        village: 'Majuli Cluster 2',
        houseNo: 'M-44',
        guardianName: 'Bipul',
        guardianPhone: '+91 9999900000',
        baselineScore: 0,
        latestScore: 0,
        previousScore: 0,
        lastScreenedDate: DateTime.now(),
        status: 'due',
        riskLevel: 'normal',
      );

      expect(elder.id, 'P-1234');
      expect(elder.status, 'due');

      // Simulate elder completing cognitive screening game
      elder.latestScore = 8;
      elder.status = 'visited_today';
      elder.riskLevel = 'normal';

      expect(elder.status, 'visited_today');
      expect(elder.latestScore, 8);
      expect(elder.riskLevel, 'normal');
      expect(elder.isCriticalDecline, isFalse);
    });
  });
}
