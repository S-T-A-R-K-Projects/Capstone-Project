# iOS Custom Sound Recognition Implementation

This document describes the current iOS custom sound recognition pipeline in `senscribe`. It reflects the implementation in `senscribe/ios/Runner/AudioClassificationPlugin.swift` and the shared Flutter UI and service layers.

## Summary

iOS custom sound recognition is a local CreateML/Core ML workflow layered on top of the same live monitoring engine used for built-in Apple sound classification.

The current flow is:

1. Flutter creates a custom sound profile.
2. iOS records `10` target clips and `3` background clips.
3. The app trains one aggregate `MLSoundClassifier` containing all enabled custom sounds plus one shared background label.
4. The trained model is compiled and stored locally.
5. During live monitoring, the plugin attaches both the built-in Apple classifier and the custom model to the same `SNAudioStreamAnalyzer`.
6. Custom detections are filtered with stricter confidence, signal, and consecutive-match rules before being emitted to Flutter.

## Shared Flutter Layer

### UI

Primary UI files:

- `lib/screens/alerts_page.dart`
- `lib/screens/custom_sound_enrollment_page.dart`

Current user-visible requirements:

- `10` target samples
- `3` background samples
- each recording lasts about `5` seconds

The enrollment page is already aligned with this:

- target clips are recorded first
- background recording stays disabled until target recording is complete
- training stays disabled until `hasEnoughSamples` is true
- the page explicitly tells the user to start detection from the unified home screen after training

### Shared model

Primary model:

- `lib/models/custom_sound_profile.dart`

Current constants:

- `kRequiredCustomSoundSamples = 10`
- `kRequiredBackgroundSamples = 3`

### Shared service

Primary service:

- `lib/services/custom_sound_service.dart`

Important responsibilities:

- create draft profiles
- persist profile metadata in `SharedPreferences`
- merge Flutter state with native iOS state
- request sample capture
- trigger training and rebuild
- enable, disable, delete, refresh, and discard profiles

Method channel used:

- `senscribe/audio_classifier`

## iOS Native File

Primary implementation file:

- `ios/Runner/AudioClassificationPlugin.swift`

This plugin handles:

- built-in Apple sound classification
- custom sample capture
- custom model training
- live inference with the trained model

## Local Training Availability

CreateML is imported conditionally:

```swift
#if canImport(CreateML)
import CreateML
#endif
```

This matters because Apple does not ship CreateML in the iOS simulator SDK.

Current behavior:

- the app can still build for simulator
- custom sound training is unavailable in that environment
- when training is attempted without CreateML support, eligible profiles are marked `failed`
- the user-facing error explains that training must run on a physical iPhone running iOS 17 or newer

## Profile Persistence

Profiles are stored at:

- `Application Support/custom_sounds/profiles.json`

The same root directory also stores:

- per-profile sample folders
- `custom_sound_model.mlmodel`
- `custom_sound_model.mlmodelc`

The Flutter layer separately stores profile metadata in `SharedPreferences`, and `CustomSoundService.loadProfiles()` merges the native and Flutter views.

## Sample Capture

Sample recording is handled by `captureSample(...)`.

### Recording format

- format: linear PCM
- sample rate: `16_000`
- channels: `1`
- bit depth: `16`
- duration: `5.0` seconds
- file extension: `.caf`

Output file names:

- target: `target_1.caf`, `target_2.caf`, ...
- background: `background_1.caf`, `background_2.caf`, ...

### Capture behavior

- only one recording can run at a time
- the profile is moved to `recording` before capture starts
- if monitoring is active, monitoring is stopped first
- the plugin switches the session to `.record` / `.measurement`
- the sample is recorded with `AVAudioRecorder`
- after capture, sample paths are reloaded from disk
- the profile returns to `draft`
- monitoring resumes automatically if it had been running before capture

On failure:

- the profile is marked `failed`
- `lastError` is updated

Unlike Android, iOS custom profiles do not persist per-profile feature banks because the trained artifact is a shared Core ML sound classifier.

## Training Pipeline

Training is handled by `trainOrRebuildCustomModel(...)`.

### Eligibility

A profile is eligible when:

- it is enabled
- it has at least `10` target sample paths
- it has at least `3` background sample paths

Eligible profiles are marked `training` before CreateML work begins.

### Dataset construction

`buildTrainingData(from:)` creates one dataset map for the aggregate classifier:

- each enabled custom sound contributes its target files under the label equal to `profile.name`
- all eligible background files from all profiles are combined under the internal label `__background__`

This means iOS trains one shared custom classifier for all enabled sounds, not one model per custom sound.

### Training and persistence

When CreateML is available, the plugin:

1. builds `filesByLabel` training data
2. requires at least two labels in the dataset
3. trains `MLSoundClassifier(trainingData: .filesByLabel(...))`
4. writes `custom_sound_model.mlmodel`
5. compiles the model
6. copies the compiled model to `custom_sound_model.mlmodelc`
7. marks eligible profiles as `ready`
8. restarts monitoring if monitoring was already active

If there are no eligible profiles:

- persisted custom model files are deleted
- stale `training` states are reset
- monitoring is reloaded if necessary

If training fails:

- eligible profiles are marked `failed`
- `lastError` is updated with the native error description

## Live Custom Detection

The custom live path is active only when:

- at least one enabled profile has enough samples
- the compiled model exists on disk

When that is true, `makeCustomAnalysisRequestIfAvailable()` loads the compiled model and creates:

- `SNClassifySoundRequest(mlModel: model)`

That request is attached to the same `SNAudioStreamAnalyzer` as the built-in Apple classifier.

### Custom runtime guards

The custom path is intentionally stricter than the built-in path.

Current custom guard values:

- confidence threshold: `0.94`
- custom throttle interval: `10.0` seconds
- minimum signal RMS: `0.008`
- required consecutive matches: `2`

Additional behavior:

- `__background__` predictions are ignored
- weak input is rejected using current RMS and peak values from the live buffer
- the same custom label must appear in consecutive results before emission
- `customSoundId` is resolved by matching the emitted label back to a profile name

Result payload for a custom detection:

- `type = "result"`
- `label = <profile name>`
- `confidence`
- `source = "custom"`
- `timestampMs`
- `customSoundId`

## Monitoring Reload Behavior

When sample capture, training, deletion, or profile changes affect model availability, the plugin can reload monitoring through `restartMonitoringIfNeeded()`.

That method:

- reconfigures the audio session
- stops the current monitoring stack without emitting a full stop event
- rebuilds the analyzer requests
- emits a `status = "reloaded"` event

This is how the app swaps in or removes the trained custom classifier while monitoring is already active.

## Important Differences From Older Docs

The older iOS custom-sound docs are stale in several places. The current code:

- requires `10/3` samples, not `5/1`
- records at `16 kHz`, not `44.1 kHz`
- targets iOS 17 in the project Podfile
- supports Android custom sounds too, so this is no longer an iOS-only product feature
- trains one aggregate shared custom model, not one model file per sound

## Key Files To Read

- `senscribe/ios/Runner/AudioClassificationPlugin.swift`
- `senscribe/ios/Runner/AppDelegate.swift`
- `senscribe/ios/Podfile`
- `senscribe/lib/models/custom_sound_profile.dart`
- `senscribe/lib/services/custom_sound_service.dart`
- `senscribe/lib/screens/custom_sound_enrollment_page.dart`
