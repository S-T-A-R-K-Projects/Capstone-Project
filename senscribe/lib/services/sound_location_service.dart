import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../models/sound_location_snapshot.dart';

abstract class SoundLocationSnapshotProvider {
  Future<void> start();
  Future<void> stop();
  Stream<SoundLocationSnapshot> get locationUpdates;
  Future<SoundLocationSnapshot> snapshotForDetection();
}

abstract class SoundLocationPlatform {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<SoundLocationPosition?> getLastKnownPosition();
  Future<SoundLocationPosition> getCurrentPosition();
  Stream<SoundLocationPosition> getPositionStream();
}

class SoundLocationPosition {
  const SoundLocationPosition({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final DateTime timestamp;
}

class GeolocatorSoundLocationPlatform implements SoundLocationPlatform {
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    timeLimit: Duration(seconds: 12),
  );

  static final AndroidSettings _androidLocationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    intervalDuration: const Duration(seconds: 2),
    timeLimit: const Duration(seconds: 12),
  );

  static final AndroidSettings _androidLocationManagerSettings =
      AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 0,
    intervalDuration: const Duration(seconds: 2),
    timeLimit: const Duration(seconds: 12),
    forceLocationManager: true,
  );

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<SoundLocationPosition?> getLastKnownPosition() async {
    final position = await Geolocator.getLastKnownPosition();
    if (position != null) {
      return _fromGeolocatorPosition(position);
    }

    if (!Platform.isAndroid) return null;

    final fallbackPosition = await Geolocator.getLastKnownPosition(
      forceAndroidLocationManager: true,
    );
    return fallbackPosition == null
        ? null
        : _fromGeolocatorPosition(fallbackPosition);
  }

  @override
  Future<SoundLocationPosition> getCurrentPosition() async {
    if (!Platform.isAndroid) {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _locationSettings,
      );
      return _fromGeolocatorPosition(position, timestamp: DateTime.now());
    }

    final position = await _firstSuccessfulPosition(
      Geolocator.getCurrentPosition(
        locationSettings: _androidLocationSettings,
      ),
      Geolocator.getCurrentPosition(
        locationSettings: _androidLocationManagerSettings,
      ),
    );
    return _fromGeolocatorPosition(position, timestamp: DateTime.now());
  }

  @override
  Stream<SoundLocationPosition> getPositionStream() {
    final settings =
        Platform.isAndroid ? _androidLocationSettings : _locationSettings;
    return Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => _fromGeolocatorPosition(
        position,
        timestamp: DateTime.now(),
      ),
    );
  }

  Future<Position> _firstSuccessfulPosition(
    Future<Position> primary,
    Future<Position> fallback,
  ) async {
    final completer = Completer<Position>();
    final errors = <Object>[];

    void handleSuccess(Position position) {
      if (!completer.isCompleted) {
        completer.complete(position);
      }
    }

    void handleError(Object error) {
      errors.add(error);
      if (errors.length == 2 && !completer.isCompleted) {
        completer.completeError(errors.first);
      }
    }

    unawaited(
      primary.then<void>(
        handleSuccess,
        onError: (Object error) => handleError(error),
      ),
    );
    unawaited(
      fallback.then<void>(
        handleSuccess,
        onError: (Object error) => handleError(error),
      ),
    );

    return completer.future;
  }

  SoundLocationPosition _fromGeolocatorPosition(
    Position position, {
    DateTime? timestamp,
  }) {
    return SoundLocationPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      timestamp: timestamp ?? position.timestamp,
    );
  }
}

class SoundLocationService
    with WidgetsBindingObserver
    implements SoundLocationSnapshotProvider {
  static final SoundLocationService _instance =
      SoundLocationService._internal();

  factory SoundLocationService() => _instance;

  SoundLocationService._internal({
    SoundLocationPlatform? platform,
  }) : _platform = platform ?? GeolocatorSoundLocationPlatform();

  static const Duration _maxCachedLocationAge = Duration(minutes: 2);
  static const Duration _initialFixWaitTimeout = Duration(seconds: 5);

  SoundLocationPlatform _platform;
  StreamSubscription<SoundLocationPosition>? _positionSubscription;
  Future<void>? _currentPositionRefresh;
  final StreamController<SoundLocationSnapshot> _locationUpdateController =
      StreamController<SoundLocationSnapshot>.broadcast();
  SoundLocationSnapshot _latestSnapshot =
      const SoundLocationSnapshot.notRecorded();
  bool _isMonitoring = false;
  bool _observerRegistered = false;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  bool get _canListenForLocation =>
      _isMonitoring && _lifecycleState == AppLifecycleState.resumed;

  @override
  Stream<SoundLocationSnapshot> get locationUpdates =>
      _locationUpdateController.stream;

  @override
  Future<void> start() async {
    _isMonitoring = true;
    _registerLifecycleObserver();
    await _refreshAvailabilityAndListen();
  }

  @override
  Future<void> stop() async {
    _isMonitoring = false;
    await _stopListening();
    _unregisterLifecycleObserver();
  }

  @override
  Future<SoundLocationSnapshot> snapshotForDetection() async {
    final snapshot = _latestSnapshot;
    if (_isFreshAvailable(snapshot)) {
      return snapshot;
    }

    if (snapshot.status == SoundLocationStatus.permissionDenied ||
        snapshot.status == SoundLocationStatus.servicesDisabled ||
        !_canListenForLocation) {
      return snapshot;
    }

    try {
      final refresh =
          _currentPositionRefresh ?? _refreshCurrentPositionForDetection();
      await refresh.timeout(_initialFixWaitTimeout);
    } catch (_) {
      // Keep the feed responsive if Android has not produced an initial fix yet.
    }

    final refreshedSnapshot = _latestSnapshot;
    if (_isFreshAvailable(refreshedSnapshot)) {
      return refreshedSnapshot;
    }

    if (refreshedSnapshot.status == SoundLocationStatus.permissionDenied ||
        refreshedSnapshot.status == SoundLocationStatus.servicesDisabled) {
      return refreshedSnapshot;
    }

    return const SoundLocationSnapshot.unavailable();
  }

  bool _isFreshAvailable(SoundLocationSnapshot snapshot) {
    if (snapshot.status != SoundLocationStatus.available) {
      return false;
    }

    final capturedAt = snapshot.capturedAt;
    return capturedAt != null &&
        DateTime.now().difference(capturedAt) <= _maxCachedLocationAge;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (!_isMonitoring) return;

    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshAvailabilityAndListen());
    } else {
      unawaited(_stopListening());
    }
  }

  Future<void> _refreshAvailabilityAndListen() async {
    try {
      final serviceEnabled = await _platform.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _latestSnapshot = const SoundLocationSnapshot.servicesDisabled();
        await _stopListening();
        return;
      }

      final permission = await _platform.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        _latestSnapshot = const SoundLocationSnapshot.permissionDenied();
        await _stopListening();
        return;
      }

      final lastKnown = await _platform.getLastKnownPosition();
      if (lastKnown != null) {
        _latestSnapshot = _snapshotFromPosition(lastKnown);
      } else if (_latestSnapshot.status != SoundLocationStatus.available) {
        _latestSnapshot = const SoundLocationSnapshot.unavailable();
      }

      if (!_canListenForLocation) return;

      await _startListening();
      _currentPositionRefresh = _refreshCurrentPositionForDetection();
      unawaited(_currentPositionRefresh);
    } catch (_) {
      _latestSnapshot = const SoundLocationSnapshot.unavailable();
      await _stopListening();
    }
  }

  Future<void> _refreshCurrentPositionForDetection() {
    final existingRefresh = _currentPositionRefresh;
    if (existingRefresh != null) {
      return existingRefresh;
    }

    final refresh = _refreshCurrentPosition();
    _currentPositionRefresh = refresh;
    unawaited(
      refresh.whenComplete(() {
        if (identical(_currentPositionRefresh, refresh)) {
          _currentPositionRefresh = null;
        }
      }),
    );
    return refresh;
  }

  Future<void> _refreshCurrentPosition() async {
    try {
      final position = await _platform.getCurrentPosition();
      _setLatestSnapshot(_snapshotFromPosition(position));
    } catch (_) {
      if (_latestSnapshot.status != SoundLocationStatus.available) {
        _latestSnapshot = const SoundLocationSnapshot.unavailable();
      }
    }
  }

  Future<void> _startListening() async {
    if (_positionSubscription != null) return;
    _positionSubscription = _platform.getPositionStream().listen(
      (position) {
        _setLatestSnapshot(_snapshotFromPosition(position));
      },
      onError: (_) {
        if (_latestSnapshot.status != SoundLocationStatus.available) {
          _latestSnapshot = const SoundLocationSnapshot.unavailable();
        }
      },
    );
  }

  Future<void> _stopListening() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  SoundLocationSnapshot _snapshotFromPosition(SoundLocationPosition position) {
    return SoundLocationSnapshot.available(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracyMeters,
      capturedAt: position.timestamp,
    );
  }

  void _setLatestSnapshot(SoundLocationSnapshot snapshot) {
    _latestSnapshot = snapshot;
    if (snapshot.status == SoundLocationStatus.available) {
      _locationUpdateController.add(snapshot);
    }
  }

  void _registerLifecycleObserver() {
    if (_observerRegistered) return;
    WidgetsBinding.instance.addObserver(this);
    _observerRegistered = true;
  }

  void _unregisterLifecycleObserver() {
    if (!_observerRegistered) return;
    WidgetsBinding.instance.removeObserver(this);
    _observerRegistered = false;
  }

  @visibleForTesting
  void debugSetPlatform(SoundLocationPlatform platform) {
    _platform = platform;
    _latestSnapshot = const SoundLocationSnapshot.notRecorded();
  }

  @visibleForTesting
  Future<void> debugReset() async {
    _latestSnapshot = const SoundLocationSnapshot.notRecorded();
    await stop();
  }
}
