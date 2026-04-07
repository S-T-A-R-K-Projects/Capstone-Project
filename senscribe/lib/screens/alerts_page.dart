import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/custom_sound_profile.dart';
import 'custom_sound_enrollment_page.dart';
import '../services/trigger_word_service.dart';
import '../services/custom_sound_service.dart';
import '../models/trigger_word.dart';
import '../models/trigger_alert.dart';
import '../utils/time_utils.dart';

class AlertsPage extends StatefulWidget {
  final int initialTabIndex;

  const AlertsPage({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final TriggerWordService _triggerWordService = TriggerWordService();
  final CustomSoundService _customSoundService = CustomSoundService();
  int _selectedTabIndex = 0; // 0 = Alerts, 1 = Alert Triggers
  bool _isAlertSelectionMode = false;
  final Set<String> _selectedAlertIds = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialTabIndex < 0) {
      _selectedTabIndex = 0;
    } else if (widget.initialTabIndex > 1) {
      _selectedTabIndex = 1;
    } else {
      _selectedTabIndex = widget.initialTabIndex;
    }
  }

  bool _isSoundAlert(TriggerAlert alert) {
    return alert.source == TriggerAlert.sourceSoundRecognition ||
        alert.source == TriggerAlert.sourceCustomSound;
  }

  IconData _alertIcon(TriggerAlert alert) {
    if (alert.source == TriggerAlert.sourceCustomSound) {
      return Icons.tune_rounded;
    }
    if (alert.source == TriggerAlert.sourceSoundRecognition) {
      return Icons.hearing_rounded;
    }
    return Icons.warning_rounded;
  }

  Color _alertIconColor(TriggerAlert alert, ColorScheme scheme) {
    if (_isSoundAlert(alert)) {
      return scheme.primary;
    }
    return scheme.error;
  }

  String _alertTitle(TriggerAlert alert) {
    if (_isSoundAlert(alert)) {
      return 'Sound: "${alert.triggerWord}"';
    }
    return 'Trigger: "${alert.triggerWord}"';
  }

  Future<void> _showAlertDetails(TriggerAlert alert) async {
    final isSoundAlert = _isSoundAlert(alert);
    await AdaptiveAlertDialog.show(
      context: context,
      title: alert.triggerWord,
      message: isSoundAlert
          ? _buildSoundAlertDetails(alert)
          : 'Detected text: ${alert.detectedText}\n'
              'Source: Speech trigger\n'
              'Detected: ${TimeUtils.formatExactDateTime(alert.timestamp)}',
      icon: _detailIconForAlert(alert),
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

  String _buildSoundAlertSummary(TriggerAlert alert) {
    final confidence = alert.soundConfidencePercent;
    final confidenceLabel = confidence == null ? 'Unknown' : '$confidence%';
    return '$confidenceLabel confidence • ${alert.soundDetectorLabel}';
  }

  String _buildSoundAlertDetails(TriggerAlert alert) {
    final confidence = alert.soundConfidencePercent;
    final confidenceLabel = confidence == null ? 'Unknown' : '$confidence%';
    return 'Detector: ${alert.soundDetectorLabel}\n'
        'Confidence: $confidenceLabel\n'
        'Priority: ${alert.soundPriorityLabel}\n'
        'Detected: ${TimeUtils.formatExactDateTime(alert.timestamp)}';
  }

  Widget _buildAlertSubtitle(TriggerAlert alert, ColorScheme scheme) {
    if (_isSoundAlert(alert)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            TimeUtils.formatExactDateTime(alert.timestamp),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: scheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _buildSoundAlertSummary(alert),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: scheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        Text(
          alert.detectedText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          TimeUtils.formatTimeAgoShort(alert.timestamp),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: scheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
      ],
    );
  }

  dynamic _detailIconForAlert(TriggerAlert alert) {
    if (PlatformInfo.isIOS26OrHigher()) {
      if (alert.source == TriggerAlert.sourceCustomSound) {
        return 'tuningfork';
      }
      if (_isSoundAlert(alert)) {
        return 'waveform';
      }
      return 'exclamationmark.bubble';
    }

    if (alert.source == TriggerAlert.sourceCustomSound) {
      return Icons.tune_rounded;
    }
    if (_isSoundAlert(alert)) {
      return Icons.graphic_eq_rounded;
    }
    return Icons.warning_rounded;
  }

  void _showTriggerWordEmptyWarning() {
    AdaptiveSnackBar.show(
      context,
      message: 'Please enter a trigger word',
      type: AdaptiveSnackBarType.warning,
    );
  }

  Future<_TriggerWordDialogResult?> _showTriggerWordDialog({
    required String title,
    required String primaryActionLabel,
    String initialWord = '',
    bool initialCaseSensitive = false,
    bool initialExactMatch = true,
  }) async {
    return showDialog<_TriggerWordDialogResult>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _TriggerWordDialog(
        title: title,
        primaryActionLabel: primaryActionLabel,
        initialWord: initialWord,
        initialCaseSensitive: initialCaseSensitive,
        initialExactMatch: initialExactMatch,
        onEmptyWord: _showTriggerWordEmptyWarning,
      ),
    );
  }

  Future<void> _showAddTriggerWordDialog() async {
    final result = await _showTriggerWordDialog(
      title: 'Add Trigger Word',
      primaryActionLabel: 'Add',
    );
    if (result == null) return;

    await _triggerWordService.addTriggerWord(
      TriggerWord(
        word: result.word,
        caseSensitive: result.caseSensitive,
        exactMatch: result.exactMatch,
      ),
    );

    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Added trigger word: ${result.word}',
      type: AdaptiveSnackBarType.success,
    );
  }

  Future<void> _showEditTriggerWordDialog(TriggerWord existingWord) async {
    final result = await _showTriggerWordDialog(
      title: 'Edit Trigger Word',
      primaryActionLabel: 'Save',
      initialWord: existingWord.word,
      initialCaseSensitive: existingWord.caseSensitive,
      initialExactMatch: existingWord.exactMatch,
    );
    if (result == null) return;

    await _triggerWordService.updateTriggerWord(
      existingWord.word,
      existingWord.copyWith(
        word: result.word,
        caseSensitive: result.caseSensitive,
        exactMatch: result.exactMatch,
      ),
    );

    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Updated trigger word: ${result.word}',
      type: AdaptiveSnackBarType.success,
    );
  }

  void _startAlertSelection(String alertId) {
    setState(() {
      _isAlertSelectionMode = true;
      _selectedAlertIds.add(alertId);
    });
  }

  void _toggleAlertSelection(String alertId) {
    setState(() {
      if (_selectedAlertIds.contains(alertId)) {
        _selectedAlertIds.remove(alertId);
      } else {
        _selectedAlertIds.add(alertId);
      }

      if (_selectedAlertIds.isEmpty) {
        _isAlertSelectionMode = false;
      }
    });
  }

  void _selectAllAlerts(List<TriggerAlert> alerts) {
    setState(() {
      _selectedAlertIds
        ..clear()
        ..addAll(alerts.map((alert) => alert.id));
      _isAlertSelectionMode = _selectedAlertIds.isNotEmpty;
    });
  }

  void _clearAlertSelection() {
    setState(() {
      _selectedAlertIds.clear();
      _isAlertSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedAlerts() async {
    if (_selectedAlertIds.isEmpty) return;

    final count = _selectedAlertIds.length;
    var shouldDelete = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Delete selected alerts?',
      message: 'Are you sure you want to delete $count alert(s)?',
      icon: PlatformInfo.isIOS26OrHigher() ? 'trash' : null,
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Delete',
          style: AlertActionStyle.destructive,
          onPressed: () {
            shouldDelete = true;
          },
        ),
      ],
    );

    if (!shouldDelete) return;

    final ids = _selectedAlertIds.toList(growable: false);
    for (final id in ids) {
      await _triggerWordService.removeAlert(id);
    }

    if (!mounted) return;
    _clearAlertSelection();
    AdaptiveSnackBar.show(
      context,
      message: 'Deleted $count alert(s)',
      type: AdaptiveSnackBarType.success,
    );
  }

  Future<void> _showAddCustomSoundDialog() async {
    final soundName = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => const _NameEntryDialog(
        title: 'Add Custom Sound',
        placeholder: 'Name this sound',
        primaryActionLabel: 'Continue',
      ),
    );
    if (soundName == null) return;

    try {
      final profile = await _customSoundService.createDraftProfile(soundName);
      if (!mounted) return;
      await _openCustomSoundEnrollmentPage(profile);
    } catch (error) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.warning,
      );
    }
  }

  Future<void> _openCustomSoundEnrollmentPage(
    CustomSoundProfile profile,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomSoundEnrollmentPage(initialProfile: profile),
      ),
    );
    await _customSoundService.discardDraft(profile.id);
    await _customSoundService.refresh();
  }

  Future<void> _toggleCustomSoundEnabled(CustomSoundProfile profile) async {
    try {
      await _customSoundService.setEnabled(profile.id, !profile.enabled);
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: profile.enabled
            ? 'Disabled ${profile.name}'
            : 'Enabled ${profile.name}',
        type: AdaptiveSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.error,
      );
    }
  }

  Future<void> _retrainCustomSounds() async {
    try {
      await _customSoundService.trainOrRebuildModel();
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: 'Rebuilt custom sound model',
        type: AdaptiveSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.error,
      );
    }
  }

  Future<void> _deleteCustomSound(CustomSoundProfile profile) async {
    var shouldDelete = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Delete ${profile.name}?',
      message: 'This removes its recordings and retrains the custom model.',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Delete',
          style: AlertActionStyle.destructive,
          onPressed: () {
            shouldDelete = true;
          },
        ),
      ],
    );

    if (!shouldDelete) return;

    try {
      await _customSoundService.deleteProfile(profile.id);
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: 'Deleted ${profile.name}',
        type: AdaptiveSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.error,
      );
    }
  }

  String _customStatusLabel(CustomSoundProfile profile) {
    if (!profile.enabled) {
      return 'Disabled';
    }
    return switch (profile.status) {
      CustomSoundProfileStatus.draft => profile.hasEnoughSamples
          ? 'Ready to train'
          : profile.targetSampleCount >= kRequiredCustomSoundSamples
              ? 'Needs background'
              : 'Needs samples',
      CustomSoundProfileStatus.recording => 'Recording',
      CustomSoundProfileStatus.training => 'Training',
      CustomSoundProfileStatus.ready => 'Ready',
      CustomSoundProfileStatus.failed => 'Failed',
    };
  }

  Widget _buildCustomSoundSection(
    List<CustomSoundProfile> profiles,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          'Custom Sounds',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'These sounds are trained on-device and run beside the built-in detector on the unified home screen.',
          style: GoogleFonts.inter(
            color: scheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 16),
        if (profiles.isEmpty)
          AdaptiveCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No custom sounds yet',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a sound, record 10 target examples and 3 background samples, then train the custom model.',
                    style: GoogleFonts.inter(
                      color: scheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...profiles.map(
            (profile) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCustomSoundCard(profile, scheme),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomSoundCard(
    CustomSoundProfile profile,
    ColorScheme scheme,
  ) {
    final statusColor = switch (profile.status) {
      CustomSoundProfileStatus.ready => Colors.green,
      CustomSoundProfileStatus.failed => scheme.error,
      CustomSoundProfileStatus.training => scheme.primary,
      CustomSoundProfileStatus.recording => scheme.primary,
      CustomSoundProfileStatus.draft => scheme.secondary,
    };

    return AdaptiveCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AdaptiveListTile(
          leading: Icon(
            profile.status == CustomSoundProfileStatus.ready
                ? Icons.graphic_eq_rounded
                : Icons.multitrack_audio_rounded,
            color: statusColor,
          ),
          title: Text(
            profile.name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    'Samples ${profile.targetSampleCount}/$kRequiredCustomSoundSamples',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    'Background ${profile.backgroundSampleCount}/$kRequiredBackgroundSamples',
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    _customStatusLabel(profile),
                    style: GoogleFonts.inter(fontSize: 10),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          trailing: AdaptivePopupMenuButton.icon<String>(
            icon: 'ellipsis.circle',
            items: [
              const AdaptivePopupMenuItem(label: 'Open', value: 'open'),
              if (profile.hasEnoughSamples)
                const AdaptivePopupMenuItem(
                  label: 'Retrain',
                  value: 'retrain',
                ),
              AdaptivePopupMenuItem(
                label: profile.enabled ? 'Disable' : 'Enable',
                value: 'toggle',
              ),
              const AdaptivePopupMenuItem(label: 'Delete', value: 'delete'),
            ],
            onSelected: (index, item) async {
              switch (item.value) {
                case 'open':
                  await _openCustomSoundEnrollmentPage(profile);
                  break;
                case 'retrain':
                  await _retrainCustomSounds();
                  break;
                case 'toggle':
                  await _toggleCustomSoundEnabled(profile);
                  break;
                case 'delete':
                  await _deleteCustomSound(profile);
                  break;
              }
            },
          ),
          onTap: () => _openCustomSoundEnrollmentPage(profile),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Alerts',
      ),
      body: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            if (topInset > 0) SizedBox(height: topInset),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: SizedBox(
                  height: 44,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      platformBrightness: theme.brightness,
                    ),
                    child: AdaptiveSegmentedControl(
                      key: ValueKey(
                        'alerts-tabs-${theme.brightness.name}',
                      ),
                      labels: const ['Recent Alerts', 'Alert Triggers'],
                      color: theme.colorScheme.surface,
                      selectedIndex: _selectedTabIndex,
                      onValueChanged: (index) {
                        setState(() {
                          _selectedTabIndex = index;
                          if (_selectedTabIndex != 0) {
                            _clearAlertSelection();
                          }
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildAlertsTab()
                  : _buildTriggerWordsTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsTab() {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<List<TriggerAlert>>(
      stream: _triggerWordService.alertsStream,
      builder: (context, snapshot) {
        return FutureBuilder<List<TriggerAlert>>(
          future: _triggerWordService.loadAlerts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data ?? [];

            if (alerts.isEmpty && _isAlertSelectionMode) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _clearAlertSelection();
              });
            }

            if (alerts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 80,
                      color: scheme.onSurface.withValues(alpha: 0.45),
                    ).animate().scale(duration: 600.ms),
                    const SizedBox(height: 24),
                    Text(
                      'No recent alerts yet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trigger detections and saved sounds will appear here',
                      style: GoogleFonts.inter(
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ).animate().fadeIn(duration: 800.ms),
              );
            }

            return Column(
              children: [
                if (_isAlertSelectionMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: 110,
                          child: AdaptiveButton(
                            onPressed: () => _selectAllAlerts(alerts),
                            label: 'Select All',
                            style: AdaptiveButtonStyle.plain,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 88,
                          child: AdaptiveButton(
                            onPressed: _selectedAlertIds.isEmpty
                                ? null
                                : _deleteSelectedAlerts,
                            label: 'Delete',
                            style: AdaptiveButtonStyle.plain,
                            color: scheme.error,
                          ),
                        ),
                        SizedBox(
                          width: 88,
                          child: AdaptiveButton(
                            onPressed: _clearAlertSelection,
                            label: 'Cancel',
                            style: AdaptiveButtonStyle.plain,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alert = alerts[index];
                      final isSelected = _selectedAlertIds.contains(alert.id);

                      return GestureDetector(
                        onLongPress: () => _startAlertSelection(alert.id),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: AdaptiveCard(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AdaptiveListTile(
                                leading: Icon(
                                  _isAlertSelectionMode
                                      ? (isSelected
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked)
                                      : _alertIcon(alert),
                                  color: _isAlertSelectionMode
                                      ? (isSelected
                                          ? scheme.primary
                                          : scheme.onSurface
                                              .withValues(alpha: 0.65))
                                      : _alertIconColor(alert, scheme),
                                ),
                                title: Text(
                                  _alertTitle(alert),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAlertSubtitle(alert, scheme),
                                  ],
                                ),
                                trailing: _isAlertSelectionMode
                                    ? null
                                    : AdaptiveButton.icon(
                                        icon: Icons.delete_outline,
                                        onPressed: () async {
                                          await _triggerWordService
                                              .removeAlert(alert.id);
                                        },
                                        style: AdaptiveButtonStyle.plain,
                                      ),
                                onTap: () {
                                  if (_isAlertSelectionMode) {
                                    _toggleAlertSelection(alert.id);
                                  } else if (_isSoundAlert(alert)) {
                                    _showAlertDetails(alert);
                                  }
                                },
                              ),
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTriggerWordsTab() {
    final scheme = Theme.of(context).colorScheme;

    return FutureBuilder<List<TriggerWord>>(
      future: _triggerWordService.loadTriggerWords(),
      builder: (context, snapshot) {
        return FutureBuilder<List<CustomSoundProfile>>(
          future: _customSoundService.loadProfiles(),
          builder: (context, customSnapshot) {
            if (!snapshot.hasData || !customSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final words = snapshot.data ?? [];
            final profiles = customSnapshot.data ?? [];

            return StreamBuilder<List<TriggerWord>>(
              stream: _triggerWordService.triggerWordsStream,
              builder: (context, streamSnapshot) {
                return StreamBuilder<List<CustomSoundProfile>>(
                  stream: _customSoundService.profilesStream,
                  builder: (context, customStreamSnapshot) {
                    final displayWords = streamSnapshot.hasData
                        ? streamSnapshot.data ?? words
                        : words;
                    final displayProfiles = customStreamSnapshot.hasData
                        ? customStreamSnapshot.data ?? profiles
                        : profiles;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (displayWords.isEmpty)
                          AdaptiveCard(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'No trigger words yet',
                                    style: GoogleFonts.inter(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add words to monitor in speech-to-text, then add a custom sound below if you want a personal sound detector on this device.',
                                    style: GoogleFonts.inter(
                                      color: scheme.onSurface
                                          .withValues(alpha: 0.68),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(duration: 800.ms)
                        else
                          ...displayWords.map(
                            (word) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: AdaptiveCard(
                                padding: EdgeInsets.zero,
                                borderRadius: BorderRadius.circular(16),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AdaptiveListTile(
                                    leading: Icon(
                                      word.enabled
                                          ? Icons.label_rounded
                                          : Icons.label_off_rounded,
                                      color: word.enabled
                                          ? scheme.primary
                                          : scheme.onSurface
                                              .withValues(alpha: 0.65),
                                    ),
                                    title: Text(
                                      '"${word.word}"',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                    subtitle: Row(
                                      children: [
                                        if (word.caseSensitive)
                                          Chip(
                                            label: Text(
                                              'Case Sensitive',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                        const SizedBox(width: 8),
                                        if (word.exactMatch)
                                          Chip(
                                            label: Text(
                                              'Exact Match',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                              ),
                                            ),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                      ],
                                    ),
                                    trailing:
                                        AdaptivePopupMenuButton.icon<String>(
                                      icon: 'ellipsis.circle',
                                      items: [
                                        const AdaptivePopupMenuItem(
                                          label: 'Edit',
                                          value: 'edit',
                                        ),
                                        AdaptivePopupMenuItem(
                                          label: word.enabled
                                              ? 'Disable'
                                              : 'Enable',
                                          value: 'toggle',
                                        ),
                                        const AdaptivePopupMenuItem(
                                          label: 'Delete',
                                          value: 'delete',
                                        ),
                                      ],
                                      onSelected: (index, item) async {
                                        if (item.value == 'edit') {
                                          _showEditTriggerWordDialog(word);
                                        } else if (item.value == 'toggle') {
                                          await _triggerWordService
                                              .updateTriggerWord(
                                            word.word,
                                            word.copyWith(
                                              enabled: !word.enabled,
                                            ),
                                          );
                                        } else if (item.value == 'delete') {
                                          await _triggerWordService
                                              .removeTriggerWord(word.word);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              )
                                  .animate()
                                  .fadeIn(duration: 400.ms)
                                  .slideX(begin: 0.1),
                            ),
                          ),
                        const SizedBox(height: 8),
                        AdaptiveButton(
                          onPressed: _showAddTriggerWordDialog,
                          label: 'Add Trigger Word',
                          style: AdaptiveButtonStyle.filled,
                        ),
                        const SizedBox(height: 12),
                        AdaptiveButton(
                          onPressed: _showAddCustomSoundDialog,
                          label: 'Add Custom Sound',
                          style: AdaptiveButtonStyle.tinted,
                        ),
                        _buildCustomSoundSection(displayProfiles, scheme),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _TriggerWordDialogResult {
  const _TriggerWordDialogResult({
    required this.word,
    required this.caseSensitive,
    required this.exactMatch,
  });

  final String word;
  final bool caseSensitive;
  final bool exactMatch;
}

class _TriggerWordDialog extends StatefulWidget {
  const _TriggerWordDialog({
    required this.title,
    required this.primaryActionLabel,
    required this.initialWord,
    required this.initialCaseSensitive,
    required this.initialExactMatch,
    required this.onEmptyWord,
  });

  final String title;
  final String primaryActionLabel;
  final String initialWord;
  final bool initialCaseSensitive;
  final bool initialExactMatch;
  final VoidCallback onEmptyWord;

  @override
  State<_TriggerWordDialog> createState() => _TriggerWordDialogState();
}

class _TriggerWordDialogState extends State<_TriggerWordDialog> {
  late final TextEditingController _controller;
  late bool _caseSensitive;
  late bool _exactMatch;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialWord);
    _caseSensitive = widget.initialCaseSensitive;
    _exactMatch = widget.initialExactMatch;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final word = _controller.text.trim();
    if (word.isEmpty) {
      widget.onEmptyWord();
      return;
    }

    Navigator.of(context).pop(
      _TriggerWordDialogResult(
        word: word,
        caseSensitive: _caseSensitive,
        exactMatch: _exactMatch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dialogBody = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: PlatformInfo.isIOS ? 19 : 22,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            AdaptiveTextField(
              controller: _controller,
              placeholder: 'Enter word to monitor',
              autofocus: true,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: scheme.onSurface,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            _TriggerWordDialogOptionRow(
              label: 'Case Sensitive',
              value: _caseSensitive,
              onChanged: (value) {
                setState(() {
                  _caseSensitive = value;
                });
              },
            ),
            const SizedBox(height: 10),
            _TriggerWordDialogOptionRow(
              label: 'Exact Word Match (whole word only)',
              value: _exactMatch,
              onChanged: (value) {
                setState(() {
                  _exactMatch = value;
                });
              },
            ),
            const SizedBox(height: 24),
            if (PlatformInfo.isIOS)
              Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: 'Cancel',
                      style: AdaptiveButtonStyle.plain,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: _submit,
                      label: widget.primaryActionLabel,
                      style: PlatformInfo.isIOS26OrHigher()
                          ? AdaptiveButtonStyle.glass
                          : AdaptiveButtonStyle.filled,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Spacer(),
                  AdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                    style: AdaptiveButtonStyle.plain,
                  ),
                  const SizedBox(width: 8),
                  AdaptiveButton(
                    onPressed: _submit,
                    label: widget.primaryActionLabel,
                    style: AdaptiveButtonStyle.filled,
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    if (PlatformInfo.isIOS) {
      return _IOSDialogScaffold(child: dialogBody);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: dialogBody,
      ),
    );
  }
}

class _NameEntryDialog extends StatefulWidget {
  const _NameEntryDialog({
    required this.title,
    required this.placeholder,
    required this.primaryActionLabel,
  });

  final String title;
  final String placeholder;
  final String primaryActionLabel;

  @override
  State<_NameEntryDialog> createState() => _NameEntryDialogState();
}

class _NameEntryDialogState extends State<_NameEntryDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    Navigator.of(context).pop(value.isEmpty ? null : value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dialogBody = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: PlatformInfo.isIOS ? 19 : 22,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            AdaptiveTextField(
              controller: _controller,
              placeholder: widget.placeholder,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: scheme.onSurface,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            if (PlatformInfo.isIOS)
              Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).pop(),
                      label: 'Cancel',
                      style: AdaptiveButtonStyle.plain,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: _submit,
                      label: widget.primaryActionLabel,
                      style: PlatformInfo.isIOS26OrHigher()
                          ? AdaptiveButtonStyle.glass
                          : AdaptiveButtonStyle.filled,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Spacer(),
                  AdaptiveButton(
                    onPressed: () => Navigator.of(context).pop(),
                    label: 'Cancel',
                    style: AdaptiveButtonStyle.plain,
                  ),
                  const SizedBox(width: 8),
                  AdaptiveButton(
                    onPressed: _submit,
                    label: widget.primaryActionLabel,
                    style: AdaptiveButtonStyle.filled,
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    if (PlatformInfo.isIOS) {
      return _IOSDialogScaffold(child: dialogBody);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: dialogBody,
      ),
    );
  }
}

class _IOSDialogScaffold extends StatelessWidget {
  const _IOSDialogScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = Theme.of(context);
    final availableHeight = mediaQuery.size.height -
        mediaQuery.padding.top -
        mediaQuery.padding.bottom -
        mediaQuery.viewInsets.bottom -
        32;

    return MediaQuery(
      data: mediaQuery.copyWith(platformBrightness: theme.brightness),
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          brightness: theme.brightness,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              mediaQuery.viewInsets.bottom + 16,
            ),
            child: SafeArea(
              child: Align(
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 420,
                    maxHeight: availableHeight
                        .clamp(220.0, double.infinity)
                        .toDouble(),
                  ),
                  child: AdaptiveCard(
                    padding: const EdgeInsets.all(22),
                    borderRadius: BorderRadius.circular(28),
                    clipBehavior: Clip.antiAlias,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TriggerWordDialogOptionRow extends StatelessWidget {
  const _TriggerWordDialogOptionRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rowColor = PlatformInfo.isIOS
        ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.8);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: rowColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: AdaptiveCheckbox(
                value: value,
                onChanged: (nextValue) => onChanged(nextValue ?? false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
