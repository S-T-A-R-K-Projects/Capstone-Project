import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import 'speech_to_text_page.dart';
import 'text_to_speech_page.dart';
import 'home_page.dart';
import '../navigation/main_navigation.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleMonitoring() {
    setState(() => _isMonitoring = !_isMonitoring);
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Welcome'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 8),
              Text('SenScribe',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),

              AdaptiveButton(
                onPressed: () {
                  // Open main home (sound recognition) via MainNavigationPage
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const MainNavigationPage()));
                },
                label: 'Open App Home',
                icon: Icons.home_rounded,
                style: AdaptiveButtonStyle.filled,
              ),

              const SizedBox(height: 12),

              AdaptiveButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => HomePage(
                            isMonitoring: _isMonitoring,
                            pulseController: _pulseController,
                            onToggleMonitoring: _toggleMonitoring,
                          )));
                },
                label: 'Active Listening (Sound Recognition)',
                icon: Icons.hearing_rounded,
                style: AdaptiveButtonStyle.plain,
              ),

              const SizedBox(height: 12),

              AdaptiveButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => SpeechToTextPage(
                            isMonitoring: _isMonitoring,
                            pulseController: _pulseController,
                            onToggleMonitoring: _toggleMonitoring,
                          )));
                },
                label: 'Speech to Text',
                icon: Icons.mic_rounded,
                style: AdaptiveButtonStyle.plain,
              ),

              const SizedBox(height: 12),

              AdaptiveButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TextToSpeechPage()));
                },
                label: 'Text to Speech',
                icon: Icons.record_voice_over_rounded,
                style: AdaptiveButtonStyle.plain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
