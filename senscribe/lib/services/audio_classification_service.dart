import 'dart:async';
import 'package:flutter/services.dart';

class AudioClassificationService {
  static const MethodChannel _methodChannel = MethodChannel(
    'senscribe/audio_classifier',
  );
  static const EventChannel _eventChannel = EventChannel(
    'senscribe/audio_classifier_events',
  );

  Stream<Map<String, dynamic>>? _cachedStream;

  Stream<Map<String, dynamic>> get classificationStream {
    _cachedStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        return Map<String, dynamic>.from(event);
      }
      throw PlatformException(
        code: 'invalid_event',
        message: 'Unexpected event type: ${event.runtimeType}',
      );
    });
    return _cachedStream!;
  }

  Future<void> start() async {
    await _methodChannel.invokeMethod('start');
  }

  Future<void> stop() async {
    await _methodChannel.invokeMethod('stop');
  }
}
