import 'dart:async';
import 'package:flutter/services.dart';
import '../models/sound_caption.dart';
import '../utils/app_constants.dart';

class AudioClassificationService {
  static final AudioClassificationService _instance =
      AudioClassificationService._internal();
  factory AudioClassificationService() => _instance;
  AudioClassificationService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/audio_classifier');
  static const EventChannel _eventChannel =
      EventChannel('senscribe/audio_classifier_events');

  final List<SoundCaption> _history = [];
  List<SoundCaption> get history => List.unmodifiable(_history);

  final _historyController = StreamController<List<SoundCaption>>.broadcast();
  Stream<List<SoundCaption>> get historyStream => _historyController.stream;

  StreamSubscription? _nativeSubscription;
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }

  Future<void> start() async {
    if (_isMonitoring) return;
    try {
      await _methodChannel.invokeMethod('start');
      _isMonitoring = true;
      _nativeSubscription =
          _eventChannel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          final data = Map<String, dynamic>.from(event);
          if (data['type'] == 'result') {
            _handleEvent(data);
          }
        }
      });
    } catch (e) {
      _log('Audio classification start error: $e');
    }
  }

  Future<void> stop() async {
    if (!_isMonitoring) return;
    try {
      await _methodChannel.invokeMethod('stop');
      _isMonitoring = false;
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
    } catch (e) {
      _log('Audio classification stop error: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> data) {
    final label = data['label'] as String? ?? 'Unknown';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

    if (confidence < AppConstants.audioConfidenceThreshold) return;

    final caption = SoundCaption(
      sound: label,
      timestamp: DateTime.now(),
      isCritical: CriticalSounds.isCritical(label),
      direction: 'Unknown',
      confidence: confidence,
    );

    _history.insert(0, caption);
    if (_history.length > AppConstants.soundHistoryMaxItems) {
      _history.removeLast();
    }
    _historyController.add(_history);
  }
}
