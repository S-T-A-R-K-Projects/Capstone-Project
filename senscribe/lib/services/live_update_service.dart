import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/live_activity_snapshot.dart';
import '../models/sound_caption.dart';
import '../models/sound_filter.dart';
import 'app_settings_service.dart';
import 'audio_classification_service.dart';
import 'sound_filter_service.dart';

class LiveUpdateService {
  static final LiveUpdateService _instance = LiveUpdateService._internal();
  factory LiveUpdateService() => _instance;
  LiveUpdateService._internal();

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/audio_classifier');
  static const MethodChannel _iosMethodChannel =
      MethodChannel('senscribe/ios_live_activities');
  final AppSettingsService _settingsService = AppSettingsService();
  final SoundFilterService _filterService = SoundFilterService();

  bool _isEnabled = false;
  bool get isEnabled => _isEnabled;

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  AudioClassificationService? _audioService;
  StreamSubscription<List<SoundCaption>>? _audioHistorySubscription;
  StreamSubscription<Set<SoundFilterId>>? _filterSelectionSubscription;
  Future<void>? _initializationFuture;
  LiveActivitySnapshot? _currentSnapshot;
  SoundCaption? _currentSnapshotEvent;
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
    await _filterService.initialize();
    _audioService = audioService;
    _audioHistorySubscription ??=
        audioService.historyStream.listen(_handleAudioHistoryUpdate);
    _filterSelectionSubscription ??=
        _filterService.selectionStream.listen(_handleFilterSelectionChanged);

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

    await _syncAndroidFilterConfig();
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

    if (Platform.isAndroid) {
      await _startAndroidLiveUpdates();
      return;
    }

    if (Platform.isIOS) {
      await _startOrRefreshIosLiveActivity();
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
    if (Platform.isAndroid) {
      await _stopAndroidLiveUpdates();
      return;
    }

    if (Platform.isIOS) {
      await _endIosActivities();
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
      _currentSnapshotEvent = null;
      _lastProcessedEventSignature = null;
    }

    _setEnabledState(false);
  }

  Future<void> _handleAudioHistoryUpdate(List<SoundCaption> events) async {
    if (!Platform.isIOS || !(_audioService?.isMonitoring ?? false)) {
      return;
    }
    if (events.isEmpty) {
      return;
    }

    SoundCaption? latestEvent;
    for (final event in events) {
      if (_filterService.matchesCaption(event)) {
        latestEvent = event;
        break;
      }
    }

    if (latestEvent == null) {
      return;
    }

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
    _currentSnapshotEvent = latestEvent;
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

  void _handleFilterSelectionChanged(Set<SoundFilterId> selectedFilters) {
    unawaited(_syncFilterSelectionChange(selectedFilters));
  }

  Future<void> _syncFilterSelectionChange(
    Set<SoundFilterId> selectedFilters,
  ) async {
    await _syncAndroidFilterConfig(selectedFilters: selectedFilters);

    if (!Platform.isIOS) {
      return;
    }

    final currentEvent = _currentSnapshotEvent;
    if (currentEvent == null) {
      return;
    }

    if (_filterService.matchesCaption(
      currentEvent,
      selectedFilters: selectedFilters,
    )) {
      return;
    }

    _resetSnapshotToListening();
    if (_audioService?.isMonitoring ?? false) {
      try {
        await syncMonitoringState(isMonitoring: true);
      } catch (e) {
        _log('Failed to sync iOS Live Activity after filter change: $e');
      }
    }
  }

  Future<void> _syncAndroidFilterConfig({
    Set<SoundFilterId>? selectedFilters,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _methodChannel.invokeMethod<void>(
        'setLiveUpdateFilterConfig',
        _filterService.androidLiveUpdateFilterConfig(
          selectedFilters: selectedFilters,
        ),
      );
    } catch (e) {
      _log('Failed to sync Android live update filters: $e');
    }
  }

  void _resetSnapshotToListening() {
    final startedAtMs =
        _currentSnapshot?.startedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    _currentSnapshot = LiveActivitySnapshot(
      status: LiveActivityStatus.listening,
      startedAtMs: startedAtMs,
    );
    _currentSnapshotEvent = null;
    _lastProcessedEventSignature = null;
  }

  void _setEnabledState(bool enabled) {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    _statusController.add(enabled);
  }

  void dispose() {
    unawaited(_audioHistorySubscription?.cancel());
    unawaited(_filterSelectionSubscription?.cancel());
    _audioHistorySubscription = null;
    _filterSelectionSubscription = null;
    _statusController.close();
  }
}
