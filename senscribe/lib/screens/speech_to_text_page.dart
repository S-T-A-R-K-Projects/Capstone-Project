import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

import '../services/history_service.dart';
import '../models/history_item.dart';
import '../services/stt_transcript_service.dart';

class SpeechToTextPage extends StatefulWidget {
  final bool isMonitoring;
  final AnimationController pulseController;
  final VoidCallback onToggleMonitoring;

  const SpeechToTextPage({
    super.key,
    required this.isMonitoring,
    required this.pulseController,
    required this.onToggleMonitoring,
  });

  @override
  State<SpeechToTextPage> createState() => _SpeechToTextPageState();
}

class _SpeechToTextPageState extends State<SpeechToTextPage> {
  String _transcribedText = '';
  String _currentWords = '';
  bool _isListening = false;
  bool _isSaving = false;
  late bool _isMonitoring;
  StreamSubscription<SttTranscriptSnapshot>? _transcriptSubscription;
  final SttTranscriptService _sttTranscriptService = SttTranscriptService();

  // Helper method to safely show SnackBar
  void _showSnackBar(String message) {
    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.info,
    );
  }

  @override
  void initState() {
    super.initState();
    _isMonitoring = widget.isMonitoring;
    _isListening = _isMonitoring;
    _syncFromSharedTranscript(_sttTranscriptService.current, notify: false);
    _transcriptSubscription = _sttTranscriptService.stream.listen((snapshot) {
      if (!mounted) return;
      _syncFromSharedTranscript(snapshot);
    });
  }

  void _syncFromSharedTranscript(
    SttTranscriptSnapshot snapshot, {
    bool notify = true,
  }) {
    if (!notify) {
      _transcribedText = snapshot.finalizedText;
      _currentWords = snapshot.partialWords;
      return;
    }

    setState(() {
      _transcribedText = snapshot.finalizedText;
      _currentWords = snapshot.partialWords;
    });
  }

  @override
  void didUpdateWidget(SpeechToTextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMonitoring != oldWidget.isMonitoring) {
      setState(() {
        _isMonitoring = widget.isMonitoring;
        _isListening = _isMonitoring;
      });
    }
  }

  Future<void> _handleToggleMonitoring() async {
    setState(() {
      _isMonitoring = !_isMonitoring;
      _isListening = _isMonitoring;
    });
    widget.onToggleMonitoring();
  }

  void _clearText() {
    _sttTranscriptService.clear();
  }

  bool get _hasTranscript {
    return _transcribedText.trim().isNotEmpty ||
        _currentWords.trim().isNotEmpty;
  }

  String get _fullTranscript {
    final buffer = StringBuffer();
    final finalized = _transcribedText.trim();
    final pending = _currentWords.trim();
    if (finalized.isNotEmpty) {
      buffer.write(finalized);
    }
    if (pending.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(pending);
    }
    return buffer.toString();
  }

  String _formatDefaultTitle(int index) {
    return 'Text-${index.toString().padLeft(4, '0')}';
  }

  Future<void> _saveTranscript() async {
    if (_isSaving) return;
    final trimmed = _fullTranscript.trim();
    if (trimmed.isEmpty) return;

    setState(() => _isSaving = true);

    final service = HistoryService();
    final nextIndex = await service.nextTextIndex();
    if (!mounted) {
      setState(() => _isSaving = false);
      return;
    }

    final defaultTitle = _formatDefaultTitle(nextIndex);
    final controller = TextEditingController(text: defaultTitle);

    final chosenTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save transcription'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Text-0001',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (!mounted) {
      controller.dispose();
      return;
    }

    controller.dispose();
    if (chosenTitle == null) {
      setState(() => _isSaving = false);
      return;
    }

    final title = chosenTitle.isEmpty ? defaultTitle : chosenTitle;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = HistoryItem(
      id: id,
      title: title,
      subtitle: 'Speech transcription',
      content: trimmed,
      timestamp: DateTime.now(),
      metadata: {'source': 'speech_to_text'},
    );

    await service.add(item);
    if (!mounted) return;
    _showSnackBar('Saved to history');
    setState(() => _isSaving = false);
  }

  @override
  void dispose() {
    _transcriptSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'SenScribe'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding for iOS app bars (17/18/26+)
              if (Platform.isIOS)
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
              // Monitoring status card
              Padding(
                padding: const EdgeInsets.all(16),
                child: AdaptiveCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: widget.pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _isMonitoring
                                ? 1.0 + (widget.pulseController.value * 0.2)
                                : 1.0,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _isMonitoring
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : Colors.grey.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isMonitoring
                                    ? Icons.mic_rounded
                                    : Icons.mic_off_rounded,
                                size: 24,
                                color: _isMonitoring ? Colors.red : Colors.grey,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isMonitoring
                                  ? 'Monitoring Active'
                                  : 'Monitoring Stopped',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: _isMonitoring
                                    ? Colors.green
                                    : Colors.grey[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _isMonitoring
                                  ? (_isListening
                                      ? 'Listening...'
                                      : 'Preparing...')
                                  : 'Tap to start monitoring',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 96,
                        child: AdaptiveButton(
                          onPressed: _handleToggleMonitoring,
                          label: _isMonitoring ? 'Stop' : 'Start',
                          style: AdaptiveButtonStyle.filled,
                        ),
                      ),
                    ],
                  ),
                ).animate().slideY(begin: 0.3, duration: 600.ms).fadeIn(),
              ),

              // Speech to Text Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Speech to Text',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 70,
                      child: AdaptiveButton(
                        onPressed: !_hasTranscript || _isListening || _isSaving
                            ? null
                            : _saveTranscript,
                        label: 'Save',
                        style: AdaptiveButtonStyle.plain,
                      ),
                    ),
                    if (_hasTranscript)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearText,
                      ),
                  ],
                ).animate().slideX(begin: -0.2, duration: 500.ms).fadeIn(),
              ),

              // Transcribed Text Display
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: !_hasTranscript
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isListening
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                size: 80,
                                color: _isListening
                                    ? Colors.red
                                    : Colors.grey[400],
                              )
                                  .animate()
                                  .scale(duration: 600.ms)
                                  .then()
                                  .shimmer(duration: 1000.ms),
                              const SizedBox(height: 24),
                              Text(
                                _isListening
                                    ? 'Listening...'
                                    : 'No speech detected yet',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: _isListening
                                      ? Colors.red
                                      : Colors.grey[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _isListening
                                    ? 'Speak now...'
                                    : 'Start monitoring to begin transcription',
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(color: Colors.grey[500]),
                              ),
                            ],
                          )
                              .animate()
                              .fadeIn(duration: 800.ms)
                              .slideY(begin: 0.2),
                        )
                      : AdaptiveCard(
                          padding: const EdgeInsets.all(20),
                          child: SizedBox(
                            width: double.infinity,
                            child: SingleChildScrollView(
                              child: SelectableText.rich(
                                TextSpan(
                                  children: [
                                    if (_transcribedText.isNotEmpty)
                                      TextSpan(
                                        text: _transcribedText,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(height: 1.5),
                                      ),
                                    if (_currentWords.isNotEmpty)
                                      TextSpan(
                                        text: _currentWords.isNotEmpty &&
                                                _transcribedText.isNotEmpty &&
                                                !_transcribedText.endsWith(' ')
                                            ? ' $_currentWords'
                                            : _currentWords,
                                        style:
                                            theme.textTheme.bodyLarge?.copyWith(
                                          height: 1.5,
                                          color: Colors.grey[600],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                ),
              ),

              // Bottom padding
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
