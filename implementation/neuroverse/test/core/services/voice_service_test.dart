import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neuroverse_app/core/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers.global'), (call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('xyz.luan/audioplayers'), (call) async => 1);
  });

  group('VoiceService Tests', () {
    test('Initializes with default settings', () {
      final voiceService = VoiceService();
      expect(voiceService.isSpeaking, isFalse);
      expect(voiceService.isGameAudioEnabled, isTrue);
      expect(voiceService.isAudioEnabled, isTrue);
    });

    test('Toggling game audio updates state', () {
      final voiceService = VoiceService();
      voiceService.setGameAudioEnabled(false);
      expect(voiceService.isGameAudioEnabled, isFalse);
      expect(voiceService.isAudioEnabled, isFalse);

      voiceService.setGameAudioEnabled(true);
      expect(voiceService.isGameAudioEnabled, isTrue);
      expect(voiceService.isAudioEnabled, isTrue);
    });

    test('checkOnlineStatus completes without crashing and caches status', () async {
      final voiceService = VoiceService();
      final status1 = await voiceService.checkOnlineStatus();
      expect(status1, isA<bool>());

      final status2 = await voiceService.checkOnlineStatus();
      expect(status2, equals(status1));
    });
  });
}
