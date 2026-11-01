import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/patient/games/common/game_intro_screen.dart';
import 'package:neuroverse_app/features/patient/games/common/ner_illustrations.dart';
import 'package:neuroverse_app/features/patient/voice/voice_mode_screen.dart';

class FakeVoiceService extends VoiceService {
  @override
  Future<bool> startListening(Function(String) onResult, {Function(String)? onPartialResult, String? lang}) async {
    return true;
  }

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {}

  @override
  Future<void> speakKey(String audioKey, {String lang = 'hi', String? fallbackText, bool wait = false}) async {}
}

class FakeHiveService extends HiveService {
  @override
  int getGameDifficulty(String gameId) => 1;
}

void main() {
  Widget createTestWidget({
    required Widget child,
    required AppProvider appProvider,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
        Provider<VoiceService>(create: (_) => FakeVoiceService()),
        Provider<HiveService>(create: (_) => FakeHiveService()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Game Instruction Screens Localization Tests', () {
    testWidgets('Memory Match How-to-Play updates to Hindi when userLanguage is Hindi', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Hindi';

      await tester.pumpWidget(createTestWidget(
        child: const GameIntroScreen(
          title: 'Memory Match',
          description: 'Match pairs of nature & tea garden symbols hidden behind tiles.',
          challengeCount: 2,
          visual: GameHubVisual.memoryMatch,
          gameWidget: Text('Active Memory Match Game Screen'),
        ),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify Hindi title and description
      expect(find.text('कार्ड मैच'), findsWidgets);
      expect(find.text('टाइल के पीछे छिपे चाय बागान व प्रकृति प्रतीकों के जोड़े मिलाएं।'), findsOneWidget);

      // Verify Hindi cultural theme badge
      expect(find.text('🌸 असम चाय बागान संस्करण'), findsOneWidget);

      // Verify Hindi How to Play header and steps
      expect(find.text('कैसे खेलें'), findsOneWidget);
      expect(find.text('बोर्ड पर पत्ते उल्टे रखे जाएंगे।'), findsOneWidget);
      expect(find.text('प्रतीकों को देखने के लिए किन्हीं दो पत्तों पर टैप करें।'), findsOneWidget);
      expect(find.text('समाप्त करने के लिए सभी समान जोड़ों को मिलाएं।'), findsOneWidget);

      // Verify Hindi Start Game button
      expect(find.text('खेल शुरू करें'), findsOneWidget);
    });

    testWidgets('Pattern Path How-to-Play updates to Bengali when userLanguage is Bengali', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Bengali';

      await tester.pumpWidget(createTestWidget(
        child: const GameIntroScreen(
          title: 'Pattern Path',
          description: 'Memorize the stones and trace the sacred root bridge trail.',
          challengeCount: 3,
          visual: GameHubVisual.patternPath,
          gameWidget: Text('Active Pattern Path Game Screen'),
        ),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify Bengali title and description
      expect(find.text('প্যাটার্ন পাথ'), findsWidgets);
      expect(find.text('উজ্জ্বল পাথর মনে রাখুন এবং জীবন্ত রুট ব্রিজের পথ অনুসরণ করুন।'), findsOneWidget);

      // Verify Bengali theme badge
      expect(find.text('🌱 লিভিং রুট ব্রিজ ট্রেল (মেঘালয়)'), findsOneWidget);

      // Verify Bengali steps
      expect(find.text('পথ বরাবর জ্বলন্ত পাথরগুলি লক্ষ্য করুন।'), findsOneWidget);
      expect(find.text('পাথরগুলির ক্রম মনোযোগ দিয়ে মনে রাখুন।'), findsOneWidget);
      expect(find.text('একই ক্রমে পাথরগুলিতে ট্যাপ করুন।'), findsOneWidget);
    });

    testWidgets('Face Recall How-to-Play updates to Assamese when userLanguage is Assamese', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Assamese';

      await tester.pumpWidget(createTestWidget(
        child: const GameIntroScreen(
          title: 'Face Recall',
          description: 'Recognize your family members and friends by listening to their name and relation.',
          challengeCount: 5,
          visual: GameHubVisual.faceRecall,
          gameWidget: Text('Active Face Recall Game Screen'),
        ),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify Assamese title, description, and badge
      expect(find.text('মুখ চিনি পাওক'), findsWidgets);
      expect(find.text('নাম আৰু সম্পৰ্ক শুনি আপোনাৰ পৰিয়াল আৰু বন্ধুসকলৰ ছবি চিনাক্ত কৰক।'), findsOneWidget);
      expect(find.text('👨‍👩‍👧 পাৰিবাৰিক এলবাম'), findsOneWidget);

      // Verify Assamese steps
      expect(find.text('স্ক্ৰীণত দেখুওৱা বা কোৱা নাম আৰু সম্পৰ্ক শুনক।'), findsOneWidget);
      expect(find.text('দেখুওৱা পৰিয়াল আৰু বন্ধুসকলৰ ছবিবোৰ মনোযোগেৰে চাওক।'), findsOneWidget);
      expect(find.text('পইণ্ট পাবলৈ সঠিক ব্যক্তিৰ ফটোখনত স্পৰ্শ কৰক।'), findsOneWidget);
    });

    testWidgets('Memory Recall How-to-Play updates to Mizo when userLanguage is Mizo', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Mizo';

      await tester.pumpWidget(createTestWidget(
        child: const GameIntroScreen(
          title: 'Memory Recall',
          description: 'Memorize North-East cultural images and recall them accurately.',
          challengeCount: 2,
          visual: GameHubVisual.memoryRecall,
          gameWidget: Text('Active Memory Recall Game Screen'),
        ),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify Mizo title, description, and badge
      expect(find.text('Object Finder'), findsWidgets);
      expect(find.text('Chhim-chhak zia-rang lemte hre reng la, sawi chhuak rawh.'), findsOneWidget);
      expect(find.text('🏔️ North-East Ziarang Ri'), findsOneWidget);

      // Verify Mizo steps
      expect(find.text('Puk zia-rang lem card tlem a lo lang ang.'), findsOneWidget);
      expect(find.text('Vawng reng turin hun i duh zat hmang la, "Ka inpeih e" tih hmet rawh.'), findsOneWidget);
      expect(find.text('I lem hriat reng dik takte chu thlang rawh.'), findsOneWidget);
    });
  });

  group('Voice Assistant Written UI Localization Tests', () {
    testWidgets('Voice Assistant written UI renders in Hindi while voiceLanguage remains English', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Hindi';
      appProvider.voiceLanguage = 'English'; // Completely independent

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify top tagline in Hindi
      expect(find.text('एक उज्जवल मन, एक सुखद कल'), findsOneWidget);

      // Verify Status Pill in Hindi
      expect(find.text('सुन रहे हैं...'), findsOneWidget);
      expect(find.text('अब बोलिए, मैं मदद के लिए यहाँ हूँ'), findsOneWidget);

      // Verify Prompt Heading in Hindi
      expect(find.text('मैं आपकी क्या मदद कर सकता हूँ?'), findsOneWidget);
      expect(find.text('आप खेल, अनुस्मारक, अपनी दिनचर्या या कुछ भी पूछ सकते हैं।'), findsOneWidget);

      // Verify Bottom Guidance Card in Hindi
      expect(find.text('सहज भाव से बोलिए'), findsOneWidget);
      expect(find.text('मैं सुन रहा हूँ...'), findsOneWidget);

      // Verify voiceLanguage was NOT modified by userLanguage
      expect(appProvider.voiceLanguage, equals('English'));
      expect(appProvider.userLanguage, equals('Hindi'));
    });

    testWidgets('Voice Assistant written UI renders in Bengali when userLanguage is Bengali', (tester) async {
      final appProvider = AppProvider();
      appProvider.userLanguage = 'Bengali';
      appProvider.voiceLanguage = 'English';

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
      ));
      await tester.pump();

      // Verify Bengali written UI elements
      expect(find.text('একটি উজ্জ্বল মন, একটি সুন্দর আগামীকাল'), findsOneWidget);
      expect(find.text('শুনছি...'), findsOneWidget);
      expect(find.text('এখন বলুন, আমি আপনাকে সাহায্য করতে প্রস্তুত'), findsOneWidget);
      expect(find.text('আমি আপনাকে কীভাবে সাহায্য করতে পারি?'), findsOneWidget);
      expect(find.text('স্বাভাবিকভাবে কথা বলুন'), findsOneWidget);
      expect(find.text('আমি শুনছি...'), findsOneWidget);

      expect(appProvider.voiceLanguage, equals('English'));
      expect(appProvider.userLanguage, equals('Bengali'));
    });
  });
}
