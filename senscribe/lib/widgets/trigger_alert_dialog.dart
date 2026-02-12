import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class TriggerAlertDialog extends StatefulWidget {
  final List<String> detectedTriggers;
  final String detectedText;

  const TriggerAlertDialog({
    super.key,
    required this.detectedTriggers,
    required this.detectedText,
  });

  @override
  State<TriggerAlertDialog> createState() => _TriggerAlertDialogState();
}

class _TriggerAlertDialogState extends State<TriggerAlertDialog>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated background blur/overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          // Main content card with pulsing animation
          ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(
                  parent: _pulseController, curve: Curves.easeInOut),
            ),
            child: Card(
              elevation: 20,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.red[400]!,
                      Colors.orange[400]!,
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Alert icon with animation
                    ScaleTransition(
                      scale: Tween<double>(begin: 1.0, end: 1.3).animate(
                        CurvedAnimation(
                          parent: _pulseController,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // "Alert" title
                    Text(
                      'TRIGGER WORD ALERT',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detected trigger words
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Detected Word${widget.detectedTriggers.length > 1 ? 's' : ''}:',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.detectedTriggers
                                .map(
                                  (trigger) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '"$trigger"',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Detected text preview
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Text:',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.detectedText,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action button - using AdaptiveButton
                    Row(
                      children: [
                        Expanded(
                          child: AdaptiveButton(
                            onPressed: () => Navigator.pop(context),
                            label: 'OK',
                            style: AdaptiveButtonStyle.filled,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).scale(
              begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0)),
        ],
      ),
    );
  }
}
