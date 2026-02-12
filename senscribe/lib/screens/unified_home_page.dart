import 'dart:async';

import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_error.dart';

import '../services/audio_classification_service.dart';
import '../services/text_to_speech_service.dart';
import '../models/sound_caption.dart';

// Import full pages for navigation
import 'speech_to_text_page.dart';
import 'text_to_speech_page.dart';
import 'home_page.dart'; // For Sound Recognition Expanded View
import '../services/history_service.dart'; // For Saving STT
import '../models/history_item.dart'; // For Saving STT
import '../services/trigger_word_service.dart';
import '../models/trigger_alert.dart';
import '../services/stt_transcript_service.dart';

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
  final TextToSpeechService _ttsService = TextToSpeechService();

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
  StreamSubscription<SttTranscriptSnapshot>? _transcriptSubscription;
  String _currentSpeechBuffer = '';
  final List<String> _speechTranscript = [];
  final TriggerWordService _triggerWordService = TriggerWordService();
  final SttTranscriptService _sttTranscriptService = SttTranscriptService();
  final Set<String> _triggersAlertedInCurrentUtterance = {};
  Timer? _speechRestartTimer;
  Timer? _utteranceBoundaryTimer;
  bool _isSpeechStarting = false;

  // Animations
  late final AnimationController _soundPulseController;
  late final AnimationController _speechPulseController;

  @override
  void initState() {
    super.initState();
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

    _soundPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _speechPulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    if (_isSoundMonitoring) {
      _soundPulseController.repeat(reverse: true);
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
    if (!_isSpeechMonitoring) return;
    if (status == 'done' || status == 'notListening') {
      _scheduleSpeechRestart(const Duration(milliseconds: 40));
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    debugPrint('STT Error: $error');
    if (!_isSpeechMonitoring || error.errorMsg == 'error_permission') return;

    final restartDelay = error.errorMsg == 'error_listen_failed'
        ? const Duration(milliseconds: 350)
        : const Duration(milliseconds: 80);
    _scheduleSpeechRestart(restartDelay);
  }

  void _scheduleSpeechRestart(Duration delay) {
    _speechRestartTimer?.cancel();
    _speechRestartTimer = Timer(delay, () {
      if (mounted && _isSpeechMonitoring) {
        _startSpeechListening();
      }
    });
  }

  void _markUtteranceActivity() {
    _utteranceBoundaryTimer?.cancel();
    _utteranceBoundaryTimer = Timer(const Duration(milliseconds: 1400), () {
      _triggersAlertedInCurrentUtterance.clear();
    });
  }

  @override
  void dispose() {
    _audioSubscription?.cancel();
    _transcriptSubscription?.cancel();
    _speechRestartTimer?.cancel();
    _utteranceBoundaryTimer?.cancel();

    _speech.stop();
    _ttsService.stop();
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
    _soundPulseController.repeat(reverse: true);
  }

  Future<void> _stopSoundMonitoring() async {
    await _audioService.stop();
    _soundPulseController.stop();
    _soundPulseController.reset();
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
        _utteranceBoundaryTimer?.cancel();
        _triggersAlertedInCurrentUtterance.clear();
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
    if (!_isSpeechAvailable || _speech.isListening || _isSpeechStarting) {
      return;
    }
    _isSpeechStarting = true;
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            _markUtteranceActivity();
          }

          _sttTranscriptService.setPartialWords(result.recognizedWords);

          if (!result.finalResult && result.recognizedWords.isNotEmpty) {
            _checkAndNotifyPartialTriggers(result.recognizedWords);
          }

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _sttTranscriptService.commitFinalWords(result.recognizedWords);
            _scrollToBottom();
            _triggersAlertedInCurrentUtterance.clear();
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
      final detected = await _triggerWordService.checkForTriggers(text);
      if (detected.isEmpty || !mounted) return;

      final newlyNotified = <String>[];

      for (final trigger in detected) {
        if (_triggersAlertedInCurrentUtterance.contains(trigger)) continue;
        _triggersAlertedInCurrentUtterance.add(trigger);
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

  Future<void> _stopSpeechException() async {
    await _speech.stop();
  }

  void _scrollToBottom() {
    if (_sttScrollController.hasClients) {
      // Small delay to allow render
      Future.delayed(const Duration(milliseconds: 100), () {
        _sttScrollController.animateTo(
          _sttScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
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
        message: "Saved to history", type: AdaptiveSnackBarType.success);
  }

  void _clearSTT() {
    _sttTranscriptService.clear();
  }

  void _clearTTS() {
    _ttsController.clear();
  }

  // --- Navigation Helpers ---
  void _navigateToExpanded(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  Future<void> _openExpandedSpeechPage() async {
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SpeechToTextPage(
          isMonitoring: _isSpeechMonitoring,
          pulseController: _speechPulseController,
          onToggleMonitoring: _toggleSpeechMonitoringFromDetail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
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
                          style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5)),
                    ],
                  ),
                ),

                // 1. Sound Recognition Section (Top)
                _buildSectionContainer(
                  title: "Sound Recognition",
                  icon: Icons.hearing_rounded,
                  height: 250,
                  isExpanded: _isSoundExpanded,
                  isMonitoring: _isSoundMonitoring,
                  onToggle: _toggleSoundMonitoring,
                  onCollapseToggle: () =>
                      setState(() => _isSoundExpanded = !_isSoundExpanded),
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

                // 2. STT Section (Middle)
                _buildSectionContainer(
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

                // 3. TTS Section (Bottom)
                _buildSectionContainer(
                  title: "Text to Speech",
                  icon: Icons.record_voice_over_rounded,
                  height: 150, // Increased to fix overflow
                  isExpanded: _isTTSExpanded,
                  isMonitoring: false, // TTS doesn't monitor
                  showToggle: false,
                  onCollapseToggle: () =>
                      setState(() => _isTTSExpanded = !_isTTSExpanded),
                  onExpand: () => _navigateToExpanded(TextToSpeechPage(
                      isMonitoring: false,
                      pulseController: _speechPulseController,
                      onToggleMonitoring: () {})),
                  child: _buildTTSContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
    required double height,
    required bool isExpanded,
    required VoidCallback onCollapseToggle,
    bool isMonitoring = false,
    bool showToggle = true,
    required VoidCallback onExpand,
    VoidCallback? onToggle,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isExpanded ? height : 80,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.transparent,
      ),
      child: AdaptiveCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  // Circular Expand/Collapse Button
                  SizedBox(
                    height: 36,
                    width: 36,
                    child: AdaptiveButton.child(
                      onPressed: onCollapseToggle,
                      style: PlatformInfo.isIOS26OrHigher()
                          ? AdaptiveButtonStyle.glass
                          : AdaptiveButtonStyle.plain,
                      child: Center(
                        child: Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 20,
                        ),
                      ),
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
                    child: AdaptiveButton.child(
                      onPressed: onExpand,
                      style: PlatformInfo.isIOS26OrHigher()
                          ? AdaptiveButtonStyle.glass
                          : AdaptiveButtonStyle.plain,
                      child: Center(
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isExpanded) ...[
              const Divider(height: 1, thickness: 0.5),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: child,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSoundContent() {
    if (_soundEvents.isEmpty) {
      return Center(
          child: Text("No sounds detected",
              style: GoogleFonts.inter(color: Colors.grey)));
    }
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(), // Nested scrolling
      shrinkWrap: true, // Needed inside SingleChildScrollView
      itemCount: _soundEvents.length > 3
          ? 3
          : _soundEvents.length, // Show limited items
      itemBuilder: (context, index) {
        final event = _soundEvents[index];
        return AdaptiveListTile(
          leading: Icon(
            event.isCritical
                ? Icons.warning_amber_rounded
                : Icons.music_note_rounded,
            color: event.isCritical ? Colors.red : Colors.blue,
          ),
          title: Text(event.sound,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          subtitle: Text("${event.confidence.toStringAsFixed(2)} confidence",
              style: GoogleFonts.inter(fontSize: 12)),
        );
      },
    );
  }

  Widget _buildSTTContent() {
    if (_speechTranscript.isEmpty && _currentSpeechBuffer.isEmpty) {
      return Center(
          child: Text("Tap play to listen...",
              style: GoogleFonts.inter(color: Colors.grey)));
    }
    return Column(
      children: [
        // Action Bar for STT
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 70,
                child: AdaptiveButton(
                  onPressed: _saveSTTTranscript,
                  label: "Save",
                  style: AdaptiveButtonStyle.plain,
                  size: AdaptiveButtonSize.small,
                ),
              ),
              SizedBox(
                width: 70,
                child: AdaptiveButton(
                  onPressed: _clearSTT,
                  label: "Clear",
                  style: AdaptiveButtonStyle.plain,
                  color: Colors.red,
                  size: AdaptiveButtonSize.small,
                ),
              ),
            ],
          ),
        ),

        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          controller: _sttScrollController,
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
                        color: Colors.grey,
                        fontStyle: FontStyle.italic)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTTSContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center, // Changed from end to center
      children: [
        Row(
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  AdaptiveTextField(
                    // Reverted to AdaptiveTextField for onSubmitted support
                    controller: _ttsController,
                    placeholder: "Type to speak...",
                    onSubmitted: (_) => _handleTTSSubmit(),
                  ),
                  if (_ttsController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: _clearTTS,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: _handleTTSSubmit,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
