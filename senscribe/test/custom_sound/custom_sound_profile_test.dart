import 'package:flutter_test/flutter_test.dart';
import 'package:senscribe/models/custom_sound_profile.dart';

void main() {
  test('requires 10 target samples and 3 background samples', () {
    final profile = CustomSoundProfile(
      id: 'profile',
      name: 'Doorbell',
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      targetSamplePaths: List<String>.generate(
        kRequiredCustomSoundSamples,
        (index) => 'target_${index + 1}.wav',
      ),
      backgroundSamplePaths: List<String>.generate(
        kRequiredBackgroundSamples,
        (index) => 'background_${index + 1}.wav',
      ),
    );

    expect(profile.needsMoreTargetSamples, isFalse);
    expect(profile.needsMoreBackgroundSamples, isFalse);
    expect(profile.hasEnoughSamples, isTrue);
  });

  test('legacy ready profile with 5/1 samples normalizes to draft', () {
    final decoded = CustomSoundProfile.decodeList(
      CustomSoundProfile.encodeList([
        CustomSoundProfile(
          id: 'legacy',
          name: 'Legacy',
          status: CustomSoundProfileStatus.ready,
          createdAt: DateTime(2026, 4, 1),
          updatedAt: DateTime(2026, 4, 1),
          targetSamplePaths: List<String>.generate(
            5,
            (index) => 'target_${index + 1}.wav',
          ),
          backgroundSamplePaths: const ['background_1.wav'],
        ),
      ]),
    ).single;

    expect(decoded.status, CustomSoundProfileStatus.draft);
    expect(decoded.hasEnoughSamples, isFalse);
    expect(decoded.needsMoreTargetSamples, isTrue);
    expect(decoded.needsMoreBackgroundSamples, isTrue);
  });

  test('serialization preserves 10/3 sample counts', () {
    final profile = CustomSoundProfile(
      id: 'ready',
      name: 'Ready',
      status: CustomSoundProfileStatus.ready,
      createdAt: DateTime(2026, 4, 1),
      updatedAt: DateTime(2026, 4, 1),
      targetSamplePaths: List<String>.generate(
        kRequiredCustomSoundSamples,
        (index) => 'target_${index + 1}.wav',
      ),
      backgroundSamplePaths: List<String>.generate(
        kRequiredBackgroundSamples,
        (index) => 'background_${index + 1}.wav',
      ),
    );

    final decoded = CustomSoundProfile.decodeList(
      CustomSoundProfile.encodeList([profile]),
    ).single;

    expect(decoded.status, CustomSoundProfileStatus.ready);
    expect(decoded.targetSampleCount, kRequiredCustomSoundSamples);
    expect(decoded.backgroundSampleCount, kRequiredBackgroundSamples);
    expect(decoded.hasEnoughSamples, isTrue);
  });
}
