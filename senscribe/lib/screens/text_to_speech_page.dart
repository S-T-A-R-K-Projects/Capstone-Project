import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/text_to_speech_service.dart';

class TextToSpeechPage extends StatefulWidget {
  // Removed monitoring parameters as this page should focus on TTS
  const TextToSpeechPage({
    super.key,
    // Keep parameters optional/named but ignore them if passed from old code to avoid breakage immediately,
    // OR better, update call sites.
    // I already updated UnifiedHomePage to pass dummy values, but I can just make them optional or remove them.
    // UnifiedHomePage passes: isMonitoring: false, pulseController: ..., onToggle: ...
    // I should probably clean up UnifiedHomePage call too, but standard practice is to clean the class first.
    // I will remove them and let the caller break, then I'll fix the caller (UnifiedHomePage) in the previous step I already did?
    // Wait, in UnifiedHomePage I wrote:
    // onExpand: () => _navigateToExpanded(TextToSpeechPage(isMonitoring: false, pulseController: _speechPulseController, onToggleMonitoring: () {})),
    // So I need to keep the constructor compatible OR update UnifiedHomePage again.
    // I'll update the constructor to be compatible but deprecated/unused, OR just update UnifiedHomePage's call.
    // Updating UnifiedHomePage again is annoying.
    // I'll keep the constructor signature for now but mark as ignored, or optional.
    // Actually, I can just change the constructor to named optional and ignore them.
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120, // Reduced height since monitoring is gone
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: Text(
              'Text to Speech',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Input Area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _textController,
                            maxLines: 5,
                            decoration: InputDecoration(
                              hintText: 'Enter text to speak...',
                              border: InputBorder.none,
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearText,
                                tooltip: 'Clear text',
                              ),
                            ),
                            style: GoogleFonts.inter(fontSize: 18),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_isSpeaking)
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: OutlinedButton.icon(
                                    onPressed: _stop,
                                    icon: const Icon(Icons.stop_rounded),
                                    label: const Text('Stop'),
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red),
                                  ),
                                ),
                              FilledButton.icon(
                                onPressed: _speak,
                                icon: const Icon(Icons.volume_up_rounded),
                                label: const Text('Speak'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
