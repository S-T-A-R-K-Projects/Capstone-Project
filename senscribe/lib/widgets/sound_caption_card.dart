import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final leadingIcon = caption.icon;
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
                    const SizedBox(height: 4),
                    // Location display
                    _buildInfoChip(
                      Icons.location_on_rounded,
                      caption.displayLocation,
                      context,
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

              _SoundCaptionMenuButton(
                onViewDetails: onViewDetails,
                onSaveToAlerts: onSaveToAlerts,
                onDelete: onDelete,
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

class _SoundCardAction {
  const _SoundCardAction({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _SoundCaptionMenuButton extends StatefulWidget {
  const _SoundCaptionMenuButton({
    this.onViewDetails,
    this.onSaveToAlerts,
    this.onDelete,
  });

  final VoidCallback? onViewDetails;
  final VoidCallback? onSaveToAlerts;
  final VoidCallback? onDelete;

  @override
  State<_SoundCaptionMenuButton> createState() =>
      _SoundCaptionMenuButtonState();
}

class _SoundCaptionMenuButtonState extends State<_SoundCaptionMenuButton> {
  List<_SoundCardAction> get _actions => [
        if (widget.onViewDetails != null)
          const _SoundCardAction(label: 'View Details', value: 'details'),
        if (widget.onSaveToAlerts != null)
          const _SoundCardAction(
            label: 'Save to Alerts',
            value: 'save_to_alerts',
          ),
        if (widget.onDelete != null)
          const _SoundCardAction(label: 'Delete', value: 'delete'),
      ];

  List<AdaptivePopupMenuEntry> get _menuItems => _actions
      .map(
        (action) => AdaptivePopupMenuItem<String>(
          label: action.label,
          icon: switch (action.value) {
            'details' => PlatformInfo.isIOS26OrHigher()
                ? 'info.circle'
                : Icons.info_outline_rounded,
            'save_to_alerts' => PlatformInfo.isIOS26OrHigher()
                ? 'bookmark'
                : Icons.bookmark_border_rounded,
            'delete' => PlatformInfo.isIOS26OrHigher()
                ? 'trash'
                : Icons.delete_outline_rounded,
            _ => null,
          },
          value: action.value,
        ),
      )
      .toList();

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'details':
        widget.onViewDetails?.call();
        break;
      case 'save_to_alerts':
        widget.onSaveToAlerts?.call();
        break;
      case 'delete':
        widget.onDelete?.call();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: AdaptivePopupMenuButton.icon<String>(
        icon: PlatformInfo.isIOS26OrHigher()
            ? 'ellipsis.circle'
            : Icons.more_horiz_rounded,
        items: _menuItems,
        onSelected: (index, item) {
          final value = item.value;
          if (value == null) return;
          _handleMenuSelection(value);
        },
      ),
    );
  }
}
