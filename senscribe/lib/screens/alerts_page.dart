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
  final TextEditingController _newWordController = TextEditingController();
  int _selectedTabIndex = 0; // 0 = Alerts, 1 = Trigger Words
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

  @override
  void dispose() {
    _newWordController.dispose();
    super.dispose();
  }

  void _showAddTriggerWordDialog() {
    _newWordController.clear();
    bool caseSensitive = false;
    bool exactMatch = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Add Trigger Word',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _newWordController,
                    decoration: const InputDecoration(
                      hintText: 'Enter word to monitor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: caseSensitive,
                        onChanged: (value) {
                          setState(() => caseSensitive = value ?? false);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Case Sensitive',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: exactMatch,
                        onChanged: (value) {
                          setState(() => exactMatch = value ?? true);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Exact Word Match (whole word only)',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final wordToAdd = _newWordController.text.trim();
                if (wordToAdd.isEmpty) {
                  AdaptiveSnackBar.show(
                    context,
                    message: 'Please enter a trigger word',
                    type: AdaptiveSnackBarType.warning,
                  );
                  return;
                }
                final navigator = Navigator.of(context);

                await _triggerWordService.addTriggerWord(
                  TriggerWord(
                    word: wordToAdd,
                    caseSensitive: caseSensitive,
                    exactMatch: exactMatch,
                  ),
                );

                if (mounted) {
                  navigator.pop();
                  AdaptiveSnackBar.show(
                    this.context,
                    message: 'Added trigger word: $wordToAdd',
                    type: AdaptiveSnackBarType.success,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTriggerWordDialog(TriggerWord existingWord) {
    _newWordController.text = existingWord.word;
    bool caseSensitive = existingWord.caseSensitive;
    bool exactMatch = existingWord.exactMatch;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Edit Trigger Word',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _newWordController,
                    decoration: const InputDecoration(
                      hintText: 'Enter word to monitor',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: caseSensitive,
                        onChanged: (value) {
                          setState(() => caseSensitive = value ?? false);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Case Sensitive',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: exactMatch,
                        onChanged: (value) {
                          setState(() => exactMatch = value ?? true);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Exact Word Match (whole word only)',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final updatedWord = _newWordController.text.trim();
                if (updatedWord.isEmpty) {
                  AdaptiveSnackBar.show(
                    context,
                    message: 'Please enter a trigger word',
                    type: AdaptiveSnackBarType.warning,
                  );
                  return;
                }

                final navigator = Navigator.of(context);

                await _triggerWordService.updateTriggerWord(
                  existingWord.word,
                  existingWord.copyWith(
                    word: updatedWord,
                    caseSensitive: caseSensitive,
                    exactMatch: exactMatch,
                  ),
                );

                if (mounted) {
                  navigator.pop();
                  AdaptiveSnackBar.show(
                    this.context,
                    message: 'Updated trigger word: $updatedWord',
                    type: AdaptiveSnackBarType.success,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
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
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Add Custom Sound',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'Name this sound',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final profile = await _customSoundService.createDraftProfile(
                  controller.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop();
                await _openCustomSoundEnrollmentPage(profile);
              } catch (error) {
                if (!mounted) return;
                AdaptiveSnackBar.show(
                  context,
                  message: '$error',
                  type: AdaptiveSnackBarType.warning,
                );
              }
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
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
                      labels: const ['Recent Alerts', 'Trigger Words'],
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
                      'No trigger word alerts yet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add trigger words and use text-to-speech to generate alerts',
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
                                      : Icons.warning_rounded,
                                  color: _isAlertSelectionMode
                                      ? (isSelected
                                          ? scheme.primary
                                          : scheme.onSurface
                                              .withValues(alpha: 0.65))
                                      : scheme.error,
                                ),
                                title: Text(
                                  'Trigger: "${alert.triggerWord}"',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      alert.detectedText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      TimeUtils.formatTimeAgoShort(
                                          alert.timestamp),
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: scheme.onSurface
                                            .withValues(alpha: 0.68),
                                      ),
                                    ),
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
