import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:senscribe/models/sound_filter.dart';
import 'package:senscribe/services/audio_classification_service.dart';
import 'package:senscribe/services/sound_filter_service.dart';

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
  });

  test('excluded detections are not added to history', () async {
    await filterService.initialize();

    audioService.debugHandleNativeResult(<String, dynamic>{
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

    audioService.debugHandleNativeResult(<String, dynamic>{
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

    audioService.debugHandleNativeResult(<String, dynamic>{
      'label': 'Humming',
      'confidence': 0.95,
      'source': 'builtIn',
      'timestampMs': DateTime(2026, 4, 12, 12).millisecondsSinceEpoch,
    });

    expect(audioService.history, isEmpty);
  });
}
