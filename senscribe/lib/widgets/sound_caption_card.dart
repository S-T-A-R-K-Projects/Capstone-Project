import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import '../models/sound_caption.dart';

class SoundCaptionCard extends StatelessWidget {
  final SoundCaption caption;

  const SoundCaptionCard({super.key, required this.caption});

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${difference.inHours}h ago';
    }
  }

  IconData _getDirectionIcon(String direction) {
    switch (direction.toLowerCase()) {
      case 'front':
        return Icons.arrow_upward_rounded;
      case 'back':
        return Icons.arrow_downward_rounded;
      case 'left':
        return Icons.arrow_back_rounded;
      case 'right':
        return Icons.arrow_forward_rounded;
      default:
        return Icons.my_location_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
              // Sound Direction Indicator
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
                  caption.isCritical
                      ? Icons.warning_rounded
                      : _getDirectionIcon(caption.direction),
                  color: caption.isCritical
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
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
                            caption.sound,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: caption.isCritical
                                  ? Colors.red[700]
                                  : Colors.black87,
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
                                color: Colors.white,
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
                          Icons.access_time_rounded,
                          _formatTimestamp(caption.timestamp),
                          context,
                        ),
                        _buildInfoChip(
                          _getDirectionIcon(caption.direction),
                          caption.direction,
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

              // Quick Actions - using AdaptivePopupMenuButton
              AdaptivePopupMenuButton.icon<String>(
                icon: 'ellipsis.circle',
                items: [
                  AdaptivePopupMenuItem(
                    label: 'View Details',
                    value: 'details',
                  ),
                  AdaptivePopupMenuItem(
                    label: 'Create Alert',
                    value: 'alert',
                  ),
                  AdaptivePopupMenuItem(
                    label: 'Train Custom',
                    value: 'train',
                  ),
                ],
                onSelected: (index, item) {
                  //
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[600],
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
