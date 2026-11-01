import 'dart:async';
import 'dart:io';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isSttInitialized = false;
  bool _isSpeaking = false;
  Completer<void>? _speechCompleter;

  /// Locales that failed with network errors when internet is unavailable.
  final Set<String> _offlineUnavailableLocales = {};
  String? _activeListeningLocale;
  bool _isRecovering = false;
  bool _isOnline = true;
  DateTime _lastOnlineCheck = DateTime.fromMillisecondsSinceEpoch(0);

  /// Checks whether internet is actively reachable.
  /// Uses a short timeout and cached value to prevent audio UI latency.
  Future<bool> checkOnlineStatus() async {
    if (kIsWeb) return true;
    final now = DateTime.now();
    if (now.difference(_lastOnlineCheck).inMilliseconds < 2500) {
      return _isOnline;
    }
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(milliseconds: 400));
      _isOnline = (result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } catch (_) {
      _isOnline = false;
    }
    _lastOnlineCheck = DateTime.now();

    // When internet connection is back, restore cloud locales
    if (_isOnline && _offlineUnavailableLocales.isNotEmpty) {
      debugPrint('VoiceService: Internet detected. Restoring online cloud speech locales.');
      _offlineUnavailableLocales.clear();
    }

    return _isOnline;
  }

  /// Returns true if assistant is currently speaking or playing audio.
  bool get isSpeaking => _isSpeaking;

  /// Specifically controls in-game sound effects & game instructions.
  /// Conversational Voice Assistant (microphone & AI voice replies) remains active!
  bool isGameAudioEnabled = true;

  void setGameAudioEnabled(bool enabled) {
    isGameAudioEnabled = enabled;
    if (!enabled) {
      _audioPlayer.stop();
    }
  }

  void setAudioEnabled(bool enabled) => setGameAudioEnabled(enabled);
  bool get isAudioEnabled => isGameAudioEnabled;

  Future<void> playAudioTestCue({String lang = 'en'}) async {
    try {
      await _audioPlayer.stop();
      final cleanLang = (lang.toLowerCase().contains('hi') || lang.toLowerCase().contains('hindi')) ? 'hi' : 'en';
      final assetPath = 'audio/voice/$cleanLang/match_find.mp3';
      await _audioPlayer.play(AssetSource(assetPath));
    } catch (_) {
      try {
        await _flutterTts.speak("Sound effects active");
      } catch (_) {}
    }
  }

  Future<void> stopGameAudio() async {
    await _audioPlayer.stop();
  }

  Future<void> init() async {
    // Configure natural Indian speech rate & pitch
    await _flutterTts.setLanguage("hi-IN");
    await _flutterTts.setSpeechRate(0.42); // Slower, gentle rate for elderly
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    void onSpeechFinished() {
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    }

    _flutterTts.setCompletionHandler(() => onSpeechFinished());
    _flutterTts.setCancelHandler(() => onSpeechFinished());
    _flutterTts.setErrorHandler((_) => onSpeechFinished());

    _audioPlayer.onPlayerComplete.listen((_) => onSpeechFinished());

    await initStt();
  }

  /// Initializes or re-initializes Speech-To-Text (e.g., if permissions granted dynamically).
  Future<bool> initStt() async {
    try {
      _isSttInitialized = await _speechToText.initialize(
        onError: (val) => _handleSttError(val),
        onStatus: (val) => _handleSttStatus(val),
      );
      return _isSttInitialized;
    } catch (e) {
      debugPrint('VoiceService initStt exception: $e');
      _isSttInitialized = false;
      return false;
    }
  }

  void Function(bool isListening)? onListeningStateChanged;
  bool _hasRecognizedWords = false;
  bool _isListeningSessionActive = false;
  Function(String)? _activeOnResult;
  Function(String)? _activeOnPartialResult;
  String _lastWords = '';
  Timer? _silenceDebounceTimer;

  void _handleSttError(SpeechRecognitionError error) {
    debugPrint('VoiceService STT Error: ${error.errorMsg} (permanent: ${error.permanent})');
    final err = error.errorMsg.toLowerCase();
    final isNetworkOrUnavailable = err.contains('network') ||
        err.contains('server') ||
        err.contains('unavailable') ||
        err.contains('error_speech_timeout');

    if (isNetworkOrUnavailable && _activeListeningLocale != null) {
      debugPrint('VoiceService: Locale $_activeListeningLocale failed with network/offline error. Adding to offline unavailable list.');
      _offlineUnavailableLocales.add(_activeListeningLocale!);
    }

    // Auto-recovery: If network error killed listening before any words were recognized and session is active,
    // immediately recover using device default offline engine (null).
    if (isNetworkOrUnavailable && _isListeningSessionActive && !_hasRecognizedWords && _activeListeningLocale != null) {
      debugPrint('VoiceService: Auto-recovering session with device offline engine (null)...');
      _isRecovering = true;
      _activeListeningLocale = null;
      Future.delayed(const Duration(milliseconds: 250), () async {
        if (_isListeningSessionActive && !_hasRecognizedWords) {
          final ok = await _listenWithCandidate(null);
          if (!ok) {
            _isRecovering = false;
            _isListeningSessionActive = false;
            onListeningStateChanged?.call(false);
          }
        } else {
          _isRecovering = false;
        }
      });
      return;
    }

    _isRecovering = false;
    _isListeningSessionActive = false;
    onListeningStateChanged?.call(false);
  }

  void _handleSttStatus(String status) {
    debugPrint('VoiceService STT Status: $status');
    if (status == 'listening') {
      _isListeningSessionActive = true;
      _isRecovering = false;
      onListeningStateChanged?.call(true);
    } else if (status == 'notListening' || status == 'done') {
      if (_isRecovering) {
        debugPrint('VoiceService STT Status $status ignored during auto-recovery transition.');
        return;
      }
      _isListeningSessionActive = false;
      onListeningStateChanged?.call(false);
    }
  }

  bool get isSttInitialized => _isSttInitialized;
  Future<bool> get hasSttPermission => _speechToText.hasPermission;
  bool get isSttAvailable => _speechToText.isAvailable;

  /// Plays studio-grade pre-recorded Indian neural audio for the given key and language.
  /// Falls back to offline Flutter TTS if key is not found or dynamic text is provided.
  Future<void> speakKey(String audioKey, {String lang = 'hi', String? fallbackText, bool wait = false}) async {
    final isCelebrationAudio = audioKey.endsWith('_win') || audioKey.contains('praise');
    if (!isGameAudioEnabled && !audioKey.startsWith('open_') && !isCelebrationAudio) {
      return;
    }
    // Normalize language code
    String cleanLang = lang.toLowerCase().trim();
    if (cleanLang.contains('hindi') || cleanLang == 'hi') {
      cleanLang = 'hi';
    } else if (cleanLang.contains('bengali') || cleanLang.contains('বাংলা') || cleanLang == 'bn') {
      cleanLang = 'bn';
    } else if (cleanLang.contains('assam') || cleanLang.contains('অসমীয়া') || cleanLang == 'as') {
      cleanLang = 'as';
    } else if (cleanLang.contains('manipuri') || cleanLang.contains('মণিপুরী') || cleanLang == 'mni') {
      cleanLang = 'mni';
    } else if (cleanLang.contains('mizo') || cleanLang == 'lus' || cleanLang == 'miz') {
      cleanLang = 'miz';
    } else {
      cleanLang = 'en';
    }

    await _audioPlayer.stop();
    try {
      await _flutterTts.stop();
    } catch (_) {}

    _speechCompleter = Completer<void>();
    _isSpeaking = true;

    final assetPath = 'audio/voice/$cleanLang/$audioKey.mp3';
    try {
      // Verify asset exists in bundle
      await rootBundle.load('assets/$assetPath');
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource(assetPath));
      if (wait) {
        await _speechCompleter?.future.timeout(const Duration(seconds: 20), onTimeout: () {});
      }
      return;
    } catch (e) {
      debugPrint("VoiceService: Asset $assetPath not available: $e");
      // Try English fallback audio if target language not found
      if (cleanLang != 'en') {
        try {
          final enPath = 'audio/voice/en/$audioKey.mp3';
          await rootBundle.load('assets/$enPath');
          await _audioPlayer.stop();
          await _audioPlayer.play(AssetSource(enPath));
          if (wait) {
            await _speechCompleter?.future.timeout(const Duration(seconds: 20), onTimeout: () {});
          }
          return;
        } catch (_) {}
      }
    }

    // Dynamic text fallback with offline TTS
    if (fallbackText != null && fallbackText.isNotEmpty) {
      await speak(fallbackText, lang: cleanLang, wait: wait);
    } else {
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    }
  }

  Future<void> speak(String text, {String? lang, bool wait = false}) async {
    if (text.trim().isEmpty) return;
    await _audioPlayer.stop();
    try {
      await _flutterTts.stop();
    } catch (_) {}

    _speechCompleter = Completer<void>();
    _isSpeaking = true;
    if (lang != null && lang.isNotEmpty) {
      String clean = lang.toLowerCase().trim();
      List<String> candidateLocales = [];

      if (clean.startsWith('en') || clean.contains('english')) {
        candidateLocales = ['en-IN', 'en_IN', 'en-US', 'en_US', 'en-GB', 'en_GB', 'en-AU', 'en', 'eng-USA', 'eng_USA'];
      } else if (clean.startsWith('hi') || clean.contains('hindi')) {
        candidateLocales = ['hi-IN', 'hi_IN', 'hi', 'hin-IND', 'hin_IND', 'hin'];
      } else if (clean.startsWith('bn') || clean.contains('bengali') || clean.contains('বাংলা')) {
        candidateLocales = ['bn-IN', 'bn_IN', 'bn-BD', 'bn_BD', 'bn', 'ben-IND'];
      } else if (clean.startsWith('as') || clean.contains('assam') || clean.contains('অসমীয়া')) {
        candidateLocales = ['as-IN', 'as_IN', 'as', 'asm-IND', 'bn-IN', 'hi-IN'];
      } else if (clean.startsWith('mni') || clean.contains('manipuri') || clean.contains('মৈতৈলোন')) {
        candidateLocales = ['mni-IN', 'mni_IN', 'mni', 'bn-IN', 'hi-IN'];
      } else if (clean.startsWith('lus') || clean.startsWith('miz') || clean.contains('mizo')) {
        candidateLocales = ['lus-IN', 'lus_IN', 'lus', 'miz', 'en-IN', 'en-US'];
      } else {
        candidateLocales = ['en-US', 'en-IN', 'hi-IN'];
      }

      bool setOk = false;
      for (final loc in candidateLocales) {
        try {
          final dynamic avail = await _flutterTts.isLanguageAvailable(loc);
          if (avail == 1 || avail == true || avail == 'true' || avail == '1') {
            await _flutterTts.setLanguage(loc);
            setOk = true;
            break;
          }
        } catch (_) {}
      }

      // If check didn't pass, attempt setting the primary candidate directly
      if (!setOk && candidateLocales.isNotEmpty) {
        try {
          await _flutterTts.setLanguage(candidateLocales.first);
        } catch (_) {}
      }
    }
    try {
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setSpeechRate(0.44);
      await _flutterTts.speak(text);
      if (wait) {
        await _speechCompleter?.future.timeout(const Duration(seconds: 20), onTimeout: () {});
      }
    } catch (e) {
      debugPrint("VoiceService: TTS speak error: $e");
      _isSpeaking = false;
      if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
        _speechCompleter!.complete();
      }
    }
  }

  Future<void> stopSpeaking() async {
    _isSpeaking = false;
    if (_speechCompleter != null && !_speechCompleter!.isCompleted) {
      _speechCompleter!.complete();
    }
    await _audioPlayer.stop();
    await _flutterTts.stop();
  }

  void _submitIfValid() {
    _silenceDebounceTimer?.cancel();
    _silenceDebounceTimer = null;
    final recognized = _lastWords.trim();
    if (recognized.isNotEmpty) {
      _lastWords = '';
      _isListeningSessionActive = false;
      _speechToText.stop();
      if (_activeOnResult != null) {
        _activeOnResult!(recognized);
      }
    }
  }

  Future<bool> _listenWithCandidate(String? locId) async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      _hasRecognizedWords = false;
      _activeListeningLocale = locId;
      await _speechToText.listen(
        onResult: (result) {
          final words = result.recognizedWords.trim();
          if (words.isNotEmpty) {
            _hasRecognizedWords = true;
            _lastWords = words;
            _activeOnPartialResult?.call(words);
          }
          if (result.finalResult) {
            _submitIfValid();
          } else if (words.isNotEmpty) {
            _silenceDebounceTimer?.cancel();
            _silenceDebounceTimer = Timer(const Duration(milliseconds: 1800), () {
              _submitIfValid();
            });
          }
        },
        listenOptions: SpeechListenOptions(
          localeId: locId,
          listenMode: ListenMode.deviceDefault,
          pauseFor: const Duration(seconds: 4),
          cancelOnError: false,
          partialResults: true,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('VoiceService: listen exception with locale $locId: $e');
      return false;
    }
  }

  Future<List<String?>> _resolveLocaleCandidates(String? lang) async {
    final List<String?> candidates = [];
    LocaleName? systemLocale;
    List<LocaleName> availableLocales = [];

    try {
      systemLocale = await _speechToText.systemLocale();
      availableLocales = await _speechToText.locales();
    } catch (_) {}

    final isOnline = await checkOnlineStatus();
    final clean = (lang ?? '').toLowerCase().trim();

    final bool systemMatchesHi = systemLocale != null && systemLocale.localeId.toLowerCase().startsWith('hi');
    final bool systemMatchesBn = systemLocale != null && systemLocale.localeId.toLowerCase().startsWith('bn');
    final bool systemMatchesEn = systemLocale != null && systemLocale.localeId.toLowerCase().startsWith('en');

    if (clean.contains('hi') || clean.contains('hindi')) {
      if (systemMatchesHi) {
        candidates.add(systemLocale!.localeId);
      }
      if (isOnline && !_offlineUnavailableLocales.contains('hi_IN') && !_offlineUnavailableLocales.contains('hi-IN')) {
        // Online: Prioritize full Google Cloud Hindi speech model
        candidates.add('hi_IN');
        candidates.add('hi-IN');
        for (final l in availableLocales) {
          if (l.localeId.toLowerCase().startsWith('hi')) {
            candidates.add(l.localeId);
            break;
          }
        }
        candidates.add(null);
      } else {
        // Offline or hi_IN failed: Prioritize device default engine (null) first.
        // Android opens the mic without ERROR_NETWORK boop cancel sound.
        candidates.add(null);
        if (systemLocale != null) {
          candidates.add(systemLocale.localeId);
        }
        candidates.add('hi_IN');
        candidates.add('hi-IN');
      }
    } else if (clean.contains('bn') || clean.contains('bengali')) {
      if (systemMatchesBn) {
        candidates.add(systemLocale!.localeId);
      }
      if (isOnline && !_offlineUnavailableLocales.contains('bn_IN')) {
        candidates.add('bn_IN');
        candidates.add('bn-IN');
        candidates.add('bn_BD');
        candidates.add(null);
      } else {
        candidates.add(null);
        if (systemLocale != null) {
          candidates.add(systemLocale.localeId);
        }
        candidates.add('bn_IN');
      }
    } else if (clean.contains('en') || clean.contains('english')) {
      if (systemMatchesEn) {
        candidates.add(systemLocale!.localeId);
      }
      for (final l in availableLocales) {
        if (l.localeId.toLowerCase().startsWith('en_in') || l.localeId.toLowerCase().startsWith('en-in')) {
          candidates.add(l.localeId);
          break;
        }
      }
      candidates.add('en_IN');
      candidates.add('en-IN');
      candidates.add('en_US');
      candidates.add('en-US');
      candidates.add(null);
    } else {
      if (systemLocale != null) {
        candidates.add(systemLocale.localeId);
      }
      candidates.add(null);
    }

    // Deduplicate preserving order
    final seen = <String?>{};
    final unique = <String?>[];
    for (final c in candidates) {
      if (!seen.contains(c)) {
        seen.add(c);
        unique.add(c);
      }
    }
    return unique.isNotEmpty ? unique : [null];
  }

  Future<bool> startListening(
    Function(String) onResult, {
    Function(String)? onPartialResult,
    String? lang,
  }) async {
    // 1. Microphone must NEVER listen while assistant is actively speaking its reply!
    if (_isSpeaking) {
      debugPrint('VoiceService: Microphone blocked - Assistant is currently speaking its reply.');
      return false;
    }

    // 2. Dynamic check: re-initialize if STT was not available or permission was granted after app start
    if (!_isSttInitialized || !_speechToText.isAvailable) {
      final ok = await initStt();
      if (!ok) {
        debugPrint('VoiceService: STT initialization failed or permission denied.');
        return false;
      }
    }

    // 3. Stop audio/speech playback
    await _audioPlayer.stop();
    await _flutterTts.stop();

    // 4. Ensure previous listening session is completely terminated
    if (_speechToText.isListening) {
      try {
        await _speechToText.stop();
        await Future.delayed(const Duration(milliseconds: 120));
      } catch (_) {}
    }

    _activeOnResult = onResult;
    _activeOnPartialResult = onPartialResult;
    _hasRecognizedWords = false;
    _isListeningSessionActive = true;
    _isRecovering = false;
    _lastWords = '';
    _silenceDebounceTimer?.cancel();
    _silenceDebounceTimer = null;

    final candidates = await _resolveLocaleCandidates(lang);
    bool started = false;
    for (int i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      debugPrint('VoiceService: Attempting to listen with candidate [$i]: $candidate');
      started = await _listenWithCandidate(candidate);
      if (started) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return started;
  }

  Future<void> stopListening() async {
    _isRecovering = false;
    _isListeningSessionActive = false;
    _silenceDebounceTimer?.cancel();
    _silenceDebounceTimer = null;
    try {
      await _speechToText.stop();
    } catch (_) {}
  }
}
