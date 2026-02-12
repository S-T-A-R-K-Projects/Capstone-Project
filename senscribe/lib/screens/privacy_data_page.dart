import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: AdaptiveButton.icon(
            icon: Icons.arrow_back_ios_new_rounded,
            onPressed: () => Navigator.of(context).pop(),
            style: AdaptiveButtonStyle.glass,
          ),
        ),
        title: Text('Privacy & Data',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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
              'Control how your audio data is processed, stored, and managed.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),

            // On-Device Processing
            _buildSection(
              context,
              'On-Device Processing',
              Icons.phonelink_lock_rounded,
              'All audio processing happens locally on your device. Your audio data never leaves your phone.\n\n'
                  '• Real-time sound classifications performed immediately\n'
                  '• No audio files sent to external servers\n'
                  '• Speech-to-text uses on-device models\n'
                  '• Text-to-speech uses on-device models',
            ),
            const SizedBox(height: 16),

            // Data Collection
            _buildSection(
              context,
              'What Data We Collect',
              Icons.data_usage_rounded,
              'We only collect data necessary for the app to function:\n\n'
                  '• Sound classification results (what was detected)\n'
                  '• Audio captions and classification history\n'
                  '• Timestamps of when classifications occurred\n'
                  '• Custom name recognition data (if enabled)\n'
                  '• Your app settings and preferences',
            ),
            const SizedBox(height: 16),

            // Data Storage
            _buildSection(
              context,
              'How Data is Stored',
              Icons.storage_rounded,
              'Your data is stored securely on your device:\n\n'
                  '• All data stored locally on your device only\n'
                  '• Encrypted storage for sensitive data\n'
                  '• No cloud synchronization\n'
                  '• Data remains private to your device\n'
                  '• Access requires device unlock',
            ),
            const SizedBox(height: 16),

            // Name Recognition
            _buildSection(
              context,
              'Name Recognition Data',
              Icons.person_rounded,
              'If you enable name recognition:\n\n'
                  '• Custom names you add are stored locally\n'
                  '• Used only for local notifications\n'
                  '• Never shared or transmitted\n'
                  '• Can be deleted anytime from settings\n'
                  '• Only on your device',
            ),
            const SizedBox(height: 16),

            // Data Retention
            _buildSection(
              context,
              'Data Retention',
              Icons.schedule_rounded,
              'Control how long your data is kept:\n\n'
                  '• Classifications kept for 30 days by default\n'
                  '• Retention period can be customized\n'
                  '• Delete individual items anytime\n'
                  '• Clear all history with one tap\n'
                  '• Clearing app data removes everything',
            ),
            const SizedBox(height: 16),

            // Export & Delete
            _buildSection(
              context,
              'Export & Delete Your Data',
              Icons.download_rounded,
              'You have complete control:\n\n'
                  '• Export history as CSV/JSON for backup\n'
                  '• Share classifications with accessibility apps\n'
                  '• All data exports are local, not uploaded\n'
                  '• Delete data permanently anytime\n'
                  '• No data recovery after deletion',
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
                  '• Access all your data anytime\n'
                  '• Delete data permanently\n'
                  '• Disable features without explanation\n'
                  '• Request data export\n'
                  '• Know exactly what is being stored',
            ),
            const SizedBox(height: 16),

            // Sound History
            _buildSection(
              context,
              'Sound Detection History',
              Icons.history_rounded,
              'Manage your classification history:\n\n'
                  '• View all detected sounds with timestamps\n'
                  '• See confidence levels for detections\n'
                  '• Filter by date range\n'
                  '• Search by sound type\n'
                  '• Delete individual entries or all at once',
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
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    String content,
  ) {
    return Card(
      child: Padding(
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
      ),
    );
  }
}
