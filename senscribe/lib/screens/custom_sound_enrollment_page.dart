import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/custom_sound_profile.dart';
import '../services/custom_sound_service.dart';

class CustomSoundEnrollmentPage extends StatefulWidget {
  const CustomSoundEnrollmentPage({
    super.key,
    required this.initialProfile,
  });

  final CustomSoundProfile initialProfile;

  @override
  State<CustomSoundEnrollmentPage> createState() =>
      _CustomSoundEnrollmentPageState();
}

class _CustomSoundEnrollmentPageState extends State<CustomSoundEnrollmentPage> {
  final CustomSoundService _customSoundService = CustomSoundService();

  late CustomSoundProfile _currentProfile;
  bool _isBusy = false;
  bool _isTraining = false;
  int _activeSampleNumber = 0;
  String _busyLabel = '';
  String _statusTitle = 'Record 10 samples';
  String _statusDetail =
      'Record 10 target clips first, then 3 background clips. Each recording lasts about 5 seconds.';
  IconData _statusIcon = Icons.mic_none_rounded;
  Color? _statusColor;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.initialProfile;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statusColor ??= Theme.of(context).colorScheme.primary;
  }

  Future<void> _runCapture({
    required int sampleNumber,
    required String label,
    required Future<CustomSoundProfile> Function() action,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    setState(() {
      _isBusy = true;
      _isTraining = false;
      _activeSampleNumber = sampleNumber;
      _busyLabel = 'Recording $label';
      _statusTitle = 'Recording $label';
      _statusDetail =
          'Recording started. Hold steady for about 5 seconds until it finishes.';
      _statusIcon = Icons.mic_rounded;
      _statusColor = scheme.primary;
    });

    AdaptiveSnackBar.show(
      context,
      message: '$label started. Hold steady for about 5 seconds.',
      type: AdaptiveSnackBarType.success,
    );

    try {
      final updated = await action();
      _currentProfile = updated;

      final refreshedProfiles = await _customSoundService.loadProfiles();
      final refreshedProfile = _findCustomProfile(
        refreshedProfiles,
        _currentProfile.id,
      );

      if (!mounted) return;
      setState(() {
        _currentProfile = refreshedProfile ?? updated;
        _statusTitle = '$label saved';
        _statusDetail =
            'Recording finished. You can continue or re-record this sample.';
        _statusIcon = Icons.check_circle_rounded;
        _statusColor = Colors.green;
      });
      AdaptiveSnackBar.show(
        context,
        message: '$label complete',
        type: AdaptiveSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _setStatus(
        title: '$label failed',
        detail: '$error',
        icon: Icons.error_outline_rounded,
        color: scheme.error,
      );
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _activeSampleNumber = 0;
          _busyLabel = '';
        });
      }
    }
  }

  Future<void> _runTraining() async {
    final scheme = Theme.of(context).colorScheme;
    setState(() {
      _isBusy = true;
      _isTraining = true;
      _activeSampleNumber = 0;
      _busyLabel = 'Preparing training';
      _statusTitle = 'Preparing training';
      _statusDetail =
          'The app will train using the saved 10 target samples and 3 background samples.';
      _statusIcon = Icons.tune_rounded;
      _statusColor = scheme.primary;
    });

    try {
      setState(() {
        _busyLabel = 'Training custom model';
        _statusTitle = 'Training custom model';
        _statusDetail =
            'Training is in progress. This may take a short moment.';
        _statusIcon = Icons.model_training_rounded;
        _statusColor = scheme.primary;
      });

      final profiles = await _customSoundService.trainOrRebuildModel();
      final updated = _findCustomProfile(profiles, _currentProfile.id);
      if (updated != null && mounted) {
        setState(() {
          _currentProfile = updated;
        });
      }

      if (!mounted) return;
      _setStatus(
        title: _currentProfile.status == CustomSoundProfileStatus.ready
            ? 'Custom sound ready'
            : 'Training finished',
        detail: _currentProfile.status == CustomSoundProfileStatus.ready
            ? 'You can now start sound recognition from the unified home screen.'
            : _customStatusLabel(_currentProfile),
        icon: _currentProfile.status == CustomSoundProfileStatus.ready
            ? Icons.check_circle_rounded
            : Icons.info_outline_rounded,
        color: _currentProfile.status == CustomSoundProfileStatus.ready
            ? Colors.green
            : scheme.primary,
      );

      AdaptiveSnackBar.show(
        context,
        message: _currentProfile.status == CustomSoundProfileStatus.ready
            ? 'Custom sound is ready to detect'
            : 'Training finished with status: ${_customStatusLabel(_currentProfile)}',
        type: _currentProfile.status == CustomSoundProfileStatus.failed
            ? AdaptiveSnackBarType.error
            : AdaptiveSnackBarType.success,
      );
    } catch (error) {
      if (!mounted) return;
      _setStatus(
        title: 'Training failed',
        detail: '$error',
        icon: Icons.error_outline_rounded,
        color: scheme.error,
      );
      AdaptiveSnackBar.show(
        context,
        message: '$error',
        type: AdaptiveSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isTraining = false;
          _busyLabel = '';
        });
      }
    }
  }

  void _setStatus({
    required String title,
    required String detail,
    required IconData icon,
    required Color color,
  }) {
    setState(() {
      _statusTitle = title;
      _statusDetail = detail;
      _statusIcon = icon;
      _statusColor = color;
    });
  }

  CustomSoundProfile? _findCustomProfile(
    List<CustomSoundProfile> profiles,
    String profileId,
  ) {
    for (final profile in profiles) {
      if (profile.id == profileId) {
        return profile;
      }
    }
    return null;
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

  Widget _buildProgressChip(String label, bool isComplete) {
    return Chip(
      avatar: Icon(
        isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 16,
      ),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 11),
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: _currentProfile.name,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
      ),
      body: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(
                'Record 10 examples of the target sound, then record 3 background samples so the custom detector can reject unrelated noise more reliably.',
                style: GoogleFonts.inter(
                  color: scheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildProgressChip(
                    'Samples ${_currentProfile.targetSampleCount}/$kRequiredCustomSoundSamples',
                    _currentProfile.targetSampleCount >=
                        kRequiredCustomSoundSamples,
                  ),
                  _buildProgressChip(
                    'Background ${_currentProfile.backgroundSampleCount}/$kRequiredBackgroundSamples',
                    _currentProfile.backgroundSampleCount >=
                        kRequiredBackgroundSamples,
                  ),
                  _buildProgressChip(
                    _customStatusLabel(_currentProfile),
                    _currentProfile.status == CustomSoundProfileStatus.ready,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AdaptiveCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _statusIcon,
                      color: _statusColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _statusTitle,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _statusDetail,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: scheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                          if (_isBusy) ...[
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _busyLabel,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: scheme.onSurface.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              AdaptiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Target Samples',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capture 10 clips of the sound you want to detect. Try small variations in distance and angle, but keep the sound itself clear.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var index = 0;
                        index < kRequiredCustomSoundSamples;
                        index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdaptiveButton(
                          key: ValueKey(
                            'custom-sample-${_currentProfile.id}-${index + 1}-${_currentProfile.targetSampleCount}-$_isBusy-$_activeSampleNumber',
                          ),
                          enabled: !_isBusy,
                          onPressed: _isBusy
                              ? null
                              : () => _runCapture(
                                    sampleNumber: index + 1,
                                    label: 'Sample ${index + 1}',
                                    action: () =>
                                        _customSoundService.captureTargetSample(
                                      _currentProfile,
                                      index,
                                    ),
                                  ),
                          label: _isBusy && _activeSampleNumber == index + 1
                              ? 'Recording Sample ${index + 1}...'
                              : index < _currentProfile.targetSampleCount
                                  ? 'Re-record Sample ${index + 1}'
                                  : 'Record Sample ${index + 1}',
                          style: AdaptiveButtonStyle.filled,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AdaptiveCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Background Samples',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capture 3 clips of nearby environmental noise without the target sound. This improves false-positive rejection.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (var index = 0;
                        index < kRequiredBackgroundSamples;
                        index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AdaptiveButton(
                          key: ValueKey(
                            'custom-background-${_currentProfile.id}-${index + 1}-${_currentProfile.backgroundSampleCount}-$_isBusy-$_activeSampleNumber',
                          ),
                          enabled: !_isBusy &&
                              _currentProfile.targetSampleCount >=
                                  kRequiredCustomSoundSamples,
                          onPressed: _isBusy ||
                                  _currentProfile.targetSampleCount <
                                      kRequiredCustomSoundSamples
                              ? null
                              : () => _runCapture(
                                    sampleNumber:
                                        kRequiredCustomSoundSamples + index + 1,
                                    label: 'Background Sample ${index + 1}',
                                    action: () => _customSoundService
                                        .captureBackgroundSample(
                                      _currentProfile,
                                      index,
                                    ),
                                  ),
                          label: _isBusy &&
                                  _activeSampleNumber ==
                                      kRequiredCustomSoundSamples + index + 1
                              ? 'Recording Background Sample ${index + 1}...'
                              : index < _currentProfile.backgroundSampleCount
                                  ? 'Re-record Background Sample ${index + 1}'
                                  : 'Record Background Sample ${index + 1}',
                          style: AdaptiveButtonStyle.filled,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: AdaptiveButton(
                  key: ValueKey(
                    'custom-train-${_currentProfile.id}-${_currentProfile.targetSampleCount}-${_currentProfile.backgroundSampleCount}-${_currentProfile.status.value}-$_isBusy',
                  ),
                  enabled: !_isBusy && _currentProfile.hasEnoughSamples,
                  onPressed: _isBusy || !_currentProfile.hasEnoughSamples
                      ? null
                      : _runTraining,
                  label: _isBusy && _isTraining
                      ? 'Training Custom Model...'
                      : _currentProfile.status == CustomSoundProfileStatus.ready
                          ? 'Retrain Custom Model'
                          : 'Train Custom Model',
                  style: AdaptiveButtonStyle.filled,
                ),
              ),
              if (_currentProfile.lastError != null &&
                  _currentProfile.lastError!.isNotEmpty) ...[
                const SizedBox(height: 16),
                AdaptiveCard(
                  child: Text(
                    _currentProfile.lastError!,
                    style: GoogleFonts.inter(
                      color: scheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
