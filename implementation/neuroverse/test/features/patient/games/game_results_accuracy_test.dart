import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/features/patient/games/common/game_results_screen.dart';

void main() {
  Widget buildTestResultsScreen({required double accuracy}) {
    return MaterialApp(
      home: GameResultsScreen(
        totalChallenges: 4,
        completedChallenges: 4,
        accuracy: accuracy,
        currentLevel: 1,
        nextLevel: 2,
        nextLevelWidget: const Scaffold(body: Center(child: Text('Next Level'))),
      ),
    );
  }

  group('GameResultsScreen Accuracy Normalization & Display Tests', () {
    testWidgets('Normal ratio 1.0 displays 100% and not 10000%', (tester) async {
      await tester.pumpWidget(buildTestResultsScreen(accuracy: 1.0));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('10000%'), findsNothing);
      expect(find.text('⭐⭐⭐ Excellent!'), findsOneWidget);
    });

    testWidgets('Defensive guard: raw percentage 100.0 displays 100% and not 10000%', (tester) async {
      await tester.pumpWidget(buildTestResultsScreen(accuracy: 100.0));
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('10000%'), findsNothing);
      expect(find.text('⭐⭐⭐ Excellent!'), findsOneWidget);
    });

    testWidgets('Accuracy 0.75 displays 75%', (tester) async {
      await tester.pumpWidget(buildTestResultsScreen(accuracy: 0.75));
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('7500%'), findsNothing);
      expect(find.text('⭐⭐ Good Job!'), findsOneWidget);
    });

    testWidgets('Defensive guard: raw percentage 75.0 displays 75%', (tester) async {
      await tester.pumpWidget(buildTestResultsScreen(accuracy: 75.0));
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget);
      expect(find.text('7500%'), findsNothing);
      expect(find.text('⭐⭐ Good Job!'), findsOneWidget);
    });
  });
}
