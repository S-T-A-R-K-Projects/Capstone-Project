import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm_model.dart';
import '../models/model_download_snapshot.dart';
import 'leap_service.dart';

class ModelDownloadService {
  ModelDownloadService._internal();

  static final ModelDownloadService _instance =
      ModelDownloadService._internal();
  factory ModelDownloadService() => _instance;

  static const MethodChannel _methodChannel =
      MethodChannel('senscribe/model_downloads');
  static const EventChannel _eventChannel =
      EventChannel('senscribe/model_download_events');
  static const MethodChannel _iosRuntimeChannel =
      MethodChannel('senscribe/ios_runtime');
  static const String _prefsKey = 'model_download_snapshot_v1';

  final LeapService _leapService = LeapService();
  final StreamController<ModelDownloadSnapshot> _controller =
      StreamController<ModelDownloadSnapshot>.broadcast();

  Stream<ModelDownloadSnapshot> get stream => _controller.stream;

  ModelDownloadSnapshot _current = ModelDownloadSnapshot.idle();
  ModelDownloadSnapshot get current => _current;

  StreamSubscription<dynamic>? _androidEventSubscription;
  Future<void>? _restoreFuture;
  Future<void>? _activeIosDownload;
  int _lastPersistedAtMs = 0;
  double _lastPersistedProgress = 0.0;

  Future<void> _ensureInitialized() async {
    _restoreFuture ??= _restorePersistedSnapshot();
    await _restoreFuture;
    try {
      if (Platform.isAndroid && _androidEventSubscription == null) {
        _androidEventSubscription = _eventChannel.receiveBroadcastStream().listen(
              _handleAndroidEvent,
              onError: (_) {},
            );
      }
    } catch (e) {
      // Platform check failed, likely on web
    }
  }

  Future<ModelDownloadSnapshot> refreshSnapshot(LLMModel model) async {
    await _ensureInitialized();

    try {
      if (Platform.isAndroid) {
        try {
          final status = await _methodChannel.invokeMapMethod<Object?, Object?>(
            'getStatus',
          );
          if (status != null) {
            _applySnapshot(ModelDownloadSnapshot.fromMap(status));
          }
        } catch (_) {
          // Keep the last-known snapshot when the native side is unavailable.
        }
      }
    } catch (e) {
      // Platform check failed, likely on web
    }

    final isConfigured = await _leapService.isModelCached(model.name);
    if (isConfigured) {
      _applySnapshot(
        _current.copyWith(
          modelId: model.name,
          isRunning: false,
          progress: 1.0,
          statusMessage: 'Model downloaded.',
          platformCanContinueInBackground: false,
          clearLastError: true,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } else {
      try {
        if (Platform.isIOS &&
            _current.isRunning &&
            _current.modelId == model.name &&
            _activeIosDownload == null) {
          _applySnapshot(
            _current.copyWith(
              modelId: model.name,
              isRunning: false,
              statusMessage:
                  'Download needs to be resumed. Stay on this screen for the most stable transfer.',
              platformCanContinueInBackground: false,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
      } catch (e) {
        // Platform check failed, likely on web
      }
    } else if (!_current.isRunning && _current.modelId == model.name) {
      _applySnapshot(
        _current.copyWith(
          modelId: model.name,
          progress: 0.0,
          statusMessage: _current.hasError ? _current.statusMessage : '',
          platformCanContinueInBackground: false,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    return _current;
  }

  Future<void> startDownload(LLMModel model) async {
    await _ensureInitialized();
    if (_current.isRunning) return;

    final startedAtMs = DateTime.now().millisecondsSinceEpoch;
    bool canContinueInBackground = false;
    try {
      canContinueInBackground = Platform.isAndroid;
    } catch (e) {
      // Platform check failed, likely on web
    }
    _applySnapshot(
      ModelDownloadSnapshot(
        modelId: model.name,
        isRunning: true,
        progress: 0.0,
        statusMessage: 'Initializing download...',
        platformCanContinueInBackground: canContinueInBackground,
        updatedAtMs: startedAtMs,
      ),
    );

    try {
      if (Platform.isAndroid) {
        try {
          await _methodChannel.invokeMethod<void>('startDownload', {
            'modelId': model.name,
            'modelSlug': model.modelSlug,
            'quantizationSlug': model.quantizationSlug,
            'displayName': model.displayName,
            'estimatedSizeMB': model.estimatedSizeMB,
          });
        } catch (error) {
          _applySnapshot(
            _current.copyWith(
              modelId: model.name,
              isRunning: false,
              statusMessage: 'Download failed to start.',
              platformCanContinueInBackground: false,
              lastError: '$error',
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
          rethrow;
        }
        return;
      }
    } catch (e) {
      // Platform check failed, likely on web
    }

    _activeIosDownload ??= _runIosDownload(model);
  }

  Future<void> cancelIfSupported() async {
    await _ensureInitialized();
    if (!_current.isRunning) return;
    final modelId = _current.modelId;
    if (Platform.isAndroid) {
      await _methodChannel.invokeMethod<void>('cancelDownload');
      return;
    }

    if (Platform.isIOS) {
      await _leapService.cancelModelDownload();
      final activeDownload = _activeIosDownload;
      if (activeDownload != null) {
        await activeDownload.catchError((_) {});
      }
      if (modelId.isNotEmpty) {
        await _deleteModelArtifacts(modelId);
      }
      await clearSnapshot(modelId: modelId);
    }
  }

  Future<void> clearSnapshot({String? modelId}) async {
    await _ensureInitialized();
    final nextModelId = modelId ?? _current.modelId;
    _applySnapshot(ModelDownloadSnapshot.idle(modelId: nextModelId));
  }

  Future<void> dispose() async {
    await _androidEventSubscription?.cancel();
    await _controller.close();
  }

  Future<void> _runIosDownload(LLMModel model) async {
    int? backgroundTaskId;
    try {
      final rawTaskId =
          await _iosRuntimeChannel.invokeMethod<int>('beginBackgroundTask', {
        'name': 'model_download_${model.name}',
      });
      backgroundTaskId = rawTaskId;
    } catch (_) {
      backgroundTaskId = null;
    }

    try {
      await _leapService.downloadModel(
        model.name,
        onProgress: (progress) {
          final percentage = (progress * 100).toStringAsFixed(1);
          _applySnapshot(
            _current.copyWith(
              modelId: model.name,
              isRunning: true,
              progress: progress,
              statusMessage: 'Downloading... $percentage%',
              platformCanContinueInBackground: false,
              clearLastError: true,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        },
        onStatus: (status) {
          _applySnapshot(
            _current.copyWith(
              modelId: model.name,
              isRunning: true,
              statusMessage: status,
              platformCanContinueInBackground: false,
              clearLastError: true,
              updatedAtMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        },
      );

      _applySnapshot(
        _current.copyWith(
          modelId: model.name,
          isRunning: false,
          progress: 1.0,
          statusMessage: 'Download complete.',
          platformCanContinueInBackground: false,
          clearLastError: true,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      if (_isCancelledDownloadError(error)) {
        _applySnapshot(
          _current.copyWith(
            modelId: model.name,
            isRunning: false,
            progress: 0.0,
            statusMessage: 'Download cancelled.',
            platformCanContinueInBackground: false,
            clearLastError: true,
            updatedAtMs: DateTime.now().millisecondsSinceEpoch,
          ),
        );
        return;
      }

      _applySnapshot(
        _current.copyWith(
          modelId: model.name,
          isRunning: false,
          statusMessage: 'Download failed.',
          platformCanContinueInBackground: false,
          lastError: '$error',
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } finally {
      if (backgroundTaskId != null) {
        try {
          await _iosRuntimeChannel.invokeMethod<void>('endBackgroundTask', {
            'taskId': backgroundTaskId,
          });
        } catch (_) {
          // Ignore cleanup failures.
        }
      }
      _activeIosDownload = null;
    }
  }

  bool _isCancelledDownloadError(Object error) {
    return error.toString().toLowerCase().contains('cancelled');
  }

  Future<void> _deleteModelArtifacts(String modelId) async {
    try {
      await _leapService.deleteModel(modelId);
    } catch (_) {
      // Ignore cleanup failures so cancel still succeeds even if no manifest exists.
    }
  }

  void _handleAndroidEvent(dynamic event) {
    if (event is! Map) return;
    final snapshot = ModelDownloadSnapshot.fromMap(
      Map<Object?, Object?>.from(event),
    );
    _applySnapshot(snapshot);
  }

  void _applySnapshot(ModelDownloadSnapshot snapshot) {
    final previous = _current;
    _current = snapshot;
    if (_shouldPersistSnapshot(previous, snapshot)) {
      _lastPersistedAtMs = DateTime.now().millisecondsSinceEpoch;
      _lastPersistedProgress = snapshot.progress;
      unawaited(_persistSnapshot(snapshot));
    }
    _controller.add(snapshot);
  }

  Future<void> _restorePersistedSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    final rawSnapshot = prefs.getString(_prefsKey);
    if (rawSnapshot == null || rawSnapshot.isEmpty) return;
    try {
      final decoded = jsonDecode(rawSnapshot);
      if (decoded is Map<String, dynamic>) {
        _current = ModelDownloadSnapshot.fromMap(
          Map<Object?, Object?>.from(decoded),
        );
      }
    } catch (_) {
      _current = ModelDownloadSnapshot.idle();
    }
  }

  Future<void> _persistSnapshot(ModelDownloadSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(snapshot.toMap()));
  }

  bool _shouldPersistSnapshot(
    ModelDownloadSnapshot previous,
    ModelDownloadSnapshot next,
  ) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (previous.modelId != next.modelId) return true;
    if (previous.isRunning != next.isRunning) return true;
    if (previous.lastError != next.lastError) return true;
    if (!next.isRunning) return true;
    if (next.statusMessage != previous.statusMessage &&
        nowMs - _lastPersistedAtMs >= 500) {
      return true;
    }
    if (nowMs - _lastPersistedAtMs < 1500) return false;
    return (next.progress - _lastPersistedProgress).abs() >= 0.02;
  }
}
