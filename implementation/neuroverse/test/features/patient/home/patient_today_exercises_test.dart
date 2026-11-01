import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/core/models/game_session.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/home/patient_home_tab.dart';

class FakeHiveService extends HiveService {
  final Map<String, int> difficulties;
  final List<GameSession> sessions;

  FakeHiveService({this.difficulties = const {}, this.sessions = const []});

  @override
  int getGameDifficulty(String gameId) => difficulties[gameId] ?? 1;

  @override
  List<GameSession> getAllGameSessions() => sessions;
}

GameSession createSession({
  required String gameId,
  required DateTime timestamp,
  int accuracy = 80,
  int score = 100,
  int difficulty = 1,
}) {
  return GameSession(
    id: 'test--',
    gameId: gameId,
    patientId: 'patient-1',
    timestamp: timestamp,
    difficultyLevel: difficulty,
    score: score,
    accuracyPercentage: accuracy,
    completionTimeSeconds: 45,
    mistakes: 1,
    hintsUsed: 0,
    isCompleted: true,
  );
}

void main() {
  Widget createTestWidget({
    required AppProvider appProvider,
    FakeHiveService? fakeHive,
    DateTime Function()? nowOverride,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => fakeHive ?? FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: Scaffold(body: PatientHomeTab(nowOverride: nowOverride)),
      ),
    );
  }

  group('Today\'s Exercises Dynamic Display Tests', () {
    final fixedNow = DateTime(2026, 9, 7, 14, 30);

    testWidgets(
      'Displays compact empty state when no games have been played today',
      (tester) async {
        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(find.text("TODAY'S EXERCISES"), findsOneWidget);
        expect(
          find.text('Your exercises will appear here as you play.'),
          findsOneWidget,
        );
        expect(
          find.text("Start a game to begin today's practice."),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.psychology_rounded), findsOneWidget);

        expect(find.text('Memory Match'), findsNothing);
        expect(find.text('Focus Finder'), findsNothing);
        expect(find.text('Pattern Path'), findsNothing);
        expect(find.text('Not started yet'), findsNothing);
      },
    );

    testWidgets(
      'Single game played today displays only that game card with play count and best accuracy',
      (tester) async {
        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 10, 15),
            accuracy: 85,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(
          find.text('Your exercises will appear here as you play.'),
          findsNothing,
        );
        expect(find.text('Card Match'), findsOneWidget);
        expect(find.text('Plays: 1'), findsOneWidget);
        expect(find.text('Best: 85%'), findsOneWidget);

        expect(find.text('Focus Finder'), findsNothing);
        expect(find.text('Pattern Path'), findsNothing);
      },
    );

    testWidgets(
      'Multiple different games played today appear in most recently played order',
      (tester) async {
        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [
          createSession(
            gameId: 'pattern_path',
            timestamp: DateTime(2026, 9, 7, 9, 0),
            accuracy: 75,
          ),
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 11, 0),
            accuracy: 90,
          ),
          createSession(
            gameId: 'face_recall',
            timestamp: DateTime(2026, 9, 7, 13, 30),
            accuracy: 95,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(find.text('Face Recall'), findsOneWidget);
        expect(find.text('Card Match'), findsOneWidget);
        expect(find.text('Pattern Path'), findsOneWidget);

        final faceRecallPos = tester.getTopLeft(find.text('Face Recall')).dy;
        final memoryMatchPos = tester.getTopLeft(find.text('Card Match')).dy;
        final patternPathPos = tester.getTopLeft(find.text('Pattern Path')).dy;

        expect(faceRecallPos, lessThan(memoryMatchPos));
        expect(memoryMatchPos, lessThan(patternPathPos));
      },
    );

    testWidgets(
      'Duplicate plays of the same game display ONCE with updated play count and best accuracy',
      (tester) async {
        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 9, 30),
            accuracy: 70,
          ),
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 12, 0),
            accuracy: 95,
          ),
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 14, 0),
            accuracy: 80,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(find.text('Card Match'), findsOneWidget);
        expect(find.text('Plays: 3'), findsOneWidget);
        expect(find.text('Best: 95%'), findsOneWidget);
      },
    );

    testWidgets('Games played yesterday do NOT appear in Today\'s Exercises', (
      tester,
    ) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'English';
      appProvider.gameHistory = [
        createSession(
          gameId: 'memory_match',
          timestamp: DateTime(2026, 9, 6, 23, 55),
          accuracy: 88,
        ),
        createSession(
          gameId: 'face_recall',
          timestamp: DateTime(2026, 9, 6, 20, 0),
          accuracy: 92,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(appProvider: appProvider, nowOverride: () => fixedNow),
      );
      await tester.pump();

      expect(find.text('Memory Match'), findsNothing);
      expect(find.text('Face Recall'), findsNothing);
      expect(
        find.text('Your exercises will appear here as you play.'),
        findsOneWidget,
      );
    });

    testWidgets('New game played after midnight appears on the new day', (
      tester,
    ) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'English';
      appProvider.gameHistory = [
        createSession(
          gameId: 'memory_match',
          timestamp: DateTime(2026, 9, 6, 23, 40),
          accuracy: 80,
        ),
        createSession(
          gameId: 'face_recall',
          timestamp: DateTime(2026, 9, 7, 0, 15),
          accuracy: 88,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(appProvider: appProvider, nowOverride: () => fixedNow),
      );
      await tester.pump();

      expect(find.text('Face Recall'), findsOneWidget);
      expect(find.text('Plays: 1'), findsOneWidget);
      expect(find.text('Best: 88%'), findsOneWidget);
      expect(find.text('Memory Match'), findsNothing);
    });

    testWidgets(
      'Calendar rollover across midnight updates exercises without app restart',
      (tester) async {
        DateTime currentTestTime = DateTime(2026, 9, 7, 23, 59);

        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [
          createSession(
            gameId: 'pattern_path',
            timestamp: DateTime(2026, 9, 7, 21, 0),
            accuracy: 90,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => currentTestTime,
          ),
        );
        await tester.pump();

        expect(find.text('Pattern Path'), findsOneWidget);
        expect(
          find.text('Your exercises will appear here as you play.'),
          findsNothing,
        );

        currentTestTime = DateTime(2026, 9, 8, 0, 1);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();

        expect(find.text('Pattern Path'), findsNothing);
        expect(
          find.text('Your exercises will appear here as you play.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Persists today\'s exercises across widget reload / provider notification',
      (tester) async {
        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [
          createSession(
            gameId: 'face_recall',
            timestamp: DateTime(2026, 9, 7, 10, 0),
            accuracy: 80,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(find.text('Face Recall'), findsOneWidget);

        appProvider.gameHistory = [
          ...appProvider.gameHistory,
          createSession(
            gameId: 'memory_match',
            timestamp: DateTime(2026, 9, 7, 14, 0),
            accuracy: 92,
          ),
        ];
        appProvider.notifyListeners();
        await tester.pump();

        expect(find.text('Card Match'), findsOneWidget);
        expect(find.text('Face Recall'), findsOneWidget);

        final memoryMatchPos = tester.getTopLeft(find.text('Card Match')).dy;
        final faceRecallPos = tester.getTopLeft(find.text('Face Recall')).dy;
        expect(memoryMatchPos, lessThan(faceRecallPos));
      },
    );

    testWidgets(
      'Renders empty state cleanly without overflow on 320x568 small screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final appProvider = AppProvider();
        appProvider.userLanguage = 'English';
        appProvider.gameHistory = [];

        await tester.pumpWidget(
          createTestWidget(
            appProvider: appProvider,
            nowOverride: () => fixedNow,
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(
          find.text('Your exercises will appear here as you play.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('Renders in Dark Mode cleanly with proper styling', (
      tester,
    ) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'English';
      appProvider.gameHistory = [];

      await tester.pumpWidget(
        createTestWidget(
          appProvider: appProvider,
          nowOverride: () => fixedNow,
          themeMode: ThemeMode.dark,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Your exercises will appear here as you play.'),
        findsOneWidget,
      );
    });
  });
}
