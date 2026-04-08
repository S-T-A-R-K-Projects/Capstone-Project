# Android Custom Sound Recognition Implementation

This document describes the current Android custom sound recognition pipeline in `senscribe`.

## Summary

Android custom sounds are implemented as an on-device feature-bank matcher.

The current flow is:

1. Flutter creates and manages custom sound profiles.
2. Android records fixed-length WAV samples for target and background audio.
3. Training extracts hand-crafted features from overlapping windows in each recording.
4. A calibrated target bank, background bank, detection threshold, and background margin are stored per profile.
5. During live monitoring, each inference window is scored against all active custom profiles.
6. The best valid match is emitted back to Flutter as a `source: custom` result.

## Shared Flutter Layer

### UI

Primary screens:

- `lib/screens/alerts_page.dart`
- `lib/screens/custom_sound_enrollment_page.dart`

Current enrollment requirements:

- `10` target samples
- `3` background samples
- each recording lasts about `5` seconds

The enrollment page text and behavior already match this requirement:

- target clips are recorded first
- background clips are enabled only after all target clips exist
- training is enabled only when `hasEnoughSamples` is true

### Shared model

Primary model:

- `lib/models/custom_sound_profile.dart`

Key fields:

- `id`
- `name`
- `enabled`
- `status`
- `targetSamplePaths`
- `backgroundSamplePaths`
- `createdAt`
- `updatedAt`
- `lastError`

Current constants:

- `kRequiredCustomSoundSamples = 10`
- `kRequiredBackgroundSamples = 3`

### Shared service

Primary service:

- `lib/services/custom_sound_service.dart`

Android uses the shared method channel:

- `senscribe/audio_classifier`

Methods used for custom sounds:

- `loadCustomSounds`
- `captureSample`
- `trainOrRebuildCustomModel`
- `setCustomSoundEnabled`
- `deleteCustomSound`

`CustomSoundService.loadProfiles()` merges Flutter `SharedPreferences` state with native profile state so the UI stays aligned with the actual files stored on device.

## Android Native Files

Core files:

- `android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt`
- `android/app/src/main/kotlin/com/example/senscribe/CustomAudioFeatureExtractor.kt`
- `android/app/src/main/kotlin/com/example/senscribe/CustomSoundMatching.kt`
- `android/app/src/test/kotlin/com/example/senscribe/CustomSoundMatchingTest.kt`

## Native Profile Persistence

Profiles are stored in:

- `filesDir/custom_sounds/profiles.json`

Per-profile sample folders:

- `filesDir/custom_sounds/<soundId>/target/`
- `filesDir/custom_sounds/<soundId>/background/`

File names:

- target: `target_1.wav`, `target_2.wav`, ...
- background: `background_1.wav`, `background_2.wav`, ...

In addition to Flutter-visible fields, Android persists matcher-specific fields:

- `targetEmbeddingBank`
- `backgroundEmbeddingBank`
- `detectionThreshold`
- `backgroundMargin`

The profile normalization logic also downgrades stale profiles back to `draft` when:

- sample requirements are no longer met
- a profile claims `ready` but is missing saved banks or thresholds

## Sample Capture

Custom sample recording is handled in `captureSample(...)` and `beginSampleCapture(...)`.

### Recording format

- source: `MediaRecorder.AudioSource.VOICE_RECOGNITION`
- sample rate: `16_000 Hz`
- channels: mono
- encoding: PCM 16-bit
- container: WAV
- duration: `5` seconds

The plugin writes the WAV header itself and stores raw PCM16 little-endian sample data.

### Capture behavior

- only one custom recording can run at a time
- if live monitoring is active, monitoring is stopped before recording
- the profile is moved to `recording` before capture starts
- after success, the profile returns to `draft`
- any previously trained banks and thresholds are cleared after a new recording
- monitoring is resumed automatically if it had been active before capture

This invalidation step is important: changing even one recorded sample forces the profile to be retrained.

## Training Pipeline

Training is handled by `trainOrRebuildCustomModel(...)` and `trainProfile(...)`.

Android does not retrain YAMNet or generate a new TFLite model. Instead it builds a calibrated matcher for each eligible profile.

### Eligibility

A profile is eligible for training when:

- `enabled == true`
- it has at least `10` target samples
- it has at least `3` background samples

Eligible profiles are marked `training`. Ineligible profiles keep their current state, except stale `training` profiles are reset to `draft`.

### Feature extraction

For each WAV file:

1. The plugin reads the PCM samples.
2. The recording is sliced into `15_600`-sample windows.
3. Windows advance by `7_800` samples during training (`EMBEDDING_STEP_SAMPLE_COUNT`).
4. Each window is converted into a hand-crafted feature vector by `CustomAudioFeatureExtractor`.

`CustomAudioFeatureExtractor` currently includes:

- 18 log-energy spectral bands derived with Goertzel analysis
- 18 per-band variance values
- 8 envelope buckets
- RMS
- peak
- zero-crossing rate

The resulting feature vector is normalized before matching.

### Window selection

Training does not keep every window from every recording.

Target recordings:

- windows are ranked by signal strength
- the strongest windows are favored
- up to `3` windows per target recording are kept

Background recordings:

- windows are ranked separately
- up to `4` windows per background recording are kept

This reduces noisy or silent windows and makes the banks more stable.

### Calibration

`CustomSoundMatching.calibrate(...)` computes:

- a representative target bank
- a representative background bank
- a per-profile `detectionThreshold`
- a per-profile `backgroundMargin`

Important limits in `CustomSoundMatching`:

- target bank max size: `24`
- background bank max size: `18`
- detection threshold clamp: `0.64` to `0.94`
- background margin clamp: `0.005` to `0.03`

The matcher uses cosine similarity over normalized feature vectors.

### Training result

Successful training stores:

- `status = "ready"`
- refreshed sample path lists
- `targetEmbeddingBank`
- `backgroundEmbeddingBank`
- `detectionThreshold`
- `backgroundMargin`

Failed training stores:

- `status = "failed"`
- `lastError`
- matcher banks and thresholds cleared

After training completes, active matchers are reloaded and live monitoring is restarted if it was already running.

## Live Custom Detection

During live sound recognition, Android runs built-in YAMNet classification and custom matching on the same rolling microphone window.

The custom path is implemented in `processCustomEmbedding(...)`.

### Runtime checks

A custom event is only emitted when all of the following pass:

- signal RMS is high enough, or peak is high enough
- similarity against the target bank is at or above the profile threshold
- similarity beats background similarity by at least the required gap
- the best profile also beats the runner-up profile by a margin
- the same profile wins for enough consecutive windows
- the per-profile throttle window has expired

Current custom runtime constants:

- minimum signal RMS: `0.008`
- minimum signal peak: `0.024`
- minimum win margin over another custom sound: `0.03`
- minimum separation from background: max(profile margin, `0.045`)
- required consecutive matches: `2`
- throttle per custom sound: `5_000 ms`

Returned event payload:

- `type = "result"`
- `label = <profile name>`
- `confidence = <similarity score>`
- `source = "custom"`
- `timestampMs`
- `customSoundId = <profile id>`

## Tests

Current Android matcher tests live in:

- `android/app/src/test/kotlin/com/example/senscribe/CustomSoundMatchingTest.kt`

The tests cover:

- threshold calibration staying in bounds
- background probes not passing target matching
- higher-scoring custom banks winning
- stale legacy profiles being normalized back to `draft`

## Key Files To Read

- `senscribe/android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt`
- `senscribe/android/app/src/main/kotlin/com/example/senscribe/CustomAudioFeatureExtractor.kt`
- `senscribe/android/app/src/main/kotlin/com/example/senscribe/CustomSoundMatching.kt`
- `senscribe/lib/models/custom_sound_profile.dart`
- `senscribe/lib/services/custom_sound_service.dart`
- `senscribe/lib/screens/custom_sound_enrollment_page.dart`
