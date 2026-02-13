import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/sound_caption.dart';
import '../widgets/sound_caption_card.dart';
import '../services/audio_classification_service.dart';

class HomePage extends StatefulWidget {
  final bool isMonitoring;
  final AnimationController pulseController;
  final VoidCallback onToggleMonitoring;

  const HomePage({
    super.key,
    required this.isMonitoring,
    required this.pulseController,
    required this.onToggleMonitoring,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Critical', 'Custom', 'Speech'];
  final AudioClassificationService _audioService = AudioClassificationService();
  List<SoundCaption> _captions = [];
  StreamSubscription<List<SoundCaption>>? _classificationSubscription;
  late bool _isMonitoring;

  @override
  void initState() {
    super.initState();
    _isMonitoring = widget.isMonitoring;
    // Sync initial state
    _captions = List.from(_audioService.history);

    // Subscribe to shared history
    _classificationSubscription = _audioService.historyStream.listen((events) {
      if (mounted) {
        setState(() {
          _captions = events;
        });
      }
    });

    if (_isMonitoring) {
      _startMonitoring();
    }
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMonitoring != oldWidget.isMonitoring) {
      _isMonitoring = widget.isMonitoring;
      if (widget.isMonitoring) {
        _startMonitoring();
      } else {
        _stopMonitoring();
      }
    }
  }

  @override
  void dispose() {
    _classificationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleMonitoring() async {
    if (!(Platform.isIOS || Platform.isAndroid)) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: 'Audio classification is not supported on this platform yet.',
        type: AdaptiveSnackBarType.warning,
      );
      return;
    }

    setState(() {
      _isMonitoring = !_isMonitoring;
    });
    widget.onToggleMonitoring();
  }

  Future<void> _startMonitoring() async {
    try {
      await _audioService.start();
    } catch (error) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: 'Unable to start monitoring: $error',
        type: AdaptiveSnackBarType.error,
      );
      if (widget.isMonitoring) {
        widget.onToggleMonitoring();
        if (mounted) {
          setState(() {
            _isMonitoring = false;
          });
        }
      }
    }
  }

  Future<void> _stopMonitoring() async {
    await _audioService.stop();
  }

  List<SoundCaption> get _filteredCaptions {
    if (_selectedFilter == 'Critical') {
      return _captions.where((caption) => caption.isCritical).toList();
    }
    return List<SoundCaption>.from(_captions);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredCaptions = _filteredCaptions;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'SenScribe'),
      body: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Top padding for iOS app bars (17/18/26+)
            if (Platform.isIOS)
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
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
                                  ? Colors.green.withValues(alpha: 0.2)
                                  : Colors.grey.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMonitoring
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              size: 24,
                              color: _isMonitoring ? Colors.green : Colors.grey,
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
                                ? 'Listening for sounds...'
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
                        onPressed: _toggleMonitoring,
                        label: _isMonitoring ? 'Stop' : 'Start',
                        style: AdaptiveButtonStyle.filled,
                      ),
                    ),
                  ],
                ),
              ).animate().slideY(begin: 0.3, duration: 600.ms).fadeIn(),
            ),

            // Filter Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _filters.asMap().entries.map((entry) {
                    final index = entry.key;
                    final filter = entry.value;
                    final isSelected = _selectedFilter == filter;

                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        horizontalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                filter,
                                style: GoogleFonts.inter(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              },
                              selectedColor: theme.colorScheme.secondary,
                              backgroundColor: Colors.white,
                              elevation: 2,
                              pressElevation: 4,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Real-time Feed Header
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
                      Icons.hearing_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Real-time Sound Feed',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ).animate().slideX(begin: -0.2, duration: 500.ms).fadeIn(),
            ),

            // Sound Captions List
            Expanded(
              child: filteredCaptions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.volume_off_rounded,
                            size: 80,
                            color: Colors.grey[400],
                          )
                              .animate()
                              .scale(duration: 600.ms)
                              .then()
                              .shimmer(duration: 1000.ms),
                          const SizedBox(height: 24),
                          Text(
                            'No sounds detected yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start monitoring to see live captions',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                        ],
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
                    )
                  : ListView.builder(
                      itemCount: filteredCaptions.length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                child: SoundCaptionCard(
                                  caption: filteredCaptions[index],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
