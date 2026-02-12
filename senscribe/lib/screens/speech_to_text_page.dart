import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../services/history_service.dart';
import '../models/history_item.dart';
import '../services/trigger_word_service.dart';
import '../models/trigger_alert.dart';

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
  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isSaving = false;
  late bool _isMonitoring;
  final Map<String, DateTime> _lastTriggerAlertAt = {};
  static const Duration _triggerCooldown = Duration(seconds: 2);
  final TriggerWordService _triggerWordService = TriggerWordService();

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
    _initializeSpeech();
  }

  @override
  void didUpdateWidget(SpeechToTextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMonitoring != oldWidget.isMonitoring) {
      _isMonitoring = widget.isMonitoring;
      if (_isMonitoring) {
        _startListening();
      } else {
        _stopListening();
      }
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
      );

      if (!_isAvailable && mounted) {
        _showSnackBar(
          'Speech recognition not available. Please check permissions.',
        );
      }

      if (mounted) setState(() {});

      if (_isAvailable && _isMonitoring) {
        await _startListening();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to initialize speech: $e');
      }
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted) return;

    if (status == 'listening') {
      setState(() => _isListening = true);
    } else if (status == 'done' || status == 'notListening') {
      // Finalize any pending text before restarting
      if (_currentWords.isNotEmpty) {
        setState(() {
          if (_transcribedText.isNotEmpty && !_transcribedText.endsWith(' ')) {
            _transcribedText += ' ';
          }
          _transcribedText += _currentWords;
          _currentWords = '';
          _isListening = false;
        });
      } else {
        setState(() => _isListening = false);
      }

      // Restart immediately if still monitoring
      if (_isMonitoring) {
        _startListening();
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    if (!mounted) return;

    setState(() => _isListening = false);

    // Only show error for non-normal errors
    if (error.errorMsg != 'error_no_match' &&
        error.errorMsg != 'error_speech_timeout') {
      _showSnackBar('Speech error: ${error.errorMsg}');
    }

    // Restart if still monitoring (unless permission error)
    if (_isMonitoring && error.errorMsg != 'error_permission') {
      _startListening();
    }
  }

  Future<void> _checkAndNotifyTriggers(String recognizedText) async {
    final text = recognizedText.trim();
    if (text.isEmpty) return;

    try {
      final detected = await _triggerWordService.checkForTriggers(text);
      if (detected.isEmpty || !mounted) return;

      final now = DateTime.now();
      final newlyNotified = <String>[];

      for (final trigger in detected) {
        final lastAt = _lastTriggerAlertAt[trigger];
        final canNotify =
            lastAt == null || now.difference(lastAt) >= _triggerCooldown;
        if (!canNotify) continue;

        _lastTriggerAlertAt[trigger] = now;
        newlyNotified.add(trigger);

        await _triggerWordService.addAlert(
          TriggerAlert(
            triggerWord: trigger,
            detectedText: text,
            source: 'speech_to_text',
          ),
        );
      }

      if (newlyNotified.isNotEmpty && mounted) {
        AdaptiveSnackBar.show(
          context,
          message: 'Trigger detected: ${newlyNotified.join(', ')}',
          type: AdaptiveSnackBarType.warning,
        );
      }
    } catch (_) {
      // Ignore trigger-check errors silently
    }
  }

  Future<void> _handleToggleMonitoring() async {
    final nextValue = !_isMonitoring;
    setState(() {
      _isMonitoring = nextValue;
    });
    widget.onToggleMonitoring();

    if (nextValue) {
      await _startListening();
    } else {
      await _stopListening();
    }
  }

  Future<void> _startListening() async {
    if (!_isAvailable || !_isMonitoring) return;

    // Don't start if already listening
    if (_speech.isListening) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          setState(() {
            _currentWords = result.recognizedWords;
          });

          if (result.recognizedWords.isNotEmpty) {
            _checkAndNotifyTriggers(result.recognizedWords);
          }

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() {
              if (_transcribedText.isNotEmpty &&
                  !_transcribedText.endsWith(' ')) {
                _transcribedText += ' ';
              }
              _transcribedText += result.recognizedWords;
              _currentWords = '';
            });
          }
        },
        listenFor: const Duration(days: 1), // Never stop on our own
        pauseFor: const Duration(days: 1), // Never finalize on pause
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          autoPunctuation: true,
        ),
      );

      if (mounted) {
        setState(() => _isListening = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isListening = false);
        // Retry after a short delay
        if (_isMonitoring) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _isMonitoring) {
              _startListening();
            }
          });
        }
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (e) {
      // Ignore stop errors
    }

    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _clearText() {
    setState(() {
      _transcribedText = '';
      _currentWords = '';
    });
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
    _speech.stop();
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
              // Top padding for iOS 26 translucent app bar
              if (PlatformInfo.isIOS26OrHigher())
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
                        width: 80,
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
                    Text(
                      'Speech to Text',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
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
