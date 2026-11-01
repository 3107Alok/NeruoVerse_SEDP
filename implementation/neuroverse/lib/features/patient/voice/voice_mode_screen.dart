import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/app_provider.dart';
import '../../../../core/services/voice_service.dart';
import '../../../../core/localization/app_translations.dart';
import '../../../../data/local/hive_service.dart' as app_hive;
import '../games/common/game_intro_screen.dart';
import '../games/common/ner_illustrations.dart';
import '../games/memory_match/memory_match_screen.dart';
import '../games/memory_recall/memory_recall_screen.dart';
import '../games/face_recall/face_recall_screen.dart';
import '../games/pattern_path/pattern_path_screen.dart';

class VoiceModeScreen extends StatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  State<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends State<VoiceModeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  String _spokenText = '';
  bool _isListening = false;
  bool _isAssistantSpeaking = false;
  bool _isProcessing = false;
  Timer? _autoListenTimer;
  VoiceService? _voiceService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vs = context.read<VoiceService>();
    if (_voiceService != vs) {
      _voiceService = vs;
      _voiceService!.onListeningStateChanged = (isListening) {
        if (!mounted) return;
        if (!isListening && !_isAssistantSpeaking && !_isProcessing) {
          setState(() {
            _isListening = false;
            _spokenText = context.tr('ready_to_listen');
          });
          _controller.stop();
          _controller.reset();
        } else if (isListening && !_isListening && !_isAssistantSpeaking && !_isProcessing) {
          setState(() {
            _isListening = true;
          });
          _controller.repeat(reverse: true);
        }
      };
    }
    if (_spokenText.isEmpty) {
      _spokenText = context.tr('speak_now');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isListening && !_isAssistantSpeaking) {
        _startListening();
      }
    }
  }

  Future<void> _startListening() async {
    _autoListenTimer?.cancel();
    final voiceService = context.read<VoiceService>();
    if (_isListening || _isAssistantSpeaking || _isProcessing || voiceService.isSpeaking) return;
    final appProvider = context.read<AppProvider>();
    final targetLang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';

    setState(() {
      _isListening = true;
      _isAssistantSpeaking = false;
      _spokenText = '...';
    });
    _controller.repeat(reverse: true);

    final started = await voiceService.startListening(
      (text) {
        _processVoiceText(text);
      },
      onPartialResult: (partial) {
        if (mounted && _isListening) {
          setState(() {
            _spokenText = '"$partial"';
          });
        }
      },
      lang: targetLang,
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _spokenText = context.tr('ready_to_listen');
      });
      _controller.stop();
      _controller.reset();
    }
  }

  String _detectInputLanguage(String text, {String fallback = 'hi'}) {
    final clean = text.trim();
    if (clean.isEmpty) return fallback;
    final lower = clean.toLowerCase();

    // 1. Check Eastern Indic Script (Bengali / Assamese / Manipuri)
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(clean)) {
      // 1A. Assamese distinct characters ('ৰ' U+09F0, 'ৱ' U+09F1) & distinct words
      if (clean.contains('ৰ') || clean.contains('ৱ') ||
          lower.contains('নমস্কাৰ') || lower.contains('কেনে') || lower.contains('আছোঁ') ||
          lower.contains('আছা') || lower.contains('ভালে') || lower.contains('খেলোঁ') ||
          lower.contains('ধেমেলীয়া') || lower.contains('চাহ') || lower.contains('আমনি') ||
          lower.contains('মৰমলগা') || lower.contains('বৰ') || lower.contains('ধুনীয়া') ||
          lower.contains('আৰম্ভ') || lower.contains('কৰক') || lower.contains('কৰোঁ')) {
        return 'as';
      }

      // 1B. Manipuri distinct words (in Bengali script)
      if (lower.contains('খুরুমজরি') || lower.contains('করম্না') || lower.contains('শান্নবা') ||
          lower.contains('শান্নসি') || lower.contains('মৈতৈ') || lower.contains('ঙসি') ||
          lower.contains('য়াম্না') || lower.contains('ফরে') || lower.contains('ফৈ') ||
          lower.contains('হৌরে') || lower.contains('হৌসিগে') || lower.contains('ৱারী') ||
          lower.contains('পোৎশক') || lower.contains('মাইখাঙ') || lower.contains('লম্বী') ||
          lower.contains('চান্নহল্লু') || lower.contains('নিংশিংউ') || lower.contains('ৱাগনু') ||
          lower.contains('থকলব্রা') || lower.contains('অদোম') || lower.contains('মোমোনোকনা')) {
        return 'mni';
      }

      // 1C. Standard Bengali
      return 'bn';
    }

    // 2. Check Devanagari script (Hindi vs Devanagari-transcribed English)
    if (RegExp(r'[\u0900-\u097F]').hasMatch(clean)) {
      // Distinct Hindi words that prove the sentence is Hindi even if a common greeting like "हेलो" is used
      final bool hasDistinctHindiWords = RegExp(r'(नमस्ते|प्रणाम|कैसी|कैसे|कैसा|हालचाल|चाय|नाश्ता|नास्ता|पीली|पी ली|पिया|पानी|खाना|चुटकुला|चुटकुले|हंसाओ|हँसाओ|हंसी|हँसी|मजाक|डर|घबराहट|परेशान|बेचैन|उदास|तारीफ|प्यारे|प्यारी|शाबाश|बढ़िया|बढिया|तैयार|शुरू|शुरु|चलो|खेलो|खेलना|पहचानो|पहचानिए|पहचानीय|परिवार|चेहरा|तस्वीर|चित्र|ढूंढो|ढूंढ|ढूँढ|खोजो|खोज|वस्तु|रास्ता|रास्ते|पत्थर|पुल|जोड़ी|जोड़े|ताश|अकेला|अकेली|थक|सुनाओ|सुनाइए|बताओ|बताइए|मदद|कहा|बताइए|करो|करेंगे|करूँ|हूँ|हैं|हो)').hasMatch(clean);

      // Distinct English phrases transcribed phonetically by Hindi STT
      final bool isDevanagariEnglish =
          lower.contains('हाउ आर यू') || lower.contains('हाउ आर यु') ||
          lower.contains('हू आर यू') || lower.contains('हू आर यु') ||
          lower.contains('गुड मॉर्निंग') || lower.contains('गुड इवर्निंग') ||
          lower.contains('गुड नाईट') || lower.contains('गुड आफ्टरनून') ||
          lower.contains('व्हाट कैन') || lower.contains('व्हाट इस') ||
          lower.contains('कैन यू') || lower.contains('टेल मी') ||
          lower.contains('हेल्प मी') || lower.contains('थैंक यू') ||
          lower.contains('थैंक्यू') || lower.contains('थैंक्स') ||
          lower.contains('आई ऍम') || lower.contains('आई एम') ||
          lower.contains('स्टार्ट गेम') || lower.contains('प्ले गेम') || lower.contains('ओपन गेम') ||
          lower.contains('स्टार्ट फेस') || lower.contains('फेस रिकॉल') || lower.contains('ओपन फेस') ||
          lower.contains('स्टार्ट कार्ड') || lower.contains('कार्ड मैच') || lower.contains('मेमोरी मैच') || lower.contains('ओपन कार्ड') ||
          lower.contains('स्टार्ट पैटर्न') || lower.contains('पैटर्न पाथ') || lower.contains('ओपन पैटर्न') ||
          lower.contains('स्टार्ट ऑब्जेक्ट') || lower.contains('ऑब्जेक्ट फाइंडर') || lower.contains('ओपन ऑब्जेक्ट') ||
          lower.contains('नाइस टू मीट') || lower.contains('व्हाट्स अप') ||
          ((lower == 'हेलो' || lower == 'हैलो' || lower == 'हाय' || lower == 'जोक' ||
            lower == 'कार्ड्स' || lower == 'गेम' || lower == 'फाइन' || lower == 'ओके' ||
            lower == 'श्योर' || lower == 'यस' || lower == 'नो') && !hasDistinctHindiWords);

      if (isDevanagariEnglish && !hasDistinctHindiWords) {
        return 'en';
      }

      return 'hi';
    }

    // 3. Latin script text: Mizo, Manipuri, Assamese, Bengali, Hinglish, or English

    // 3A. Mizo vocabulary in Latin script
    if (RegExp(r'\b(chibai|engtin|vawiin|thingpui|damlo|thluak|lutuk|hriatrengna|khawngaihin|lungngai|fiamthu|inmil|hmet|rawh|hmel|tan|khel|ning|suh|awm|thawk|fel|hlim|ka tha|ngaithla)\b', caseSensitive: false).hasMatch(lower)) {
      return 'miz';
    }

    // 3B. Romanized Manipuri
    if (RegExp(r'\b(khurumjari|karamna|touri|shannasi|shannaba|houre|meitei|ngasi|yamna|phare|waree|wari|thoklabra|fagi|phagi|waganu|maikhang|ningshingu|potshak|lambi)\b', caseSensitive: false).hasMatch(lower)) {
      return 'mni';
    }

    // 3C. Romanized Assamese
    if (RegExp(r'\b(nomoskar|kene|asa|aso|arombho|korok|chah|dhemeliya|amoni|napabo|mormologa|dhuniya)\b', caseSensitive: false).hasMatch(lower)) {
      return 'as';
    }

    // 3D. Romanized Bengali
    if (RegExp(r'\b(kemon|achen|acho|bhalo|achi|khela|korun|koutuk|bolun|dhonnobad|ekla|bhoy|shuru|korbo)\b', caseSensitive: false).hasMatch(lower)) {
      return 'bn';
    }

    // 3E. Hinglish (Hindi words in Latin script)
    final bool hasStrongHinglish = RegExp(r'\b(namaste|namaskar|pranam|kaise|kese|kaisi|kaisa|haal|chal|chai|chaha|nashta|nasta|peeli|peli|piya|pani|khana|kha|akela|akeli|shabaash|shabash|badiya|badhiya|pyare|pyari|haan|han|taiyar|shuru|chalo|chal|karo|kare|karoge|karna|sunao|suno|batao|bataiye|accha|achha|theek|thik|parivar|chehra|dost|madad|mera|meri|mere|mujhe|mujhko|tum|tumhara|aap|ap|hum|humara|bhai|yaar|yrr|pehechan|pahchan|dhundo|dhoond|rasta|patthar|pul|jodi|tash|udas|darr|dar|ghabrahat|ghabra|bechain|tension|pareshan|bolo|bol|raha|rahi|rahe|kuch|nahi|mat|acha|shukriya|dhanyawad|khel|khela|khelna|khelo|khelein|chalu|chalao|chutkula|kahani|kavita|dawai|tasveer|tasvir|mitra|baat|kisko|kiske|kisi|kyu|kyun|kab|kahan|kaha|kidhar|sahi|galat|kaun|dekho|dekh)\b', caseSensitive: false).hasMatch(lower);

    // 3F. Pure English phrases and vocabulary
    final bool isEnglish = RegExp(r'\b(how are you|who are you|good morning|good evening|good night|thank you|thanks|please|help me|start game|open game|face recall|card match|memory match|pattern path|object finder|tell me|joke|jokes|i am|what can you|what is|can you|play game|hello|hi|hey|awesome|wonderful|bored|boring|happy|sad|nervous|anxious|tea|fine|yes|no|sure|ok|okay)\b', caseSensitive: false).hasMatch(lower);

    if (hasStrongHinglish && !isEnglish) {
      return 'hi';
    }

    if (isEnglish) {
      return 'en';
    }

    if (hasStrongHinglish) {
      return 'hi';
    }

    // Check individual English vocabulary words
    if (RegExp(r'\b(hello|hi|hey|how|who|what|where|when|why|can|will|do|did|tell|say|play|game|games|start|open|face|recall|card|cards|match|matching|pattern|path|object|finder|family|friend|friends|photo|photos|bored|happy|sad|fine|calm|day|me|my|your|you|the|is|are|am)\b', caseSensitive: false).hasMatch(lower)) {
      return 'en';
    }

    // 4. Default fallback to app voice setting if nothing could be determined
    final cleanFallback = AppTranslations.normalizeLangCode(fallback);
    return cleanFallback;
  }

  Future<void> _processVoiceText(String text) async {
    if (!mounted || _isProcessing) return;
    _isProcessing = true;
    try {
      final voiceService = context.read<VoiceService>();

      // 1. Cancel any auto-listen timer and explicitly stop the microphone
      _autoListenTimer?.cancel();
      await voiceService.stopListening();
      if (!mounted) return;

      setState(() {
        _spokenText = '"$text"';
        _isListening = false;
        _isAssistantSpeaking = false;
      });
      _controller.stop();
      _controller.reset();

      // Brief processing delay
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;

      final appProvider = context.read<AppProvider>();
      final defaultVoiceLang = appProvider.voiceLanguage ?? appProvider.userLanguage ?? 'hi';
      final cleanText = text
          .replaceAll('“', '')
          .replaceAll('”', '')
          .replaceAll('"', '')
          .replaceAll('?', '')
          .replaceAll('।', '')
          .replaceAll(',', '')
          .replaceAll('!', '')
          .trim();
      final lowerText = cleanText.toLowerCase();

      // Smart Multi-lingual Auto-Detection based on input speech (independent of settings)
      final String targetLang = _detectInputLanguage(cleanText, fallback: defaultVoiceLang);

      String response = "I'm listening and here to support you.";
      String? audioKey;

      // Normalized language check helper
      final tl = targetLang.toLowerCase();
      final isHi = tl.contains('hi') || tl.contains('hindi');
      final isBn = tl.contains('bn') || tl.contains('bengali') || tl.contains('বাংলা');
      final isAs = tl.contains('as') || tl.contains('assam') || tl.contains('অসমীয়া');
      final isMni = tl.contains('mni') || tl.contains('manipuri') || tl.contains('মৈতৈলোন');
      final isMiz = tl.contains('miz') || tl.contains('lus') || tl.contains('mizo');

      // 1. Face Recall
      if (lowerText.contains('face') ||
          lowerText.contains('फेस') ||
          lowerText.contains('chehra') ||
          lowerText.contains('चेहरा') ||
          lowerText.contains('family') ||
          lowerText.contains('परिवार') ||
          lowerText.contains('photo') ||
          lowerText.contains('फोटो') ||
          lowerText.contains('तस्वीर') ||
          lowerText.contains('पहचान') ||
          lowerText.contains('pehechan') ||
          lowerText.contains('parivar') ||
          lowerText.contains('focus') ||
          lowerText.contains('फोकस') ||
          lowerText.contains('fokus') ||
          lowerText.contains('মাইখাঙ') ||
          lowerText.contains('hmel') ||
          lowerText.contains('concentrate')) {
        audioKey = 'open_face_recall';
        if (isAs) {
          response = "মুখ চিনি পোৱা খেল আৰম্ভ কৰিছোঁ, চিনি পাওক!";
        } else if (isMni) {
          response = "মাইখাঙ খঙদোকউ হৌরে, খঙদোকউ!";
        } else if (isMiz) {
          response = "Hmel Hriatrengna kan tan e, hre reng rawh!";
        } else if (isBn) {
          response = "ফেস রিকল শুরু করছি, পরিবারকে চিনুন!";
        } else if (isHi) {
          response = "चेहरा पहचानें शुरू कर रही हूँ, परिवार को पहचानिए!";
        } else {
          response = "Starting Face Recall, let's recognize your family!";
        }
        setState(() {
          _spokenText = response;
          _isListening = false;
          _isAssistantSpeaking = true;
        });
        _controller.stop();
        _controller.reset();
        await voiceService.speakKey(audioKey, lang: targetLang, fallbackText: response);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          final hive = context.read<app_hive.HiveService>();
          final diff = hive.getGameDifficulty('face_recall');
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GameIntroScreen(
              title: context.tr('face_recall'),
              description: context.tr('desc_face_recall'),
              challengeCount: 1,
              icon: Icons.family_restroom_rounded,
              themeTag: context.tr('tag_family_faces'),
              visual: GameHubVisual.faceRecall,
              gameBuilder: () => FaceRecallScreen(difficulty: diff),
            ),
          ));
        }
        return;
      }
      // 2. Pattern Path
      else if (lowerText.contains('pattern') ||
               lowerText.contains('पैटर्न') ||
               lowerText.contains('path') ||
               lowerText.contains('पाथ') ||
               lowerText.contains('rasta') ||
               lowerText.contains('रास्ता') ||
               lowerText.contains('रास्ते') ||
               lowerText.contains('bridge') ||
               lowerText.contains('pul') ||
               lowerText.contains('पुल') ||
               lowerText.contains('stone') ||
               lowerText.contains('patthar') ||
               lowerText.contains('पत्थर') ||
               lowerText.contains('টাইল') ||
               lowerText.contains('পেটাৰ্ন') ||
               lowerText.contains('প্যাটার্ন') ||
               lowerText.contains('লম্বী')) {
        audioKey = 'open_pattern';
        if (isAs) {
          response = "পেটাৰ্ন পাথ আৰম্ভ কৰিছোঁ, পথ মনত ৰাখক!";
        } else if (isMni) {
          response = "প্যাটার্ন পাথ হৌরে, লম্বী নিংশিংউ!";
        } else if (isMiz) {
          response = "Pattern Path kan tan e, vawng reng rawh!";
        } else if (isBn) {
          response = "প্যাটার্ন পাথ শুরু করছি, পথ মনে রাখুন!";
        } else if (isHi) {
          response = "पैटर्न पाथ शुरू कर रही हूँ, रास्ता याद रखिए!";
        } else {
          response = "Starting Pattern Path, remember the tiles!";
        }
        setState(() {
          _spokenText = response;
          _isListening = false;
          _isAssistantSpeaking = true;
        });
        _controller.stop();
        _controller.reset();
        await voiceService.speakKey(audioKey, lang: targetLang, fallbackText: response);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          final hive = context.read<app_hive.HiveService>();
          final diff = hive.getGameDifficulty('pattern_path');
          Navigator.of(context).pop();
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => GameIntroScreen(
              title: context.tr('pattern_path'),
              description: context.tr('desc_pattern_path'),
              challengeCount: 2 + diff,
              icon: Icons.extension,
              themeTag: context.tr('tag_root_bridge'),
              visual: GameHubVisual.patternPath,
              gameWidget: PatternPathScreen(difficulty: diff),
            ),
          ));
        }
        return;
      }
      // 3. Object Finder (Memory Recall)
      else if (lowerText.contains('object') ||
               lowerText.contains('finder') ||
               lowerText.contains('ऑब्जेक्ट') ||
               lowerText.contains('फाइंडर') ||
               lowerText.contains('vastu') ||
               lowerText.contains('वस्तु') ||
               lowerText.contains('chij') ||
               lowerText.contains('चीज') ||
               lowerText.contains('चीज़') ||
               lowerText.contains('chitra') ||
               lowerText.contains('चित्र') ||
               lowerText.contains('khoj') ||
               lowerText.contains('खोज') ||
               lowerText.contains('dhoond') ||
               lowerText.contains('ढूंढ') ||
               lowerText.contains('ढूँढ') ||
               lowerText.contains('recall') ||
               lowerText.contains('रिकॉल') ||
               lowerText.contains('रिकोल') ||
               lowerText.contains('অবজেক্ট') ||
               lowerText.contains('ফাইন্ডার') ||
               lowerText.contains('ফাইণ্ডাৰ') ||
               lowerText.contains('পোৎশক') ||
               lowerText.contains('thil')) {
        audioKey = 'open_object_finder';
        if (isAs) {
          response = "অবজেক্ট ফাইণ্ডাৰ আৰম্ভ কৰিছোঁ, মনত ৰাখক!";
        } else if (isMni) {
          response = "অবজেক্ট ফাইন্ডার হৌরে, নিংশিংউ!";
        } else if (isMiz) {
          response = "Object Finder kan tan e, vawng reng rawh!";
        } else if (isBn) {
          response = "অবজেক্ট ফাইন্ডার শুরু করছি, ছবি মনে রাখুন!";
        } else if (isHi) {
          response = "ऑब्जेक्ट फाइंडर शुरू कर रही हूँ, तस्वीरें याद रखिए!";
        } else {
          response = "Starting Object Finder, memorize the objects!";
        }
        setState(() {
          _spokenText = response;
          _isListening = false;
          _isAssistantSpeaking = true;
        });
        _controller.stop();
        _controller.reset();
        await voiceService.speakKey(audioKey, lang: targetLang, fallbackText: response);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          final hive = context.read<app_hive.HiveService>();
          final diff = hive.getGameDifficulty('memory_recall');
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameIntroScreen(
                title: context.tr('memory_recall'),
                description: context.tr('desc_memory_recall'),
                challengeCount: (3 + (diff - 1) ~/ 2).clamp(3, 8),
                icon: Icons.psychology_alt_rounded,
                themeTag: context.tr('tag_heritage_echoes'),
                visual: GameHubVisual.memoryRecall,
                gameWidget: MemoryRecallScreen(difficulty: diff),
              ),
            ),
          );
        }
        return;
      }
      // 4. Card Match (Memory Match) or Generic Game
      else if (lowerText.contains('card') ||
               lowerText.contains('कार्ड') ||
               lowerText.contains('cards') ||
               lowerText.contains('कार्ड्स') ||
               lowerText.contains('pair') ||
               lowerText.contains('jodi') ||
               lowerText.contains('जोड़ी') ||
               lowerText.contains('जोड़े') ||
               lowerText.contains('tash') ||
               lowerText.contains('ताश') ||
               lowerText.contains('game') ||
               lowerText.contains('गेम') ||
               lowerText.contains('play') ||
               lowerText.contains('memory match') ||
               lowerText.contains('मेमोरी मैच') ||
               lowerText.contains('khelna') ||
               lowerText.contains('khel') ||
               lowerText.contains('खेल') ||
               lowerText.contains('खेलना') ||
               lowerText.contains('खेलो') ||
               lowerText.contains('খেল') ||
               lowerText.contains('খেলা') ||
               lowerText.contains('শান্নবা') ||
               lowerText.contains('শান্নসি') ||
               lowerText.contains('open') ||
               lowerText.contains('खोल') ||
               lowerText.contains('चालू')) {
        audioKey = 'open_card_match';
        if (isAs) {
          response = "কাৰ্ড মেচ আৰম্ভ কৰিছোঁ, কাৰ্ডবোৰ মেলাওক!";
        } else if (isMni) {
          response = "কার্দ ম্যাচ হৌরে, চান্নহল্লু!";
        } else if (isMiz) {
          response = "Card Match kan tan e, a inmil zawng rawh!";
        } else if (isBn) {
          response = "কার্ড ম্যাচ শুরু করছি, জোড়া মেলান!";
        } else if (isHi) {
          response = "कार्ड मैच शुरू कर रही हूँ, कार्ड्स मिलाइए!";
        } else {
          response = "Starting Card Match, let's find the pairs!";
        }
        setState(() {
          _spokenText = response;
          _isListening = false;
          _isAssistantSpeaking = true;
        });
        _controller.stop();
        _controller.reset();
        await voiceService.speakKey(audioKey, lang: targetLang, fallbackText: response);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          final hive = context.read<app_hive.HiveService>();
          final diff = hive.getGameDifficulty('memory_match');
          Navigator.of(context).pop();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => GameIntroScreen(
                title: context.tr('memory_match'),
                description: context.tr('desc_memory_match'),
                challengeCount: 2 + (diff - 1),
                icon: Icons.psychology,
                themeTag: context.tr('tag_tea_estates'),
                visual: GameHubVisual.memoryMatch,
                gameWidget: MemoryMatchScreen(difficulty: diff),
              ),
            ),
          );
        }
        return;
      }
      // 5. Jokes & Humor
      else if (lowerText.contains('joke') ||
               lowerText.contains('जोक') ||
               lowerText.contains('chutkula') ||
               lowerText.contains('चुटकुला') ||
               lowerText.contains('चुटकुले') ||
               lowerText.contains('hasao') ||
               lowerText.contains('हंसाओ') ||
               lowerText.contains('हँसाओ') ||
               lowerText.contains('laugh') ||
               lowerText.contains('hasi') ||
               lowerText.contains('हंसी') ||
               lowerText.contains('हँसी') ||
               lowerText.contains('funny') ||
               lowerText.contains('majak') ||
               lowerText.contains('मजाक') ||
               lowerText.contains('kautuk') ||
               lowerText.contains('কৌতুক') ||
               lowerText.contains('ধেমেলীয়া') ||
               lowerText.contains('ফাগী') ||
               lowerText.contains('fiamthu')) {
        audioKey = 'talk_joke';
        if (isAs) {
          response = "ডাক্তৰে ক'লে- আপোনাৰ মগজু বৰ চোকা, ব্যৱহাৰো কৰিব! হাহা, আহক খেলোঁ!";
        } else if (isMni) {
          response = "ডাক্তরনা হায়রি- নহাক্কী ৱাখল য়াম্না ফৈ, শিজিন্নবিয়ু! হাহা, চৎসি শান্নসি!";
        } else if (isMiz) {
          response = "Doctor-in damlo hnenah, 'I thluak a tha lutuk, hmang ve thin rawh' a ti! Haha, khel ang le!";
        } else if (isBn) {
          response = "ডাক্তার বললেন- আপনার মাথা খুব ভালো, মাঝেমধ্যে ব্যবহার করবেন! হা হা, চলুন খেলি!";
        } else if (isHi) {
          response = "डॉक्टर ने कहा- आपका दिमाग बहुत तेज है, बस इस्तेमाल भी कीजिए! हाहा, चलिए खेलें!";
        } else {
          response = "Why did the computer sneeze? It caught a virus! Haha, let's play!";
        }
      }
      // 6. Tea, Snacks & Friendly Chit-Chat
      else if (lowerText.contains('chai') ||
               lowerText.contains('चाय') ||
               lowerText.contains('tea') ||
               lowerText.contains('chaha') ||
               lowerText.contains('thingpui') ||
               lowerText.contains('nasta') ||
               lowerText.contains('nashta') ||
               lowerText.contains('नाश्ता') ||
               lowerText.contains('नास्ता') ||
               lowerText.contains('breakfast') ||
               lowerText.contains('peeli') ||
               lowerText.contains('peli') ||
               lowerText.contains('पी ली') ||
               lowerText.contains('पीली') ||
               lowerText.contains('पिया') ||
               lowerText.contains('pi li') ||
               lowerText.contains('pili') ||
               lowerText.contains('pani') ||
               lowerText.contains('पानी') ||
               lowerText.contains('khana') ||
               lowerText.contains('खाना') ||
               lowerText.contains('চা') ||
               lowerText.contains('চাহ')) {
        audioKey = 'talk_tea';
        if (isAs) {
          response = "গৰম চাহ আৰু শুৱলা কথা! আহক এটা খেল খেলোঁ?";
        } else if (isMni) {
          response = "অশেংবা চাহ অমসুং ৱারী! চৎসি অমা শান্নসি?";
        } else if (isMiz) {
          response = "Thingpui sa tha tak! Game khel ang hmiang?";
        } else if (isBn) {
          response = "গরম চা আর মিষ্টি গল্প! চলুন এবার একটা খেলা হোক?";
        } else if (isHi) {
          response = "अरे वाह, कड़क चाय! चलिए, अब एक खेल हो जाए?";
        } else {
          response = "Hot tea sounds lovely! Shall we play a quick game?";
        }
      }
      // 7. Boredom & Companionship
      else if (lowerText.contains('bore') ||
               lowerText.contains('बोर') ||
               lowerText.contains('boring') ||
               lowerText.contains('mann nahi') ||
               lowerText.contains('मन नहीं') ||
               lowerText.contains('kuch nahi') ||
               lowerText.contains('कुछ नहीं') ||
               lowerText.contains('akela') ||
               lowerText.contains('अकेला') ||
               lowerText.contains('अकेली') ||
               lowerText.contains('amoni') ||
               lowerText.contains('আমনি') ||
               lowerText.contains('ninawm') ||
               lowerText.contains('thak') ||
               lowerText.contains('थक')) {
        audioKey = 'talk_bored';
        if (isAs) {
          response = "আমনি নাপাব, মই আছোঁ নহয়! আহক খেলোঁ!";
        } else if (isMni) {
          response = "ৱাগনু, ঐ লৈরিবা নত্রো! চৎসি শান্নসি!";
        } else if (isMiz) {
          response = "Ning suh, ka awm alawm! Game khel ang hmiang!";
        } else if (isBn) {
          response = "বোর হবেন না, আমি তো আছি! চলুন খেলা যাক!";
        } else if (isHi) {
          response = "अरे बोर मत होइए, मैं हूँ ना! चलिए एक गेम खेलते हैं!";
        } else {
          response = "Don't be bored, I'm right here! Let's play a fun game!";
        }
      }
      // 8. Praise & Compliments
      else if (lowerText.contains('shabaash') ||
               lowerText.contains('shabash') ||
               lowerText.contains('शाबाश') ||
               lowerText.contains('tareef') ||
               lowerText.contains('तारीफ') ||
               lowerText.contains('praise') ||
               lowerText.contains('nice') ||
               lowerText.contains('sweet') ||
               lowerText.contains('acche ho') ||
               lowerText.contains('अच्छे हो') ||
               lowerText.contains('acchi ho') ||
               lowerText.contains('अच्छी हो') ||
               lowerText.contains('badiya') ||
               lowerText.contains('बढ़िया') ||
               lowerText.contains('बढिया') ||
               lowerText.contains('pyare') ||
               lowerText.contains('प्यारे') ||
               lowerText.contains('love') ||
               lowerText.contains('good job') ||
               lowerText.contains('ভাল') ||
               lowerText.contains('মৰমলগা')) {
        audioKey = 'talk_praise';
        if (isAs) {
          response = "আপুনি বৰ মৰমলগা মানুহ! সদায় এনেকৈয়ে হাঁহি থাকিব!";
        } else if (isMni) {
          response = "অদোম য়াম্না অফবা মীওইনি! মোমোনোকনা লৈবীয়ু!";
        } else if (isMiz) {
          response = "I va fel tak em! Hlim reng rawh aw!";
        } else if (isBn) {
          response = "আপনি খুব মিষ্টি মানুষ! সবসময় হাসিমুখে থাকুন!";
        } else if (isHi) {
          response = "अरे वाह, आप बहुत प्यारे हैं! हमेशा मुस्कुराते रहिए!";
        } else {
          response = "Aww, you're wonderful! Keep smiling always!";
        }
      }
      // 9. Ready & Affirmations
      else if (lowerText.contains('ready') ||
               lowerText.contains('haan') ||
               lowerText.contains('हाँ') ||
               lowerText.contains('हां') ||
               lowerText.contains('yes') ||
               lowerText.contains('taiyar') ||
               lowerText.contains('तैयार') ||
               lowerText.contains('shuru') ||
               lowerText.contains('शुरू') ||
               lowerText.contains('शुरु') ||
               lowerText.contains('saju') ||
               lowerText.contains('start') ||
               lowerText.contains('chalo') ||
               lowerText.contains('चलो') ||
               lowerText.contains('চলুন') ||
               lowerText.contains('আৰম্ভ')) {
        audioKey = 'ready';
        if (isAs) {
          response = "বৰ ভাল, আহক আৰম্ভ কৰোঁ!";
        } else if (isMni) {
          response = "য়াম্না ফরে, চৎসি হৌসিগে!";
        } else if (isMiz) {
          response = "A tha lutuk, kan tan e!";
        } else if (isBn) {
          response = "দারুণ, চলুন শুরু করা যাক!";
        } else if (isHi) {
          response = "बहुत बढ़िया, चलिए शुरू करते हैं!";
        } else {
          response = "Awesome, let's get started!";
        }
      }
      // 10. How Are You
      else if (lowerText.contains('how are you') ||
               lowerText.contains('हाउ आर यू') ||
               lowerText.contains('हाउ आर यु') ||
               lowerText.contains('kaise ho') ||
               lowerText.contains('कैसे हो') ||
               lowerText.contains('kese ho') ||
               lowerText.contains('कैसी हो') ||
               lowerText.contains('आप कैसे') ||
               lowerText.contains('आप कैसी') ||
               lowerText.contains('हालचाल') ||
               lowerText.contains('halchal') ||
               lowerText.contains('kemon') ||
               lowerText.contains('কেমন') ||
               lowerText.contains('kene') ||
               lowerText.contains('কেনে') ||
               lowerText.contains('karamna') ||
               lowerText.contains('করম্না') ||
               lowerText.contains('engtin')) {
        audioKey = 'how_are_you';
        if (isAs) {
          response = "মই বঢ়িয়া আছোঁ! আজি চাহ খালে নে?";
        } else if (isMni) {
          response = "ঐ য়াম্না ফরে! চাহ থকলব্রা?";
        } else if (isMiz) {
          response = "Ka tha lutuk e! Thingpui i in tawh em?";
        } else if (isBn) {
          response = "আমি খুব ভালো আছি! আজ চা খাওয়া হলো?";
        } else if (isHi) {
          response = "मैं बिल्कुल ठीक हूँ! आप बताइए, आज चाय पी ली?";
        } else {
          response = "I'm doing great! Did you have your tea today?";
        }
      }
      // 11. Greetings
      else if (lowerText.contains('hello') ||
               lowerText.contains('हेलो') ||
               lowerText.contains('हैलो') ||
               lowerText.contains('हू आर यू') ||
               lowerText.contains('हू आर यु') ||
               lowerText.contains('गुड मॉर्निंग') ||
               lowerText.contains('hi') ||
               lowerText.contains('हाय') ||
               lowerText.contains('namaste') ||
               lowerText.contains('नमस्ते') ||
               lowerText.contains('namaskar') ||
               lowerText.contains('नमस्कार') ||
               lowerText.contains('pranam') ||
               lowerText.contains('प्रणाम') ||
               lowerText.contains('নমস্কার') ||
               lowerText.contains('নমস্কাৰ') ||
               lowerText.contains('খুরুমজরি') ||
               lowerText.contains('chibai')) {
        audioKey = 'greeting';
        if (isAs) {
          response = "নমস্কাৰ! আপুনি আজি কেনে অনুভৱ কৰিছে?";
        } else if (isMni) {
          response = "খুরুমজরি! অদোম ঙসি করম্না তৌরি?";
        } else if (isMiz) {
          response = "Chibai! Engtin nge vawiin i awm?";
        } else if (isBn) {
          response = "নমস্কার! আপনি আজ কেমন আছেন?";
        } else if (isHi) {
          response = "नमस्ते! आप आज कैसा महसूस कर रहे हैं?";
        } else {
          response = "Hello! How are you feeling today?";
        }
      }
      // 12. Calm Anxiety
      else if (lowerText.contains('nervous') ||
               lowerText.contains('anxious') ||
               lowerText.contains('sad') ||
               lowerText.contains('scared') ||
               lowerText.contains('darr') ||
               lowerText.contains('डर') ||
               lowerText.contains('udas') ||
               lowerText.contains('उदास') ||
               lowerText.contains('ghabrahat') ||
               lowerText.contains('घबराहट') ||
               lowerText.contains('घबरा') ||
               lowerText.contains('tens') ||
               lowerText.contains('tension') ||
               lowerText.contains('टेंशन') ||
               lowerText.contains('परेशान') ||
               lowerText.contains('pareshan') ||
               lowerText.contains('bechain') ||
               lowerText.contains('बेचैन') ||
               lowerText.contains('ভয়') ||
               lowerText.contains('অস্থিৰ') ||
               lowerText.contains('lungngai')) {
        audioKey = 'calm_anxiety';
        if (isAs) {
          response = "শান্ত হওক, দীঘল উশাহ লওক, সকলো ঠিক আছে।";
        } else if (isMni) {
          response = "ৱাখল ৱাগনু, লুহৌবা লোউ, লোইনা ফগনি।";
        } else if (isMiz) {
          response = "Lungngai suh, thawk la vak la, a tha vek mai ang.";
        } else if (isBn) {
          response = "শান্ত হন, গভীর শ্বাস নিন, সব ঠিক আছে।";
        } else if (isHi) {
          response = "शांत हो जाइए, गहरी सांस लीजिए, सब ठीक है।";
        } else {
          response = "Take a gentle deep breath, everything will be fine.";
        }
      }
      // 13. Default conversational feedback
      else {
        if (isAs) {
          response = "মই শুনি আছোঁ! আপুনি মোৰ লগত চাহ, ধেমেলীয়া কথা বা খেলৰ বিষয়ে কথা পাতিব পাৰে।";
        } else if (isMni) {
          response = "ঐ তারি! অদোম ঐগা চাহ, ফাগী নত্রগা শান্নবগী মরমদা ৱারী শান্নবা য়াগনি।";
        } else if (isMiz) {
          response = "Ka lo ngaithla e! Fiamthu, thingpui, emaw game chungchang i sawi thei ang.";
        } else if (isBn) {
          response = "আমি শুনছি! আপনি আমার সাথে চা, কৌতুক বা যেকোনো খেলা নিয়ে কথা বলতে পারেন।";
        } else if (isHi) {
          response = "जी, मैं सुन रही हूँ! आप मुझसे चाय, चुटकुले या किसी खेल के बारे में बात कर सकते हैं।";
        } else {
          response = "I am right here with you! You can ask me for a joke, talk about tea, or play a fun game.";
        }
      }

      setState(() {
        _spokenText = response;
        _isListening = false;
        _isAssistantSpeaking = true;
      });
      _controller.repeat(reverse: true);

      if (audioKey != null) {
        await voiceService.speakKey(audioKey, lang: targetLang, fallbackText: response, wait: true);
      } else {
        await voiceService.speak(response, lang: targetLang, wait: true);
      }

      if (!mounted) return;
      setState(() {
        _isAssistantSpeaking = false;
        _isListening = false;
      });
      _controller.stop();
      _controller.reset();

      // Immediately start listening the moment reply finishes (with clean 250ms silence buffer)
      _autoListenTimer?.cancel();
      _autoListenTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted && !_isListening && !_isAssistantSpeaking && !_isProcessing && !voiceService.isSpeaking) {
          _startListening();
        }
      });
    } finally {
      if (mounted) {
        _isProcessing = false;
      }
    }
  }

  Future<void> _handleMicTap() async {
    final voiceService = context.read<VoiceService>();
    _autoListenTimer?.cancel();

    // 1. Barge-in / Interrupt: if assistant is speaking or processing, stop speaking immediately and listen!
    if (_isAssistantSpeaking || _isProcessing || voiceService.isSpeaking) {
      _isProcessing = false;
      await voiceService.stopSpeaking();
      if (!mounted) return;
      setState(() {
        _isAssistantSpeaking = false;
      });
      _startListening();
      return;
    }

    // 2. If listening, tap stops/cancels listening
    if (_isListening) {
      await voiceService.stopListening();
      if (!mounted) return;
      setState(() {
        _isListening = false;
        _spokenText = context.tr('ready_to_listen');
      });
      _controller.stop();
      _controller.reset();
      return;
    }

    // 3. Otherwise start listening
    _startListening();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoListenTimer?.cancel();
    _controller.dispose();
    if (_voiceService != null) {
      _voiceService!.onListeningStateChanged = null;
      _voiceService!.stopListening();
      _voiceService!.stopSpeaking();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF101A17) : const Color(0xFFF8FAF6);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1B3B36);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final isSmall = h < 680;

            return Stack(
              children: [
                // 1. Top-Right Botanical Branch Asset (partially extending beyond screen edge)
                Positioned(
                  top: -h * 0.03,
                  right: -w * 0.05,
                  width: w * 0.62,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isDark ? 0.38 : 0.92,
                      child: Image.asset(
                        'assets/images/voice_botanical_top_right.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // 2. Left Botanical Branch Asset (vertically along left edge, around middle section)
                Positioned(
                  top: h * 0.23,
                  left: -w * 0.14,
                  width: w * 0.48,
                  height: h * 0.50,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isDark ? 0.38 : 0.92,
                      child: Image.asset(
                        'assets/images/voice_botanical_left.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),

                // 3. Right / Lower-Right Botanical Branch Asset (vertically along right edge)
                Positioned(
                  top: h * 0.35,
                  right: -w * 0.04,
                  width: w * 0.32,
                  height: h * 0.40,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: isDark ? 0.36 : 0.90,
                      child: Image.asset(
                        'assets/images/voice_botanical_right.png',
                        fit: BoxFit.contain,
                        alignment: Alignment.centerRight,
                      ),
                    ),
                  ),
                ),

                // Responsive foreground content (positioned in front of decorative botanicals)
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: h,
                        ),
                        child: IntrinsicHeight(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18.0,
                              vertical: isSmall ? 6.0 : 10.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 1. Top Bar with Close and Centered NeuroVerse Branding
                                _buildTopBar(context, isDark, primaryTextColor),

                                // 2. Status Pill: "Listening..."
                                _buildStatusPill(isDark, isSmall),

                                // 3. Central Glowing Microphone
                                _buildMicrophoneArea(isSmall),

                                // 4. Grouped Prompt Title & Subtitle + Waveform
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildPromptSection(isDark, primaryTextColor, isSmall),
                                    SizedBox(height: isSmall ? 8 : 12),
                                    AnimatedBuilder(
                                      animation: _controller,
                                      builder: (context, _) => _AudioWaveform(
                                        isListening: _isListening || _isAssistantSpeaking,
                                        animationValue: _controller.value,
                                        isSmall: isSmall,
                                      ),
                                    ),
                                  ],
                                ),

                                // 5. Bottom Capsule Card: "Just speak naturally"
                                _buildBottomGuidanceCard(isDark, primaryTextColor, isSmall),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, bool isDark, Color primaryTextColor) {
    final buttonBg = isDark
        ? const Color(0xFF182923)
        : const Color(0xFFE3EFE8);
    final iconColor = isDark
        ? Colors.white70
        : const Color(0xFF1B3B36);

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close (X) button
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: iconColor, size: 22),
              tooltip: context.tr('close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Central NeuroVerse Official App Icon & Branding
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.3 : 0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/app_icon.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'NeuroVerse',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    context.tr('app_tagline'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : const Color(0xFF5A7268),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Help Guide (?) button with aesthetic dialog
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(Icons.help_outline_rounded, color: iconColor, size: 22),
              tooltip: context.tr('voice_help_title'),
              onPressed: () => _showVoiceHelpDialog(context, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(bool isDark, bool isSmall) {
    final pillBg = isDark
        ? const Color(0xFF162821)
        : const Color(0xFFE2F1E8);
    final pillBorder = isDark
        ? const Color(0xFF244438)
        : const Color(0xFFD0E8DB);

    String statusTitle;
    String statusSubtitle;
    if (_isAssistantSpeaking) {
      statusTitle = context.tr('speaking');
      statusSubtitle = context.tr('tap_to_interrupt');
    } else if (_isListening) {
      statusTitle = context.tr('listening');
      statusSubtitle = context.tr('speak_now_help');
    } else {
      statusTitle = context.tr('ready_to_listen');
      statusSubtitle = context.tr('tap_mic_to_speak');
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 20 : 28,
        vertical: isSmall ? 8 : 11,
      ),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: pillBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusTitle,
            style: TextStyle(
              fontSize: isSmall ? 16.5 : 18.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF164E43),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusSubtitle,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : const Color(0xFF3D685E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneArea(bool isSmall) {
    final coreSize = isSmall ? 104.0 : 138.0;

    return GestureDetector(
      onTap: _handleMicTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final pulse = (_isListening || _isAssistantSpeaking) ? _controller.value : 0.0;
          final outerSize = coreSize + (isSmall ? 48.0 : 84.0) + (pulse * (isSmall ? 18.0 : 26.0));
          final middleSize = coreSize + (isSmall ? 24.0 : 44.0) + (pulse * (isSmall ? 10.0 : 14.0));

          return SizedBox(
            width: outerSize,
            height: outerSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer subtle glowing halo
                Container(
                  width: outerSize,
                  height: outerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF00796B).withValues(alpha: 0.16 * (1.0 - pulse * 0.4)),
                        const Color(0xFF00796B).withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),

                // Middle glowing ring
                Container(
                  width: middleSize,
                  height: middleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF00796B).withValues(alpha: 0.12 + (pulse * 0.08)),
                    border: Border.all(
                      color: const Color(0xFF00796B).withValues(alpha: 0.25 + (pulse * 0.15)),
                      width: 1.5,
                    ),
                  ),
                ),

                // Central Vibrant Teal Core Button
                Container(
                  width: coreSize,
                  height: coreSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00796B), Color(0xFF004D40)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00796B).withValues(alpha: 0.38),
                        blurRadius: isSmall ? 16 : 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mic_rounded,
                      size: isSmall ? 44 : 58,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromptSection(bool isDark, Color primaryTextColor, bool isSmall) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.tr('how_can_help'),
          style: TextStyle(
            fontSize: isSmall ? 22 : 25,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: isSmall ? 4 : 6),
        Text(
          context.tr('voice_prompt_sub'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isSmall ? 13.5 : 14.5,
            color: isDark ? Colors.white60 : const Color(0xFF5A7268),
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomGuidanceCard(bool isDark, Color primaryTextColor, bool isSmall) {
    final cardBg = isDark
        ? const Color(0xFF162620)
        : const Color(0xFFE6F4EB);
    final cardBorder = isDark
        ? const Color(0xFF244438)
        : const Color(0xFFD4EBE0);

    String displayFeedback;
    if (_spokenText.isEmpty || _spokenText == '...') {
      displayFeedback = context.tr('im_listening');
    } else {
      displayFeedback = _spokenText;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isSmall ? 9 : 12,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Botanical Sprout Icon
          Container(
            padding: EdgeInsets.all(isSmall ? 6 : 7),
            decoration: BoxDecoration(
              color: const Color(0xFF00796B).withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_rounded,
              size: isSmall ? 18 : 20,
              color: const Color(0xFF00796B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('speak_naturally'),
                  style: TextStyle(
                    fontSize: isSmall ? 12.5 : 13.5,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  displayFeedback,
                  style: TextStyle(
                    fontSize: isSmall ? 11.5 : 12.5,
                    color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF3D685E),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceHelpDialog(BuildContext context, bool isDark) {
    final bgColor = isDark ? const Color(0xFF13221C) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1A2E26) : const Color(0xFFF3F8F5);
    final cardBorder = isDark ? const Color(0xFF234438) : const Color(0xFFE0ECE5);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF1A3029);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF4A6359);
    const accentTeal = Color(0xFF00796B);

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: isDark ? 0.7 : 0.5),
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? const Color(0xFF264C3E) : const Color(0xFFD6EAE0),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentTeal.withValues(alpha: isDark ? 0.2 : 0.08),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Glowing Question Mark Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF26A69A),
                                Color(0xFF00796B),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentTeal.withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.help_outline_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          context.tr('voice_help_title'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19.5,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Subtitle
                        Text(
                          context.tr('voice_help_subtitle'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Section 1: Questions & Conversations (Speak & Hear Reply)
                        _buildHelpSection(
                          dialogCtx: dialogCtx,
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          title: context.tr('voice_help_section_chat'),
                          accentColor: const Color(0xFF0288D1),
                          items: [
                            _HelpItem(
                              text: context.tr('voice_help_chat_tea'),
                              icon: Icons.local_cafe_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_chat_joke'),
                              icon: Icons.sentiment_very_satisfied_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_chat_feelings'),
                              icon: Icons.favorite_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_chat_anxiety'),
                              icon: Icons.spa_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Section 2: Cognitive Games (Speak to Launch)
                        _buildHelpSection(
                          dialogCtx: dialogCtx,
                          isDark: isDark,
                          cardBg: cardBg,
                          cardBorder: cardBorder,
                          title: context.tr('voice_help_section_games'),
                          accentColor: const Color(0xFF00897B),
                          items: [
                            _HelpItem(
                              text: context.tr('voice_help_game_card_match'),
                              icon: Icons.style_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_game_pattern_path'),
                              icon: Icons.alt_route_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_game_object_finder'),
                              icon: Icons.search_rounded,
                            ),
                            _HelpItem(
                              text: context.tr('voice_help_game_face_recall'),
                              icon: Icons.face_retouching_natural_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Tip banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF163328) : const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF265440) : const Color(0xFFC8E6C9),
                            ),
                          ),
                          child: Text(
                            context.tr('voice_help_tip'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Close button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00796B),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            child: Text(
                              context.tr('close'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Top-Right Cross (X) Close Button
                  Positioned(
                    top: 14,
                    right: 14,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E362D) : const Color(0xFFE8F1EC),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF2E5244) : const Color(0xFFCCE0D5),
                          width: 1.0,
                        ),
                      ),
                      child: IconButton(
                        key: const Key('voice_help_dialog_close_button'),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : const Color(0xFF1B3B36),
                        ),
                        tooltip: context.tr('close'),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHelpSection({
    required BuildContext dialogCtx,
    required bool isDark,
    required Color cardBg,
    required Color cardBorder,
    required String title,
    required Color accentColor,
    required List<_HelpItem> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1B3B36),
              ),
            ),
          ),
          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.of(dialogCtx).pop();
                    final cleanText = item.text
                        .replaceAll('“', '')
                        .replaceAll('”', '')
                        .replaceAll('"', '')
                        .trim();
                    _spokenText = cleanText;
                    _processVoiceText(cleanText);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF13221C) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2B4D3F) : const Color(0xFFCCE3D7),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.22 : 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(item.icon, size: 15, color: accentColor),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.text,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF1B3B36),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 12,
                          color: isDark ? Colors.white30 : const Color(0xFF90A4AE),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Symmetrical animated audio waveform matching the reference design.
class _AudioWaveform extends StatelessWidget {
  final bool isListening;
  final double animationValue;
  final bool isSmall;

  const _AudioWaveform({
    required this.isListening,
    required this.animationValue,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = const Color(0xFF00796B).withValues(alpha: isListening ? 0.55 : 0.28);
    const int count = 23;
    final barHeight = isSmall ? 32.0 : 44.0;
    final maxCenterHeight = isSmall ? 28.0 : 40.0;
    const double minOuterHeight = 6.0;

    return SizedBox(
      height: barHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(count, (index) {
          // Distance from center (0 at center, 1 at edge)
          final distanceFromCenter = (index - (count / 2).floor()).abs() / (count / 2);
          final baseHeight = minOuterHeight + (maxCenterHeight - minOuterHeight) * (1.0 - distanceFromCenter);

          // Subtle animated oscillation when listening
          double dynamicHeight = baseHeight;
          if (isListening) {
            final wave = math.sin((animationValue * 2 * math.pi) + (index * 0.45));
            dynamicHeight = (baseHeight * (0.75 + (wave * 0.25))).clamp(5.0, barHeight);
          }

          return Container(
            margin: EdgeInsets.symmetric(horizontal: isSmall ? 1.8 : 2.2),
            width: isSmall ? 3.0 : 3.6,
            height: dynamicHeight,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

class _HelpItem {
  final String text;
  final IconData icon;
  const _HelpItem({
    required this.text,
    required this.icon,
  });
}
