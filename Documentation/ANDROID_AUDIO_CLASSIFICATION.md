# Android Audio Classification Implementation Overview

This document describes the current Android sound recognition implementation in `senscribe`.

## Current Stack

- Flutter entry point: `lib/services/audio_classification_service.dart`
- Android plugin: `android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt`
- YAMNet runtime wrapper: `android/app/src/main/kotlin/com/example/senscribe/YamnetLiteRtRunner.kt`
- Custom feature extractor: `android/app/src/main/kotlin/com/example/senscribe/CustomAudioFeatureExtractor.kt`
- Custom matcher calibration: `android/app/src/main/kotlin/com/example/senscribe/CustomSoundMatching.kt`
- Foreground notification service: `android/app/src/main/kotlin/com/example/senscribe/LiveUpdateForegroundService.kt`

Android runs:

1. A direct TensorFlow Lite LiteRT-backed YAMNet runner for built-in classes.
2. A separate on-device custom matcher built from saved feature banks.

## High-Level Flow

1. Flutter calls `senscribe/audio_classifier` with `start`.
2. `AudioClassificationPlugin` checks `RECORD_AUDIO`, starts a foreground service, acquires a partial wake lock, and creates an `AudioRecord`.
3. The plugin reads mono PCM16 audio at `16_000 Hz`.
4. A rolling window of `15_600` samples is maintained for inference. New audio is appended in `3_200` sample hops.
5. The current window is sent to `YamnetLiteRtRunner`, which executes the bundled `yamnet/yamnet.tflite` model and returns the top classes.
6. If trained custom sounds exist, the same rolling window is also converted into a hand-crafted feature vector and scored against each saved custom matcher.
7. Detection payloads are emitted to Flutter over `senscribe/audio_classifier_events`.
8. `AudioClassificationService` converts those payloads into `SoundCaption` entries and updates the UI.

## Flutter Contract

### Method channel

Channel name:

- `senscribe/audio_classifier`

Methods currently handled on Android:

- `start`
- `stop`
- `startLiveUpdates`
- `stopLiveUpdates`
- `loadCustomSounds`
- `captureSample`
- `trainOrRebuildCustomModel`
- `deleteCustomSound`
- `setCustomSoundEnabled`

### Event channel

Channel name:

- `senscribe/audio_classifier_events`

Result payload shape:

- `type`: `result`
- `label`
- `confidence`
- `source`: `builtIn` or `custom`
- `timestampMs`
- `customSoundId` only for custom detections

Status payload shape:

- `type`: `status`
- `status`: values such as `started` or `stopped`

`AudioClassificationService` currently only consumes `type == "result"` events. Native status events still exist for platform-side lifecycle signaling.

## Built-In Android Classification Path

The built-in path is implemented in `processBuiltInResult(...)`.

### Audio capture and inference

- Recorder source: `MediaRecorder.AudioSource.VOICE_RECOGNITION`
- Sample rate: `16_000 Hz`
- Channels: mono
- Encoding: PCM 16-bit
- Inference window: `15_600` samples, about `0.975 s`
- Hop size: `3_200` samples, about `0.2 s`

### Model loading

`YamnetLiteRtRunner`:

- loads `android/app/src/main/assets/yamnet/yamnet.tflite`
- loads labels from `android/app/src/main/assets/yamnet/yamnet_class_map.csv`
- uses the LiteRT/TensorFlow Lite `Interpreter`
- scans outputs to find the score tensor whose width matches the class map
- aggregates frame scores by taking the maximum score per class across returned frames
- returns the top 3 categories

### Built-in runtime gating

The plugin does not emit every top category immediately. It applies the following guards:

- minimum score: `0.4`
- minimum signal RMS: `0.006`
- minimum signal peak: `0.018`
- minimum margin over the runner-up class: `0.06`
- required consecutive matches: `2`
- throttle per built-in label: `5_000 ms`

## Android Live Updates

Android live updates are separate from classification itself.

Relevant pieces:

- Flutter service: `lib/services/live_update_service.dart`
- Android methods: `startLiveUpdates`, `stopLiveUpdates`
- Foreground service: `LiveUpdateForegroundService`

Behavior:

- When enabled, Flutter asks the plugin to show live updates.
- The plugin starts or keeps a foreground service alive.
- Detection payloads can update a custom notification.
- Notification updates are throttled to `1_000 ms`.
- The service exposes `Open app`, `Mute/Unmute`, and `Stop` actions.
- `Stop` ends monitoring through `AudioClassificationPlugin.sharedInstance()?.stopMonitoringFromService()`.

## Lifecycle and Permissions

### Permissions

Android manifest entries used by this feature include:

- `RECORD_AUDIO`
- `POST_NOTIFICATIONS`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_MICROPHONE`
- `WAKE_LOCK`

The plugin requests `RECORD_AUDIO` at runtime through `ActivityCompat.requestPermissions(...)`. `POST_NOTIFICATIONS` is requested separately by `LiveUpdateService` before Android live updates are enabled.

### MainActivity integration

`MainActivity.kt`:

- registers `AudioClassificationPlugin` in `configureFlutterEngine`
- registers `ModelDownloadBridge`
- forwards `onRequestPermissionsResult(...)` to the audio plugin
- keeps the activity visible on the lock screen when required by the app

## Project Configuration Relevant to Android

### Gradle

`android/app/build.gradle.kts` currently declares:

- `minSdk = 31`
- Java 17 / Kotlin JVM 17
- `implementation("com.google.ai.edge.litert:litert:2.1.3")`

The app minimum is Android API 31 and above. That matches the project configuration and the user requirement for Android support.

### Manifest

`android/app/src/main/AndroidManifest.xml` also declares:

- `LiveUpdateForegroundService` with `foregroundServiceType="microphone"`
- `ModelDownloadForegroundService` with `foregroundServiceType="dataSync"`

## Key Files To Read

- `senscribe/android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt`
- `senscribe/android/app/src/main/kotlin/com/example/senscribe/YamnetLiteRtRunner.kt`
- `senscribe/lib/services/audio_classification_service.dart`
- `senscribe/lib/services/live_update_service.dart`
