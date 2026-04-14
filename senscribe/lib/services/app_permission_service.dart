import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'app_settings_service.dart';

class AppPermissionSnapshot {
  const AppPermissionSnapshot({
    required this.microphone,
    required this.notifications,
    this.speechRecognition,
    this.location,
    this.ignoreBatteryOptimizations,
  });

  final PermissionStatus microphone;
  final PermissionStatus notifications;
  final PermissionStatus? speechRecognition;
  final PermissionStatus? location;
  final PermissionStatus? ignoreBatteryOptimizations;
}

class AppPermissionService {
  static const MethodChannel _iosPermissionChannel =
      MethodChannel('senscribe/ios_permissions');
  static final AppPermissionService _instance =
      AppPermissionService._internal();
  factory AppPermissionService() => _instance;
  AppPermissionService._internal();

  final AppSettingsService _settingsService = AppSettingsService();

  Future<AppPermissionSnapshot> loadStatuses() async {
    try {
      if (Platform.isIOS) {
        final nativeSnapshot = await _loadIosStatuses();
        if (nativeSnapshot != null) {
          return nativeSnapshot;
        }
      }
    } catch (e) {
      // Platform check failed, likely on web
    }

    final microphone = await Permission.microphone.status;
    final notifications = await Permission.notification.status;
    final location = await Permission.locationWhenInUse.status;
    PermissionStatus? speechRecognition;
    try {
      speechRecognition =
          Platform.isIOS ? await Permission.speech.status : null;
    } catch (e) {
      // Platform check failed
    }
    PermissionStatus? ignoreBatteryOptimizations;
    try {
      ignoreBatteryOptimizations = Platform.isAndroid
          ? await Permission.ignoreBatteryOptimizations.status
          : null;
    } catch (e) {
      // Platform check failed
    }

    return AppPermissionSnapshot(
      microphone: microphone,
      notifications: notifications,
      location: location,
      speechRecognition: speechRecognition,
      ignoreBatteryOptimizations: ignoreBatteryOptimizations,
    );
  }

  Future<AppPermissionSnapshot?> _loadIosStatuses() async {
    try {
      final response =
          await _iosPermissionChannel.invokeMapMethod<String, dynamic>(
        'getPermissionStatuses',
      );
      if (response == null) return null;

      return AppPermissionSnapshot(
        microphone: _mapNativeStatus(response['microphone'] as String?),
        notifications: _mapNativeStatus(response['notifications'] as String?),
        location: _mapNativeStatus(response['location'] as String?),
        speechRecognition:
            _mapNativeStatus(response['speechRecognition'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  PermissionStatus _mapNativeStatus(String? rawStatus) {
    switch (rawStatus) {
      case 'granted':
        return PermissionStatus.granted;
      case 'limited':
        return PermissionStatus.limited;
      case 'restricted':
        return PermissionStatus.restricted;
      case 'permanentlyDenied':
        return PermissionStatus.permanentlyDenied;
      case 'provisional':
        return PermissionStatus.granted;
      case 'denied':
      case 'notDetermined':
      default:
        return PermissionStatus.denied;
    }
  }

  Future<void> requestInitialPermissionsIfNeeded() async {
    final alreadyRequested =
        await _settingsService.hasRequestedInitialPermissions();
    if (alreadyRequested) return;

    await _settingsService.markInitialPermissionsRequested();

    await requestMicrophone();

    try {
      if (Platform.isIOS) {
        await requestSpeechRecognition();
      }
    } catch (e) {
      // Platform check failed
    }

    await requestNotifications();
    await requestLocation();

    try {
      if (Platform.isAndroid) {
        await requestIgnoreBatteryOptimizations();
      }
    } catch (e) {
      // Platform check failed
    }
  }

  Future<PermissionStatus> requestMicrophone() {
    return Permission.microphone.request();
  }

  Future<PermissionStatus> requestNotifications() {
    return Permission.notification.request();
  }

  Future<PermissionStatus> requestLocation() {
    return Permission.locationWhenInUse.request();
  }

  Future<PermissionStatus> requestSpeechRecognition() {
    return Permission.speech.request();
  }

  Future<PermissionStatus> requestIgnoreBatteryOptimizations() {
    return Permission.ignoreBatteryOptimizations.request();
  }
}
