import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/live_activity_snapshot.dart';
import '../models/sound_caption.dart';
import 'app_settings_service.dart';
import 'audio_classification_service.dart';

class LiveUpdateService {
  static final LiveUpdateService _instance = LiveUpdateService._internal();
  factory LiveUpdateService() => _instance;
  LiveUpdateService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/audio_classifier');
  static const MethodChannel _iosMethodChannel =
      MethodChannel('senscribe/ios_live_activities');
  final AppSettingsService _settingsService = AppSettingsService();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  AudioClassificationService? _audioService;
  StreamSubscription<List<SoundCaption>>? _audioHistorySubscription;
  Future<void>? _initializationFuture;
  LiveActivitySnapshot? _currentSnapshot;
  String? _lastProcessedEventSignature;
  bool _isIosPluginReady = false;
  bool _isInitializing = false;

  void _log(String message) {
    assert(() {
      // ignore: avoid_print
      print(message);
      return true;
    }());
  }

  Future<void> initialize({
    required AudioClassificationService audioService,
  }) async {
    _audioService = audioService;
    _audioHistorySubscription ??=
        audioService.historyStream.listen(_handleAudioHistoryUpdate);

    if (_initializationFuture != null) {
      return _initializationFuture;
    }

    _initializationFuture = _initializeInternal(audioService);
    return _initializationFuture;
  }

  Future<void> _initializeInternal(
      AudioClassificationService audioService) async {
    _isInitializing = true;
    try {
      if (Platform.isIOS) {
        _isIosPluginReady = true;
      }
    } catch (e) {
      _isIosPluginReady = false;
      _log('Failed to initialize live updates: $e');
    } finally {
      _isInitializing = false;
    }

    await _syncMonitoringStateInternal(isMonitoring: audioService.isMonitoring);
  }

  Future<void> syncMonitoringState({required bool isMonitoring}) async {
    if (!_isInitializing) {
      await (_initializationFuture ?? Future<void>.value());
    }
    await _syncMonitoringStateInternal(isMonitoring: isMonitoring);
  }

  Future<void> _syncMonitoringStateInternal(
      {required bool isMonitoring}) async {
    final liveUpdatesEnabled = await _settingsService.loadLiveUpdatesEnabled();

    if (!liveUpdatesEnabled || !isMonitoring) {
      await _disableLiveUpdates();
      return;
    }

    try {
      if (Platform.isAndroid) {
        await _startAndroidLiveUpdates();
        return;
      }
    } catch (e) {
      _log('Android platform check failed: $e');
    }

    try {
      if (Platform.isIOS) {
        await _startOrRefreshIosLiveActivity();
      }
    } catch (e) {
      _log('iOS platform check failed: $e');
    }
  }

  Future<void> _startAndroidLiveUpdates() async {
    if (_isEnabled) return;

    final status = await Permission.notification.status;
    if (!status.isGranted) {
      final result = await Permission.notification.request();
      if (!result.isGranted) {
        throw Exception('Notification permission denied');
      }
    }

    try {
      await _methodChannel.invokeMethod('startLiveUpdates');
      _setEnabledState(true);
      _log('Android live updates started');
    } catch (e) {
      _log('Failed to start Android live updates: $e');
      rethrow;
    }
  }

  Future<void> _startOrRefreshIosLiveActivity() async {
    if (!_isIosPluginReady) return;

    try {
      final snapshot = _currentSnapshot ??
          LiveActivitySnapshot(
            status: LiveActivityStatus.listening,
            startedAtMs: DateTime.now().millisecondsSinceEpoch,
          );

      _currentSnapshot = snapshot;

      await _iosMethodChannel.invokeMethod<void>(
        'createOrUpdate',
        snapshot.toActivityData(),
      );
      _setEnabledState(true);
      _log('iOS Live Activity synced');
    } catch (e) {
      _log('Failed to create/update iOS Live Activity: $e');
      await _endIosActivities(resetSnapshot: false);
    }
  }

  Future<void> _disableLiveUpdates() async {
    try {
      if (Platform.isAndroid) {
        await _stopAndroidLiveUpdates();
        return;
      }
    } catch (e) {
      _log('Android platform check failed in disable: $e');
    }

    try {
      if (Platform.isIOS) {
        await _endIosActivities();
      }
    } catch (e) {
      _log('iOS platform check failed in disable: $e');
    }
  }

  Future<void> _stopAndroidLiveUpdates() async {
    if (!_isEnabled) return;

    try {
      await _methodChannel.invokeMethod('stopLiveUpdates');
      _setEnabledState(false);
      _log('Android live updates stopped');
    } catch (e) {
      _log('Failed to stop Android live updates: $e');
      rethrow;
    }
  }

  Future<void> _endIosActivities({bool resetSnapshot = true}) async {
    if (_isIosPluginReady) {
      try {
        await _iosMethodChannel.invokeMethod<void>('endAll');
      } catch (e) {
        _log('Failed to end iOS Live Activities: $e');
      }
    }

    if (resetSnapshot) {
      _currentSnapshot = null;
      _lastProcessedEventSignature = null;
    }

    _setEnabledState(false);
  }

  Future<void> _handleAudioHistoryUpdate(List<SoundCaption> events) async {
    try {
      if (!Platform.isIOS || !(_audioService?.isMonitoring ?? false)) {
        return;
      }
    } catch (e) {
      // Platform check failed, likely on web
      return;
    }
    if (events.isEmpty) return;

    final latestEvent = events.first;
    final eventSignature = [
      latestEvent.source.name,
      latestEvent.customSoundId ?? '',
      latestEvent.sound,
      latestEvent.timestamp.millisecondsSinceEpoch,
    ].join('|');

    if (eventSignature == _lastProcessedEventSignature) {
      return;
    }

    _lastProcessedEventSignature = eventSignature;
    _currentSnapshot = (_currentSnapshot ??
            LiveActivitySnapshot(
              status: LiveActivityStatus.listening,
              startedAtMs: DateTime.now().millisecondsSinceEpoch,
            ))
        .copyWith(
      status: LiveActivityStatus.detected,
      lastDetectedIdentifier: latestEvent.sound,
      lastDetectedLabel: latestEvent.displaySound,
      lastDetectedConfidencePercent: (latestEvent.confidence * 100).round(),
      lastDetectedAtMs: latestEvent.timestamp.millisecondsSinceEpoch,
    );

    try {
      await syncMonitoringState(isMonitoring: true);
    } catch (e) {
      _log('Failed to refresh iOS Live Activity from audio event: $e');
    }
  }

  void _setEnabledState(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _statusController.add(enabled);
  }

  void dispose() {
    unawaited(_audioHistorySubscription?.cancel());
    _audioHistorySubscription = null;
    _statusController.close();
  }
}
