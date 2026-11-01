import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ner_illustrations.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/voice_service.dart';

class _GameIntroTheme {
  final GameHubVisual visual;
  final Color primaryColor;
  final Color cardBg;
  final Color borderColor;
  final Color badgeBg;
  final Color badgeText;
  final String defaultThemeTag;
  final IconData howToPlayIcon;

  const _GameIntroTheme({
    required this.visual,
    required this.primaryColor,
    required this.cardBg,
    required this.borderColor,
    required this.badgeBg,
    required this.badgeText,
    required this.defaultThemeTag,
    required this.howToPlayIcon,
  });
}

class GameIntroScreen extends StatefulWidget {
  final String title;
  final String description;
  final int challengeCount;
  final IconData icon;
  final Widget? gameWidget;
  final Widget Function()? gameBuilder;
  final String? themeTag;
  final String? themeSubtitle;
  final List<String>? howToPlaySteps;
  final GameHubVisual? visual;

  const GameIntroScreen({
    super.key,
    required this.title,
    required this.description,
    required this.challengeCount,
    this.icon = Icons.psychology_rounded,
    this.gameWidget,
    this.gameBuilder,
    this.themeTag,
    this.themeSubtitle,
    this.howToPlaySteps,
    this.visual,
  }) : assert(gameWidget != null || gameBuilder != null, 'Either gameWidget or gameBuilder must be provided');

  @override
  State<GameIntroScreen> createState() => _GameIntroScreenState();
}

class _GameIntroScreenState extends State<GameIntroScreen> {
  VoiceService? _voiceService;
  Timer? _speechTimer;
  bool _isNavigatingToGame = false;

  @override
  void initState() {
    super.initState();
    // Allow route transition animation to settle so audio focus and speech trigger cleanly
    _speechTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _speakInstructions();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceService = context.read<VoiceService>();
    } catch (_) {
      _voiceService = null;
    }
  }

  @override
  void dispose() {
    _speechTimer?.cancel();
    if (!_isNavigatingToGame) {
      _voiceService?.stopSpeaking();
    }
    super.dispose();
  }

  void _speakInstructions() {
    if (!mounted) return;
    try {
      VoiceService? voice = _voiceService;
      if (voice == null) {
        try {
          voice = context.read<VoiceService>();
          _voiceService = voice;
        } catch (_) {}
      }
      if (voice == null) return;

      final v = _determineVisual();
      String lang = 'hi';
      try {
        final appProv = context.read<AppProvider>();
        lang = appProv.voiceLanguage ?? appProv.userLanguage ?? 'hi';
      } catch (_) {}
      final cleanLang = AppTranslations.normalizeLangCode(lang);

      // Use studio pre-recorded Indian audio key for game starting instructions
      String audioKey = '';
      String fallbackText = '';
      switch (v) {
        case GameHubVisual.faceRecall:
          audioKey = 'intro_face_recall';
          if (cleanLang == 'hi') {
            fallbackText = "फेस रिकॉल खेलने का तरीका: स्क्रीन पर दिखाए गए नाम और रिश्ते को सुनें। परिवार की तस्वीरों को ध्यान से देखें। पूछे गए सदस्य की तस्वीर पर टैप करें!";
          } else if (cleanLang == 'bn') {
            fallbackText = "ফেস রিকল খেলার নিয়ম: স্ক্রিনে নাম ও সম্পর্ক শুনুন। পরিবারের ছবিগুলি মনোযোগ দিয়ে দেখুন। সঠিক ব্যক্তির ছবিতে ট্যাপ করুন!";
          } else if (cleanLang == 'as') {
            fallbackText = "ফেচ ৰিকল খেলৰ নিয়ম: স্ক্ৰীনত নাম আৰু সম্পৰ্ক শুনক। পৰিয়ালৰ ছবিবোৰ মনোযোগেৰে চাওক। সঠিক ব্যক্তিৰ ছবিত টেপ কৰক!";
          } else if (cleanLang == 'mni') {
            fallbackText = "ফেস রিকল শান্নবগী নিয়ম: মমিং অমসুং মরী নীংথিনা তাবীয়ু। ইমুংগী ফোতোশিং নীংথিনা য়েংউ। চপ চাবা মীওই অদুগী ফোতোদা থম্বীয়ু!";
          } else if (cleanLang == 'miz') {
            fallbackText = "Face Recall khelh dan: Screen a hming leh inlaichinna lo lang kha ngaihthlak rawh. Thlalak en la, an sawi tak kha thlang chhuak rawh le!";
          } else {
            fallbackText = "How to play Face Recall: Listen to the name and relation shown on screen. Look carefully at the family photos displayed. Tap the photo of the requested person to earn points!";
          }
          break;
        case GameHubVisual.memoryMatch:
          audioKey = 'intro_card_match';
          if (cleanLang == 'hi') {
            fallbackText = "कार्ड मैच खेलने का तरीका: बोर्ड पर पत्ते उल्टे रखे जाएंगे। प्रतीकों को देखने के लिए किन्हीं दो पत्तों पर टैप करें। जीतने के लिए सभी समान जोड़ों को मिलाएं!";
          } else if (cleanLang == 'bn') {
            fallbackText = "কার্ড ম্যাচ খেলার নিয়ম: বোর্ডে কার্ডগুলি উল্টো করে রাখা হবে। প্রতীক দেখতে দুটি কার্ডে ট্যাপ করুন। শেষ করতে সমস্ত জোড়া মিলিয়ে দিন!";
          } else if (cleanLang == 'as') {
            fallbackText = "কাৰ্ড মেচ খেলৰ নিয়ম: ব'ৰ্ডত কাৰ্ডবোৰ ওলোটাকৈ ৰখা হ'ব। প্ৰতীক চাবলৈ দুখন কাৰ্ডত টেপ কৰক। শেষ কৰিবলৈ সকলো যোৰ মিলাই দিয়ক!";
          } else if (cleanLang == 'mni') {
            fallbackText = "কার্দ ম্যাচ শান্নবগী নিয়ম: বোর্দতা কার্দশিং অদু খুপতুনা থমগনি। শক্তম য়েংনবা কার্দ অনিদা থম্বীয়ু। লোইশিন্নবা কার্দ পুম্নমক চপ চানা চান্নহল্লু!";
          } else if (cleanLang == 'miz') {
            fallbackText = "Card Match khelh dan: Card-te chu a khup zawngin dah a ni ang. A lem en turin card pahnih hmet la, a inmil zawng zawng zawng chhuak rawh le!";
          } else {
            fallbackText = "How to play Card Match: Cards are placed face down on the board. Tap two cards to flip and reveal their symbols. Match all identical pairs to finish!";
          }
          break;
        case GameHubVisual.patternPath:
          audioKey = 'intro_pattern_path';
          if (cleanLang == 'hi') {
            fallbackText = "पैटर्न पाथ खेलने का तरीका: रास्ते में चमकते पत्थरों को ध्यान से देखें। पत्थरों के क्रम को अच्छी तरह याद रखें। उसी क्रम में पत्थरों पर टैप करके रास्ता पूरा करें!";
          } else if (cleanLang == 'bn') {
            fallbackText = "প্যাটার্ন পাথ খেলার নিয়ম: পাথরের আলো জ্বলা মনোযোগ দিয়ে দেখুন। ক্রমটি মনে রাখুন এবং একই ক্রমে ট্যাপ করে পথ সম্পূর্ণ করুন!";
          } else if (cleanLang == 'as') {
            fallbackText = "পেটাৰ্ন পাথ খেলৰ নিয়ম: শিলৰ পোহৰ মনোযোগেৰে চাওক। ক্ৰমটো মনত ৰাখক আৰু একে ক্ৰমত টেপ কৰি পথ সম্পূৰ্ণ কৰক!";
          } else if (cleanLang == 'mni') {
            fallbackText = "প্যাটার্ন পাথ শান্নবগী নিয়ম: নোংশাংশিংগী মঙাল নীংথিনা য়েংউ। মথং মনাও নীংথিনা নিংশিংউ অমসুং চপ মান্ননা থম্বীয়ু!";
          } else if (cleanLang == 'miz') {
            fallbackText = "Pattern Path khelh dan: Lung eng kha ngun takin en la, a inrem dan vawng reng la, a indawtin hmet rawh le!";
          } else {
            fallbackText = "How to play Pattern Path: Watch the stones light up along the path. Remember the sequence carefully. Tap the stepping stones in the same order!";
          }
          break;
        case GameHubVisual.memoryRecall:
          audioKey = 'intro_object_finder';
          if (cleanLang == 'hi') {
            fallbackText = "ऑब्जेक्ट फाइंडर खेलने का तरीका: स्क्रीन पर चित्र कार्ड दिखेंगे। इन्हें ध्यान से याद कर लीजिए, फिर मैं तैयार हूँ दबाएं। याद किए गए सभी सही चित्रों को चुनिए!";
          } else if (cleanLang == 'bn') {
            fallbackText = "অবজেক্ট ফাইন্ডার খেলার নিয়ম: স্ক্রিনে ছবি কার্ড দেখতে পাবেন। মন দিয়ে সেগুলি মনে রাখুন, তারপর তৈরি বোতাম টিপুন। মনে রাখা সব সঠিক ছবি নির্বাচন করুন!";
          } else if (cleanLang == 'as') {
            fallbackText = "অবজেক্ট ফাইণ্ডাৰ খেলৰ নিয়ম: স্ক্ৰীনত ছবি কাৰ্ড দেখা পাব। মনোযোগেৰে মনত ৰাখক, তাৰ পিছত মই সাজু টিপক। মনত ৰখা সকলো সঠিক ছবি বাছক!";
          } else if (cleanLang == 'mni') {
            fallbackText = "অবজেক্ট ফাইন্ডার শান্নবগী নিয়ম: স্ক্রিন্দা ফোতো কাৰ্দ উগনি। নীংথিনা নিংশিংউ, অদুগা ঐ শেম-শারে নম্বীয়ু। নিংশিংবা ফোতোশিং খনউ!";
          } else if (cleanLang == 'miz') {
            fallbackText = "Object Finder khelh dan: Screen ah lemte a lo lang ang. Ngun takin vawng reng la, Ka inpeih e tih hmet la, i hriatreng lemte kha thlang chhuak rawh le!";
          } else {
            fallbackText = "How to play Object Finder: Illustration cards will appear on screen. Take your time to memorize them, then tap I'm Ready. Select all the correct images you memorized!";
          }
          break;
      }
      voice.speakKey(audioKey, lang: cleanLang, fallbackText: fallbackText);
    } catch (e) {
      debugPrint("GameIntroScreen: Voice error: $e");
    }
  }

  GameHubVisual _determineVisual() {
    if (widget.visual != null) return widget.visual!;
    final t = widget.title.toLowerCase();
    if (t.contains('face') || t.contains('चेहरा') || t.contains('মুখ') || t.contains('মাইখাঙ') || t.contains('hmel')) {
      return GameHubVisual.faceRecall;
    } else if ((t.contains('memory') && t.contains('match')) || t.contains('memory game') || t.contains('মেমরি') || t.contains('মেমো') || t.contains('মেচ')) {
      return GameHubVisual.memoryMatch;
    } else if (t.contains('pattern') || t.contains('path') || t.contains('প্যাটার্ন') || t.contains('পেটাৰ্ন') || t.contains('पैटर्न')) {
      return GameHubVisual.patternPath;
    }
    return GameHubVisual.memoryRecall;
  }

  _GameIntroTheme _resolveGameTheme(BuildContext context, GameHubVisual v, bool isDark) {
    switch (v) {
      case GameHubVisual.faceRecall:
        return _GameIntroTheme(
          visual: GameHubVisual.faceRecall,
          primaryColor: const Color(0xFFD97706), // Warm Amber Gold
          cardBg: isDark ? const Color(0xFF261E12) : const Color(0xFFFFFBEB),
          borderColor: isDark ? const Color(0xFF4E3816) : const Color(0xFFFDE68A),
          badgeBg: isDark ? const Color(0xFF382914) : const Color(0xFFFEF3C7),
          badgeText: isDark ? const Color(0xFFFFD54F) : const Color(0xFF92400E),
          defaultThemeTag: context.tr('tag_family_faces'),
          howToPlayIcon: Icons.family_restroom_rounded,
        );
      case GameHubVisual.memoryMatch:
        return _GameIntroTheme(
          visual: GameHubVisual.memoryMatch,
          primaryColor: const Color(0xFFBE185D), // Kopou orchid rose magenta
          cardBg: isDark ? const Color(0xFF24151C) : const Color(0xFFFFF5F7),
          borderColor: isDark ? const Color(0xFF4A1E2F) : const Color(0xFFFBCFE8),
          badgeBg: isDark ? const Color(0xFF351A25) : const Color(0xFFFCE7F3),
          badgeText: isDark ? const Color(0xFFF48FB1) : const Color(0xFF9D174D),
          defaultThemeTag: context.tr('tag_tea_estates'),
          howToPlayIcon: Icons.filter_vintage_rounded,
        );
      case GameHubVisual.patternPath:
        return _GameIntroTheme(
          visual: GameHubVisual.patternPath,
          primaryColor: const Color(0xFF2E7D32), // Lush forest / Living Root Green
          cardBg: isDark ? const Color(0xFF142418) : const Color(0xFFF0FDF4),
          borderColor: isDark ? const Color(0xFF1E4826) : const Color(0xFFBBF7D0),
          badgeBg: isDark ? const Color(0xFF1B3821) : const Color(0xFFDCFCE7),
          badgeText: isDark ? const Color(0xFFA5D6A7) : const Color(0xFF166534),
          defaultThemeTag: context.tr('tag_root_bridge'),
          howToPlayIcon: Icons.park_rounded,
        );

      case GameHubVisual.memoryRecall:
        return _GameIntroTheme(
          visual: GameHubVisual.memoryRecall,
          primaryColor: const Color(0xFF2563EB), // Heritage Azure Blue
          cardBg: isDark ? const Color(0xFF121F2D) : const Color(0xFFF0F7FF),
          borderColor: isDark ? const Color(0xFF1A3B60) : const Color(0xFFBFDBFE),
          badgeBg: isDark ? const Color(0xFF172D45) : const Color(0xFFDBEAFE),
          badgeText: isDark ? const Color(0xFF90CAF9) : const Color(0xFF1E40AF),
          defaultThemeTag: context.tr('tag_heritage_echoes'),
          howToPlayIcon: Icons.wb_sunny_rounded,
        );
    }
  }

  String _resolveThemeTag(BuildContext context, _GameIntroTheme gameTheme) {
    if (widget.themeTag != null &&
        widget.themeTag!.isNotEmpty &&
        widget.themeTag != '🌿 Assam Tea Estates Edition' &&
        widget.themeTag != '🌸 Assam Tea Estates Edition' &&
        widget.themeTag != '🌱 Living Root Bridge Trail (Meghalaya)' &&
        widget.themeTag != '🏔️ North-East Heritage Echoes') {
      return widget.themeTag!;
    }
    return gameTheme.defaultThemeTag;
  }

  String _resolveTitle(BuildContext context, GameHubVisual v) {
    if (widget.title.isNotEmpty &&
        widget.title != 'Face Recall' &&
        widget.title != 'Memory Match' &&
        widget.title != 'Card Match' &&
        widget.title != 'Memory Game' &&
        widget.title != 'Pattern Path' &&
        widget.title != 'Pattern Game' &&
        widget.title != 'Memory Recall' &&
        widget.title != 'Object Finder') {
      return widget.title;
    }
    switch (v) {
      case GameHubVisual.faceRecall:
        return context.tr('face_recall');
      case GameHubVisual.memoryMatch:
        return context.tr('memory_match');
      case GameHubVisual.patternPath:
        return context.tr('pattern_path');
      case GameHubVisual.memoryRecall:
        return context.tr('memory_recall');
    }
  }

  String _resolveDescription(BuildContext context, GameHubVisual v) {
    if (widget.description.isNotEmpty &&
        widget.description != 'Match pairs of nature & tea garden symbols hidden behind tiles.' &&
        widget.description != 'Memorize the stones and trace the sacred root bridge trail.' &&
        widget.description != 'Memorize illuminated stones and trace the root bridge trail.' &&
        widget.description != 'Memorize the path\nand repeat it.' &&
        widget.description != 'Remember the objects\nand answer the questions.' &&
        widget.description != 'Memorize North-East cultural words and recall them accurately.' &&
        widget.description != 'Memorize North-East cultural images and recall them accurately.' &&
        widget.description != 'Memorize cultural objects and find them accurately.' &&
        widget.description != 'Recognize your family members and friends by listening to their name and relation.') {
      return widget.description;
    }
    switch (v) {
      case GameHubVisual.faceRecall:
        return context.tr('desc_face_recall');
      case GameHubVisual.memoryMatch:
        return context.tr('desc_memory_match');
      case GameHubVisual.patternPath:
        return context.tr('desc_pattern_path');
      case GameHubVisual.memoryRecall:
        return context.tr('desc_memory_recall');
    }
  }

  List<String> _resolveSteps(BuildContext context, GameHubVisual v) {
    if (widget.howToPlaySteps != null && widget.howToPlaySteps!.isNotEmpty) return widget.howToPlaySteps!;
    switch (v) {
      case GameHubVisual.faceRecall:
        return [
          context.tr('step_fr_1'),
          context.tr('step_fr_2'),
          context.tr('step_fr_3'),
        ];
      case GameHubVisual.memoryMatch:
        return [
          context.tr('step_mm_1'),
          context.tr('step_mm_2'),
          context.tr('step_mm_3'),
        ];
      case GameHubVisual.patternPath:
        return [
          context.tr('step_pp_1'),
          context.tr('step_pp_2'),
          context.tr('step_pp_3'),
        ];
      case GameHubVisual.memoryRecall:
        return [
          context.tr('step_mr_1'),
          context.tr('step_mr_2'),
          context.tr('step_mr_3'),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final v = _determineVisual();
    final gameTheme = _resolveGameTheme(context, v, isDark);
    final resolvedThemeTag = _resolveThemeTag(context, gameTheme);
    final resolvedTitle = _resolveTitle(context, v);
    final resolvedDescription = _resolveDescription(context, v);
    final steps = _resolveSteps(context, v);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _voiceService?.stopSpeaking();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFBF9F5),
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              _voiceService?.stopSpeaking();
              Navigator.of(context).pop();
            },
          ),
          title: Text(
            resolvedTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 19,
              color: isDark ? Colors.white : const Color(0xFF1E2829),
            ),
          ),
          centerTitle: true,
        ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 18.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Culturally authentic pastel badge
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: gameTheme.badgeBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: gameTheme.borderColor,
                                width: 1.2,
                              ),
                            ),
                            child: Text(
                              resolvedThemeTag,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: gameTheme.badgeText,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 2. Large Game-Specific NER Illustration Hero Card
                        Center(
                          child: Container(
                            width: 120,
                            height: 120,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: gameTheme.cardBg,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: gameTheme.borderColor,
                                width: 1.5,
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: gameTheme.primaryColor.withValues(alpha: 0.08),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Center(
                              child: GameHubIllustration(
                                visual: gameTheme.visual,
                                size: 94,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // 3. Title & Description
                        Text(
                          resolvedTitle,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B3B36),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          resolvedDescription,
                          style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 22),

                        // 4. Clean "HOW TO PLAY" Steps Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white12 : gameTheme.borderColor.withValues(alpha: 0.8),
                              width: 1.5,
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    gameTheme.howToPlayIcon,
                                    size: 17,
                                    color: gameTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    context.tr('how_to_play'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: gameTheme.primaryColor,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Voice Repeat button
                                  InkWell(
                                    onTap: _speakInstructions,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: gameTheme.primaryColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: gameTheme.primaryColor.withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.volume_up_rounded,
                                            size: 15,
                                            color: gameTheme.primaryColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            context.tr('repeat_instruction'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: gameTheme.primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              ...steps.asMap().entries.map((entry) {
                                final index = entry.key + 1;
                                final text = entry.value;
                                final isLast = index == steps.length;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: isLast ? 0 : 14.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: gameTheme.badgeBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: gameTheme.borderColor.withValues(alpha: 0.8),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '$index',
                                            style: TextStyle(
                                              color: gameTheme.badgeText,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 3.0),
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white.withValues(alpha: 0.88) : const Color(0xFF2D3748),
                                              height: 1.38,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        // Spacer pushes button comfortably to bottom on tall screens
                        const Spacer(),
                        const SizedBox(height: 20),

                        // 5. Large Tactile "Start Game" Button
                        SizedBox(
                          height: 58,
                          child: ElevatedButton(
                            onPressed: () async {
                              _isNavigatingToGame = true;
                              _speechTimer?.cancel();
                              try {
                                await _voiceService?.stopSpeaking();
                              } catch (_) {}
                              if (!context.mounted) return;
                              final Widget targetGame = widget.gameBuilder != null
                                  ? widget.gameBuilder!()
                                  : widget.gameWidget!;
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(builder: (context) => targetGame),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gameTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_arrow_rounded, size: 30),
                                SizedBox(width: 8),
                                Text(
                                  context.tr('start_game'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}
