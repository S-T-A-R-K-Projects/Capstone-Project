# Android Audio Classification Implementation Overview

This document explains how SenScribe performs live audio classification on Android using MediaPipe Tasks and the YAMNet TensorFlow Lite model. It is intended for newcomers who have not seen the code before.

## High-Level Flow

1. Flutter’s `AudioClassificationService` (shared with iOS) invokes a platform method channel named `senscribe/audio_classifier`.
2. `android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt` receives the call, ensures microphone permission, and starts an internal audio pipeline.
3. The plugin records PCM audio via `AudioRecord`, converts buffers to MediaPipe’s `AudioData`, and feeds them to `AudioClassifier`.
4. Results stream back to Flutter through an event channel (`senscribe/audio_classifier_events`). Flutter converts them into `SoundCaption` objects and updates the UI.

All work runs locally on the device. The TensorFlow Lite runtime bundled in `com.google.mediapipe:tasks-audio` performs the inference.

## Flutter-Side Components

- `lib/services/audio_classification_service.dart` exposes a uniform API for both platforms using shared channel names.
- `lib/screens/home_page.dart` subscribes to the event stream, filters results, and refreshes the UI list. The code is identical to iOS; only the native plugin differs.

## Native Plugin Breakdown

`android/app/src/main/kotlin/com/example/senscribe/AudioClassificationPlugin.kt` handles the heavy lifting. The core responsibilities are:

### Permissions and Lifecycle

- Requests `RECORD_AUDIO` permission if needed (`ActivityCompat.requestPermissions`).
- Keeps track of pending start calls so it can resume classification after the user grants access.
- Cleans up the classifier, worker thread, and recorder when Flutter stops listening or when the activity is destroyed.

### MediaPipe Setup

- Declares constants for sample rate (`16000 Hz`), channel count (`mono`), and buffer size to match YAMNet’s expected input window (15 600 samples ≈ 0.975 s).
- Builds `AudioClassifierOptions` with:
  - `BaseOptions.setModelAssetPath("yamnet.tflite")` to load the bundled model.
  - `RunningMode.AUDIO_CLIPS` because we push buffered chunks instead of streaming callbacks.
  - `setMaxResults(3)` and a confidence threshold in code to avoid low-confidence noise.
- Instantiates `AudioClassifier` and creates a plain `AudioRecord` configured with the same sample rate and format. Using `MediaRecorder.AudioSource.VOICE_RECOGNITION` reduces automatic gain control artifacts.

### Audio Loop

- Runs on a dedicated `HandlerThread` to keep the UI responsive.
- Repeatedly reads `CLASSIFICATION_SAMPLE_COUNT` PCM16 samples from `AudioRecord` into a short array, then normalizes to floats (`[-1, 1]`) for MediaPipe.
- Wraps the float array into an `AudioData` container and calls `classifier.classify(audioData)`.
- Interprets the returned `AudioClassifierResult`, pulls the top category, and throttles duplicate labels (same label within 700 ms) before sending them back to Flutter via the event channel.

### Error Handling

- Emits descriptive error codes (`stream_failed`, `analysis_failed`, etc.) through the event sink so the Flutter layer can surface snack bars.
- Stops classification cleanly whenever an exception occurs, permissions are revoked, or Flutter cancels the stream.

## Android Project Configuration

- `android/app/src/main/assets/yamnet.tflite` – model file moved from the repository root.
- `android/app/src/main/AndroidManifest.xml` – adds `<uses-permission android:name="android.permission.RECORD_AUDIO" />`.
- `android/app/build.gradle.kts` – pins `minSdk` to at least 23 (required by the MediaPipe dependency) and adds `implementation("com.google.mediapipe:tasks-audio:0.10.14")`.
- `android/app/src/main/kotlin/com/example/senscribe/MainActivity.kt` – registers the plugin in `configureFlutterEngine`, delegates permission results, and disposes the plugin on destroy.

No Gradle scripts outside the Flutter module were modified.

## Testing Notes

- Run `flutter run` on a physical Android device (MediaPipe audio stream mode requires real microphone input). Grant microphone access when prompted.
- Tap Start on the home screen; the list should populate with live labels (speech, music, dog bark, etc.). Labels will appear more quickly if you provide distinct sounds near the microphone.
- Use `adb logcat` or the Flutter console to inspect error messages emitted by the plugin when diagnosing issues.

## Extending Further

- Replace `yamnet.tflite` with a custom MediaPipe-compatible classifier (update the asset, and the options builder if metadata differs).
- Surface all categories per frame by forwarding the full classification list instead of just the top label.
- Align the throttle duration or confidence threshold with UX needs. These values live near the top of `AudioClassificationPlugin.kt`.
- To support background execution, move the recording logic into a foreground service and adapt the plugin to bind to it before streaming events back to Flutter.
