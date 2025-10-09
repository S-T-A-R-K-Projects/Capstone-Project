mport 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      {
        'title': 'Welcome to the app!',
        'subtitle': 'Thanks for joining. Let’s get started.',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.0),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Card(
                  child: ListTile(
                    leading: Icon(
                      item['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary,
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
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1);
              },
            ),
          ),
        ],
      ),
    );
  }
}
