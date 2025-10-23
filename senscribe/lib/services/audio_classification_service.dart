import 'dart:async';
import 'package:flutter/services.dart';

class AudioClassificationResult {
  final String label;
  final double confidence;
  final DateTime timestamp;
  final String? direction;

  AudioClassificationResult({
    required this.label,
    required this.confidence,
    required this.timestamp,
    this.direction,
  });

  factory AudioClassificationResult.fromMap(Map<String, dynamic> map) {
    return AudioClassificationResult(
      label: map['label'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      direction: map['direction'] as String?,
    );
  }
}

class AudioClassificationService {
  static const MethodChannel _channel = MethodChannel('com.senscribe/audio_classification');
  static const EventChannel _eventChannel = EventChannel('com.senscribe/audio_events');
  
  static final AudioClassificationService _instance = AudioClassificationService._internal();
  factory AudioClassificationService() => _instance;
  AudioClassificationService._internal();

  StreamSubscription? _eventSubscription;
  final StreamController<AudioClassificationResult> _resultsController =
      StreamController<AudioClassificationResult>.broadcast();

  Stream<AudioClassificationResult> get resultsStream => _resultsController.stream;

  Future<void> initialize() async {
    try {
      await _channel.invokeMethod('initialize');
      _setupEventListener();
    } catch (e) {
      throw Exception('Failed to initialize audio classification: $e');
    }
  }

  void _setupEventListener() {
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final result = AudioClassificationResult.fromMap(Map<String, dynamic>.from(event));
          _resultsController.add(result);
        }
      },
      onError: (error) {
        _resultsController.addError(error);
      },
    );
  }
  
  Future<bool> requestMicrophonePermission() async {
    try {
      final result = await _channel.invokeMethod('requestMicrophonePermission');
      return result as bool;
    } catch (e) {
      print('Error requesting microphone permission: $e');
      return false;
    }
  }

  Future<void> startMonitoring() async {
    try {
      await _channel.invokeMethod('startMonitoring');
    } catch (e) {
      throw Exception('Failed to start monitoring: $e');
    }
  }

  Future<void> stopMonitoring() async {
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      throw Exception('Failed to stop monitoring: $e');
    }
  }

  Future<bool> isMonitoring() async {
    try {
      final result = await _channel.invokeMethod('isMonitoring');
      return result as bool;
    } catch (e) {
      return false;
    }
  }

  Future<void> enableDirectionDetection(bool enable) async {
    try {
      await _channel.invokeMethod('enableDirectionDetection', {'enable': enable});
    } catch (e) {
      throw Exception('Failed to toggle direction detection: $e');
    }
  }

  void dispose() {
    _eventSubscription?.cancel();
    _resultsController.close();
  }
}
