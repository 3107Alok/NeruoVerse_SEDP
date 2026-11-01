import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/games/common/game_results_screen.dart';

void main() {
  Widget buildTestResultsScreen({
    required String language,
    double accuracy = 0.9,
    int currentLevel = 2,
    int? nextLevel = 3,
  }) {
    final appProvider = AppProvider();
    appProvider.userLanguage = language;

    return ChangeNotifierProvider<AppProvider>.value(
      value: appProvider,
      child: MaterialApp(
        home: GameResultsScreen(
          totalChallenges: 5,
          completedChallenges: 5,
          accuracy: accuracy,
          currentLevel: currentLevel,
          nextLevel: nextLevel,
          nextLevelWidget: const Scaffold(body: Center(child: Text('Next Level Screen'))),
        ),
      ),
    );
  }

  group('GameResultsScreen Localization & Overflow Tests', () {
    final languages = ['miz', 'en', 'hi', 'bn', 'as', 'mni'];
    final viewports = [
      const Size(320, 568), // Ultra narrow (e.g. iPhone SE 1st gen)
      const Size(360, 640), // Standard budget Android
      const Size(412, 915), // Standard Android Pixel
    ];

    for (final lang in languages) {
      for (final size in viewports) {
        testWidgets('Zero overflow in $lang at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(buildTestResultsScreen(language: lang));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: 'RenderFlex overflow or exception occurred in $lang on $size');

          // Verify both buttons exist
          expect(find.byType(OutlinedButton), findsOneWidget);
          expect(find.byType(ElevatedButton), findsOneWidget);
        });
      }
    }

    testWidgets('Mizo language buttons wrap and do not overflow even with nextLevel=null', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestResultsScreen(
        language: 'miz',
        currentLevel: 1,
        nextLevel: null,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Level dawt leh'), findsOneWidget);
      expect(find.text('In lamah kir rawh'), findsOneWidget);
    });
  });
}
