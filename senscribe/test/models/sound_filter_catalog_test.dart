import 'package:flutter_test/flutter_test.dart';
import 'package:senscribe/models/sound_filter.dart';
import 'package:senscribe/utils/sound_filter_catalog.dart';

void main() {
  test('android speech label resolves to People & Speech', () {
    final filters = SoundFilterCatalog.filtersForBuiltInLabel(
      'Speech',
      isAndroid: true,
    );

    expect(filters, isNotNull);
    expect(filters, contains(SoundFilterId.peopleSpeech));
  });

  test('ios ambulance siren overlaps vehicles and impacts', () {
    final filters = SoundFilterCatalog.filtersForBuiltInLabel(
      'ambulance_siren',
      isAndroid: false,
    );

    expect(filters, isNotNull);
    expect(filters, contains(SoundFilterId.vehiclesTransport));
    expect(filters, contains(SoundFilterId.impactsToolsAlarms));
  });

  test('ios choir singing overlaps people and music', () {
    final filters = SoundFilterCatalog.filtersForBuiltInLabel(
      'choir_singing',
      isAndroid: false,
    );

    expect(filters, isNotNull);
    expect(filters, contains(SoundFilterId.peopleSpeech));
    expect(filters, contains(SoundFilterId.musicPerformance));
  });
}
