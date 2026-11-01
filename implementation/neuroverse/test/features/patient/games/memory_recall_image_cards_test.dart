import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/core/services/adaptive_intelligence_service.dart';
import 'package:neuroverse_app/core/services/q_learning_service.dart';
import 'package:neuroverse_app/core/services/sync_service.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/core/models/game_session.dart';
import 'package:neuroverse_app/features/patient/games/memory_recall/memory_recall_screen.dart';

class MockVoiceService extends VoiceService {
  final List<String> spoken = [];

  @override
  Future<void> speakKey(String audioKey, {String lang = 'hi', String? fallbackText, bool wait = false}) async {
    spoken.add(audioKey);
  }

  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {
    spoken.add(text);
  }

  @override
  Future<void> stopSpeaking() async {}
}

class FakeHiveService extends HiveService {
  final Map<String, dynamic> _profile = {};
  final List<GameSession> savedSessions = [];

  @override
  Map<String, dynamic>? getUserProfile() => _profile.isEmpty ? null : _profile;

  @override
  Future<void> saveUserProfile(Map<String, dynamic> profileData) async {
    _profile.addAll(profileData);
  }

  @override
  int getGameDifficulty(String gameId) => 1;

  @override
  Future<void> saveGameDifficulty(String gameId, int difficulty) async {}

  @override
  Future<void> saveGameSession(GameSession session) async {
    savedSessions.add(session);
  }

  @override
  List<GameSession> getAllGameSessions() => savedSessions;

  @override
  Map<String, Map<String, double>> loadQTable() => {};

  @override
  Future<void> saveQTable(Map<String, Map<String, double>> qTable) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  final List<String> expected40Items = [
    'momos', 'tea_leaves', 'orchid', 'bamboo', 'traditional_house', 'waterfall', 'hills', 'hornbill',
    'red_panda', 'one_horned_rhino', 'traditional_dress', 'bamboo_basket', 'traditional_instrument', 'black_rice', 'local_fruits', 'pine_trees',
    'rhododendron', 'river', 'sunrise', 'handloom_fabric', 'fishing_basket', 'cultural_mask', 'mithun', 'clouds',
    'local_tea_cup', 'chili_peppers', 'ginger', 'lemon', 'banana_leaf', 'rice_field', 'traditional_jewellery', 'handicraft',
    'canoe', 'lotus', 'elephant', 'clouded_leopard', 'maple_leaves', 'toki_bird', 'traditional_hat', 'orange'
  ];

  test('All 40 Northeast India themed image card assets exist on disk', () {
    expect(expected40Items.length, 40);
    expect(expected40Items.toSet().length, 40); // No duplicates

    for (final item in expected40Items) {
      final file = File('assets/images/memory_cards/$item.png');
      expect(file.existsSync(), isTrue, reason: 'Missing asset file: assets/images/memory_cards/$item.png');
    }
  });

  Widget buildTestGame({required Widget child, FakeHiveService? hiveService}) {
    final fakeHive = hiveService ?? FakeHiveService();
    final qLearning = QLearningService();
    final adaptive = AdaptiveIntelligenceService(qLearning);
    final sync = SyncService(fakeHive);
    final mockVoice = MockVoiceService();
    final appProvider = AppProvider()
      ..setUserProfile('Test', '72', 'Female', 'en')
      ..setVoiceLanguage('en');

    return MultiProvider(
      providers: [
        Provider<HiveService>.value(value: fakeHive),
        Provider<AdaptiveIntelligenceService>.value(value: adaptive),
        Provider<SyncService>.value(value: sync),
        Provider<VoiceService>.value(value: mockVoice),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  testWidgets('MemoryRecallScreen renders image cards during Memorize phase', (tester) async {
    await tester.pumpWidget(buildTestGame(child: const MemoryRecallScreen(difficulty: 1)));
    await tester.pump();

    // Verify Title & Memorize instruction
    expect(find.text('Object Finder'), findsOneWidget);
    expect(find.text('Memorize these images:'), findsOneWidget);

    // Verify level indicator
    expect(find.text('Level 1'), findsOneWidget);

    // Level 1 should display 1 target card as requested
    final imageWidgets = find.byType(Image);
    expect(imageWidgets, findsNWidgets(1));

    // Verify calm observation prompt and "I'm Ready" button
    expect(find.text('Take your time to observe the images'), findsOneWidget);
    expect(find.byIcon(Icons.remove_red_eye_outlined), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'I’m Ready'), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsNothing);
  });

  testWidgets('MemoryRecallScreen transitions to Recall phase and allows card selection via I’m Ready button', (tester) async {
    await tester.pumpWidget(buildTestGame(child: const MemoryRecallScreen(difficulty: 1)));
    await tester.pump();

    // In memorize phase, 1 card is shown for Level 1
    expect(find.byType(Image), findsNWidgets(1));

    // Tap "I'm Ready" to transition to recall phase
    final readyBtn = find.widgetWithText(ElevatedButton, 'I’m Ready');
    expect(readyBtn, findsOneWidget);
    await tester.tap(readyBtn);
    await tester.pumpAndSettle();

    // Now in recall phase
    expect(find.text('Select the images you saw:'), findsOneWidget);

    // GridView should now be visible with options
    expect(find.byType(GridView), findsOneWidget);
    final optionCards = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(GestureDetector),
    );
    expect(optionCards, findsWidgets);

    // Initially no checkmarks
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    // Tap the first card in the grid
    await tester.tap(optionCards.first);
    await tester.pump();

    // Now one checkmark badge is visible
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    // Tap the first card again to deselect
    await tester.tap(optionCards.first);
    await tester.pump();

    // Checkmark is removed
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('MemoryRecallScreen Hint button highlights a target card', (tester) async {
    await tester.pumpWidget(buildTestGame(child: const MemoryRecallScreen(difficulty: 1)));
    await tester.pump();

    // Tap "I'm Ready" to enter recall phase
    final readyBtn = find.widgetWithText(ElevatedButton, 'I’m Ready');
    await tester.tap(readyBtn);
    await tester.pumpAndSettle();

    // Hint button should now be visible in AppBar
    final hintButton = find.widgetWithText(TextButton, 'Hint');
    expect(hintButton, findsOneWidget);

    // Tap Hint
    await tester.tap(hintButton);
    await tester.pump();

    // A hint badge (lightbulb) appears on one of the cards
    expect(find.byIcon(Icons.lightbulb_rounded), findsWidgets);

    // Drain the 3-second hint dismissal timer
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('MemoryRecallScreen: Full match on first attempt records 100% accuracy and 0 mistakes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeHive = FakeHiveService();
    await tester.pumpWidget(buildTestGame(
      child: const MemoryRecallScreen(difficulty: 1),
      hiveService: fakeHive,
    ));
    await tester.pump();

    // In memorize phase, collect target card asset paths
    final targetImages = tester.widgetList<Image>(find.byType(Image)).toList();
    final targetAssetNames = targetImages
        .map((img) => (img.image as AssetImage).assetName)
        .toList();
    expect(targetAssetNames.length, 1);

    // Tap "I'm Ready" to enter recall phase
    final readyBtn = find.widgetWithText(ElevatedButton, 'I’m Ready');
    await tester.tap(readyBtn);
    await tester.pumpAndSettle();

    // Select each target card in the recall grid
    for (final assetName in targetAssetNames) {
      final imageFinder = find.byWidgetPredicate((w) =>
          w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == assetName);
      await tester.tap(imageFinder.first);
      await tester.pump();
    }

    // "Check Answers" button should be active
    final checkBtn = find.widgetWithText(ElevatedButton, 'Check Answers');
    expect(checkBtn, findsOneWidget);
    await tester.tap(checkBtn);
    await tester.pumpAndSettle();

    // Verify session data in Hive
    expect(fakeHive.savedSessions.length, 1);
    final session = fakeHive.savedSessions.first;
    expect(session.accuracyPercentage, 100);
    expect(session.score, 100);
    expect(session.mistakes, 0);
    expect(session.patientId, isNot('mock_patient_id'));
    expect(session.gameCategory, 'Memory & Recognition');
    expect(session.cognitiveScore, isNotNull);
    expect(session.reactionTimeAverageMs, isNotNull);
  });

  testWidgets('MemoryRecallScreen: Distractor pick retains correct cards on retry, penalizes accuracy, and accumulates mistakes', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeHive = FakeHiveService();
    await tester.pumpWidget(buildTestGame(
      child: const MemoryRecallScreen(difficulty: 3),
      hiveService: fakeHive,
    ));
    await tester.pump();

    // Collect target asset names
    final targetImages = tester.widgetList<Image>(find.byType(Image)).toList();
    final targetAssetNames = targetImages
        .map((img) => (img.image as AssetImage).assetName)
        .toSet();

    // Tap "I'm Ready"
    await tester.tap(find.widgetWithText(ElevatedButton, 'I’m Ready'));
    await tester.pumpAndSettle();

    // Pick 2 targets and 1 distractor
    final gridImages = tester.widgetList<Image>(find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Image),
    )).toList();

    final List<String> allOptionAssets = gridImages
        .map((img) => (img.image as AssetImage).assetName)
        .toList();

    final distractorAsset = allOptionAssets.firstWhere((a) => !targetAssetNames.contains(a));
    final targetsToPick = targetAssetNames.take(2).toList();
    final thirdTarget = targetAssetNames.last;

    // Tap 2 targets
    for (final assetName in targetsToPick) {
      final imageFinder = find.byWidgetPredicate((w) =>
          w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == assetName);
      await tester.tap(imageFinder.first);
      await tester.pump();
    }

    // Tap 1 distractor
    final distractorFinder = find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == distractorAsset);
    await tester.tap(distractorFinder.first);
    await tester.pump();

    // Submit attempt 1 with 1 mistake
    final checkBtn = find.widgetWithText(ElevatedButton, 'Check Answers');
    await tester.tap(checkBtn);
    await tester.pump();

    // Feedback shown: 2 correct cards retained, distractor unselected
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.textContaining('2 of 3 correct!'), findsOneWidget);

    // Now tap the actual 3rd target card to complete
    final thirdImageFinder = find.byWidgetPredicate((w) =>
        w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == thirdTarget);
    await tester.tap(thirdImageFinder.first);
    await tester.pump();

    // Submit attempt 2
    await tester.tap(find.widgetWithText(ElevatedButton, 'Check Answers'));
    await tester.pumpAndSettle();

    // Verify session accuracy: 1 mistake => 100 - (1 * 10) = 90%
    expect(fakeHive.savedSessions.length, 1);
    final session = fakeHive.savedSessions.first;
    expect(session.mistakes, 1);
    expect(session.accuracyPercentage, 90);
    expect(session.score, 90);
  });

  testWidgets('MemoryRecallScreen: Max 3 attempts completes game without infinite loop and clamps accuracy fairly', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeHive = FakeHiveService();
    await tester.pumpWidget(buildTestGame(
      child: const MemoryRecallScreen(difficulty: 3),
      hiveService: fakeHive,
    ));
    await tester.pump();

    // Collect target asset names
    final targetImages = tester.widgetList<Image>(find.byType(Image)).toList();
    final targetAssetNames = targetImages
        .map((img) => (img.image as AssetImage).assetName)
        .toSet();

    // Tap "I'm Ready"
    await tester.tap(find.widgetWithText(ElevatedButton, 'I’m Ready'));
    await tester.pumpAndSettle();

    final gridImages = tester.widgetList<Image>(find.descendant(
      of: find.byType(GridView),
      matching: find.byType(Image),
    )).toList();

    final distractors = gridImages
        .map((img) => (img.image as AssetImage).assetName)
        .where((a) => !targetAssetNames.contains(a))
        .take(3)
        .toList();

    // Helper to select 3 distractors and submit
    Future<void> selectAndSubmitDistractors() async {
      for (final assetName in distractors) {
        final imageFinder = find.byWidgetPredicate((w) =>
            w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == assetName);
        await tester.tap(imageFinder.first);
        await tester.pump();
      }
      final checkBtn = find.widgetWithText(ElevatedButton, 'Check Answers');
      await tester.tap(checkBtn);
      await tester.pump();
    }

    // Attempt 1
    await selectAndSubmitDistractors();
    // Attempt 2
    await selectAndSubmitDistractors();
    // Attempt 3 (Final max attempts limit reached)
    await selectAndSubmitDistractors();
    await tester.pumpAndSettle();

    // Game completed cleanly without infinite loop
    expect(fakeHive.savedSessions.length, 1);
    final session = fakeHive.savedSessions.first;
    expect(session.mistakes, 9); // 3 mistakes x 3 attempts
    expect(session.accuracyPercentage, inInclusiveRange(15, 20)); // Clamped to 15%
  });
}
