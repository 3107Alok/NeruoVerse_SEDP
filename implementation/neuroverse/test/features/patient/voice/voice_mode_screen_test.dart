import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:neuroverse_app/providers/app_provider.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';
import 'package:neuroverse_app/data/local/hive_service.dart';
import 'package:neuroverse_app/features/patient/voice/voice_mode_screen.dart';
import 'package:neuroverse_app/features/patient/games/common/game_intro_screen.dart';

class FakeVoiceService extends VoiceService {
  bool isListeningStarted = false;
  bool isListeningStopped = false;
  Function(String)? listeningCallback;
  String? lastSpokenKey;
  String? lastSpokenText;
  String? lastSpokenLang;

  @override
  Future<bool> startListening(Function(String) onResult, {Function(String)? onPartialResult, String? lang}) async {
    isListeningStarted = true;
    listeningCallback = onResult;
    return true;
  }

  @override
  Future<void> stopListening() async {
    isListeningStopped = true;
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<void> speak(String text, {String? lang, bool wait = false}) async {
    lastSpokenText = text;
    lastSpokenLang = lang;
  }

  @override
  Future<void> speakKey(String audioKey, {String lang = 'hi', String? fallbackText, bool wait = false}) async {
    lastSpokenKey = audioKey;
    lastSpokenText = fallbackText;
    lastSpokenLang = lang;
  }
}

class FakeHiveService extends HiveService {
  @override
  int getGameDifficulty(String gameId) => 1;
}

void main() {
  Widget createTestWidget({
    required Widget child,
    required AppProvider appProvider,
    FakeVoiceService? voiceService,
  }) {
    return MultiProvider(
      providers: [
        Provider<VoiceService>(create: (_) => voiceService ?? FakeVoiceService()),
        Provider<HiveService>(create: (_) => FakeHiveService()),
        ChangeNotifierProvider<AppProvider>.value(value: appProvider),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('VoiceModeScreen Redesign Tests', () {
    testWidgets('Renders top bar with Close button, centered NeuroVerse branding, and Help button', (tester) async {
      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Check Close button is present
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Verify top-right Help (?) icon is present
      expect(find.byIcon(Icons.help_outline_rounded), findsOneWidget);

      // Tap Help icon to open Help dialog
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify dialog header and content are displayed
      expect(find.text('Voice Assistant Guide'), findsOneWidget);
      expect(find.text('Speak any phrase below to hear the assistant’s voice reply:'), findsOneWidget);
      expect(find.text('💬 Daily Questions & Conversations (Speak & Hear Reply)'), findsOneWidget);
      expect(find.text('🎮 Cognitive Games (Speak to Launch)'), findsOneWidget);
      expect(find.text('“Start Card Match”'), findsOneWidget);

      // Close dialog
      await tester.ensureVisible(find.text('Close'));
      await tester.pump();
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Re-open dialog and verify top cross button closes it
      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.byKey(const Key('voice_help_dialog_close_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_help_dialog_close_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Voice Assistant Guide'), findsNothing);

      // Check NeuroVerse Branding, App Icon asset, & Tagline
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/app_icon.jpg'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/voice_botanical_top_right.png'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/voice_botanical_left.png'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/voice_botanical_right.png'), findsOneWidget);
      expect(find.text('NeuroVerse'), findsOneWidget);
      expect(find.text('A brighter mind, a kinder tomorrow'), findsOneWidget);
    });

    testWidgets('Renders status pill, clean centered microphone, prompt section, and bottom card', (tester) async {
      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Check Status Pill
      expect(find.text('Listening...'), findsOneWidget);
      expect(find.text('Speak now, I’m here to help'), findsOneWidget);

      // Check Central Microphone Icon
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // Verify "Small Questions Big Support" and heart icon are completely removed
      expect(find.byIcon(Icons.favorite_rounded), findsNothing);
      expect(find.textContaining('Small Questions'), findsNothing);

      // Check Prompt
      expect(find.text('How can I help you?'), findsOneWidget);
      expect(find.text('You can ask about games, reminders,\nyour day, or anything else.'), findsOneWidget);

      // Check Bottom Guidance Card
      expect(find.byIcon(Icons.spa_rounded), findsOneWidget);
      expect(find.text('Just speak naturally'), findsOneWidget);
    });

    testWidgets('Tapping Close button pops the screen', (tester) async {
      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).push(MaterialPageRoute(
                  builder: (_) => MultiProvider(
                    providers: [
                      Provider<VoiceService>(create: (_) => fakeVoice),
                      Provider<HiveService>(create: (_) => FakeHiveService()),
                      ChangeNotifierProvider<AppProvider>.value(value: appProvider),
                    ],
                    child: const VoiceModeScreen(),
                  ),
                ));
              },
              child: const Text('Open Voice'),
            ),
          ),
        ),
      ));

      // Open VoiceModeScreen
      await tester.tap(find.text('Open Voice'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('NeuroVerse'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify back on parent screen
      expect(find.text('Open Voice'), findsOneWidget);
      expect(find.text('NeuroVerse'), findsNothing);
    });

    testWidgets('Responsive test on narrow viewport (360x640) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(360 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check for zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Responsive test on small viewport (320x568) with zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check for zero RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('Recognizes Devanagari conversational phrases and triggers corresponding audio keys', (tester) async {
      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      expect(fakeVoice.listeningCallback, isNotNull);

      // 1. "क्या आपने चाय पी ली?" triggers talk_tea
      fakeVoice.listeningCallback!("क्या आपने चाय पी ली?");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('talk_tea'));
      expect(fakeVoice.lastSpokenText, contains('कड़क चाय'));

      // Wait for voice processing to complete
      await tester.pump(const Duration(milliseconds: 500));

      // 2. "मुझे एक चुटकुला सुनाओ" triggers talk_joke
      fakeVoice.listeningCallback!("मुझे एक चुटकुला सुनाओ");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('talk_joke'));
      expect(fakeVoice.lastSpokenText, contains('डॉक्टर ने कहा'));

      // Wait for voice processing to complete
      await tester.pump(const Duration(milliseconds: 500));

      // 3. "आप कैसे हैं?" triggers how_are_you
      fakeVoice.listeningCallback!("आप कैसे हैं?");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('मैं बिल्कुल ठीक हूँ'));

      // Wait for voice processing to complete
      await tester.pump(const Duration(milliseconds: 500));

      // 4. "मुझे घबराहट हो रही है" triggers calm_anxiety
      fakeVoice.listeningCallback!("मुझे घबराहट हो रही है");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('calm_anxiety'));
      expect(fakeVoice.lastSpokenText, contains('शांत हो जाइए'));
    });

    testWidgets('Recognizes game launch phrases and navigates to GameIntroScreen', (tester) async {
      final appProvider = AppProvider();
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // "ऑब्जेक्ट फाइंडर ओपन करो" triggers open_object_finder
      fakeVoice.listeningCallback!("ऑब्जेक्ट फाइंडर ओपन करो");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('open_object_finder'));
      expect(fakeVoice.lastSpokenText, contains('ऑब्जेक्ट फाइंडर'));

      // Pump 2.5s for game launch navigation
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.byType(GameIntroScreen), findsOneWidget);
    });

    testWidgets('Responds in English when user speaks English, even if settings voice language is Hindi', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('hi');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      expect(fakeVoice.listeningCallback, isNotNull);

      // User speaks English
      fakeVoice.listeningCallback!("Hello, how are you today?");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('doing great'));
    });

    testWidgets('Responds in English when user speaks English phrases transcribed phonetically by Hindi STT', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('hi');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      expect(fakeVoice.listeningCallback, isNotNull);

      // Hindi STT transcribed English sentence phonetically into Devanagari
      fakeVoice.listeningCallback!("हाउ आर यू");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('doing great'));
      expect(fakeVoice.lastSpokenLang, equals('en'));
    });

    testWidgets('Responds in Hindi when user speaks Hindi, even if settings voice language is English', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('en');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      expect(fakeVoice.listeningCallback, isNotNull);

      // User speaks Hindi in Devanagari
      fakeVoice.listeningCallback!("नमस्ते आप कैसे हो");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('मैं बिल्कुल ठीक हूँ'));
      expect(fakeVoice.lastSpokenLang, equals('hi'));

      // User speaks Hindi in Hinglish (transcribed by English STT)
      fakeVoice.listeningCallback!("namaste kaise ho");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('मैं बिल्कुल ठीक हूँ'));
      expect(fakeVoice.lastSpokenLang, equals('hi'));
    });

    testWidgets('Responds in Bengali when user speaks Bengali, independent of voice settings', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('en');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Bengali speech
      fakeVoice.listeningCallback!("নমস্কার কেমন আছেন");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('আমি খুব ভালো আছি'));
      expect(fakeVoice.lastSpokenLang, equals('bn'));
    });

    testWidgets('Responds in Assamese when user speaks Assamese', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('en');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Assamese speech with distinct characters 'ৰ'
      fakeVoice.listeningCallback!("নমস্কাৰ কেনে আছে");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('মই বঢ়িয়া আছোঁ'));
      expect(fakeVoice.lastSpokenLang, equals('as'));
    });

    testWidgets('Responds in Manipuri when user speaks Manipuri', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('en');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Manipuri speech
      fakeVoice.listeningCallback!("খুরুমজরি করম্না তৌরি");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('ঐ য়াম্না ফরে'));
      expect(fakeVoice.lastSpokenLang, equals('mni'));
    });

    testWidgets('Responds in Mizo when user speaks Mizo', (tester) async {
      final appProvider = AppProvider()..setVoiceLanguage('hi');
      final fakeVoice = FakeVoiceService();

      await tester.pumpWidget(createTestWidget(
        child: const VoiceModeScreen(),
        appProvider: appProvider,
        voiceService: fakeVoice,
      ));
      await tester.pump();

      // Mizo speech
      fakeVoice.listeningCallback!("Chibai engtin nge i awm");
      await tester.pump(const Duration(milliseconds: 400));
      expect(fakeVoice.lastSpokenKey, equals('how_are_you'));
      expect(fakeVoice.lastSpokenText, contains('Ka tha lutuk e'));
      expect(fakeVoice.lastSpokenLang, equals('miz'));
    });
  });
}

