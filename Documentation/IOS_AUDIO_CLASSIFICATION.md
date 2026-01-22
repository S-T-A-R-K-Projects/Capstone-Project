# iOS Audio Classification Implementation Overview

This document walks through the iOS-side sound classification integration that powers SenScribe’s live captions. It covers the Flutter-facing service, native plugin, and the configuration changes required to run Apple’s SoundAnalysis pipeline.

## High-Level Flow

1. The Flutter UI (currently `lib/screens/home_page.dart`) calls into `AudioClassificationService` when the user taps Start.
2. `AudioClassificationService` forwards the request over a shared method channel (`senscribe/audio_classifier`).
3. The native plugin (`ios/Runner/AudioClassificationPlugin.swift`) starts an `AVAudioEngine`, feeds microphone buffers into an `SNAudioStreamAnalyzer`, and publishes results over an event channel (`senscribe/audio_classifier_events`).
4. Flutter listens to that event stream, converts each result into a `SoundCaption`, and updates the UI.

All processing stays on-device. The pipeline works offline and employs Apple’s built-in sound classifier (Core ML model).

## Flutter-Side Components

- `lib/services/audio_classification_service.dart` exposes a simple API (`start()`, `stop()`, and a results stream). It hides platform-specific logic behind the same channel names used on Android so the UI can stay platform-agnostic.
- `lib/screens/home_page.dart` toggles monitoring, subscribes to the service stream, and maps each native result into the existing caption list. The UI still shows mocked entries until detections arrive, and a small critical-label filter highlights important sounds (siren, smoke alarm, etc.).

## Native Plugin Details

The plugin lives in `ios/Runner/AudioClassificationPlugin.swift` and is registered from `AppDelegate.swift`.

Key responsibilities:

- Request microphone permission through `AVAudioSession.requestRecordPermission`.
- Create an `AVAudioEngine` and `SNAudioStreamAnalyzer` using the microphone input format.
- Install an audio tap that streams microphone buffers into the analyzer on a background queue.
- Start a single `SNClassifySoundRequest`. On iOS 15+ a specific classifier (`.version1`) provides 300+ environmental labels. Earlier versions fall back to the default initializer; the plugin returns an error if started on unsupported systems.
- Emit result payloads over the event channel. Each payload includes label, confidence, and a UTC timestamp.
- Send status updates (`started`, `stopped`) and error messages that the Flutter layer can convert into snack bars.
- Throttle rapid duplicate predictions to avoid flooding the UI.

### iOS Configuration Changes

- `ios/Runner/Info.plist` now declares `NSMicrophoneUsageDescription` so the system prompt explains why access is required.
- `ios/Podfile` sets `platform :ios, '13.0'` because SoundAnalysis is only available from iOS 13 onward.
- `ios/Runner/AppDelegate.swift` registers the plugin right after `GeneratedPluginRegistrant`.

No external dependencies were added on the iOS side; SoundAnalysis ships with iOS.

## Testing Notes

- Run the app on an iOS 15+ device or simulator with microphone access. Start monitoring and verify that the UI populates with live labels (try clapping, speaking, or playing a sound sample near the device).
- Monitor Xcode logs for messages from `AudioClassificationPlugin` if troubleshooting is needed.
- If permission is denied, a Flutter snack bar notifies the user and the service halts cleanly.

## Extending Further

- Replace the built-in classifier with a custom Core ML model: update the plugin to load `SNClassifySoundRequest(mlModel:)` with your asset.
- Surface richer metadata (multiple simultaneous categories, confidence bars) by forwarding the full `SNClassificationResult` instead of only the top prediction.
- Consider adapting the throttle logic or confidence threshold for your use case. These values live near the top of `AudioClassificationPlugin.swift`.
