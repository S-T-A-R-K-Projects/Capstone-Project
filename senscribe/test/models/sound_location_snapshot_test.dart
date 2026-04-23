import 'package:flutter_test/flutter_test.dart';
import 'package:senscribe/models/sound_location_snapshot.dart';
import 'package:senscribe/utils/sound_location_formatter.dart';

void main() {
  test('available location snapshots encode and decode coordinates', () {
    final capturedAt = DateTime(2026, 4, 22, 10, 30);
    final snapshot = SoundLocationSnapshot.available(
      latitude: 37.4219999,
      longitude: -122.0840575,
      accuracyMeters: 11.6,
      capturedAt: capturedAt,
    );

    final decoded = SoundLocationSnapshot.fromJson(snapshot.toJson());

    expect(decoded.status, SoundLocationStatus.available);
    expect(decoded.latitude, 37.4219999);
    expect(decoded.longitude, -122.0840575);
    expect(decoded.accuracyMeters, 11.6);
    expect(decoded.capturedAt, capturedAt);
    expect(decoded.hasCoordinates, isTrue);
  });

  test('missing metadata decodes as not recorded for old alerts', () {
    final decoded = SoundLocationSnapshot.fromMetadata(
      const <String, dynamic>{'confidencePercent': 91},
    );

    expect(decoded.status, SoundLocationStatus.notRecorded);
    expect(
        SoundLocationFormatter.detailsText(decoded), 'Location not recorded');
  });

  test('invalid available coordinates decode as unavailable', () {
    final decoded = SoundLocationSnapshot.fromJson(
      const <String, dynamic>{'status': 'available'},
    );

    expect(decoded.status, SoundLocationStatus.unavailable);
    expect(decoded.hasCoordinates, isFalse);
  });

  test('formatter shows offline coordinates and accuracy', () {
    final text = SoundLocationFormatter.detailsText(
      SoundLocationSnapshot.available(
        latitude: 37.4219999,
        longitude: -122.0840575,
        accuracyMeters: 11.6,
        capturedAt: DateTime(2026, 4, 22, 10, 30),
      ),
    );

    expect(text, contains('Location: 37.422000, -122.084058'));
    expect(text, contains('Accuracy: +/- 12 m'));
    expect(text, contains('Location captured:'));
  });
}
