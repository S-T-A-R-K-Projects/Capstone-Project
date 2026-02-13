import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExperimentalPage extends StatelessWidget {
  const ExperimentalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Functions',
      ),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding for iOS app bars (17/18/26+)
              if (Platform.isIOS)
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
              // Header
              Text(
                'Speech & Audio Functions',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Advanced features for converting between audio and text.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 24),

              // Speech-to-Text Section
              _buildSection(
                context,
                'Speech-to-Text (STT)',
                Icons.mic_rounded,
                'Convert spoken words into written text.\n\n'
                    '• Real-time speech recognition\n'
                    '• Processes audio as you speak\n'
                    '• Displays confidence levels\n'
                    '• Works with multiple languages\n'
                    '• Local processing (no cloud upload)',
              ),
              const SizedBox(height: 16),

              // STT Features
              _buildSection(
                context,
                'STT Features',
                Icons.check_circle_rounded,
                '• Start/stop recording manually\n'
                    '• Auto-stop on silence (configurable)\n'
                    '• Display live transcription as you speak\n'
                    '• Show confidence percentage for accuracy\n'
                    '• Copy text to clipboard\n'
                    '• Share transcription\n'
                    '• Save to history',
              ),
              const SizedBox(height: 16),

              // STT Settings
              _buildSection(
                context,
                'STT Configuration',
                Icons.settings_rounded,
                '• Select input language\n'
                    '• Adjust silence timeout (how long to wait)\n'
                    '• Toggle partial result display\n'
                    '• Enable/disable sound effects\n'
                    '• Choose output format (text only, with timestamps)\n'
                    '• Microphone input selection',
              ),
              const SizedBox(height: 16),

              // Text-to-Speech Section
              _buildSection(
                context,
                'Text-to-Speech (TTS)',
                Icons.volume_up_rounded,
                'Convert written text into spoken audio.\n\n'
                    '• Synthesize text into natural speech\n'
                    '• Multiple voice options\n'
                    '• Adjustable speech rate\n'
                    '• Adjustable pitch and volume\n'
                    '• Support for multiple languages',
              ),
              const SizedBox(height: 16),

              // TTS Features
              _buildSection(
                context,
                'TTS Features',
                Icons.check_circle_rounded,
                '• Paste or type text to speak\n'
                    '• Play/pause/stop audio playback\n'
                    '• Display text with word highlighting\n'
                    '• Speed control (slow, normal, fast)\n'
                    '• Save audio recording\n'
                    '• Share audio as file\n'
                    '• Multiple voice options to choose from',
              ),
              const SizedBox(height: 16),

              // TTS Settings
              _buildSection(
                context,
                'TTS Configuration',
                Icons.settings_rounded,
                '• Select voice (male, female, accent)\n'
                    '• Adjust speech rate (0.5x to 2x)\n'
                    '• Pitch control (high/low)\n'
                    '• Volume adjustment\n'
                    '• Language selection\n'
                    '• Phoneme correction for proper pronunciation',
              ),
              const SizedBox(height: 16),

              // History & Management
              _buildSection(
                context,
                'History & Management',
                Icons.history_rounded,
                'Keep track of your transcriptions and audio:\n\n'
                    '• View all past STT transcriptions\n'
                    '• View all past TTS generated audio\n'
                    '• Search by date or keyword\n'
                    '• Delete individual items\n'
                    '• Clear all history\n'
                    '• Export as text/audio files',
              ),
              const SizedBox(height: 16),

              // Accessibility Integration
              _buildSection(
                context,
                'Accessibility Integration',
                Icons.accessibility_rounded,
                'Works seamlessly with your accessibility features:\n\n'
                    '• Compatible with screen readers\n'
                    '• Works with Bluetooth/headset microphones\n'
                    '• Haptic feedback on speech detection\n'
                    '• Large text support for TTS output\n'
                    '• High contrast modes supported',
              ),
              const SizedBox(height: 16),

              // Performance & Quality
              _buildSection(
                context,
                'Performance & Accuracy',
                Icons.speed_rounded,
                '• Fast real-time processing\n'
                    '• Offline functionality (no internet required)\n'
                    '• Low latency speech recognition\n'
                    '• Clear, natural sounding speech\n'
                    '• Handles background noise well\n'
                    '• Optimized for mobile devices',
              ),
              const SizedBox(height: 16),

              // Troubleshooting
              _buildSection(
                context,
                'Troubleshooting',
                Icons.help_rounded,
                'Common issues and solutions:\n\n'
                    '• No microphone input? Check permissions\n'
                    '• Poor accuracy? Speak clearly, control background noise\n'
                    '• TTS not playing? Check volume/mute settings\n'
                    '• Language not recognized? Update language pack\n'
                    '• Lag or delays? Close other apps',
              ),
              const SizedBox(height: 16),

              // Best Practices
              _buildSection(
                context,
                'Best Practices',
                Icons.lightbulb_rounded,
                '• Speak clearly for better STT accuracy\n'
                    '• Use proper microphone distance (4-6 inches)\n'
                    '• Minimize background noise\n'
                    '• Check connectivity before using TTS\n'
                    '• Use punctuation for better TTS naturalness\n'
                    '• Review and save important transcriptions',
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
