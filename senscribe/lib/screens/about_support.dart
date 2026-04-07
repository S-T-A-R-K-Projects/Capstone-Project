import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AboutSupportPage extends StatelessWidget {
  const AboutSupportPage({super.key});

  static const _supportEmail = 'support@senscribe.example';
  static const List<String> _directDependencies = [
    'adaptive_platform_ui',
    'cupertino_icons',
    'dio',
    'flutter_animate',
    'flutter_localizations',
    'flutter_staggered_animations',
    'flutter_tts',
    'google_fonts',
    'liquid_ai',
    'path',
    'path_provider',
    'permission_handler',
    'shared_preferences',
    'shimmer',
    'speech_to_text',
    'url_launcher',
    'uuid',
  ];

  void _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportEmail));
    if (!context.mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Support email copied to clipboard',
      type: AdaptiveSnackBarType.success,
    );
  }

  void _showLicenses(BuildContext context) {
    showLicensePage(
      context: context,
      applicationName: 'SenScribe',
      applicationVersion: '1.0.0',
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'About & Support'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topInset > 0) SizedBox(height: topInset),
              Text(
                'About SenScribe',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'On-device sound recognition, speech tools, alert triggers, and custom sound alerts.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),

              // About Section
              _buildSection(
                context,
                'What is SenScribe?',
                Icons.info_rounded,
                'SenScribe is a mobile application that provides real-time audio classification and speech processing capabilities for accessibility and productivity.\n\n'
                    'The app classifies environmental sounds, converts speech to text, converts text to speech, checks speech for trigger words, and lets you train custom sounds for local alerts.\n\n'
                    'All processing happens on your device—no data is sent to external servers.',
              ),
              const SizedBox(height: 16),

              // Key Features
              _buildSection(
                context,
                'Key Features',
                Icons.star_rounded,
                '• Real-time sound classification using AI/ML\n'
                    '• Speech-to-Text for voice input\n'
                    '• Text-to-Speech for audio output\n'
                    '• Alert triggers for speech and sound monitoring\n'
                    '• Custom sound training and detection\n'
                    '• Saved texts stored locally on-device\n'
                    '• Privacy-first design (on-device processing)',
              ),
              const SizedBox(height: 16),

              // Technology Stack
              _buildSection(
                context,
                'Technology Stack',
                Icons.computer_rounded,
                'SenScribe is built with cutting-edge technologies:\n\n'
                    '• Flutter: Cross-platform mobile framework\n'
                    '• MediaPipe Tasks: AI/ML inference framework\n'
                    '• YAMNet TensorFlow Lite: Audio classification model\n'
                    '• Speech-to-Text: On-device voice recognition\n'
                    '• Text-to-Speech: Local speech synthesis',
              ),
              const SizedBox(height: 16),

              // How Audio Classification Works
              _buildSection(
                context,
                'How Audio Classification Works',
                Icons.settings_remote_rounded,
                '1. Your device records audio through the microphone\n'
                    '2. Audio is processed in real-time (16 kHz, mono)\n'
                    '3. YAMNet AI model analyzes the audio (0.975 sec windows)\n'
                    '4. Results return with confidence scores\n'
                    '5. Top classifications displayed in real-time\n'
                    '6. Duplicate labels throttled (700 ms minimum)\n'
                    '7. Recent detections stay local on your device\n\n'
                    'All processing is 100% on-device. No audio is sent anywhere.',
              ),
              const SizedBox(height: 16),

              // Platform Support
              _buildSection(
                context,
                'Platform Support',
                Icons.devices_rounded,
                '• Android 12+ (API 31+)\n'
                    '• iOS 17.0+\n'
                    '• Requires microphone permissions\n'
                    '• Works offline (no internet required)\n'
                    '• Optimized for Bluetooth/headset microphones',
              ),
              const SizedBox(height: 16),

              // Known Limitations
              _buildSection(
                context,
                'Known Limitations',
                Icons.warning_rounded,
                '• Accuracy depends on audio quality and background noise\n'
                    '• Some sounds may not be recognized\n'
                    '• Requires recent device hardware for optimal performance\n'
                    '• Battery usage increases during active monitoring\n'
                    '• Works best in quiet to moderate noise environments',
              ),
              const SizedBox(height: 16),

              // Team & Contributors
              _buildSection(
                context,
                'Team & Contributors',
                Icons.people_rounded,
                'SenScribe was developed by Team STARK:\n\n'
                    '• Kaushik Naik\n'
                    '• Tamerlan Khalilbayov\n'
                    '• Spencer Russel\n'
                    '• Reewaz Rijal\n\n'
                    'CSCE 4901 Capstone Project',
              ),
              const SizedBox(height: 16),

              // Dependencies
              _buildDependenciesSection(context),
              const SizedBox(height: 16),

              // Support & Contact
              _buildSection(
                context,
                'Support & Contact',
                Icons.support_rounded,
                'Have questions or found a bug?\n\n'
                    'Contact support at:\n'
                    'support@senscribe.example\n\n'
                    'Or use the Contact Support button below.',
              ),
              const SizedBox(height: 16),

              // FAQ
              _buildSection(
                context,
                'Frequently Asked Questions',
                Icons.help_rounded,
                'Q: Is my audio data safe?\n'
                    'A: Yes! All processing happens on your device. No data is uploaded.\n\n'
                    'Q: Does the app work offline?\n'
                    'A: Yes! The app works completely offline.\n\n'
                    'Q: Why is accuracy sometimes low?\n'
                    'A: Accuracy depends on sound clarity and background noise.\n\n'
                    'Q: Can I export my saved texts?\n'
                    'A: Not currently. Saved app data stays local on this device unless you delete it.',
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: () => _copyEmail(context),
                      label: 'Support Email',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
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
            content,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDependenciesSection(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.extension_rounded,
                color: scheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open Source Dependencies',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'This build uses the direct Flutter dependencies listed below. Use View Licenses to inspect bundled package attributions and full license text available in the app.',
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _directDependencies
                .map(
                  (dependency) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      dependency,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: AdaptiveButton(
              onPressed: () => _showLicenses(context),
              label: 'View Licenses',
              style: AdaptiveButtonStyle.plain,
            ),
          ),
        ],
      ),
    );
  }
}
