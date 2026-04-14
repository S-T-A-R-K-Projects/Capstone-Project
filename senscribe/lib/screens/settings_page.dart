import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../main.dart';
import 'alerts_page.dart';
import 'about_support.dart';
import 'experimental_page.dart';
import 'home_tab.dart';
import 'privacy_data_page.dart';
import 'permissions_background_page.dart';
import 'model_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.instance;
    final theme = Theme.of(context);
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight + 16
        : 16.0;

    final SystemUiOverlayStyle overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: AdaptiveScaffold(
        appBar: AdaptiveAppBar(
          title: 'Settings',
        ),
        body: Material(
        color: Colors.transparent,
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: topInset,
            bottom: 120,
          ),
          children: [
            // Appearance Section
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.palette_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Appearance',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_auto_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'App Theme',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        platformBrightness: theme.brightness,
                      ),
                      child: AdaptiveSegmentedControl(
                        key: ValueKey(
                          'settings-theme-${theme.brightness.name}',
                        ),
                        labels: const ['System', 'Light', 'Dark'],
                        color: theme.colorScheme.surface,
                        shrinkWrap: false,
                        selectedIndex: themeProvider.themeMode.index,
                        onValueChanged: (int index) {
                          themeProvider.setTheme(ThemeMode.values[index]);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Experimental (P3) - styled card like About & Support
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Functions',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Speech-to-Text, Text-to-Speech',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ExperimentalPage(),
                        ),
                      ),
                      label: 'Manage',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // AI Model Configuration
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'AI Model Configuration',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Configure on-device AI model for text summarization. Model runs locally for privacy.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ModelSettingsPage(),
                        ),
                      ),
                      label: 'Configure',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Alert Triggers
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.notifications_active_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Alert Triggers',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Manage trigger words for speech monitoring and custom sounds for local audio alerts. Everything stays on this device.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AlertsPage(initialTabIndex: 1),
                        ),
                      ),
                      label: 'Open Alert Triggers',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Privacy & Data - styled card like About & Support
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.privacy_tip_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Privacy & Data',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No data collection, no cloud upload, and local-only storage for the items you create in the app.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyDataPage(),
                        ),
                      ),
                      label: 'Manage',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Permissions & Background - styled card like About & Support
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Permissions & Background',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _getPlatformDescription(),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PermissionsBackgroundPage(),
                        ),
                      ),
                      label: 'Open',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Re-launch onboarding tour
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Onboarding',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Restart the step-by-step introduction whenever you want to revisit key features.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () async {
                        await HomeTab.restartOnboarding();
                        if (!context.mounted) return;
                        AdaptiveSnackBar.show(
                          context,
                          message:
                              'Onboarding restarted. Go back to Home to continue.',
                          type: AdaptiveSnackBarType.success,
                        );
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      label: 'Run Onboarding',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // About & Support
            AdaptiveCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'About & Support',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AdaptiveListTile(
                    title: const Text('Version'),
                    subtitle: const Text('1.0.0'),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AdaptiveButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AboutSupportPage(),
                        ),
                      ),
                      label: 'Acknowledgements',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }

  String _getPlatformDescription() {
    try {
      return Platform.isIOS
          ? 'Microphone, speech recognition, local alerts, Live Activities, and background audio behavior.'
          : 'Microphone, notifications, battery optimization, and background monitoring behavior.';
    } catch (e) {
      // Platform check failed, likely on web
      return 'Microphone, notifications, and background monitoring behavior.';
    }
  }
}
