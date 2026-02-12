import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final TriggerWordService _triggerWordService = TriggerWordService();

  // Helper method to safely show SnackBar
  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
  }

  @override
  void didUpdateWidget(SpeechToTextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMonitoring != oldWidget.isMonitoring) {
      if (widget.isMonitoring) {
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
      if (widget.isMonitoring) {
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
    if (widget.isMonitoring && error.errorMsg != 'error_permission') {
      _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!_isAvailable || !widget.isMonitoring) return;

    // Don't start if already listening
    if (_speech.isListening) return;

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) return;

          // Always update with latest recognized words
          // We treat partial results as the "current segment"
          // and finalize them when the session ends
          setState(() {
            _currentWords = result.recognizedWords;
          });

          // If this is marked as final, move to transcript
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            setState(() {
              if (_transcribedText.isNotEmpty &&
                  !_transcribedText.endsWith(' ')) {
                _transcribedText += ' ';
              }
              _transcribedText += result.recognizedWords;
              _currentWords = '';
            });

            // Check for trigger words in the finalized segment
            () async {
              try {
                final detected = await _triggerWordService
                    .checkForTriggers(result.recognizedWords);
                if (detected.isNotEmpty) {
                  for (final trigger in detected) {
                    await _triggerWordService.addAlert(
                      TriggerAlert(
                        triggerWord: trigger,
                        detectedText: result.recognizedWords,
                        source: 'speech_to_text',
                      ),
                    );
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Trigger detected: ${detected.join(', ')}'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              } catch (_) {
                // Ignore trigger-check errors silently
              }
            }();
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
        if (widget.isMonitoring) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && widget.isMonitoring) {
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
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Text-0001',
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
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: AdaptiveButton.icon(
                icon: Icons.arrow_back_ios_new_rounded,
                onPressed: () => Navigator.of(context).pop(),
                style: AdaptiveButtonStyle.glass,
              ),
            ),
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            title: Text(
              'SenScribe',
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
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Listening Status Card
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: widget.pulseController,
                                  builder: (context, child) {
                                    return Transform.scale(
                                      scale: widget.isMonitoring
                                          ? 1.0 +
                                              (widget.pulseController.value *
                                                  0.2)
                                          : 1.0,
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: widget.isMonitoring
                                              ? Colors.red.withValues(
                                                  alpha: 0.2,
                                                )
                                              : Colors.grey.withValues(
                                                  alpha: 0.2,
                                                ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          widget.isMonitoring
                                              ? Icons.mic_rounded
                                              : Icons.mic_off_rounded,
                                          size: 24,
                                          color: widget.isMonitoring
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.isMonitoring
                                            ? 'Monitoring Active'
                                            : 'Monitoring Stopped',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              color: widget.isMonitoring
                                                  ? Colors.green
                                                  : Colors.grey[600],
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        widget.isMonitoring
                                            ? (_isListening
                                                ? 'Listening...'
                                                : 'Preparing...')
                                            : 'Tap to start monitoring',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey[600],
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: widget.onToggleMonitoring,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.isMonitoring
                                        ? Colors.red
                                        : Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                  child: Text(
                                    widget.isMonitoring ? 'Stop' : 'Start',
                                  ),
                                )
                                    .animate()
                                    .scale(duration: 200.ms)
                                    .then()
                                    .shimmer(
                                      duration: 1000.ms,
                                      delay: 500.ms,
                                    ),
                              ],
                            ),
                          ),
                        )
                            .animate()
                            .slideY(begin: 0.3, duration: 600.ms)
                            .fadeIn(),

                        const SizedBox(height: 64),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Speech to Text Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Speech to Text',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: !_hasTranscript || _isListening || _isSaving
                        ? null
                        : _saveTranscript,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      disabledForegroundColor: Colors.grey,
                    ),
                  ),
                  if (_hasTranscript)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearText,
                      tooltip: 'Clear text',
                    ),
                ],
              ).animate().slideX(begin: -0.2, duration: 500.ms).fadeIn(),
            ),
          ),

          // Transcribed Text Display
          SliverFillRemaining(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                            color: _isListening ? Colors.red : Colors.grey[400],
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
                    )
                  : Card(
                      elevation: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        child: SingleChildScrollView(
                          child: SelectableText.rich(
                            TextSpan(
                              children: [
                                if (_transcribedText.isNotEmpty)
                                  TextSpan(
                                    text: _transcribedText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(height: 1.5),
                                  ),
                                if (_currentWords.isNotEmpty)
                                  TextSpan(
                                    text: _currentWords.isNotEmpty &&
                                            _transcribedText.isNotEmpty &&
                                            !_transcribedText.endsWith(' ')
                                        ? ' $_currentWords'
                                        : _currentWords,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
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

          // Bottom padding for FAB
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
