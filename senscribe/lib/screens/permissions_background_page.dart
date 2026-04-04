import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/app_permission_service.dart';

class PermissionsBackgroundPage extends StatefulWidget {
  const PermissionsBackgroundPage({super.key});

  @override
  State<PermissionsBackgroundPage> createState() =>
      _PermissionsBackgroundPageState();
}

class _PermissionsBackgroundPageState extends State<PermissionsBackgroundPage>
    with WidgetsBindingObserver {
  final AppPermissionService _permissionService = AppPermissionService();
  AppPermissionSnapshot? _snapshot;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshStatuses();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatuses();
    }
  }

  Future<void> _refreshStatuses() async {
    final snapshot = await _permissionService.loadStatuses();
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _isLoading = false;
    });
  }

  Future<void> _requestPermission(
    Future<PermissionStatus> Function() request, {
    required String grantedMessage,
    required String deniedMessage,
    required String permanentlyDeniedMessage,
  }) async {
    final status = await request();
    await _refreshStatuses();

    if (!mounted) return;

    if (status.isGranted) {
      AdaptiveSnackBar.show(
        context,
        message: grantedMessage,
        type: AdaptiveSnackBarType.success,
      );
      return;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      _showOpenSettingsDialog(permanentlyDeniedMessage);
      return;
    }

    AdaptiveSnackBar.show(
      context,
      message: deniedMessage,
      type: AdaptiveSnackBarType.warning,
    );
  }

  void _showOpenSettingsDialog(String message) {
    AdaptiveAlertDialog.show(
      context: context,
      title: 'Open Settings',
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

  String _statusLabel(PermissionStatus status) {
    if (status.isGranted) return 'Enabled';
    if (status.isLimited) return 'Limited';
    if (status.isPermanentlyDenied) return 'Blocked';
    if (status.isRestricted) return 'Restricted';
    return 'Disabled';
  }

  Color _statusColor(PermissionStatus status) {
    if (status.isGranted) return Colors.green;
    if (status.isLimited) return Colors.orange;
    if (status.isPermanentlyDenied || status.isRestricted) {
      return Colors.red;
    }
    return Colors.red;
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required IconData icon,
    required PermissionStatus status,
    required VoidCallback onEnable,
    required String disableMessage,
  }) {
    final color = _statusColor(status);
    final label = _statusLabel(status);
    final canRequest = !(status.isGranted || status.isLimited);

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
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
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
                  onPressed: canRequest ? onEnable : null,
                  label: canRequest ? 'Enable' : 'Enabled',
                  style: AdaptiveButtonStyle.filled,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AdaptiveButton(
                  onPressed: () => _showOpenSettingsDialog(disableMessage),
                  label: 'System Settings',
                  style: AdaptiveButtonStyle.bordered,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'Permissions & Background'),
      body: Material(
        color: Colors.transparent,
        child: _isLoading || _snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (topInset > 0) SizedBox(height: topInset),
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
                      Platform.isIOS
                          ? 'Monitor microphone, speech recognition, local alerts, Live Activities, and background audio readiness.'
                          : 'Monitor microphone, notifications, battery optimization, and background monitoring readiness.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPermissionCard(
                      title: 'Microphone',
                      description:
                          'Required for sound recognition, speech-to-text, and custom sound training.',
                      icon: Icons.mic_rounded,
                      status: _snapshot!.microphone,
                      onEnable: () => _requestPermission(
                        _permissionService.requestMicrophone,
                        grantedMessage: 'Microphone permission granted',
                        deniedMessage: 'Microphone permission denied',
                        permanentlyDeniedMessage:
                            'Microphone access is blocked. Open Settings to enable it for SenScribe.',
                      ),
                      disableMessage:
                          'Use system settings if you want to revoke microphone access for SenScribe.',
                    ),
                    const SizedBox(height: 16),
                    _buildPermissionCard(
                      title: 'Notifications',
                      description: Platform.isIOS
                          ? 'Used for local alerts. Live Activities are managed separately by iOS when supported.'
                          : 'Required for local alerts and Android live update notifications.',
                      icon: Icons.notifications_rounded,
                      status: _snapshot!.notifications,
                      onEnable: () => _requestPermission(
                        _permissionService.requestNotifications,
                        grantedMessage: 'Notification permission granted',
                        deniedMessage: 'Notification permission denied',
                        permanentlyDeniedMessage:
                            'Notification access is blocked. Open Settings to enable it for SenScribe.',
                      ),
                      disableMessage:
                          'Use system settings if you want to revoke notification access for SenScribe.',
                    ),
                    if (Platform.isIOS &&
                        _snapshot!.speechRecognition != null) ...[
                      const SizedBox(height: 16),
                      _buildPermissionCard(
                        title: 'Speech Recognition',
                        description:
                            'Required for speech-to-text transcription on iOS. There is no separate app-level iOS sound recognition permission.',
                        icon: Icons.record_voice_over_rounded,
                        status: _snapshot!.speechRecognition!,
                        onEnable: () => _requestPermission(
                          _permissionService.requestSpeechRecognition,
                          grantedMessage:
                              'Speech recognition permission granted',
                          deniedMessage: 'Speech recognition permission denied',
                          permanentlyDeniedMessage:
                              'Speech recognition access is blocked. Open Settings to enable it for SenScribe.',
                        ),
                        disableMessage:
                            'Use system settings if you want to revoke speech recognition access for SenScribe.',
                      ),
                    ],
                    if (Platform.isAndroid &&
                        _snapshot!.ignoreBatteryOptimizations != null) ...[
                      const SizedBox(height: 16),
                      _buildPermissionCard(
                        title: 'Battery Optimization',
                        description:
                            'Disable battery optimization so Android is less likely to stop background monitoring.',
                        icon: Icons.battery_saver_rounded,
                        status: _snapshot!.ignoreBatteryOptimizations!,
                        onEnable: () => _requestPermission(
                          _permissionService.requestIgnoreBatteryOptimizations,
                          grantedMessage:
                              'Battery optimization disabled for SenScribe',
                          deniedMessage:
                              'Battery optimization is still enabled',
                          permanentlyDeniedMessage:
                              'Open system settings and allow SenScribe to ignore battery optimization for more reliable background monitoring.',
                        ),
                        disableMessage:
                            'Use system settings if you want Android battery optimization enabled again for SenScribe.',
                      ),
                    ],
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
                              Expanded(
                                child: Text(
                                  'Background Behavior',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            Platform.isIOS
                                ? 'SenScribe is configured for background audio activity on iOS 17 and later. When Live Updates are enabled, sound monitoring can surface in a Live Activity while the app remains active in the background. Microphone permission is required, and speech recognition remains a separate iOS permission for transcription only.'
                                : 'SenScribe uses an Android foreground microphone service for background live updates. For the most reliable background behavior, keep notifications enabled and disable battery optimization for the app.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              height: 1.6,
                            ),
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
