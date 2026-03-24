# iOS Custom Sound Recognition Implementation

This document describes how custom sound recognition is currently implemented on iOS in `senscribe`.

## Scope

- Platform: iOS only for custom sound enrollment, training, and custom-model inference
- Flutter UI: shared Flutter screens using `adaptive_platform_ui`
- Android: custom sound training is not implemented in the current codebase

## High-Level Flow

The iOS custom sound feature is split into four parts:

1. Flutter UI on the Alerts page lets the user create and manage custom sounds.
2. Flutter service code persists profile metadata and forwards capture/train requests to iOS.
3. Native iOS code records audio samples, stores them on disk, and trains a local Core ML sound classifier.
4. During live sound recognition, iOS runs Apple’s built-in classifier and the trained custom classifier at the same time on the same microphone stream.

## Flutter UI

Current UI entry point:

- `lib/screens/alerts_page.dart`

Current user flow:

1. The user opens `Alerts` -> `Trigger Words`.
2. The user taps `Add Custom Sound`.
3. A draft profile is created with a name.
4. A bottom sheet opens for that profile.
5. The user records 5 target samples.
6. The user records 1 background calibration sample.
7. The user taps `Train Custom Model`.

The sheet tracks progress with:

- `Samples x/5`
- `Background Ready` / `Background Needed`
- status labels such as `Needs samples`, `Needs background`, `Ready to train`, `Training`, and `Ready`

Important behavior in the current implementation:

- Each target sample is recorded separately.
- The background sample is recorded separately and stored independently from the 5 target samples.
- Reopening a saved custom sound lets the user re-record only the background calibration and retrain without replacing the 5 target samples.
- Training is only enabled after all 5 target samples and 1 background sample are present.

## Flutter Data Model

Primary model:

- `lib/models/custom_sound_profile.dart`

`CustomSoundProfile` stores:

- `id`
- `name`
- `enabled`
- `status`
- `targetSamplePaths`
- `backgroundSamplePaths`
- `createdAt`
- `updatedAt`
- `lastError`

Current sample requirements are defined in the model:

- `kRequiredCustomSoundSamples = 5`
- `kRequiredBackgroundSamples = 1`

`hasEnoughSamples` is true only when:

- there are at least 5 target samples
- there is at least 1 background sample

## Flutter Service Layer

Primary service:

- `lib/services/custom_sound_service.dart`

Responsibilities:

- create draft custom sound profiles
- persist profile metadata in `SharedPreferences`
- merge Flutter-side metadata with native iOS profile state
- trigger native sample capture through a method channel
- trigger native model training/rebuild
- enable, disable, delete, refresh, and discard draft profiles

Method channel used:

- `senscribe/audio_classifier`

Important service methods:

- `createDraftProfile`
- `captureTargetSample`
- `captureBackgroundSample`
- `trainOrRebuildModel`
- `setEnabled`
- `deleteProfile`
- `loadProfiles`

## Native iOS Implementation

Primary native file:

- `ios/Runner/AudioClassificationPlugin.swift`

The plugin handles both:

- built-in Apple sound recognition for live monitoring
- custom sound enrollment and training for user-created sounds

Frameworks used:

- `AVFoundation` for microphone access and recording
- `SoundAnalysis` for live classification
- `CoreML` for loading the trained model
- `CreateML` for local sound classifier training when available

`CreateML` is conditionally imported:

```swift
#if canImport(CreateML)
import CreateML
#endif
```

This matters because Apple does not provide `CreateML` in the iOS simulator SDK. As a result:

- the app can compile for simulator
- actual custom model training must run on a physical iPhone

## Sample Recording

Native recording is handled by `captureSample(...)`.

Current recording details:

- format: linear PCM
- sample rate: `44_100`
- channels: `1`
- bit depth: `16`
- file type: `.caf`
- fixed duration: `5.0` seconds

Files are stored per profile under app support storage. The plugin creates separate folders for:

- target samples
- background samples

Naming pattern:

- target: `target_1.caf`, `target_2.caf`, ...
- background: `background_1.caf`

After recording finishes, the plugin reloads sample file paths from disk and updates the saved profile.

## Profile Persistence on iOS

The native plugin stores profile metadata in:

- `custom_sounds/profiles.json`

This lives inside the app support directory.

The plugin also stores:

- recorded sample files
- generated `.mlmodel`
- compiled `.mlmodelc`

The Flutter layer also stores profile metadata in `SharedPreferences`. On iOS, `CustomSoundService.loadProfiles()` merges Flutter-persisted data with native profile data so the UI stays in sync with the files that actually exist on disk.

## Training Pipeline

Training is triggered from Flutter by calling:

- `trainOrRebuildCustomModel`

On iOS, the plugin:

1. Loads all saved profiles.
2. Filters to profiles that are enabled and have enough samples.
3. Marks eligible profiles as `training`.
4. Builds a training dataset from the profile audio files.
5. Trains one aggregate `MLSoundClassifier`.
6. Writes the `.mlmodel`.
7. Compiles it to `.mlmodelc`.
8. Marks eligible profiles as `ready` on success or `failed` on error.

Training data is built as:

- one label per custom sound, using that profile’s 5 target samples
- one shared background label, using all background calibration samples from eligible profiles

Internal background label:

- `__background__`

This means the current custom model is a single shared model for all enabled custom sounds, not one model per sound.

## Live Detection

Live monitoring is also managed by `AudioClassificationPlugin`.

When sound recognition starts:

1. The plugin configures the audio session.
2. It creates an `SNAudioStreamAnalyzer`.
3. It attaches Apple’s built-in classifier request.
4. If a trained custom model exists, it also attaches a custom classifier request built from the compiled model.
5. Both classifiers receive the same microphone input stream.

Built-in classifier:

- Apple `SNClassifySoundRequest(classifierIdentifier: .version1)`

Custom classifier:

- `SNClassifySoundRequest(mlModel: model)`

The plugin emits result events back to Flutter with:

- `label`
- `confidence`
- `source`
- `timestampMs`
- optional `customSoundId`

`source` is:

- `builtIn`
- `custom`

## Custom Detection Guards

To reduce false positives, the custom detection path applies stricter gating than the built-in path.

Current custom guard values in native code:

- confidence threshold: `0.94`
- throttle interval: `1.0` second
- minimum input RMS: `0.008`
- required consecutive matches: `2`

Behavior:

- background-label hits are ignored
- low-signal input is ignored for custom events
- repeated identical custom classifications must occur consecutively before an event is emitted

These guards are separate from Flutter’s own event filtering.

## Flutter Recognition History

Primary file:

- `lib/services/audio_classification_service.dart`

The Flutter audio classification service:

- starts and stops monitoring through the method channel
- listens to `senscribe/audio_classifier_events`
- converts native events into `SoundCaption` objects
- stores recent history in memory for the UI

The custom event payload is converted into:

- `SoundCaptionSource.custom` for custom sounds
- `SoundCaptionSource.builtIn` for Apple’s built-in detector

## Current Limitations

- Custom sound training is iOS-only.
- Training requires a physical iPhone because `CreateML` is unavailable in the simulator SDK.
- Recording duration is currently fixed to 5 seconds per capture.
- The custom model uses a shared background label rather than environment-specific adaptive logic.
- The system Accessibility custom sound feature in iOS Settings is not used by this app. This implementation is app-local and based on `CreateML` + `SoundAnalysis`.

## Files Involved

Main files for this feature:

- `lib/screens/alerts_page.dart`
- `lib/models/custom_sound_profile.dart`
- `lib/services/custom_sound_service.dart`
- `lib/services/audio_classification_service.dart`
- `lib/models/sound_caption.dart`
- `ios/Runner/AudioClassificationPlugin.swift`

## Summary

The current iOS implementation uses 5 target recordings plus 1 background calibration recording to train a local custom sound classifier on-device. The resulting custom classifier runs in parallel with Apple’s built-in sound classifier during live monitoring. The five target samples remain reusable after training, and the background sample can be re-recorded later so the model can be retrained without recreating the target samples.
