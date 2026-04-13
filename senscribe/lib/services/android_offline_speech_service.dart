import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum AndroidOfflineSpeechEventType { partial, finalResult, status, error }

class AndroidOfflineSpeechEvent {
  const AndroidOfflineSpeechEvent({
    required this.type,
    this.text = '',
    this.status = '',
    this.errorCode = '',
    this.errorMessage = '',
  });

  final AndroidOfflineSpeechEventType type;
  final String text;
  final String status;
  final String errorCode;
  final String errorMessage;
}

class AndroidOfflineSpeechService {
  static final AndroidOfflineSpeechService _instance =
      AndroidOfflineSpeechService._internal();

  factory AndroidOfflineSpeechService() => _instance;

  AndroidOfflineSpeechService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/android_speech');
  static const EventChannel _eventChannel =
      EventChannel('senscribe/android_speech_events');

  final _eventController =
      StreamController<AndroidOfflineSpeechEvent>.broadcast();
  StreamSubscription? _nativeSubscription;
  bool _isInitialized = false;
  bool _isListening = false;

  Stream<AndroidOfflineSpeechEvent> get events => _eventController.stream;
  bool get isListening => _isListening;

  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    _nativeSubscription ??= _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (Object error) {
        _eventController.add(
          AndroidOfflineSpeechEvent(
            type: AndroidOfflineSpeechEventType.error,
            errorCode: 'stream_error',
            errorMessage: error.toString(),
          ),
        );
      },
    );

    try {
      final ready =
          await _methodChannel.invokeMethod<bool>('initialize') ?? false;
      _isInitialized = ready;
      return ready;
    } catch (error) {
      _eventController.add(
        AndroidOfflineSpeechEvent(
          type: AndroidOfflineSpeechEventType.error,
          errorCode: 'initialize_failed',
          errorMessage: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> startListening() async {
    await _methodChannel.invokeMethod('start');
  }

  Future<void> stopListening() async {
    await _methodChannel.invokeMethod('stop');
  }

  Future<void> cancelListening() async {
    await _methodChannel.invokeMethod('cancel');
  }

  void _handleNativeEvent(dynamic event) {
    if (event is! Map) {
      return;
    }
    final data = Map<String, dynamic>.from(event);
    final type = data['type'] as String? ?? '';

    switch (type) {
      case 'partial':
        _eventController.add(
          AndroidOfflineSpeechEvent(
            type: AndroidOfflineSpeechEventType.partial,
            text: (data['text'] as String? ?? '').trim(),
          ),
        );
        break;
      case 'final':
        _eventController.add(
          AndroidOfflineSpeechEvent(
            type: AndroidOfflineSpeechEventType.finalResult,
            text: (data['text'] as String? ?? '').trim(),
          ),
        );
        break;
      case 'status':
        final status = (data['status'] as String? ?? '').trim();
        _isListening = status == 'listening';
        _eventController.add(
          AndroidOfflineSpeechEvent(
            type: AndroidOfflineSpeechEventType.status,
            status: status,
          ),
        );
        break;
      case 'error':
        _isListening = false;
        _eventController.add(
          AndroidOfflineSpeechEvent(
            type: AndroidOfflineSpeechEventType.error,
            errorCode: (data['code'] as String? ?? '').trim(),
            errorMessage: (data['message'] as String? ?? '').trim(),
          ),
        );
        break;
      default:
        if (kDebugMode) {
          debugPrint('Unknown Android speech event: $data');
        }
    }
  }

  Future<void> dispose() async {
    await _nativeSubscription?.cancel();
    _nativeSubscription = null;
    _isInitialized = false;
    _isListening = false;
  }
}
