import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'home_page.dart';
import 'speech_to_text_page.dart';
import 'text_to_speech_page.dart';

/// A simple landing screen that presents three primary sections of the
/// application.  Each button pushes the corresponding feature page so the
/// user can jump directly into text‑to‑speech, speech‑to‑text, or the sound
/// recognition/active‑listening workflow.
///
/// The visual style mirrors the rest of the app by using [AdaptiveScaffold],
/// [AdaptiveAppBar] and the standard theme colours for buttons.
class StartPage extends StatefulWidget {
  const StartPage({Key? key}) : super(key: key);

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> with TickerProviderStateMixin {
  late final AnimationController _soundPulseController;
  late final AnimationController _speechPulseController;

  bool _isSoundMonitoring = false;
  bool _isSpeechMonitoring = false;

  @override
  void initState() {
    super.initState();
    _soundPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _speechPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _soundPulseController.dispose();
    _speechPulseController.dispose();
    super.dispose();
  }

  void _toggleSoundMonitoring() {
    setState(() {
      _isSoundMonitoring = !_isSoundMonitoring;
      if (_isSoundMonitoring) {
        _soundPulseController.repeat(reverse: true);
      } else {
        _soundPulseController.stop();
      }
    });
  }

  void _toggleSpeechMonitoring() {
    setState(() {
      _isSpeechMonitoring = !_isSpeechMonitoring;
      if (_isSpeechMonitoring) {
        _speechPulseController.repeat(reverse: true);
      } else {
        _speechPulseController.stop();
      }
    });
  }

  void _openTextToSpeech() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (c) => const TextToSpeechPage()),
    );
  }

  void _openSpeechToText() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => SpeechToTextPage(
          isMonitoring: _isSpeechMonitoring,
          pulseController: _speechPulseController,
          onToggleMonitoring: _toggleSpeechMonitoring,
        ),
      ),
    );
  }

  void _openSoundRecognition() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => HomePage(
          isMonitoring: _isSoundMonitoring,
          pulseController: _soundPulseController,
          onToggleMonitoring: _toggleSoundMonitoring,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: const AdaptiveAppBar(title: 'Welcome'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (topInset > 0) SizedBox(height: topInset),
              // replicate header from unified home to keep branding
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/images/real_logo.png',
                        height: 32,
                        width: 32,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "SenScribe",
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Start here',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    AdaptiveButton(
                      onPressed: _openTextToSpeech,
                      label: 'Text to Speech',
                      style: AdaptiveButtonStyle.filled,
                    ),
                    const SizedBox(height: 16),
                    AdaptiveButton(
                      onPressed: _openSpeechToText,
                      label: 'Speech to Text',
                      style: AdaptiveButtonStyle.filled,
                    ),
                    const SizedBox(height: 16),
                    AdaptiveButton(
                      onPressed: _openSoundRecognition,
                      label: 'Sound Recognition',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
