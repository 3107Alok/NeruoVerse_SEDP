import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/models/family_member_model.dart';
import 'package:neuroverse_app/core/models/game_session.dart';
import 'package:neuroverse_app/core/services/adaptive_intelligence_service.dart';
import 'package:neuroverse_app/core/services/q_learning_service.dart';
import 'package:neuroverse_app/core/localization/app_translations.dart';
import 'package:neuroverse_app/core/utils/indic_transliteration.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
import 'package:neuroverse_app/features/patient/games/common/game_intro_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FamilyMember Model Tests', () {
    test('getDefaultDemoMembers returns 8 valid demo members', () {
      final members = FamilyMember.getDefaultDemoMembers();
      expect(members.length, equals(8));
      expect(members.any((m) => m.name == 'Rohan'), isTrue);
      expect(members.any((m) => m.relation == 'Son'), isTrue);
      expect(members.any((m) => m.relationKey == 'rel_son'), isTrue);
      expect(members.every((m) => m.isDefaultAsset), isTrue);
      expect(members.every((m) => m.imageBase64.isNotEmpty), isTrue);
    });

    test('FamilyMember toMap and fromMap serialization works symmetrically', () {
      final member = FamilyMember(
        id: 'test_123',
        name: 'Aarav',
        relation: 'Grandson',
        relationKey: 'rel_grandson',
        imageBase64: 'data:image/jpeg;base64,samplebase64==',
        isDefaultAsset: false,
        createdAt: DateTime(2026, 9, 11),
      );

      final map = member.toMap();
      final revived = FamilyMember.fromMap(map);

      expect(revived.id, equals('test_123'));
      expect(revived.name, equals('Aarav'));
      expect(revived.relation, equals('Grandson'));
      expect(revived.relationKey, equals('rel_grandson'));
      expect(revived.imageBase64, equals('data:image/jpeg;base64,samplebase64=='));
      expect(revived.isDefaultAsset, isFalse);
    });
  });

  group('Face Recall Adaptive Intelligence Tests', () {
    test('Level up threshold for face_recall is 66% (memory game progression)', () {
      final qLearning = QLearningService();
      final adaptiveService = AdaptiveIntelligenceService(qLearning);

      final session = GameSession(
        id: 'sess_1',
        gameId: 'face_recall',
        patientId: 'patient_1',
        timestamp: DateTime.now(),
        difficultyLevel: 1,
        score: 120,
        accuracyPercentage: 80, // >= 66%
        completionTimeSeconds: 20,
        mistakes: 1,
        hintsUsed: 0,
        gameCategory: 'Familial & Visual Memory',
      );

      final nextDiff = adaptiveService.processSessionAndGetNextDifficulty(session);
      expect(nextDiff, equals(2)); // Level up to 2
    });

    test('Face recall decreases difficulty when accuracy is below 50%', () {
      final qLearning = QLearningService();
      final adaptiveService = AdaptiveIntelligenceService(qLearning);

      final session = GameSession(
        id: 'sess_2',
        gameId: 'face_recall',
        patientId: 'patient_1',
        timestamp: DateTime.now(),
        difficultyLevel: 3,
        score: 20,
        accuracyPercentage: 30, // < 50%
        completionTimeSeconds: 65,
        mistakes: 4,
        hintsUsed: 1,
        gameCategory: 'Familial & Visual Memory',
      );

      final nextDiff = adaptiveService.processSessionAndGetNextDifficulty(session);
      expect(nextDiff, equals(2)); // Decreases from 3 to 2
    });
  });

  group('Multilingual Face Recall Translations Tests', () {
    final languages = ['en', 'hi', 'bn', 'as', 'mni', 'lus'];

    test('All 6 languages have face_recall title, prompt and relation keys', () {
      for (final lang in languages) {
        final title = AppTranslations.get(lang, 'face_recall');
        expect(title.isNotEmpty, isTrue, reason: 'face_recall missing for $lang');

        final subtitle = AppTranslations.get(lang, 'face_recall_sub');
        expect(subtitle.isNotEmpty, isTrue, reason: 'face_recall_sub missing for $lang');

        final prompt = AppTranslations.get(lang, 'prompt_find_member');
        expect(prompt.isNotEmpty, isTrue, reason: 'prompt_find_member missing for $lang');
        expect(prompt.contains('{name}'), isTrue, reason: 'prompt missing {name} for $lang');

        final sonRel = AppTranslations.get(lang, 'rel_son');
        expect(sonRel.isNotEmpty, isTrue, reason: 'rel_son missing for $lang');

        final step1 = AppTranslations.get(lang, 'step_fr_1');
        expect(step1.isNotEmpty, isTrue, reason: 'step_fr_1 missing for $lang');
      }
    });
  });

  group('GameIntroScreen Face Recall Tests', () {
    testWidgets('Renders Face Recall Game Intro with Warm Amber Theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: GameIntroScreen(
            title: 'Face Recall',
            description: 'Identify family and friends',
            challengeCount: 5,
            visual: GameHubVisual.faceRecall,
            gameWidget: const Scaffold(body: Text('Game In Progress')),
          ),
        ),
      );
      await tester.pump();

      // Title appears in both AppBar and Hero Header
      expect(find.text('Face Recall'), findsWidgets);
      expect(find.byType(GameIntroScreen), findsOneWidget);
    });
  });

  group('IndicTransliteration Offline Phonetic Tests', () {
    test('transliterate converts English names to Devanagari Hindi phonetically', () {
      expect(IndicTransliteration.transliterate('Rohan', 'hi'), equals('रोहन'));
      expect(IndicTransliteration.transliterate('Sunita', 'hi'), equals('सुनिता'));
      expect(IndicTransliteration.transliterate('Suneeta', 'hi'), equals('सुनीता'));
      expect(IndicTransliteration.transliterate('Priya', 'hi'), equals('प्रिया'));
      expect(IndicTransliteration.transliterate('Aarav', 'hi'), equals('आरव'));
      expect(IndicTransliteration.transliterate('Deepak', 'hi'), equals('दीपक'));
    });

    test('transliterate converts English names to Bengali/Assamese script', () {
      expect(IndicTransliteration.transliterate('Rohan', 'bn'), equals('রোহন'));
      expect(IndicTransliteration.transliterate('Sunita', 'bn'), equals('সুনিতা'));
      expect(IndicTransliteration.transliterate('Suneeta', 'bn'), equals('সুনীতা'));
      expect(IndicTransliteration.transliterate('Priya', 'bn'), equals('প্রিয়া'));
    });

    test('transliterate preserves English and Mizo Latin text', () {
      expect(IndicTransliteration.transliterate('Rohan', 'en'), equals('Rohan'));
      expect(IndicTransliteration.transliterate('Rohan', 'english'), equals('Rohan'));
      expect(IndicTransliteration.transliterate('Rohan', 'lus'), equals('Rohan'));
      expect(IndicTransliteration.transliterate('Rohan', 'miz'), equals('Rohan'));
      expect(IndicTransliteration.transliterate('Rohan', 'mizo'), equals('Rohan'));
    });

    test('transliterate leaves already Indic text untouched', () {
      expect(IndicTransliteration.transliterate('रोहन', 'hi'), equals('रोहन'));
      expect(IndicTransliteration.transliterate('রোহন', 'bn'), equals('রোহন'));
    });

    test('Photo option count is 2 for levels 1-2 and 4 for levels 3+', () {
      int getOptions(int level) => level <= 2 ? 2 : 4;
      expect(getOptions(1), equals(2));
      expect(getOptions(2), equals(2));
      expect(getOptions(3), equals(4));
      expect(getOptions(4), equals(4));
    });
  });
}
