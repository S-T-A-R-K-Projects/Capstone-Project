import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/sound_caption.dart';
import 'sound_filter_service.dart';
import '../utils/app_constants.dart';
import 'location_service.dart';

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
  List<SoundCaption> get history => _visibleHistorySnapshot();
  int? _historyLimit = AppConstants.soundHistoryMaxItems;
  int? get historyLimit => _historyLimit;

  final _historyController = StreamController<List<SoundCaption>>.broadcast();
  Stream<List<SoundCaption>> get historyStream => _historyController.stream;
  final _monitoringStateController = StreamController<bool>.broadcast();
  Stream<bool> get monitoringStateStream => _monitoringStateController.stream;

  Position? _lastPosition;
  String? _lastLocationName;

  StreamSubscription? _nativeSubscription;
  bool _isMonitoring = false;
  bool get isMonitoring => _isMonitoring;
  final SoundFilterService _soundFilterService = SoundFilterService();

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }

  Future<void> start() async {
    if (_isMonitoring) return;
    await _soundFilterService.initialize();
        _lastPosition = await LocationService().getCurrentPosition();
    if (_lastPosition != null) {
      _lastLocationName = await LocationService().getLocationName(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
      );
    }
    try {
      await _methodChannel.invokeMethod('start');
      _isMonitoring = true;
      _monitoringStateController.add(true);
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
      _monitoringStateController.add(false);
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
    } catch (e) {
      _log('Audio classification stop error: $e');
    }
  }

  Future<void> setSpeechRecognitionActive(bool active) async {
    try {
      await _methodChannel.invokeMethod(
        'setSpeechRecognitionActive',
        <String, dynamic>{'active': active},
      );
    } catch (e) {
      _log('Audio classification speech sync error: $e');
    }
  }

  void _handleEvent(Map<String, dynamic> data) {
    final label = data['label'] as String? ?? 'Unknown';
    final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
    final sourceValue = data['source'] as String? ?? 'builtIn';
    final timestampMs = data['timestampMs'] as int?;
    final customSoundId = data['customSoundId'] as String?;
    final isCustom = sourceValue == 'custom';

    if (!isCustom && confidence < AppConstants.audioConfidenceThreshold) {
      return;
    }

        final caption = SoundCaption(
      sound: label,
      timestamp: timestampMs == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampMs),
      isCritical: CriticalSounds.isCritical(label),
      confidence: confidence,
      source: isCustom ? SoundCaptionSource.custom : SoundCaptionSource.builtIn,
      customSoundId: customSoundId,
      latitude: _lastPosition?.latitude,
      longitude: _lastPosition?.longitude,
      locationName: _lastLocationName,
    );

    if (!_soundFilterService.matchesCaption(caption)) {
      return;
    }

    _history.insert(0, caption);
    _broadcastHistory();
  }

  void clearHistory() {
    if (_history.isEmpty) return;
    _history.clear();
    _broadcastHistory();
  }

  bool deleteCaption(SoundCaption caption) {
    final removed = _history.remove(caption);
    if (!removed) return false;
    _broadcastHistory();
    return true;
  }

  void setHistoryLimit(int? limit) {
    if (limit != null && limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'Must be greater than zero.');
    }
    if (_historyLimit == limit) return;
    _historyLimit = limit;
    _broadcastHistory();
  }

  List<SoundCaption> _visibleHistorySnapshot() {
    final limit = _historyLimit;
    if (limit == null) {
      return List<SoundCaption>.unmodifiable(_history);
    }
    return List<SoundCaption>.unmodifiable(_history.take(limit));
  }

  void _broadcastHistory() {
    _historyController.add(_visibleHistorySnapshot());
  }

  @visibleForTesting
  void debugReplaceHistory(List<SoundCaption> captions) {
    _history
      ..clear()
      ..addAll(captions);
    _broadcastHistory();
  }

  @visibleForTesting
  void debugSetMonitoring(bool isMonitoring) {
    _isMonitoring = isMonitoring;
    _monitoringStateController.add(isMonitoring);
  }

  @visibleForTesting
  void debugHandleNativeResult(Map<String, dynamic> data) {
    _handleEvent(data);
  }
}
