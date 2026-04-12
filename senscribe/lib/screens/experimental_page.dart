import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sound_filter.dart';
import '../services/audio_classification_service.dart';
import '../services/sound_filter_service.dart';
import '../utils/sound_filter_catalog.dart';

class ExperimentalPage extends StatefulWidget {
  const ExperimentalPage({super.key});

  @override
  State<ExperimentalPage> createState() => _ExperimentalPageState();
}

class _ExperimentalPageState extends State<ExperimentalPage> {
  final AudioClassificationService _audioService = AudioClassificationService();
  final SoundFilterService _soundFilterService = SoundFilterService();
  StreamSubscription<bool>? _monitoringSubscription;
  StreamSubscription<Set<SoundFilterId>>? _filterConfigSubscription;
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _isMonitoring = _audioService.isMonitoring;
    unawaited(_soundFilterService.initialize());
    _monitoringSubscription =
        _audioService.monitoringStateStream.listen((value) {
      if (!mounted) return;
      setState(() {
        _isMonitoring = value;
      });
    });
    _filterConfigSubscription = _soundFilterService.selectionStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _monitoringSubscription?.cancel();
    _filterConfigSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;
    final isAndroid = !Platform.isIOS;
    final platformLabel = isAndroid ? 'Android' : 'iOS';
    final sections = SoundFilterCatalog.referenceSectionsForPlatform(
      isAndroid: isAndroid,
    );

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Sound Filters',
      ),
      body: Material(
        color: Colors.transparent,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            if (topInset > 0) SizedBox(height: topInset),
            Text(
              'Sound Filters',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose which sound categories appear in the app and enable or disable specific built-in labels for this platform.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            _buildSoundFilterSection(
              context,
              platformLabel: platformLabel,
              sections: sections,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSoundFilterSection(
    BuildContext context, {
    required String platformLabel,
    required List<SoundFilterReferenceSection> sections,
  }) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hearing_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sound Filters',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Current platform: $platformLabel',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isMonitoring
                ? 'Stop sound recognition monitoring before editing the individual sounds inside each filter.'
                : 'Tap any sound below to enable or disable it for that specific filter. All sounds are enabled by default.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: _isMonitoring
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          for (final section in sections) ...[
            _SoundFilterSettingsCard(
              section: section,
              isMonitoring: _isMonitoring,
              soundFilterService: _soundFilterService,
              isAndroid: !Platform.isIOS,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _SoundFilterSettingsCard extends StatelessWidget {
  const _SoundFilterSettingsCard({
    required this.section,
    required this.isMonitoring,
    required this.soundFilterService,
    required this.isAndroid,
  });

  final SoundFilterReferenceSection section;
  final bool isMonitoring;
  final SoundFilterService soundFilterService;
  final bool isAndroid;

  @override
  Widget build(BuildContext context) {
    final labels = section.labels;
    final enabledCount = section.filterId.isBuiltInCategory
        ? soundFilterService
            .enabledBuiltInLabelsForFilter(
              section.filterId,
              isAndroid: isAndroid,
            )
            .length
        : 0;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          section.filterId.label,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          section.filterId == SoundFilterId.customSounds
              ? 'User-trained device-specific sounds'
              : '$enabledCount/${labels.length} sounds enabled',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        children: [
          if (section.filterId == SoundFilterId.customSounds)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Custom Sounds are still managed from Alert Triggers and custom sound enrollment. This section remains informational.',
                  style: GoogleFonts.inter(fontSize: 14, height: 1.5),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels.map((label) {
                  final isEnabled =
                      soundFilterService.isBuiltInLabelEnabledForFilter(
                    section.filterId,
                    label,
                    isAndroid: isAndroid,
                  );
                  return FilterChip(
                    label: Text(
                      label,
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    selected: isEnabled,
                    onSelected: isMonitoring
                        ? null
                        : (selected) {
                            soundFilterService.setBuiltInLabelEnabledForFilter(
                              section.filterId,
                              label,
                              selected,
                              isAndroid: isAndroid,
                            );
                          },
                  );
                }).toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}
