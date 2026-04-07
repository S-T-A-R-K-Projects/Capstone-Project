# iOS Audio Classification Implementation Overview

This document describes the current iOS sound classification implementation in `senscribe`. It reflects the code in `senscribe/ios/Runner/AudioClassificationPlugin.swift`, `AppDelegate.swift`, and the shared Flutter services.

## Platform Baseline

The iOS project currently declares:

- `platform :ios, '17.0'` in `senscribe/ios/Podfile`

The app targets iOS 17 and newer.

## Current Stack

- Flutter service: `lib/services/audio_classification_service.dart`
- iOS plugin: `ios/Runner/AudioClassificationPlugin.swift`
- plugin registration and iOS bridges: `ios/Runner/AppDelegate.swift`
- iOS live activity bridge: `senscribe/ios_live_activities` in `AppDelegate.swift`

## High-Level Flow

1. Flutter calls `senscribe/audio_classifier` with `start`.
2. `AudioClassificationPlugin` requests microphone permission.
3. The plugin configures `AVAudioSession` with `.playAndRecord` and `.measurement`.
4. It creates an `AVAudioEngine` and `SNAudioStreamAnalyzer`.
5. A built-in `SNClassifySoundRequest(classifierIdentifier: .version1)` is attached.
6. If a trained custom model is present, a second `SNClassifySoundRequest(mlModel:)` is also attached.
7. Audio from the engine input tap is forwarded to the analyzer on a background queue.
8. Result events are published to Flutter over `senscribe/audio_classifier_events`.
9. Flutter converts those events into `SoundCaption` objects and updates the UI.

## Flutter Contract

### Method channel

Channel name:

- `senscribe/audio_classifier`

Methods handled by the iOS plugin:

- `start`
- `stop`
- `loadCustomSounds`
- `captureSample`
- `trainOrRebuildCustomModel`
- `deleteCustomSound`
- `setCustomSoundEnabled`

### Event channel

Channel name:

- `senscribe/audio_classifier_events`

Result payload fields:

- `type = "result"`
- `label`
- `confidence`
- `source = "builtIn"` or `source = "custom"`
- `timestampMs`
- optional `customSoundId`

Status payload fields:

- `type = "status"`
- `status`, such as `started`, `stopped`, or `reloaded`

`AudioClassificationService` currently only processes `result` events, but the iOS plugin still emits status events.

## iOS Audio Session and Monitoring Lifecycle

The plugin uses two session modes depending on the task:

### Live monitoring session

Configured in `configureAudioSession()`:

- category: `.playAndRecord`
- mode: `.measurement`
- options:
  - `.mixWithOthers`
  - `.allowBluetooth`
  - `.allowBluetoothA2DP`
  - `.defaultToSpeaker`

Additional behavior:

- preferred IO buffer duration: `0.02`
- the session is activated before monitoring starts
- monitoring deactivates the session on stop

### Monitoring engine

`startMonitoringSession()`:

- creates `AVAudioEngine`
- uses the input node output format
- creates `SNAudioStreamAnalyzer`
- installs an input tap with buffer size `8192`
- forwards each buffer into the analyzer on `analyzerQueue`

## Built-In iOS Classification Path

The built-in request is:

- `SNClassifySoundRequest(classifierIdentifier: .version1)`

The plugin currently requires iOS 15 or newer for this request, but because the project minimum is now iOS 17, the app-side deployment target already satisfies that requirement.

### Built-in runtime gating

The built-in path uses:

- confidence threshold: `0.25`
- throttle per built-in label: `5.0` seconds

The built-in iOS path emits the top classification once it passes threshold and throttle checks.

## Input Signal Tracking

The plugin also computes current input levels from the live audio buffer:

- RMS
- peak

These values are used by the custom classifier path to reject weak or silent input before emitting custom detections.

## iOS Live Activities

iOS live updates are implemented separately from the audio plugin.

Relevant pieces:

- Flutter service: `lib/services/live_update_service.dart`
- method channel: `senscribe/ios_live_activities`
- bridge setup: `ios/Runner/AppDelegate.swift`
- ActivityKit manager: `SenscribeLiveActivityManager` in `AppDelegate.swift`

Behavior:

- Flutter listens to audio history updates.
- When monitoring is active and live updates are enabled, Flutter creates or updates a Live Activity with the latest detection.
- `AudioClassificationPlugin` itself does not create the Live Activity directly.

The iOS audio plugin is still the source of the detection events that feed that Live Activity.

## Permissions and Configuration

### Info.plist

Relevant keys in `ios/Runner/Info.plist`:

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSSupportsLiveActivities`
- `UIBackgroundModes` includes `audio`

For sound classification specifically, the native plugin only needs microphone permission. Speech recognition permission is for the separate speech-to-text pipeline.

### AppDelegate

`ios/Runner/AppDelegate.swift` currently:

- registers generated Flutter plugins
- registers `AudioClassificationPlugin`
- exposes `senscribe/ios_permissions`
- exposes `senscribe/ios_live_activities`
- exposes `senscribe/ios_runtime`

## Key Files To Read

- `senscribe/ios/Runner/AudioClassificationPlugin.swift`
- `senscribe/ios/Runner/AppDelegate.swift`
- `senscribe/ios/Podfile`
- `senscribe/lib/services/audio_classification_service.dart`
- `senscribe/lib/services/live_update_service.dart`
