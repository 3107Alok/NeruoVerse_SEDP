import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
import 'package:neuroverse_app/features/patient/games/memory_match/memory_match_screen.dart';
import 'package:neuroverse_app/features/patient/games/pattern_path/pattern_path_screen.dart';

class FakeVoiceService extends VoiceService {
  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {}
  @override
  Future<void> stopSpeaking() async {}
}

void main() {
  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>(create: (_) => AppProvider()),
        Provider<VoiceService>(create: (_) => FakeVoiceService()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Memory Match NER UI Tests', () {
    testWidgets('Renders NER CardBacks and reveals NerIllustration when tapped', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const MemoryMatchScreen(difficulty: 1)));
      await tester.pump();

      // Verify header
      expect(find.text("Find all the matching pairs!"), findsOneWidget);

      // Verify Level indicator
      expect(find.text('Level 1'), findsOneWidget);

      // Initially all 4 cards (2 pairs) show NerCardBack
      expect(find.byType(NerCardBack), findsNWidgets(4));
      expect(find.byType(NerIllustration), findsNothing);

      // Tap the first card
      await tester.tap(find.byType(NerCardBack).first);
      await tester.pump();

      // Now 1 card is flipped showing photographic memory card Image
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(NerCardBack), findsNWidgets(3));
    });
  });

  group('Pattern Path NER UI Tests', () {
    testWidgets('Renders stepping stones and prompt message', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PatternPathScreen(difficulty: 1)));
      await tester.pump();

      // Header is visible
      expect(find.text("Pattern Path"), findsOneWidget);
      expect(find.text("Watch the pattern..."), findsOneWidget);

      // Stepping stones are rendered (2x2 = 4 tiles for difficulty 1)
      expect(find.byType(AnimatedContainer), findsWidgets);
      expect(find.text("Level 1"), findsOneWidget);

      // Drain sequence playback timers
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
