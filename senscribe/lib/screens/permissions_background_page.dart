import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
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
      AdaptiveSnackBar.show(
        context,
        message: 'Microphone permission denied',
        type: AdaptiveSnackBarType.warning,
      );
    } else if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(
          'Microphone permission is permanently denied. Open settings to enable it?');
    } else if (status.isGranted) {
      AdaptiveSnackBar.show(
        context,
        message: 'Microphone permission granted',
        type: AdaptiveSnackBarType.success,
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
      AdaptiveSnackBar.show(
        context,
        message: 'Notification permission denied',
        type: AdaptiveSnackBarType.warning,
      );
    } else if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(
          'Notification permission is permanently denied. Open settings to enable it?');
    } else if (status.isGranted) {
      AdaptiveSnackBar.show(
        context,
        message: 'Notification permission granted',
        type: AdaptiveSnackBarType.success,
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
    AdaptiveAlertDialog.show(
      context: context,
      title: 'Permission Required',
      message: message,
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Open Settings',
          style: AlertActionStyle.primary,
          onPressed: () {
            openAppSettings();
          },
        ),
      ],
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
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: FutureBuilder<PermissionStatus>(
        future: statusFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return AdaptiveListTile(
              leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
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
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                    child: AdaptiveButton(
                      onPressed: isGranted ? null : onEnable,
                      label: isGranted ? 'Enabled' : 'Enable',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AdaptiveButton(
                      onPressed: isGranted ? onDisable : null,
                      label: 'Disable',
                      style: AdaptiveButtonStyle.bordered,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Permissions & Background'),
      body: Material(
        color: Colors.transparent,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top padding for iOS 26 translucent app bar
              if (Platform.isIOS)
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.top + kToolbarHeight),
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
            ],
          ),
        ),
      ),
    );
  }
}
