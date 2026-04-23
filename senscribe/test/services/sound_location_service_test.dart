import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:senscribe/models/sound_location_snapshot.dart';
import 'package:senscribe/services/sound_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoundLocationService service;

  setUp(() async {
    service = SoundLocationService();
    await service.debugReset();
  });

  tearDown(() async {
    await service.debugReset();
  });

  test('detection waits briefly for first current position fix', () async {
    final currentPosition = Completer<SoundLocationPosition>();
    service.debugSetPlatform(
      _FakeSoundLocationPlatform(
        currentPosition: currentPosition.future,
      ),
    );

    await service.start();

    final snapshotFuture = service.snapshotForDetection();
    final capturedAt = DateTime.now();
    currentPosition.complete(
      SoundLocationPosition(
        latitude: 37.4219999,
        longitude: -122.0840575,
        accuracyMeters: 12,
        timestamp: capturedAt,
      ),
    );

    final snapshot = await snapshotFuture;

    expect(snapshot.status, SoundLocationStatus.available);
    expect(snapshot.latitude, 37.4219999);
    expect(snapshot.longitude, -122.0840575);
    expect(snapshot.capturedAt, capturedAt);
  });
}

class _FakeSoundLocationPlatform implements SoundLocationPlatform {
  _FakeSoundLocationPlatform({
    required this.currentPosition,
  });

  final Future<SoundLocationPosition> currentPosition;

  @override
  Future<LocationPermission> checkPermission() async {
    return LocationPermission.whileInUse;
  }

  @override
  Future<SoundLocationPosition> getCurrentPosition() {
    return currentPosition;
  }

  @override
  Future<SoundLocationPosition?> getLastKnownPosition() async {
    return null;
  }

  @override
  Stream<SoundLocationPosition> getPositionStream() {
    return const Stream<SoundLocationPosition>.empty();
  }

  @override
  Future<bool> isLocationServiceEnabled() async {
    return true;
  }
}
