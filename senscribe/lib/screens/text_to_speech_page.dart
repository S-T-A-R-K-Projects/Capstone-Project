import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../services/text_to_speech_service.dart';

class TextToSpeechPage extends StatefulWidget {
  const TextToSpeechPage({
    super.key,
    this.isMonitoring = false,
    this.pulseController,
    this.onToggleMonitoring,
  });

  final bool isMonitoring;
  final AnimationController? pulseController;
  final VoidCallback? onToggleMonitoring;

  @override
  State<TextToSpeechPage> createState() => _TextToSpeechPageState();
}

class _TextToSpeechPageState extends State<TextToSpeechPage> {
  final TextEditingController _textController = TextEditingController();
  final TextToSpeechService _ttsService = TextToSpeechService();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTTS();
  }

  Future<void> _initTTS() async {
    await _ttsService.init();
  }

  @override
  void dispose() {
    _textController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _speak() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSpeaking = true);
    await _ttsService.speak(text);
    setState(() => _isSpeaking = false);
  }

  void _stop() async {
    await _ttsService.stop();
    setState(() => _isSpeaking = false);
  }

  void _clearText() {
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Text to Speech'),
      body: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Top padding for iOS app bars (17/18/26+)
                if (Platform.isIOS)
                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.top + kToolbarHeight),
                // Input Area
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AdaptiveCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _textController,
                              maxLines: 5,
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                              decoration: InputDecoration(
                                hintText: 'Enter text to speak...',
                                border: InputBorder.none,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: _clearText,
                                ),
                              ),
                              style: GoogleFonts.inter(fontSize: 18),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (_isSpeaking)
                                  SizedBox(
                                    width: 70,
                                    child: AdaptiveButton(
                                      onPressed: _stop,
                                      label: 'Stop',
                                      style: AdaptiveButtonStyle.bordered,
                                    ),
                                  ),
                                SizedBox(
                                  width: 80,
                                  child: AdaptiveButton(
                                    onPressed: _speak,
                                    label: 'Speak',
                                    style: AdaptiveButtonStyle.filled,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
