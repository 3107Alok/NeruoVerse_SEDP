import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/models/game_session.dart';
import 'package:neuroverse_app/features/patient/progress/patient_progress_tab.dart';

class FakeHiveService extends HiveService {
  @override
  List<GameSession> getAllGameSessions() => [];
}

void main() {
  Widget createTestWidget({
    required Widget child,
    required AppProvider appProvider,
    ThemeMode themeMode = ThemeMode.light,
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
          body: child,
        ),
      ),
    );
  }

  group('PatientProgressTab Polish Tests', () {
    testWidgets('Renders friendly empty state when no game history exists', (tester) async {
      final appProvider = AppProvider();
      appProvider.gameHistory = [];

      await tester.pumpWidget(createTestWidget(
        child: const PatientProgressTab(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Check header and subtitle
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Track your cognitive journey & daily milestones'), findsOneWidget);

      // Check empty state card
      expect(find.text('No Analytics Yet'), findsOneWidget);
      expect(find.byIcon(Icons.bar_chart_rounded), findsOneWidget);
      expect(find.textContaining('Play your first cognitive game'), findsOneWidget);
    });

    testWidgets('Renders polished header, soft streak card, summary stats, daily tracking, and game performance', (tester) async {
      final now = DateTime.now();
      final mockSession = GameSession(
        id: 'sess_1',
        gameId: 'memory_match',
        patientId: 'patient_1',
        timestamp: now,
        difficultyLevel: 3,
        score: 950,
        accuracyPercentage: 90,
        completionTimeSeconds: 42,
        mistakes: 1,
        hintsUsed: 0,
        cognitiveScore: 88.0,
      );

      final appProvider = AppProvider();
      appProvider.gameHistory = [mockSession];

      await tester.pumpWidget(createTestWidget(
        child: const PatientProgressTab(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Analytics'), findsOneWidget);
      expect(find.text('Track your cognitive journey & daily milestones'), findsOneWidget);

      // Check soft streak card
      expect(find.textContaining('Streak!'), findsOneWidget);
      expect(find.text('Tap to view active days & calendar'), findsOneWidget);

      // Check 3 summary stats
      expect(find.text('Total Games'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Total games count
      expect(find.text('Avg Accuracy'), findsOneWidget);
      expect(find.text('90%'), findsWidgets); // Summary and game card
      expect(find.text('Cognitive Score'), findsOneWidget);
      expect(find.text('88.0'), findsOneWidget);

      // Check Daily Level Tracking
      expect(find.text('Daily Level Tracking'), findsOneWidget);
      expect(find.text('Daily Reset Active'), findsOneWidget);

      // Scroll down to reveal Game Performance Card
      await tester.scrollUntilVisible(find.text('Card Match'), 300);
      expect(find.text('Game Performance'), findsOneWidget);
      expect(find.text('Card Match'), findsWidgets);
      expect(find.text('Best: Lvl 3'), findsOneWidget);
      expect(find.text('Avg Time'), findsOneWidget);
      expect(find.text('42.0s'), findsOneWidget);
      expect(find.text('Total Plays'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Tapping streak card triggers showActiveDaysDialog', (tester) async {
      final now = DateTime.now();
      final mockSession = GameSession(
        id: 'sess_1',
        gameId: 'pattern_path',
        patientId: 'patient_1',
        timestamp: now,
        difficultyLevel: 2,
        score: 800,
        accuracyPercentage: 85,
        completionTimeSeconds: 35,
        mistakes: 2,
        hintsUsed: 0,
      );

      final appProvider = AppProvider();
      appProvider.gameHistory = [mockSession];

      await tester.pumpWidget(createTestWidget(
        child: const PatientProgressTab(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Tap streak card
      final streakFinder = find.text('Tap to view active days & calendar');
      expect(streakFinder, findsOneWidget);
      await tester.tap(streakFinder);
      await tester.pumpAndSettle();

      // Verify Active Days dialog appears
      expect(find.text('Active Training Days'), findsOneWidget);
      expect(find.text('Awesome! Keep Training'), findsOneWidget);
    });

    testWidgets('Responsive test on narrow viewport (360x640) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final sessions = [
        GameSession(
          id: 'sess_1',
          gameId: 'memory_match',
          patientId: 'patient_1',
          timestamp: now,
          difficultyLevel: 4,
          score: 1000,
          accuracyPercentage: 100,
          completionTimeSeconds: 30,
          mistakes: 0,
          hintsUsed: 0,
          cognitiveScore: 95.0,
        ),
        GameSession(
          id: 'sess_2',
          gameId: 'face_recall',
          patientId: 'patient_1',
          timestamp: now,
          difficultyLevel: 3,
          score: 850,
          accuracyPercentage: 80,
          completionTimeSeconds: 25,
          mistakes: 1,
          hintsUsed: 0,
          cognitiveScore: 82.0,
        ),
      ];

      final appProvider = AppProvider();
      appProvider.gameHistory = sessions;

      await tester.pumpWidget(createTestWidget(
        child: const PatientProgressTab(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Verify no overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Renders fully localized Hindi daily tracking, date, plays badge, and game metrics when userLanguage is Hindi', (tester) async {
      // Create a session for a fixed past date (e.g. Sep 8, 2026 - Tuesday)
      final sessionDate = DateTime(2026, 9, 8, 10, 30);
      final mockSession = GameSession(
        id: 'sess_hi_1',
        gameId: 'pattern_path',
        patientId: 'patient_1',
        timestamp: sessionDate,
        difficultyLevel: 2,
        score: 750,
        accuracyPercentage: 85,
        completionTimeSeconds: 30,
        mistakes: 1,
        hintsUsed: 0,
        cognitiveScore: 80.0,
      );

      final appProvider = AppProvider();
      appProvider.userLanguage = 'Hindi';
      appProvider.gameHistory = [mockSession];

      await tester.pumpWidget(createTestWidget(
        child: const PatientProgressTab(),
        appProvider: appProvider,
      ));
      await tester.pumpAndSettle();

      // Check Hindi headers
      expect(find.text('प्रगति विश्लेषण'), findsOneWidget);
      expect(find.text('दैनिक लेवल ट्रैकिंग'), findsOneWidget);
      expect(find.text('दैनिक रीसेट सक्रिय'), findsOneWidget);

      // Check localized date format: Tuesday Sep 8, 2026 in Hindi is "मंगल, 8 सितं 2026"
      expect(find.text('मंगल, 8 सितं 2026'), findsOneWidget);

      // Check localized plays badge: "1 बार खेला"
      expect(find.text('1 बार खेला'), findsOneWidget);

      // Scroll to game performance
      await tester.scrollUntilVisible(find.text('पैटर्न पाथ'), 300);
      expect(find.text('खेल प्रदर्शन'), findsOneWidget);
      expect(find.text('पैटर्न पाथ'), findsWidgets);
    });
  });
}
