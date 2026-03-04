import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Simple singleton wrapper around flutter_local_notifications.
///
/// - call [init] once on app start (before showing any notifications)
/// - use [showAlertNotification] to display an immediate notification
///  ; it is preconfigured to vibrate and play sound on both platforms.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create a channel with vibration enabled. This channel will be used for
    // all "trigger word" alerts so that the device will buzz even if the
    // user has otherwise silenced notifications.
    if (!kIsWeb) {
      const channel = AndroidNotificationChannel(
        'trigger_channel',
        'Trigger Alerts',
        description: 'Notifications when a trigger word is heard',
        importance: Importance.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        playSound: true,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    _initialized = true;
  }

  /// Displays a simple notification with [title] and [body].
  ///
  /// On Android the notification is posted to the `trigger_channel` which was
  /// configured to vibrate; the iOS counterpart simply presents an alert with
  /// sound.
  Future<void> showAlertNotification(String title, String body) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'trigger_channel',
        'Trigger Alerts',
        channelDescription: 'Notifications when a trigger word is heard',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        playSound: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      final details = const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(0, title, body, details);
    } catch (e) {
      debugPrint('NotificationService.showAlertNotification failed: $e');
    }
  }
}
