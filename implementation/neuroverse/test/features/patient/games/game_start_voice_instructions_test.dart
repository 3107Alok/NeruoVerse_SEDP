import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/patient/games/memory_recall/memory_recall_screen.dart';
import 'package:neuroverse_app/features/patient/games/memory_match/memory_match_screen.dart';
import 'package:neuroverse_app/features/patient/games/pattern_path/pattern_path_screen.dart';

class MockVoiceService extends VoiceService {
  final List<Map<String, dynamic>> spokenCalls = [];

  @override
  Future<void> speakKey(String audioKey, {String lang = 'hi', String? fallbackText, bool wait = false}) async {
    spokenCalls.add({
      'audioKey': audioKey,
      'lang': lang,
      'fallbackText': fallbackText,
    });
  }

  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {
    spokenCalls.add({
      'speakText': text,
      'lang': lang,
    });
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeHiveService extends HiveService {
  final Map<String, dynamic> _profile = {};

  @override
  Map<String, dynamic>? getUserProfile() => _profile.isEmpty ? null : _profile;

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    _profile.addAll(profileData);
  }
}

void main() {
  Widget buildTestGame({
    required Widget game,
    required MockVoiceService mockVoice,
    String language = 'en',
    String? voiceLanguage,
  }) {
    final appProvider = AppProvider()
      ..setUserProfile('Test User', '70', 'Female', language)
      ..setVoiceLanguage(voiceLanguage ?? language);

    return MultiProvider(
      providers: [
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        Provider<VoiceService>.value(value: mockVoice),
      ],
      child: MaterialApp(
        home: game,
      ),
    );
  }

  group('Game-Start Voice Instructions: Memory Recall', () {

    testWidgets('Memory Recall triggers initial voice instruction on game start (English)', (tester) async {
      final mockVoice = MockVoiceService();

      await tester.pumpWidget(
        buildTestGame(
          game: const MemoryRecallScreen(difficulty: 1),
          mockVoice: mockVoice,
          language: 'en',
        ),
      );
      await tester.pump(); // allow postFrameCallback to execute

      expect(mockVoice.spokenCalls.length, 1);
      final call = mockVoice.spokenCalls.first;
      expect(call['audioKey'], 'recall_images');
      expect(call['lang'], 'en');
      expect(call['fallbackText'], 'Memorize these images.');

      // Verify game is rendered in memorize phase with calm prompt and I'm Ready button
      expect(find.text('Memorize these images:'), findsOneWidget);
      expect(find.text('Take your time to observe the images'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'I’m Ready'), findsOneWidget);
    });

    testWidgets('Memory Recall triggers localized voice instruction on game start (Hindi)', (tester) async {
      final mockVoice = MockVoiceService();

      await tester.pumpWidget(
        buildTestGame(
          game: const MemoryRecallScreen(difficulty: 1),
          mockVoice: mockVoice,
          language: 'hi',
        ),
      );
      await tester.pump();

      expect(mockVoice.spokenCalls.length, 1);
      final call = mockVoice.spokenCalls.first;
      expect(call['audioKey'], 'recall_images');
      expect(call['lang'], 'hi');
      expect(call['fallbackText'], 'इन चित्रों को याद रखें');
      expect(find.text('इन चित्रों को याद रखें:'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'मैं तैयार हूँ'), findsOneWidget);
    });

    testWidgets('Voice instructions and I’m Ready button transition smoothly to selection phase', (tester) async {
      final mockVoice = MockVoiceService();

      await tester.pumpWidget(
        buildTestGame(
          game: const MemoryRecallScreen(difficulty: 1),
          mockVoice: mockVoice,
          language: 'en',
        ),
      );
      await tester.pump();

      // Initial voice was triggered
      expect(mockVoice.spokenCalls.length, 1);
      expect(mockVoice.spokenCalls.first['audioKey'], 'recall_images');

      // Tap "I'm Ready" button
      final readyBtn = find.widgetWithText(ElevatedButton, 'I’m Ready');
      expect(readyBtn, findsOneWidget);
      await tester.tap(readyBtn);
      await tester.pumpAndSettle();

      // Should seamlessly transition to selection phase
      expect(find.text('Select the images you saw:'), findsOneWidget);
    });
  });

  group('Preservation: Memory Match and Pattern Path working voice behavior', () {
    testWidgets('Memory Match triggers match_find voice instruction', (tester) async {
      final mockVoice = MockVoiceService();

      await tester.pumpWidget(
        buildTestGame(
          game: const MemoryMatchScreen(difficulty: 1),
          mockVoice: mockVoice,
          language: 'en',
        ),
      );
      await tester.pump();

      expect(mockVoice.spokenCalls.length, 1);
      final call = mockVoice.spokenCalls.first;
      expect(call['audioKey'], 'match_find');
      expect(call['fallbackText'], startsWith('Find all the matching pairs!'));
    });

    testWidgets('Pattern Path triggers pattern_watch voice instruction', (tester) async {
      final mockVoice = MockVoiceService();

      await tester.pumpWidget(
        buildTestGame(
          game: const PatternPathScreen(difficulty: 1),
          mockVoice: mockVoice,
          language: 'en',
        ),
      );
      await tester.pump();

      expect(mockVoice.spokenCalls.length, 1);
      final call = mockVoice.spokenCalls.first;
      expect(call['audioKey'], 'pattern_watch');
      expect(call['fallbackText'], startsWith('Watch the pattern closely'));

      // Drain sequence timer
      await tester.pump(const Duration(seconds: 4));
    });
  });
}
