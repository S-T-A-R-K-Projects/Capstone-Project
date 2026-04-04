import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Privacy & Data'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (topInset > 0) SizedBox(height: topInset),
              Text(
                'Privacy & Data',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'SenScribe processes audio on-device and does not collect or upload your personal data.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),

              // On-Device Processing
              _buildSection(
                context,
                'What Happens On Device',
                Icons.phonelink_lock_rounded,
                'SenScribe runs its core features locally on your phone.\n\n'
                    '• Environmental sound recognition runs on-device\n'
                    '• Speech-to-text runs on-device\n'
                    '• Text-to-speech runs on-device\n'
                    '• Trigger word matching runs against local transcript text\n'
                    '• Custom sound matching stays on this device',
              ),
              const SizedBox(height: 16),

              // Data Collection
              _buildSection(
                context,
                'What SenScribe Collects',
                Icons.data_usage_rounded,
                'SenScribe does not collect data for us.\n\n'
                    '• No account creation\n'
                    '• No analytics or tracking SDKs\n'
                    '• No cloud upload of audio, transcripts, or alerts\n'
                    '• No sale or sharing of personal data\n'
                    '• No remote profiling based on what you say or hear',
              ),
              const SizedBox(height: 16),

              // Data Storage
              _buildSection(
                context,
                'What is Stored Locally',
                Icons.storage_rounded,
                'The app can store feature data inside local app storage on this device.\n\n'
                    '• Trigger words and recent trigger alerts\n'
                    '• Custom sound profiles and recorded training samples\n'
                    '• Saved text history and generated summaries\n'
                    '• App preferences such as theme and onboarding state\n'
                    '• Model and feature settings required by the app',
              ),
              const SizedBox(height: 16),

              // Audio Handling
              _buildSection(
                context,
                'How Audio and Text are Handled',
                Icons.mic_rounded,
                'Microphone input is processed live on-device while features are active.\n\n'
                    '• Live sound detections are shown locally in the app\n'
                    '• Trigger words are checked against recognized speech on-device\n'
                    '• Saved text history is only kept when you choose to save text inside the app\n'
                    '• Custom sound recordings remain in the app’s local storage\n'
                    '• Nothing is sent to SenScribe servers because there are none for processing',
              ),
              const SizedBox(height: 16),

              // Permissions
              _buildSection(
                context,
                'Permissions Used',
                Icons.admin_panel_settings_rounded,
                'Permissions are used only for local app features.\n\n'
                    '• Microphone: required for sound recognition, speech-to-text, and custom sound training\n'
                    '• Notifications: used for live updates and local alerts\n'
                    '• Device storage/app files: used to keep local preferences and custom sound samples\n'
                    '• No permission is used to upload your data elsewhere',
              ),
              const SizedBox(height: 16),

              // Your Control
              _buildSection(
                context,
                'Your Control',
                Icons.tune_rounded,
                'You control the data that stays on your device.\n\n'
                    '• Delete saved history entries from History\n'
                    '• Remove trigger words or trigger alerts from Alerts\n'
                    '• Delete custom sounds and their samples from Alerts\n'
                    '• Turn live updates on or off from Settings\n'
                    '• Revoke permissions from iOS or Android system settings',
              ),
              const SizedBox(height: 16),

              // Third-Party Services
              _buildSection(
                context,
                'Third-Party Services',
                Icons.security_rounded,
                'We do not use third-party services for:\n\n'
                    '• Audio processing or storage\n'
                    '• Analytics or tracking\n'
                    '• Data selling or sharing\n'
                    '• Cloud services\n'
                    '• User profiling or targeting',
              ),
              const SizedBox(height: 16),

              // Your Rights
              _buildSection(
                context,
                'Your Privacy Rights',
                Icons.verified_user_rounded,
                'You have the right to:\n\n'
                    '• Know what the app stores locally\n'
                    '• Delete local app data you created\n'
                    '• Disable features you do not want to use\n'
                    '• Revoke permissions at the OS level\n'
                    '• Use the app without creating an account',
              ),
              const SizedBox(height: 16),

              // Consent & Transparency
              _buildSection(
                context,
                'Consent & Transparency',
                Icons.check_circle_rounded,
                'Your consent matters:\n\n'
                    '• You explicitly enable each feature\n'
                    '• You control all permissions\n'
                    '• You can revoke access anytime\n'
                    '• No automatic data collection\n'
                    '• Transparent about what we store',
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
}
