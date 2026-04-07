import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class TextToSpeechService {
  static final TextToSpeechService _instance = TextToSpeechService._internal();
  factory TextToSpeechService() => _instance;
  TextToSpeechService._internal();

  final FlutterTts flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;
  final ValueNotifier<bool> speakingNotifier = ValueNotifier<bool>(false);

  void _setSpeaking(bool value) {
    if (_isSpeaking == value) return;
    _isSpeaking = value;
    speakingNotifier.value = value;
  }

  Future<void> init() async {
    if (_isInitialized) return;

    if (Platform.isIOS) {
      await flutterTts.setSharedInstance(true);
      await flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.allowAirPlay,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );
    }

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);
        true); // Ensure speak returns only after completion
    await flutterTts.awaitSpeakCompletion(true);
    flutterTts.setStartHandler(() => _setSpeaking(true));
    flutterTts.setCompletionHandler(() => _setSpeaking(false));
    flutterTts.setCancelHandler(() => _setSpeaking(false));
    flutterTts.setPauseHandler(() => _setSpeaking(false));
    flutterTts.setContinueHandler(() => _setSpeaking(true));
    flutterTts.setErrorHandler((_) => _setSpeaking(false));

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    if (text.isNotEmpty) {
      _setSpeaking(true);
      await flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await flutterTts.stop();
    _setSpeaking(false);
  }
}
