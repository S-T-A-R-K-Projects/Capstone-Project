import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestMicrophonePermission() async {
    print('Requesting microphone permission...');
    
    final status = await Permission.microphone.status;
    print('Current microphone status: $status');
    
    if (status.isDenied || status.isPermanentlyDenied) {
      print('Permission denied or permanently denied, requesting...');
      final newStatus = await Permission.microphone.request();
      print('New microphone status after request: $newStatus');
      return newStatus.isGranted;
    }
    
    return status.isGranted;
  }

  Future<bool> checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    print('Checking microphone permission: $status');
    return status.isGranted;
  }
  
  Future<PermissionStatus> getMicrophoneStatus() async {
    return await Permission.microphone.status;
  }

  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
