import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/sound_caption.dart';
import '../models/sound_filter.dart';
import '../models/trigger_alert.dart';
import '../utils/time_utils.dart';
import '../widgets/sound_caption_card.dart';
import '../services/audio_classification_service.dart';
import '../services/sound_filter_service.dart';
import '../services/trigger_word_service.dart';

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
  final AudioClassificationService _audioService = AudioClassificationService();
  final SoundFilterService _soundFilterService = SoundFilterService();
  final TriggerWordService _triggerWordService = TriggerWordService();
  List<SoundCaption> _captions = [];
  StreamSubscription<List<SoundCaption>>? _classificationSubscription;
  StreamSubscription<Set<SoundFilterId>>? _filterSelectionSubscription;
  late bool _isMonitoring;
  Set<SoundFilterId> _selectedFilters = Set<SoundFilterId>.from(
    SoundFilterId.defaultSelection,
  );

  // Cached filtered list — invalidated when _captions or _selectedFilter change.
  List<SoundCaption>? _filteredCaptionsCache;

  @override
  void initState() {
    super.initState();
    unawaited(_soundFilterService.initialize());
    _isMonitoring = widget.isMonitoring;
    // Sync initial state
    _captions = List.from(_audioService.history);
    _selectedFilters = _soundFilterService.selectedFilters;

    // Subscribe to shared history
    _classificationSubscription = _audioService.historyStream.listen((events) {
      if (mounted) {
        setState(() {
          _captions = events;
          _filteredCaptionsCache = null; // invalidate
        });
      }
    });
    _filterSelectionSubscription =
        _soundFilterService.selectionStream.listen((selectedFilters) {
      if (!mounted) return;
      setState(() {
        _selectedFilters = selectedFilters;
        _filteredCaptionsCache = null;
      });
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
    _filterSelectionSubscription?.cancel();
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

  void _deleteCaption(SoundCaption caption) {
    final removed = _audioService.deleteCaption(caption);
    if (!removed || !mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Sound removed from the feed',
      type: AdaptiveSnackBarType.info,
    );
  }

  Future<void> _saveCaptionToAlerts(SoundCaption caption) async {
    final alert = TriggerAlert(
      triggerWord: caption.displaySound,
      detectedText: _buildCaptionSummary(caption),
      timestamp: caption.timestamp,
      source: caption.source == SoundCaptionSource.custom
          ? TriggerAlert.sourceCustomSound
          : TriggerAlert.sourceSoundRecognition,
      metadata: _buildCaptionMetadata(caption),
    );

    final inserted = await _triggerWordService.addAlert(alert);
    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: inserted
          ? '${caption.displaySound} saved to Recent Alerts'
          : 'This detected ${caption.displaySound} sound is already saved in Recent Alerts',
      type: inserted
          ? AdaptiveSnackBarType.success
          : AdaptiveSnackBarType.warning,
    );
  }

  Future<void> _showCaptionDetails(SoundCaption caption) async {
    await AdaptiveAlertDialog.show(
      context: context,
      title: caption.displaySound,
      message: _buildCaptionDetailsMessage(caption),
      icon: _detailIconForCaption(caption),
      iconSize: 36,
      iconColor: Theme.of(context).colorScheme.primary,
      actions: [
        AlertAction(
          title: 'Close',
          style: AlertActionStyle.primary,
          onPressed: () {},
        ),
      ],
    );
  }

  Map<String, dynamic> _buildCaptionMetadata(SoundCaption caption) {
    return {
      'detectorLabel': _captionDetectorLabel(caption),
      'confidencePercent': (caption.confidence * 100).round(),
      'priorityLabel': caption.isCritical ? 'Critical' : 'Standard',
      'isCritical': caption.isCritical,
    };
  }

  String _captionDetectorLabel(SoundCaption caption) {
    return caption.source == SoundCaptionSource.custom
        ? 'Custom sound'
        : 'Built-in sound';
  }

  String _buildCaptionSummary(SoundCaption caption) {
    final confidence = (caption.confidence * 100).round();
    final priority = caption.isCritical ? 'Critical' : 'Standard';
    return '${_captionDetectorLabel(caption)} • '
        '$confidence% confidence • '
        '$priority priority';
  }

  String _buildCaptionDetailsMessage(SoundCaption caption) {
    final sourceLabel = _captionDetectorLabel(caption);
    final confidence = (caption.confidence * 100).round();
    final priority = caption.isCritical ? 'Critical' : 'Standard';
    final detectedAt = TimeUtils.formatExactDateTime(caption.timestamp);
    return 'Detector: $sourceLabel\n'
        'Confidence: $confidence%\n'
        'Priority: $priority\n'
        'Detected: $detectedAt';
  }

  dynamic _detailIconForCaption(SoundCaption caption) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return caption.source == SoundCaptionSource.custom
          ? 'tuningfork'
          : 'waveform';
    }
    return caption.source == SoundCaptionSource.custom
        ? Icons.tune_rounded
        : Icons.graphic_eq_rounded;
  }

  void _clearCaptions() {
    if (_captions.isEmpty) {
      AdaptiveSnackBar.show(
        context,
        message: 'The sound feed is already empty',
        type: AdaptiveSnackBarType.info,
      );
      return;
    }
    _audioService.clearHistory();
    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Sound feed cleared',
      type: AdaptiveSnackBarType.success,
    );
  }

  Future<void> _showHistoryLimitOptions() async {
    String customValue = _audioService.historyLimit?.toString() ?? '';
    final selection = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Latest sound items',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHistoryLimitOption(dialogContext, '15 latest', '15'),
                  _buildHistoryLimitOption(dialogContext, '30 latest', '30'),
                  _buildHistoryLimitOption(dialogContext, '50 latest', '50'),
                  _buildHistoryLimitOption(dialogContext, '100 latest', '100'),
                  _buildHistoryLimitOption(
                    dialogContext,
                    'Unlimited',
                    'unlimited',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Custom',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: customValue,
                    keyboardType: TextInputType.number,
                    onChanged: (value) => customValue = value,
                    decoration: const InputDecoration(
                      hintText: 'Enter number of latest sound items',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext)
                  .pop('custom:${customValue.trim()}'),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (!mounted || selection == null) return;

    if (selection.startsWith('custom:')) {
      final rawValue = selection.substring('custom:'.length);
      final value = int.tryParse(rawValue);
      if (value == null || value <= 0) {
        AdaptiveSnackBar.show(
          context,
          message: 'Enter a number greater than 0',
          type: AdaptiveSnackBarType.warning,
        );
        return;
      }
      _audioService.setHistoryLimit(value);
      setState(() {});
      return;
    }

    final nextLimit = selection == 'unlimited' ? null : int.tryParse(selection);
    _audioService.setHistoryLimit(nextLimit);
    if (mounted) setState(() {});
  }

  Widget _buildHistoryLimitOption(
    BuildContext context,
    String label,
    String value,
  ) {
    return TextButton(
      onPressed: () => Navigator.of(context).pop(value),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(label, style: GoogleFonts.inter()),
      ),
    );
  }

  String get _historyLimitLabel {
    final limit = _audioService.historyLimit;
    return limit == null ? 'Unlimited' : limit.toString();
  }

  List<SoundCaption> get _filteredCaptions {
    if (_filteredCaptionsCache != null) return _filteredCaptionsCache!;
    final result = _soundFilterService.visibleCaptions(
      _captions,
      selectedFilters: _selectedFilters,
    );
    _filteredCaptionsCache = result;
    return result;
  }

  Future<void> _onFilterChipPressed(
    SoundFilterId filterId,
    bool selected,
  ) async {
    final result =
        await _soundFilterService.setFilterSelected(filterId, selected);
    if (!mounted) return;

    if (result == SoundFilterSelectionResult.updated &&
        !_soundFilterService.hasAnySelectedFilters) {
      _showNoFiltersSelectedMessage();
    }
  }

  Future<void> _onAllFilterPressed() async {
    await _soundFilterService.selectAllFilters();
    if (!mounted) return;
    if (!_soundFilterService.hasAnySelectedFilters) {
      _showNoFiltersSelectedMessage();
    }
  }

  void _showNoFiltersSelectedMessage() {
    const message = 'Please select a filter to show the sounds';

    if (!Platform.isAndroid) {
      AdaptiveSnackBar.show(
        context,
        message: message,
        type: AdaptiveSnackBarType.info,
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final snackBarTheme = Theme.of(context).snackBarTheme;
    final colorScheme = Theme.of(context).colorScheme;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: snackBarTheme.contentTextStyle ??
                GoogleFonts.inter(
                  color: colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
          ),
          behavior: snackBarTheme.behavior ?? SnackBarBehavior.floating,
          backgroundColor: snackBarTheme.backgroundColor ??
              colorScheme.surfaceContainerHighest,
          shape: snackBarTheme.shape,
          margin: snackBarTheme.insetPadding,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filteredCaptions = _filteredCaptions;
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'SenScribe'),
      body: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            if (topInset > 0) SizedBox(height: topInset),
            Padding(
              padding: const EdgeInsets.all(16),
              child: AdaptiveCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                                  : scheme.onSurface.withValues(alpha: 0.16),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isMonitoring
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              size: 24,
                              color: _isMonitoring
                                  ? Colors.green
                                  : scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
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
                                  : scheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _isMonitoring
                                ? 'Listening for sounds...'
                                : 'Tap to start monitoring',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color:
                                    scheme.onSurface.withValues(alpha: 0.72)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 92,
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
                  children: [
                    AnimationConfiguration.staggeredList(
                      position: 0,
                      duration: const Duration(milliseconds: 375),
                      child: SlideAnimation(
                        horizontalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(
                                'All',
                                style: GoogleFonts.inter(
                                  color:
                                      _soundFilterService.areAllFiltersSelected
                                          ? scheme.onPrimary
                                          : scheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              selected:
                                  _soundFilterService.areAllFiltersSelected,
                              onSelected: (_) => _onAllFilterPressed(),
                              selectedColor: scheme.primary,
                              backgroundColor: scheme.surfaceContainerHighest,
                              elevation: 2,
                              pressElevation: 4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    ...SoundFilterId.displayOrder.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final filter = entry.value;
                      final isSelected = _selectedFilters.contains(filter);

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
                                  filter.label,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? scheme.onPrimary
                                        : scheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                selected: isSelected,
                                onSelected: (selected) =>
                                    _onFilterChipPressed(filter, selected),
                                selectedColor: scheme.primary,
                                backgroundColor: scheme.surfaceContainerHighest,
                                elevation: 2,
                                pressElevation: 4,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.hearing_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
              child: Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: _clearCaptions,
                      label: 'Clear',
                      style: AdaptiveButtonStyle.plain,
                      color: scheme.error,
                      size: AdaptiveButtonSize.small,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: _showHistoryLimitOptions,
                      label: 'Latest: $_historyLimitLabel',
                      style: AdaptiveButtonStyle.plain,
                      size: AdaptiveButtonSize.small,
                    ),
                  ),
                ],
              ),
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
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          )
                              .animate()
                              .scale(duration: 600.ms)
                              .then()
                              .shimmer(duration: 1000.ms),
                          const SizedBox(height: 24),
                          Text(
                            _selectedFilters.isEmpty
                                ? 'No filters selected'
                                : _captions.isEmpty
                                    ? 'No sounds detected yet'
                                    : 'No sounds match the selected filters',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedFilters.isEmpty
                                ? 'Select a filter chip above to show matching sounds'
                                : _captions.isEmpty
                                    ? 'Start monitoring to see live captions'
                                    : 'Adjust the filter chips above to show more sounds',
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface.withValues(alpha: 0.7)),
                          ),
                        ],
                      ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.2),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 0, bottom: 8),
                      itemCount: filteredCaptions.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: SoundCaptionCard(
                            caption: filteredCaptions[index],
                            onViewDetails: () => _showCaptionDetails(
                              filteredCaptions[index],
                            ),
                            onSaveToAlerts: () => _saveCaptionToAlerts(
                              filteredCaptions[index],
                            ),
                            onDelete: () =>
                                _deleteCaption(filteredCaptions[index]),
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
