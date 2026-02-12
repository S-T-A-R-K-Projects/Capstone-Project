import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final notifications = [
      {
        'title': 'Welcome to the app!',
        'subtitle': 'Thanks for joining. Let\'s get started.',
        'icon': Icons.celebration_rounded,
      },
      {
        'title': 'Update Available',
        'subtitle': 'Version 1.1.0 is ready to install.',
        'icon': Icons.system_update_alt_rounded,
      },
      {
        'title': 'Privacy Reminder',
        'subtitle': 'Review your privacy settings for better control.',
        'icon': Icons.lock_rounded,
      },
      {
        'title': 'New Feature: Dark Mode',
        'subtitle': 'Try out the new appearance settings.',
        'icon': Icons.dark_mode_rounded,
      },
    ];

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Notifications'),
      body: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Top padding for iOS 26 translucent app bar
            if (PlatformInfo.isIOS26OrHigher())
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final item = notifications[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AdaptiveCard(
                      padding: const EdgeInsets.all(0),
                      child: AdaptiveListTile(
                        leading: Icon(
                          item['icon'] as IconData,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(
                          item['title'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          item['subtitle'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
