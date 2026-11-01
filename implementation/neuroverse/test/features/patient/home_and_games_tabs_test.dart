import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
import 'package:neuroverse_app/features/patient/home/patient_home_tab.dart';
import 'package:neuroverse_app/features/patient/games/game_hub/game_hub_tab.dart';
import 'package:neuroverse_app/features/patient/games/common/daily_thought_card.dart';

class FakeHiveService extends HiveService {
  @override
  int getGameDifficulty(String gameId) => 1;
}

void main() {
  Widget createTestWidget({required Widget child, required AppProvider appProvider}) {
    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('PatientHomeTab Redesign Tests', () {
    testWidgets('Renders landscape header, goal card, quick stats, exercises, and quote banner', (tester) async {
      final appProvider = AppProvider();
      appProvider.userName = 'Alok';

      await tester.pumpWidget(createTestWidget(
        child: const PatientHomeTab(),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Check Greeting
      expect(find.text('Alok!'), findsOneWidget);

      // Check Today's Goal Card
      expect(find.text("Today's Goal"), findsOneWidget);
      expect(find.text('0 of 3 exercises completed'), findsOneWidget);

      // Check Quick Stats
      expect(find.text('Daily Streak 🔥'), findsOneWidget);
      expect(find.text("Today's Acc"), findsOneWidget);

      // Check Today's Exercises Section
      expect(find.text("TODAY'S EXERCISES"), findsOneWidget);
      expect(find.text('Memory Match'), findsOneWidget);
      expect(find.text('Focus Finder'), findsOneWidget);
      expect(find.text('Pattern Path'), findsOneWidget);

      // Check 3 game illustrations for the 3 exercises
      expect(find.byType(GameHubIllustration), findsNWidgets(3));

      // Check positive calming thought card with lightbulb icon
      expect(find.byIcon(Icons.lightbulb_rounded), findsWidgets);
      expect(find.byType(DailyThoughtCard), findsOneWidget);
      expect(DailyThoughts.thoughts.contains(DailyThoughts.homeThought), isTrue);
    });
  });

  group('GameHubTab Redesign Tests', () {
    testWidgets('Renders 2x2 grid with 4 dedicated GameHubIllustrations and distinct DailyThoughtCard', (tester) async {
      final appProvider = AppProvider();

      await tester.pumpWidget(createTestWidget(
        child: const GameHubTab(),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Header title (breathing naturally without badge)
      expect(find.text('Cognitive Games'), findsOneWidget);
      expect(find.text('Play\nLearn\nStay Sharper'), findsNothing);

      // 4 Game cards
      expect(find.text('Memory Match'), findsOneWidget);
      expect(find.text('Match all pairs'), findsOneWidget);
      expect(find.text('Pattern Path'), findsOneWidget);
      expect(find.text('Memorize the path'), findsOneWidget);
      expect(find.text('Focus Finder'), findsOneWidget);
      expect(find.text('Spot the difference'), findsOneWidget);
      expect(find.text('Memory Recall'), findsOneWidget);
      expect(find.text('Memorize words'), findsOneWidget);

      // Check 4 dedicated GameHubIllustration visuals
      expect(find.byType(GameHubIllustration), findsNWidgets(4));

      // Check Level indicators on cards
      expect(find.text('Level 1'), findsNWidgets(4));

      // Check Thought card at bottom with lightbulb icon
      expect(find.byType(DailyThoughtCard), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_rounded), findsWidgets);

      // Verify Home and Games thoughts are strictly distinct
      expect(DailyThoughts.homeThought, isNot(equals(DailyThoughts.gamesThought)));
      expect(DailyThoughts.thoughts.contains(DailyThoughts.gamesThought), isTrue);
    });
  });
}
