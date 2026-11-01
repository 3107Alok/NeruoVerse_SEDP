import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/features/patient/games/common/game_intro_screen.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: child,
    );
  }

  group('GameIntroScreen UI & Navigation Tests', () {
    testWidgets('Memory Match: renders Kopou orchid visual, steps, and theme styling', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GameIntroScreen(
          title: 'Memory Match',
          description: 'Match pairs of nature & tea garden symbols hidden behind tiles.',
          challengeCount: 2,
          themeTag: '🌸 Assam Tea Estates Edition',
          gameWidget: Text('Active Memory Match Game Screen'),
        ),
      ));
      await tester.pump();

      // Check title & description
      expect(find.text('Card Match'), findsWidgets);
      expect(find.text('Match pairs of nature & tea garden symbols hidden behind tiles.'), findsOneWidget);

      // Check thematic tag
      expect(find.text('🌸 Assam Tea Estates Edition'), findsOneWidget);

      // Check custom GameHubIllustration is rendered
      final illustrationFinder = find.byType(GameHubIllustration);
      expect(illustrationFinder, findsOneWidget);
      final illustration = tester.widget<GameHubIllustration>(illustrationFinder);
      expect(illustration.visual, equals(GameHubVisual.memoryMatch));

      // Check How to Play section & steps
      expect(find.text('HOW TO PLAY'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Cards will be placed face down on the board.'), findsOneWidget);
      expect(find.text('Tap two cards to flip and reveal their symbols.'), findsOneWidget);
      expect(find.text('Match all identical pairs to finish.'), findsOneWidget);

      // Check Start Game button
      expect(find.text('Start Game'), findsOneWidget);
    });

    testWidgets('Pattern Path: renders Living Root Bridge visual and auto-resolved tag', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GameIntroScreen(
          title: 'Pattern Path',
          description: 'Memorize the stones and trace the sacred root bridge trail.',
          challengeCount: 3,
          gameWidget: Text('Active Pattern Path Game Screen'),
        ),
      ));
      await tester.pump();

      // Check title and resolved tag
      expect(find.text('Pattern Path'), findsWidgets);
      expect(find.text('🌱 Living Root Bridge Trail (Meghalaya)'), findsOneWidget);

      // Check illustration
      final illustration = tester.widget<GameHubIllustration>(find.byType(GameHubIllustration));
      expect(illustration.visual, equals(GameHubVisual.patternPath));

      // Check steps
      expect(find.text('Watch the stones light up along the path.'), findsOneWidget);
      expect(find.text('Remember the sequence carefully.'), findsOneWidget);
      expect(find.text('Tap the stepping stones in the same order.'), findsOneWidget);
    });

    testWidgets('Face Recall: renders Family faces visual and auto-resolved tag', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GameIntroScreen(
          title: 'Face Recall',
          description: 'Recognize your family members and friends by listening to their name and relation.',
          challengeCount: 5,
          gameWidget: Text('Active Face Recall Game Screen'),
        ),
      ));
      await tester.pump();

      // Check title and resolved tag
      expect(find.text('Face Recall'), findsWidgets);
      expect(find.text('👨‍👩‍👧 Family & Heritage Album'), findsOneWidget);

      // Check illustration
      final illustration = tester.widget<GameHubIllustration>(find.byType(GameHubIllustration));
      expect(illustration.visual, equals(GameHubVisual.faceRecall));

      // Check steps
      expect(find.text('Listen to the name and relation spoken aloud or shown on screen.'), findsOneWidget);
      expect(find.text('Look carefully at the family & friend photos displayed.'), findsOneWidget);
      expect(find.text('Tap the photo of the requested person to earn points.'), findsOneWidget);
    });

    testWidgets('Memory Recall: renders Mindful Jaapi visual and auto-resolved tag', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GameIntroScreen(
          title: 'Memory Recall',
          description: 'Memorize North-East cultural words and recall them.',
          challengeCount: 2,
          gameWidget: Text('Active Memory Recall Game Screen'),
        ),
      ));
      await tester.pump();

      // Check title and resolved tag
      expect(find.text('Object Finder'), findsWidgets);
      expect(find.text('🏔️ North-East Heritage Echoes'), findsOneWidget);

      // Check illustration
      final illustration = tester.widget<GameHubIllustration>(find.byType(GameHubIllustration));
      expect(illustration.visual, equals(GameHubVisual.memoryRecall));

      // Check steps
      expect(find.text('A few heritage illustration cards will appear on screen.'), findsOneWidget);
      expect(find.text('Take your time to memorize them, then tap I’m Ready.'), findsOneWidget);
      expect(find.text('Select all the correct images you memorized.'), findsOneWidget);
    });

    testWidgets('Tapping Start Game launches gameWidget via pushReplacement', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Navigator(
          onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => const GameIntroScreen(
              title: 'Memory Match',
              description: 'Match pairs of symbols.',
              challengeCount: 2,
              gameWidget: Scaffold(body: Text('Active Game Screen')),
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('Active Game Screen'), findsNothing);
      expect(find.text('Start Game'), findsOneWidget);

      // Tap Start Game
      await tester.tap(find.text('Start Game'));
      await tester.pumpAndSettle();

      // Target game screen is now displayed
      expect(find.text('Active Game Screen'), findsOneWidget);
      expect(find.text('HOW TO PLAY'), findsNothing);
    });

    testWidgets('Tapping back arrow pops navigation', (tester) async {
      final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        home: Scaffold(
          body: ElevatedButton(
            onPressed: () {
              navKey.currentState!.push(
                MaterialPageRoute(
                  builder: (_) => const GameIntroScreen(
                    title: 'Pattern Path',
                    description: 'Follow the path.',
                    challengeCount: 2,
                    gameWidget: Text('Pattern Game'),
                  ),
                ),
              );
            },
            child: const Text('Open Intro'),
          ),
        ),
      ));
      await tester.pump();

      // Open Intro Screen
      await tester.tap(find.text('Open Intro'));
      await tester.pumpAndSettle();

      expect(find.text('HOW TO PLAY'), findsOneWidget);

      // Tap back arrow
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Intro popped
      expect(find.text('HOW TO PLAY'), findsNothing);
      expect(find.text('Open Intro'), findsOneWidget);
    });
  });
}
