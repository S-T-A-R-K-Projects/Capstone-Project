import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveUpdateService {
  static final LiveUpdateService _instance = LiveUpdateService._internal();
  factory LiveUpdateService() => _instance;
  LiveUpdateService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/audio_classifier');

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }

  Future<void> startLiveUpdates() async {
    if (_isEnabled) return;

    // Request notification permission if needed
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        throw Exception('Notification permission denied');
      }
    }

    try {
      await _methodChannel.invokeMethod('startLiveUpdates');
      _isEnabled = true;
      _statusController.add(true);
      _log('Live updates started');
    } catch (e) {
      _log('Failed to start live updates: $e');
      rethrow;
    }
  }

  Future<void> stopLiveUpdates() async {
    if (!_isEnabled) return;
    try {
      await _methodChannel.invokeMethod('stopLiveUpdates');
      _isEnabled = false;
      _statusController.add(false);
      _log('Live updates stopped');
    } catch (e) {
      _log('Failed to stop live updates: $e');
      rethrow;
    }
  }

  void dispose() {
    _statusController.close();
  }
}