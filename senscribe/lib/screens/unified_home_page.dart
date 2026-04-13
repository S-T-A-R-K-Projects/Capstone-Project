import 'dart:async';

import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../navigation/adaptive_page_route.dart';
import '../services/audio_classification_service.dart';
import '../services/text_to_speech_service.dart';
import '../models/sound_caption.dart';
import '../models/sound_filter.dart';
import 'package:flutter/services.dart';

import 'speech_to_text_page.dart';
import 'text_to_speech_page.dart';
import 'home_page.dart';
import '../services/history_service.dart';
import '../models/history_item.dart';
import '../services/trigger_word_service.dart';
import '../models/trigger_alert.dart';
import '../models/trigger_word.dart';
import '../services/android_offline_speech_service.dart';
import '../services/stt_transcript_service.dart';
import '../utils/time_utils.dart';
import '../utils/app_constants.dart';
import '../services/live_update_service.dart';
import '../services/sound_filter_service.dart';

class UnifiedHomePage extends StatefulWidget {
  const UnifiedHomePage({super.key});

  @override
  State<UnifiedHomePage> createState() => _UnifiedHomePageState();
}

class _UnifiedHomePageState extends State<UnifiedHomePage>
    with TickerProviderStateMixin {
  // Services
  final AudioClassificationService _audioService = AudioClassificationService();
  final SpeechToText _speech = SpeechToText();
  final AndroidOfflineSpeechService _androidSpeechService =
      AndroidOfflineSpeechService();
  final TextToSpeechService _ttsService = TextToSpeechService();
  final LiveUpdateService _liveUpdateService = LiveUpdateService();
  final SoundFilterService _soundFilterService = SoundFilterService();

  // State
  List<SoundCaption> _soundEvents = [];
  final TextEditingController _ttsController = TextEditingController();
  final ScrollController _sttScrollController = ScrollController();

  // Expansion State
  bool _isSoundExpanded = true;
  bool _isSTTExpanded = true;
  bool _isTTSExpanded = true;

  // Simultaneous Monitoring States
  bool _isSoundMonitoring = false;
  bool _isSpeechMonitoring = false;
  bool _isSpeechAvailable = false;

  StreamSubscription? _audioSubscription;
  StreamSubscription<Set<SoundFilterId>>? _filterSelectionSubscription;
  StreamSubscription<AndroidOfflineSpeechEvent>? _androidSpeechSubscription;
  StreamSubscription<SttTranscriptSnapshot>? _transcriptSubscription;
  String _currentSpeechBuffer = '';
  final List<String> _speechTranscript = [];
  final TriggerWordService _triggerWordService = TriggerWordService();
  final SttTranscriptService _sttTranscriptService = SttTranscriptService();
  final Map<String, int> _lastAlertedTriggerCount = {};
  Timer? _speechRestartTimer;
  bool _isSpeechStarting = false;

  // Animations
  late final AnimationController _soundPulseController;
  late final AnimationController _speechPulseController;

  @override
  void initState() {
    super.initState();
    unawaited(_soundFilterService.initialize());
    unawaited(_triggerWordService.warmCache());
    // Sync initial state
    _isSoundMonitoring = _audioService.isMonitoring;
    _soundEvents = List.from(_audioService.history);

    // Subscribe to shared history
    _audioSubscription = _audioService.historyStream.listen((events) {
      if (mounted) {
        setState(() {
          _soundEvents = events;
        });
      }
    });
    _filterSelectionSubscription =
        _soundFilterService.selectionStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });

    _soundPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _speechPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    if (_isSoundMonitoring) {
      _soundPulseController.repeat(reverse: true);
      unawaited(_syncLiveUpdatesSafely(isMonitoring: true));
    }

    _ttsController.addListener(() {
      if (mounted) setState(() {});
    });

    _syncFromSharedTranscript(_sttTranscriptService.current, notify: false);
    _transcriptSubscription = _sttTranscriptService.stream.listen((snapshot) {
      if (!mounted) return;
      _syncFromSharedTranscript(snapshot);
    });

    _initSpeech();
    _initTTS();
  }

  void _syncFromSharedTranscript(
    SttTranscriptSnapshot snapshot, {
    bool notify = true,
  }) {
    if (!notify) {
      _speechTranscript
        ..clear()
        ..addAll(snapshot.finalizedSegments);
      _currentSpeechBuffer = snapshot.partialWords;
      return;
    }

    setState(() {
      _speechTranscript
        ..clear()
        ..addAll(snapshot.finalizedSegments);
      _currentSpeechBuffer = snapshot.partialWords;
    });
  }

  Future<void> _initTTS() async {
    await _ttsService.init();
  }

  Future<void> _initSpeech() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _androidSpeechSubscription ??= _androidSpeechService.events.listen(
        _handleAndroidSpeechEvent,
      );
      _isSpeechAvailable = await _androidSpeechService.initialize();
      if (mounted) setState(() {});

      if (_isSpeechAvailable && _isSpeechMonitoring) {
        await _startSpeechListening();
      }
      return;
    }

    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: _onSpeechError,
        onStatus: _onSpeechStatus,
      );
      if (mounted) setState(() {});

      if (_isSpeechAvailable && _isSpeechMonitoring) {
        await _startSpeechListening();
      }
    } catch (e) {
      debugPrint('STT Init Failed: $e');
    }
  }

  void _onSpeechStatus(String status) {
    if (!mounted || !_isSpeechMonitoring) return;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      if (status == 'stopped') {
        _scheduleSpeechRestart(Delays.speechRestart);
      }
      return;
    }
    if (!_isSpeechMonitoring) return;
    if (status == 'done' || status == 'notListening') {
      _scheduleSpeechRestart(Delays.speechRestart);
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('STT Error: $error');
    if (!_isSpeechMonitoring || error.errorMsg == 'error_permission') return;

    if (error.errorMsg == 'error_audio_error' ||
        error.errorMsg == 'error_client') {
      return;
    }

    final restartDelay = error.errorMsg == 'error_listen_failed'
        ? Delays.speechRestartAfterFailed
        : Delays.speechRestartAfterError;
    _scheduleSpeechRestart(restartDelay);
  }

  void _handleAndroidSpeechEvent(AndroidOfflineSpeechEvent event) {
    switch (event.type) {
      case AndroidOfflineSpeechEventType.partial:
        final refinedText = _triggerWordService.refineRecognizedText(event.text);
        _sttTranscriptService.setPartialWords(refinedText);
        if (refinedText.isNotEmpty) {
          unawaited(_checkAndNotifyPartialTriggers(refinedText));
        }
        break;
      case AndroidOfflineSpeechEventType.finalResult:
        final refinedText = _triggerWordService.refineRecognizedText(event.text);
        if (refinedText.isNotEmpty) {
          _sttTranscriptService.commitFinalWords(refinedText);
          _scrollToBottom();
        }
        break;
      case AndroidOfflineSpeechEventType.status:
        _onSpeechStatus(event.status);
        break;
      case AndroidOfflineSpeechEventType.error:
        debugPrint(
          'Android Offline STT Error: ${event.errorCode} ${event.errorMessage}',
        );
        if (!_isSpeechMonitoring) {
          return;
        }
        _scheduleSpeechRestart(Delays.speechRestartAfterError);
        break;
    }
  }

  void _scheduleSpeechRestart(Duration delay) {
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(delay, () {
      if (mounted && _isSpeechMonitoring) {
        _startSpeechListening();
      }
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _filterSelectionSubscription?.cancel();
    _androidSpeechSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _speechRestartTimer?.cancel();

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      unawaited(_androidSpeechService.stopListening());
    } else {
      _speech.stop();
    }
    _soundPulseController.dispose();
    _speechPulseController.dispose();
    _ttsController.dispose();
    _sttScrollController.dispose();
    super.dispose();
  }

  // --- Sound Monitoring ---
  void _toggleSoundMonitoring() {
    setState(() {
      _isSoundMonitoring = !_isSoundMonitoring;
      if (_isSoundMonitoring) {
        _startSoundMonitoring();
      } else {
        _stopSoundMonitoring();
      }
    });
  }

  Future<void> _startSoundMonitoring() async {
    await _audioService.start();
    if (!_audioService.isMonitoring) {
      if (!mounted) return;
      setState(() {
        _isSoundMonitoring = false;
      });
      return;
    }
    _soundPulseController.repeat(reverse: true);
    await _syncLiveUpdatesSafely(isMonitoring: true);
  }

  Future<void> _stopSoundMonitoring() async {
    await _audioService.stop();
    _soundPulseController.stop();
    _soundPulseController.reset();
    await _syncLiveUpdatesSafely(isMonitoring: false);
  }

  Future<void> _syncLiveUpdatesSafely({required bool isMonitoring}) async {
    try {
      await _liveUpdateService.syncMonitoringState(isMonitoring: isMonitoring);
    } catch (error) {
      debugPrint('Live update sync failed: $error');
    }
  }

  // _handleSoundEvent removed as it's handled by service
  // _isCriticalSound removed as it's handled by service/model

  // --- Speech Monitoring ---
  void _toggleSpeechMonitoring() {
    setState(() {
      _isSpeechMonitoring = !_isSpeechMonitoring;
      if (_isSpeechMonitoring) {
        _startSpeechListening();
        _speechPulseController.repeat(reverse: true);
      } else {
        _speechRestartTimer?.cancel();
        _lastAlertedTriggerCount.clear();
        _stopSpeechException();
        _speechPulseController.stop();
        _speechPulseController.reset();
      }
    });
  }

  void _toggleSpeechMonitoringFromDetail() {
    _toggleSpeechMonitoring();
  }

  Future<void> _startSpeechListening() async {
    final usesAndroidOfflineSpeech =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final speechAlreadyListening = usesAndroidOfflineSpeech
        ? _androidSpeechService.isListening
        : _speech.isListening;

    if (!_isSpeechAvailable || speechAlreadyListening || _isSpeechStarting) {
      return;
    }
    _isSpeechStarting = true;
    try {
      if (usesAndroidOfflineSpeech) {
        await _androidSpeechService.startListening();
      } else {
        await _speech.cancel();
        await _speech.listen(
          onResult: (result) {
            final refinedText = _triggerWordService.refineRecognizedText(
              result.recognizedWords,
            );
            _sttTranscriptService.setPartialWords(refinedText);

            if (!result.finalResult && refinedText.isNotEmpty) {
              _checkAndNotifyPartialTriggers(refinedText);
            }

            if (result.finalResult && refinedText.isNotEmpty) {
              _sttTranscriptService.commitFinalWords(refinedText);
              _scrollToBottom();
            }
          },
          listenFor: const Duration(minutes: 10),
          pauseFor: const Duration(seconds: 45),
          listenOptions: SpeechListenOptions(
            partialResults: true,
            cancelOnError: false,
            listenMode: ListenMode.dictation,
          ),
        );
      }
    } catch (e) {
      debugPrint('STT Listen Error: $e');
      if (_isSpeechMonitoring) {
        _scheduleSpeechRestart(const Duration(milliseconds: 350));
      }
    } finally {
      _isSpeechStarting = false;
    }
  }

  Future<void> _checkAndNotifyPartialTriggers(String recognizedText) async {
    final text = recognizedText.trim();
    if (text.isEmpty || !mounted) return;

    try {
      final triggerConfigs = await _triggerWordService.loadTriggerWords();
      final detected = await _triggerWordService.checkForTriggers(text);
      if (detected.isEmpty || !mounted) return;

      final newlyNotified = <String>[];

      for (final trigger in detected) {
        TriggerWord? config;
        for (final word in triggerConfigs) {
          if (word.word.toLowerCase() == trigger.toLowerCase()) {
            config = word;
            break;
          }
        }
        if (config == null) continue;

        final currentCount = _countTriggerOccurrences(text, config);
        final lastCount = _lastAlertedTriggerCount[trigger.toLowerCase()] ?? 0;
        if (currentCount <= lastCount) continue;

        _lastAlertedTriggerCount[trigger.toLowerCase()] = currentCount;
        newlyNotified.add(trigger);

        await _triggerWordService.addAlert(
          TriggerAlert(
            triggerWord: trigger,
            detectedText: text,
            source: TriggerAlert.sourceSpeechToText,
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

  int _countTriggerOccurrences(String text, TriggerWord triggerWord) {
    if (text.isEmpty) return 0;

    if (triggerWord.exactMatch) {
      final expression = RegExp(
        r'\b' + RegExp.escape(triggerWord.word) + r'\b',
        caseSensitive: triggerWord.caseSensitive,
      );
      return expression.allMatches(text).length;
    }

    final haystack = triggerWord.caseSensitive ? text : text.toLowerCase();
    final needle = triggerWord.caseSensitive
        ? triggerWord.word
        : triggerWord.word.toLowerCase();
    if (needle.isEmpty) return 0;

    var count = 0;
    var start = 0;
    while (true) {
      final index = haystack.indexOf(needle, start);
      if (index == -1) break;
      count++;
      start = index + needle.length;
    }
    return count;
  }

  Future<void> _stopSpeechException() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _androidSpeechService.stopListening();
      return;
    }
    await _speech.stop();
  }

  void _scrollToBottom() {
    if (_sttScrollController.hasClients) {
      Future.delayed(Delays.scrollDelay, () {
        _sttScrollController.animateTo(
          _sttScrollController.position.maxScrollExtent,
          duration: Delays.scrollAnimation,
          curve: Curves.easeOut,
        );
      });
    }
  }

  // --- TTS ---
  void _handleTTSSubmit() {
    final text = _ttsController.text.trim();
    if (text.isEmpty) return;

    _ttsController.clear();
    _ttsService.speak(text);

    setState(() {});
  }

  // --- STT Saving ---
  Future<void> _saveSTTTranscript() async {
    final fullText = _sttTranscriptService.current.fullText;
    if (fullText.trim().isEmpty) return;

    final service = HistoryService();
    final nextIndex = await service.nextTextIndex();
    if (!mounted) return;

    final defaultTitle = 'Text-${nextIndex.toString().padLeft(4, '0')}';

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = HistoryItem(
      id: id,
      title: defaultTitle,
      subtitle: 'Unified STT',
      content: fullText,
      timestamp: DateTime.now(),
      metadata: {'source': 'unified_stt'},
    );

    await service.add(item);
    if (!mounted) return;
    AdaptiveSnackBar.show(context,
        message: "Text saved", type: AdaptiveSnackBarType.success);
  }

  void _clearSTT() {
    _sttTranscriptService.clear();
  }

  void _clearTTS() {
    _ttsController.clear();
  }

  // --- Navigation Helpers ---
  void _navigateToExpanded(Widget page) {
    pushAdaptivePage<void>(context, builder: (_) => page);
  }

  Future<void> _openExpandedSpeechPage() async {
    if (!mounted) return;

    await pushAdaptivePage<void>(
      context,
      builder: (_) => SpeechToTextPage(
        isMonitoring: _isSpeechMonitoring,
        pulseController: _speechPulseController,
        onToggleMonitoring: _toggleSpeechMonitoringFromDetail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final SystemUiOverlayStyle overlayStyle = brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: AdaptiveScaffold(
          body: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  children: [
                    // Header
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
                          Text("SenScribe",
                              style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5)),
                        ],
                      ),
                    ),

                    // 1. Sound Recognition Section (Top)
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms),
                        SlideEffect(
                            begin: Offset(0, 0.1),
                            duration: 400.ms,
                            curve: Curves.easeOutQuad)
                      ],
                      child: _buildSectionContainer(
                        title: "Sound Recognition",
                        icon: Icons.hearing_rounded,
                        height: 250,
                        isExpanded: _isSoundExpanded,
                        isMonitoring: _isSoundMonitoring,
                        onToggle: _toggleSoundMonitoring,
                        onCollapseToggle: () => setState(
                            () => _isSoundExpanded = !_isSoundExpanded),
                        onExpand: () {
                          // Navigate to detailed Sound page (HomePage)
                          _navigateToExpanded(HomePage(
                            isMonitoring: _isSoundMonitoring,
                            pulseController: _soundPulseController,
                            onToggleMonitoring: _toggleSoundMonitoring,
                          ));
                        },
                        child: _buildSoundContent(),
                      ),
                    ),
                    // 2. STT Section (Middle)
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms, delay: 100.ms),
                        SlideEffect(
                            begin: Offset(0, 0.1),
                            duration: 400.ms,
                            curve: Curves.easeOutQuad,
                            delay: 100.ms)
                      ],
                      child: _buildSectionContainer(
                        title: "Speech to Text",
                        icon: Icons.mic_rounded,
                        height: 280, // Reduced from 400 as requested
                        isExpanded: _isSTTExpanded,
                        isMonitoring: _isSpeechMonitoring,
                        onToggle: _toggleSpeechMonitoring,
                        onCollapseToggle: () =>
                            setState(() => _isSTTExpanded = !_isSTTExpanded),
                        onExpand: _openExpandedSpeechPage,
                        child: _buildSTTContent(),
                      ),
                    ),
                    // 3. TTS Section (Bottom)
                    Animate(
                      effects: [
                        FadeEffect(duration: 400.ms, delay: 200.ms),
                        SlideEffect(
                            begin: Offset(0, 0.1),
                            duration: 400.ms,
                            curve: Curves.easeOutQuad,
                            delay: 200.ms)
                      ],
                      child: _buildSectionContainer(
                        title: "Text to Speech",
                        icon: Icons.record_voice_over_rounded,
                        isExpanded: _isTTSExpanded,
                        isMonitoring: false, // TTS doesn't monitor
                        showToggle: false,
                        scrollableBody: false,
                        onCollapseToggle: () =>
                            setState(() => _isTTSExpanded = !_isTTSExpanded),
                        onExpand: () => _navigateToExpanded(TextToSpeechPage(
                            isMonitoring: false,
                            pulseController: _speechPulseController,
                            onToggleMonitoring: () {})),
                        child: _buildTTSContent(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
    double? height, // Made optional/unused
    required bool isExpanded,
    required VoidCallback onCollapseToggle,
    bool isMonitoring = false,
    bool showToggle = true,
    bool scrollableBody = true,
    required VoidCallback onExpand,
    VoidCallback? onToggle,
  }) {
    final sectionBorderRadius = BorderRadius.circular(24);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: sectionBorderRadius,
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: AdaptiveCard(
        padding: EdgeInsets.zero,
        borderRadius: sectionBorderRadius,
        clipBehavior: PlatformInfo.isIOS ? Clip.antiAlias : Clip.none,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Circular Expand/Collapse Button
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: _buildSectionIconButton(
                        icon: isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        onPressed: onCollapseToggle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon,
                        size: 24, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                    if (showToggle && onToggle != null)
                      IconButton(
                        icon: Icon(isMonitoring
                            ? Icons.stop_circle_rounded
                            : Icons.play_circle_fill_rounded),
                        color: isMonitoring ? Colors.red : Colors.green,
                        iconSize: 32,
                        onPressed: onToggle,
                      ),
                    const SizedBox(width: 8),
                    // Circular Forward Button
                    SizedBox(
                      height: 36,
                      width: 36,
                      child: _buildSectionIconButton(
                        icon: Icons.chevron_right_rounded,
                        onPressed: onExpand,
                      ),
                    ),
                  ],
                ),
              ),

              if (isExpanded) ...[
                const Divider(height: 1, thickness: 0.5),
                // Content
                if (height != null)
                  SizedBox(
                    height: height - 80, // Approximate height remaining
                    child: scrollableBody
                        ? SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: child,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: child,
                          ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: child,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final backgroundColor = PlatformInfo.isIOS
        ? scheme.primary.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSoundContent() {
    final scheme = Theme.of(context).colorScheme;
    final visibleSoundEvents =
        _soundFilterService.visibleCaptions(_soundEvents);

    return Column(
      children: [
        // Sound Events List
        if (visibleSoundEvents.isEmpty)
          _buildSectionEmptyState(
            icon: Icons.graphic_eq_rounded,
            title: _soundFilterService.hasAnySelectedFilters
                ? 'No sounds detected yet'
                : 'No filters selected',
            subtitle: !_soundFilterService.hasAnySelectedFilters
                ? 'Open the full Sound Recognition page and select a filter to show sounds here.'
                : _isSoundMonitoring
                    ? 'Listening for sounds that match your selected filters.'
                    : 'Start monitoring to classify nearby audio.',
            iconColor: scheme.onSurface.withValues(alpha: 0.32),
          )
        else
          ListView.builder(
            physics: const NeverScrollableScrollPhysics(), // Nested scrolling
            shrinkWrap: true, // Needed inside SingleChildScrollView
            itemCount: visibleSoundEvents.length,
            itemBuilder: (context, index) {
              final event = visibleSoundEvents[index];
              final matchLabel =
                  '${(event.confidence * 100).toStringAsFixed(0)}%';

              return AdaptiveListTile(
                leading: Icon(
                  event.icon,
                  color: event.isCritical ? scheme.error : scheme.primary,
                ),
                title: Text(
                  event.displaySound,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  TimeUtils.formatTimeAgo(event.timestamp),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.68),
                  ),
                ),
                trailing: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 48),
                  child: Text(
                    matchLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface.withValues(alpha: 0.84),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSTTContent() {
    final scheme = Theme.of(context).colorScheme;

    if (_speechTranscript.isEmpty && _currentSpeechBuffer.isEmpty) {
      return _buildSectionEmptyState(
        icon: _isSpeechMonitoring ? Icons.mic_rounded : Icons.mic_none_rounded,
        title: _isSpeechMonitoring
            ? 'Listening for speech...'
            : 'Tap play to transcribe speech',
        subtitle: _isSpeechMonitoring
            ? 'Speak near the microphone to see live transcription.'
            : null,
        iconColor: _isSpeechMonitoring
            ? scheme.primary.withValues(alpha: 0.72)
            : scheme.onSurface.withValues(alpha: 0.32),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Action Bar for STT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            children: [
              SizedBox(
                width: 70,
                child: AdaptiveButton(
                  onPressed: _saveSTTTranscript,
                  label: "Save",
                  style: AdaptiveButtonStyle.plain,
                  size: AdaptiveButtonSize.small,
                  useNative: false,
                ),
              ),
              SizedBox(
                width: 70,
                child: AdaptiveButton(
                  onPressed: _clearSTT,
                  label: "Clear",
                  style: AdaptiveButtonStyle.plain,
                  color: scheme.error,
                  size: AdaptiveButtonSize.small,
                  useNative: false,
                ),
              ),
            ],
          ),
        ),

        Column(
          children: [
            ..._speechTranscript.map((t) => Padding(
                  padding:
                      const EdgeInsets.only(bottom: 8.0, left: 8.0, right: 8.0),
                  child: Text(t, style: GoogleFonts.inter(fontSize: 16)),
                )),
            if (_currentSpeechBuffer.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_currentSpeechBuffer,
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        color: scheme.onSurface.withValues(alpha: 0.72),
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color iconColor,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 50, color: iconColor),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface.withValues(alpha: 0.84),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                height: 1.35,
                color: scheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTTSContent() {
    return Row(
      children: [
        Expanded(
          child: AdaptiveTextField(
            controller: _ttsController,
            placeholder: "Type to speak...",
            onSubmitted: (_) => _handleTTSSubmit(),
            style: GoogleFonts.inter(
              fontSize: 16,
              height: 1.25,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            suffixIcon: _ttsController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: _clearTTS,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: _handleTTSSubmit,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
