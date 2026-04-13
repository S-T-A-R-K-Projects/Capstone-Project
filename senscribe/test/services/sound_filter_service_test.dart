import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/sound_caption.dart';
import 'package:senscribe/models/sound_filter.dart';
import 'package:senscribe/services/sound_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoundFilterService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    service = SoundFilterService();
    await service.debugReset(selectedFilters: SoundFilterId.defaultSelection);
  });

  test('custom sounds only match the Custom Sounds filter', () async {
    final caption = SoundCaption(
      sound: 'Doorbell',
      timestamp: DateTime(2026, 4, 12, 9),
      isCritical: false,
      confidence: 0.93,
      source: SoundCaptionSource.custom,
      customSoundId: 'doorbell',
    );

    expect(
      service.matchesCaption(
        caption,
        selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
      ),
      isFalse,
    );
    expect(
      service.matchesCaption(
        caption,
        selectedFilters: <SoundFilterId>{SoundFilterId.customSounds},
      ),
      isTrue,
    );
  });

  test('allows deselecting the last remaining filter', () async {
    await service.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await service.initialize();

    final result = await service.setFilterSelected(
      SoundFilterId.peopleSpeech,
      false,
    );

    expect(result, SoundFilterSelectionResult.updated);
    expect(service.selectedFilters, isEmpty);
  });

  test('selected filters persist across service reinitialization', () async {
    await service.debugReset(
      selectedFilters: <SoundFilterId>{
        SoundFilterId.animals,
        SoundFilterId.customSounds,
      },
    );
    await service.initialize();

    await service.debugReset();
    await service.initialize();

    expect(
      service.selectedFilters,
      <SoundFilterId>{
        SoundFilterId.animals,
        SoundFilterId.customSounds,
      },
    );
  });

  test('disabled labels are persisted per filter', () async {
    await service.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await service.initialize();

    await service.setBuiltInLabelEnabledForFilter(
      SoundFilterId.peopleSpeech,
      'Speech',
      false,
      isAndroid: true,
    );

    await service.debugReset();
    await service.initialize();

    expect(
      service.isBuiltInLabelEnabledForFilter(
        SoundFilterId.peopleSpeech,
        'Speech',
        isAndroid: true,
      ),
      isFalse,
    );
  });

  test('all toggle clears and restores the full filter set', () async {
    await service.initialize();

    await service.selectAllFilters();
    expect(service.selectedFilters, isEmpty);

    await service.selectAllFilters();
    expect(service.selectedFilters, SoundFilterId.defaultSelection);
  });

  test('normalized labels resolve to the disabled built-in label', () async {
    await service.debugReset(
      selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
    );
    await service.initialize();

    await service.setBuiltInLabelEnabledForFilter(
      SoundFilterId.peopleSpeech,
      'Finger snapping',
      false,
      isAndroid: true,
    );

    expect(
      service.matchesBuiltInLabel(
        'finger_snapping',
        isAndroid: true,
        selectedFilters: <SoundFilterId>{SoundFilterId.peopleSpeech},
      ),
      isFalse,
    );
  });
}
