import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/sound_filter.dart';
import 'package:senscribe/models/sound_location_snapshot.dart';
import 'package:senscribe/services/audio_classification_service.dart';
import 'package:senscribe/services/sound_filter_service.dart';
import 'package:senscribe/services/sound_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioClassificationService audioService;
  late SoundFilterService filterService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    audioService = AudioClassificationService();
    filterService = SoundFilterService();
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.animals},
    );
    audioService.debugReplaceHistory(const []);
    audioService.debugSetLocationProvider(
      const _FakeLocationProvider(SoundLocationSnapshot.unavailable()),
    );
  });

  test('excluded detections are not added to history', () async {
    await filterService.initialize();

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(audioService.history, isEmpty);

    await filterService.setFilterSelected(SoundFilterId.peopleSpeech, true);

    expect(audioService.history, isEmpty);
  });

  test('disabled labels are excluded at ingest time', () async {
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await filterService.initialize();
    await filterService.setBuiltInLabelEnabledForFilter(
      SoundFilterId.peopleSpeech,
      'Speech',
      false,
      isAndroid: true,
    );

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(audioService.history, isEmpty);
  });

  test('overlapping labels stay excluded after being disabled', () async {
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{
        SoundFilterId.peopleSpeech,
        SoundFilterId.musicPerformance,
      },
    );
    await filterService.initialize();
    await filterService.setBuiltInLabelEnabledForFilter(
      SoundFilterId.peopleSpeech,
      'Humming',
      false,
      isAndroid: true,
    );

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Humming',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(audioService.history, isEmpty);
  });

  test('granted location snapshot is attached to ingested sound', () async {
    final capturedAt = DateTime(2026, 4, 22, 10, 30);
    audioService.debugSetLocationProvider(
      _FakeLocationProvider(
        SoundLocationSnapshot.available(
          latitude: 37.4219999,
          longitude: -122.0840575,
          accuracyMeters: 12,
          capturedAt: capturedAt,
        ),
      ),
    );
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await filterService.initialize();

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    final location = audioService.history.single.location!;
    expect(location.status, SoundLocationStatus.available);
    expect(location.latitude, 37.4219999);
    expect(location.longitude, -122.0840575);
    expect(location.capturedAt, capturedAt);
  });

  test('denied location snapshot is attached to ingested sound', () async {
    audioService.debugSetLocationProvider(
      const _FakeLocationProvider(SoundLocationSnapshot.permissionDenied()),
    );
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await filterService.initialize();

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(
      audioService.history.single.location!.status,
      SoundLocationStatus.permissionDenied,
    );
  });

  test('disabled services location snapshot is attached to ingested sound',
      () async {
    audioService.debugSetLocationProvider(
      const _FakeLocationProvider(SoundLocationSnapshot.servicesDisabled()),
    );
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await filterService.initialize();

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(
      audioService.history.single.location!.status,
      SoundLocationStatus.servicesDisabled,
    );
  });

  test('delayed available location updates recent unavailable sound', () async {
    final locationUpdates = StreamController<SoundLocationSnapshot>.broadcast();
    audioService.debugSetLocationProvider(
      _FakeLocationProvider(
        const SoundLocationSnapshot.unavailable(),
        locationUpdates: locationUpdates.stream,
      ),
    );
    await filterService.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await filterService.initialize();

    await audioService.debugHandleNativeResultAsync(<String, dynamic>{
      'label': 'Speech',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
    });

    expect(
      audioService.history.single.location!.status,
      SoundLocationStatus.unavailable,
    );

    final resolvedLocation = SoundLocationSnapshot.available(
      latitude: 37.4219999,
      longitude: -122.0840575,
      accuracyMeters: 12,
      capturedAt: DateTime.now(),
    );
    locationUpdates.add(resolvedLocation);
    await Future<void>.delayed(Duration.zero);

    final location = audioService.history.single.location!;
    expect(location.status, SoundLocationStatus.available);
    expect(location.latitude, 37.4219999);
    expect(location.longitude, -122.0840575);

    await locationUpdates.close();
  });
}

class _FakeLocationProvider implements SoundLocationSnapshotProvider {
  const _FakeLocationProvider(
    this.snapshot, {
    this.locationUpdates = const Stream<SoundLocationSnapshot>.empty(),
  });

  final SoundLocationSnapshot snapshot;

  @override
  final Stream<SoundLocationSnapshot> locationUpdates;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<SoundLocationSnapshot> snapshotForDetection() async => snapshot;
}
