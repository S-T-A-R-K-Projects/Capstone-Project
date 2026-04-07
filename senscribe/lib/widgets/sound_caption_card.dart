import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/sound_caption.dart';
import '../utils/time_utils.dart';

class SoundCaptionCard extends StatelessWidget {
  final SoundCaption caption;
  final VoidCallback? onDelete;
  final VoidCallback? onViewDetails;
  final VoidCallback? onSaveToAlerts;

  const SoundCaptionCard({
    super.key,
    required this.caption,
    this.onDelete,
    this.onViewDetails,
    this.onSaveToAlerts,
  });

  void _showActionsSheet(BuildContext context) {
    final actions = <_SoundCardAction>[
      if (onViewDetails != null)
        _SoundCardAction(
          label: 'View Details',
          value: _SoundCardActionValue.details,
        ),
      if (onSaveToAlerts != null)
        _SoundCardAction(
          label: 'Save to Alerts',
          value: _SoundCardActionValue.saveToAlerts,
        ),
      if (onDelete != null)
        _SoundCardAction(
          label: 'Delete',
          value: _SoundCardActionValue.delete,
          isDestructive: true,
        ),
    ];

    if (actions.isEmpty) return;

    final selectionFuture = PlatformInfo.isIOS
        ? showCupertinoModalPopup<_SoundCardActionValue>(
            context: context,
            builder: (sheetContext) {
              return CupertinoActionSheet(
                actions: actions
                    .map(
                      (action) => CupertinoActionSheetAction(
                        isDestructiveAction: action.isDestructive,
                        onPressed: () => Navigator.of(sheetContext).pop(
                          action.value,
                        ),
                        child: Text(action.label),
                      ),
                    )
                    .toList(),
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  isDefaultAction: true,
                  child: const Text('Cancel'),
                ),
              );
            },
          )
        : showModalBottomSheet<_SoundCardActionValue>(
            context: context,
            showDragHandle: true,
            builder: (sheetContext) {
              final scheme = Theme.of(sheetContext).colorScheme;
              return SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final action in actions)
                      ListTile(
                        title: Text(
                          action.label,
                          style: GoogleFonts.inter(
                            color: action.isDestructive
                                ? scheme.error
                                : scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => Navigator.of(sheetContext).pop(
                          action.value,
                        ),
                      ),
                  ],
                ),
              );
            },
          );

    selectionFuture.then((selected) {
      switch (selected) {
        case _SoundCardActionValue.details:
          onViewDetails?.call();
          break;
        case _SoundCardActionValue.saveToAlerts:
          onSaveToAlerts?.call();
          break;
        case _SoundCardActionValue.delete:
          onDelete?.call();
          break;
        case null:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leadingIcon = caption.isCritical
        ? Icons.warning_rounded
        : caption.source == SoundCaptionSource.custom
            ? Icons.tune_rounded
            : Icons.music_note_rounded;
    final leadingColor = caption.isCritical ? Colors.red : scheme.primary;

    return AdaptiveCard(
      padding: const EdgeInsets.all(0),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: caption.isCritical
              ? Border.all(color: Colors.red, width: 2)
              : null,
          gradient: caption.isCritical
              ? LinearGradient(
                  colors: [
                    Colors.red.withValues(alpha: 0.05),
                    Colors.red.withValues(alpha: 0.02),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Sound event indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: caption.isCritical
                        ? [
                            Colors.red.withValues(alpha: 0.2),
                            Colors.red.withValues(alpha: 0.1)
                          ]
                        : [
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.2),
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  leadingIcon,
                  color: leadingColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),

              // Caption Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            caption.displaySound,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: caption.isCritical
                                  ? Colors.red[700]
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (caption.isCritical)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.red, Colors.redAccent],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'CRITICAL',
                              style: GoogleFonts.inter(
                                color: Theme.of(context).colorScheme.onError,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                              .animate()
                              .scale(duration: 300.ms)
                              .then()
                              .shimmer(duration: 1000.ms),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        _buildInfoChip(
                          caption.source == SoundCaptionSource.custom
                              ? Icons.tune_rounded
                              : Icons.library_music_rounded,
                          caption.source == SoundCaptionSource.custom
                              ? 'Custom'
                              : 'Built-in',
                          context,
                        ),
                        _buildInfoChip(
                          Icons.access_time_rounded,
                          TimeUtils.formatTimeAgoForSound(caption.timestamp),
                          context,
                        ),
                        _buildInfoChip(
                          Icons.graphic_eq_rounded,
                          '${(caption.confidence * 100).toInt()}%',
                          context,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showActionsSheet(context),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface.withValues(alpha: 0.92),
                      border: Border.all(
                        color: scheme.outline.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Icon(
                      PlatformInfo.isIOS26OrHigher()
                          ? CupertinoIcons.ellipsis
                          : Icons.more_horiz_rounded,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: scheme.onSurface.withValues(alpha: 0.75),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: scheme.onSurface.withValues(alpha: 0.78),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

enum _SoundCardActionValue { details, saveToAlerts, delete }

class _SoundCardAction {
  const _SoundCardAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });

  final String label;
  final _SoundCardActionValue value;
  final bool isDestructive;
}
