import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._internal();
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;

  final FlutterTts _flutterTts = FlutterTts();

  Future<void> init() async {
    // Optional: Set default options. Keep minimal defaults.
    try {
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.awaitSpeakCompletion(true);
    } catch (e) {
      // ignore silently for now; caller can catch when speaking
      // dev print for debugging
      // print('TtsService.init error: $e');
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android-specific settings could go here.
    }
  }

  Future<void> speak(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    try {
      // stop any existing speech
      await _flutterTts.stop();
      await _flutterTts.speak(t);
    } catch (e) {
      // rethrow so caller can handle
      throw Exception('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
