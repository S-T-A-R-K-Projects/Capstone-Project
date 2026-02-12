import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsBackgroundPage extends StatefulWidget {
  const PermissionsBackgroundPage({super.key});

  @override
  State<PermissionsBackgroundPage> createState() =>
      _PermissionsBackgroundPageState();
}

class _PermissionsBackgroundPageState extends State<PermissionsBackgroundPage> {
  late Future<PermissionStatus> _microphoneStatus;
  late Future<PermissionStatus> _notificationStatus;

  @override
  void initState() {
    super.initState();
    _microphoneStatus = Permission.microphone.status;
    _notificationStatus = Permission.notification.status;
  }

  Future<void> _requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _microphoneStatus = Future.value(status);
    });

    if (!mounted) return;

    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(
          'Microphone permission is permanently denied. Open settings to enable it?');
    } else if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission granted')),
      );
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationStatus = Future.value(status);
    });

    if (!mounted) return;

    if (status.isDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission denied')),
      );
    } else if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(
          'Notification permission is permanently denied. Open settings to enable it?');
    } else if (status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification permission granted')),
      );
    }
  }

  Future<void> _disableMicrophonePermission() async {
    _showOpenSettingsDialog(
        'To disable microphone permission, go to System Settings and revoke it for this app.');
  }

  Future<void> _disableNotificationPermission() async {
    _showOpenSettingsDialog(
        'To disable notification permission, go to System Settings and revoke it for this app.');
  }

  void _showOpenSettingsDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.of(context).pop();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard(
    String title,
    String description,
    IconData icon,
    Future<PermissionStatus> statusFuture,
    VoidCallback onEnable,
    VoidCallback onDisable,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<PermissionStatus>(
          future: statusFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                leading:
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                title: Text(title,
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                subtitle: const Text('Loading...'),
              );
            }

            final status = snapshot.data!;
            final isGranted = status.isGranted;
            final color = isGranted ? Colors.green : Colors.red;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon,
                        color: Theme.of(context).colorScheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            description,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isGranted ? 'Enabled' : 'Disabled',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(
                            isGranted ? Icons.check_circle : Icons.add_circle),
                        label: Text(isGranted ? 'Enabled' : 'Enable'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGranted
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isGranted ? null : onEnable,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Disable'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isGranted ? Colors.red : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: isGranted ? onDisable : null,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

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
        title: Text('Permissions & Background',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Permissions',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage permissions required for the app to function properly',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 24),
            // Microphone Permission
            _buildPermissionCard(
              'Microphone',
              'Record audio for sound classification',
              Icons.mic_rounded,
              _microphoneStatus,
              _requestMicrophonePermission,
              _disableMicrophonePermission,
            ),
            const SizedBox(height: 16),
            // Notification Permission
            _buildPermissionCard(
              'Notifications',
              'Send alerts and notifications',
              Icons.notifications_rounded,
              _notificationStatus,
              _requestNotificationPermission,
              _disableNotificationPermission,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
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
                          'About Permissions',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Microphone: Required to capture audio for real-time sound classification.\n\n'
                      'Notifications: Allows the app to send you alerts for critical sounds detected.\n\n'
                      'If permissions are permanently denied, open Settings and manually enable them.',
                      style: GoogleFonts.inter(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
