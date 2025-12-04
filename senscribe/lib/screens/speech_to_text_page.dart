import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../services/history_service.dart';
import '../models/history_item.dart';

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

  // Helper method to safely show SnackBar (avoids showing during build)
  void _showSnackBar(String message) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    });
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
      if (widget.isMonitoring && !_isListening) {
        _startListening();
      } else if (!widget.isMonitoring && _isListening) {
        _stopListening();
      }
    }
  }

  Future<void> _initializeSpeech() async {
    // The speech_to_text plugin handles permission requests internally
    // initialize() will request permissions and return false if denied
    // or if speech recognition is not available on the device
    try {
      _isAvailable = await _speech.initialize(
        onStatus: _onSpeechStatus,
        onError: _onSpeechError,
        debugLogging: true, // Enable debug logging to help diagnose issues
      );

      print('=== SPEECH INITIALIZE RESULT: $_isAvailable ===');

      if (!_isAvailable && mounted) {
        _showSnackBar(
          'Speech recognition not available. Please check permissions in Settings.',
        );
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('=== INIT ERROR: $e ===');
      if (mounted) {
        _showSnackBar('Failed to initialize speech: $e');
      }
    }
  }

  void _onSpeechStatus(String status) {
    print('=== SPEECH STATUS: $status ===');
    print('Monitoring: ${widget.isMonitoring}, Listening: $_isListening');

    if (status == 'done' || status == 'notListening') {
      print('Speech stopped - status: $status');
      if (mounted) {
        setState(() {
          _isListening = false;
        });
        // Auto-restart if still monitoring
        if (widget.isMonitoring) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && widget.isMonitoring && !_speech.isListening) {
              _startListening();
            }
          });
        }
      }
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    print('=== SPEECH ERROR: ${error.errorMsg} ===');
    if (mounted) {
      // error_no_match is normal - just means no speech detected in timeout period
      if (error.errorMsg == 'error_no_match') {
        print('No match error - restarting if still monitoring...');
        if (widget.isMonitoring) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && widget.isMonitoring) {
              _startListening();
            }
          });
        } else {
          setState(() => _isListening = false);
        }
      } else {
        // Real error - show message and stop
        setState(() => _isListening = false);
        _showSnackBar('Speech error: ${error.errorMsg}');
      }
    }
  }

  Future<void> _startListening() async {
    print('=== START LISTENING CALLED ===');
    print(
      'Available: $_isAvailable, Already listening: ${_speech.isListening}',
    );

    if (!_isAvailable) {
      print('ERROR: Speech not available');
      _showSnackBar('Speech recognition not available');
      return;
    }

    try {
      print('Calling speech.listen...');
      await _speech.listen(
        onResult: (result) {
          print(
            'Got result: ${result.recognizedWords}, final: ${result.finalResult}',
          );
          if (mounted) {
            // Only update current words if not final
            if (!result.finalResult) {
              setState(() {
                _currentWords = result.recognizedWords;
              });
            } else {
              // Final result - save to transcript ONLY ONCE
              if (widget.isMonitoring && result.recognizedWords.isNotEmpty) {
                print('=== SAVING FINAL RESULT ===');
                print('Before: "$_transcribedText"');
                print('Adding: "${result.recognizedWords}"');
                setState(() {
                  _transcribedText += result.recognizedWords + ' ';
                  _currentWords = '';
                });
                print('After: "$_transcribedText"');

                // Save a minimal history entry for this transcription
                try {
                  final id = DateTime.now().millisecondsSinceEpoch.toString();
                  final item = HistoryItem(
                    id: id,
                    title: result.recognizedWords,
                    subtitle: 'Speech transcription',
                    timestamp: DateTime.now(),
                    metadata: {'source': 'speech_to_text'},
                  );
                  HistoryService().add(item);
                } catch (e) {
                  print('Failed saving history: $e');
                }

                // Restart immediately to keep listening
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (mounted && widget.isMonitoring && !_speech.isListening) {
                    print('Restarting to continue listening...');
                    _startListening();
                  }
                });
              }
            }
          }
        },
        listenFor: const Duration(hours: 24),
        pauseFor: const Duration(hours: 24),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      );

      print('Listen started successfully');
      if (mounted) setState(() => _isListening = true);
    } catch (e) {
      print('ERROR starting listening: $e');
      if (mounted) {
        _showSnackBar('Error: $e');
      }
    }
  }

  Future<void> _stopListening() async {
    print('=== STOP LISTENING CALLED ===');
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        // Don't save current words here - final result callback already handled it
        _currentWords = '';
      });
    }
    print('Stopped successfully');
  }

  void _clearText() {
    setState(() {
      _transcribedText = '';
      _currentWords = '';
    });
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
                                                    (widget
                                                            .pulseController
                                                            .value *
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
                                                ? 'Speak now...'
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
                                            widget.isMonitoring
                                                ? 'Stop'
                                                : 'Start',
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
                  if (_transcribedText.isNotEmpty)
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
              child: (_transcribedText.isEmpty && _currentWords.isEmpty)
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
                            style: Theme.of(context).textTheme.titleMedium
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
                            style: Theme.of(context).textTheme.bodyMedium
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
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(height: 1.5),
                                  ),
                                if (_currentWords.isNotEmpty)
                                  TextSpan(
                                    text: _currentWords,
                                    style: Theme.of(context).textTheme.bodyLarge
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
