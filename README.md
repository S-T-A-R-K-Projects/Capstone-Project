# SenScribe - Accessibility-First Sound Detection App

SenScribe is a Flutter-based mobile application designed for individuals with hearing impairments. It provides real-time audio captioning, critical sound alerts, and an accessible user interface with high contrast themes.

## Prerequisites

### System Requirements

- **Flutter SDK**: 3.35.0 or higher
- **Dart**: 3.9.2 or higher
- **iOS**: iOS 17.0+ (for iOS development)
- **Android**: API Level 31+ (Android 12) or higher

### Development Tools

- **Git**: Version control system
- **Flutter**: UI toolkit for cross-platform development
- **Android Studio** or **Xcode**: For device testing
- **VS Code** (optional): Recommended code editor

### Installation Links

- Git: [https://git-scm.com/downloads](https://git-scm.com/downloads)
- Flutter: [https://docs.flutter.dev/get-started/install](https://docs.flutter.dev/get-started/install)
- Android Studio: [https://developer.android.com/studio](https://developer.android.com/studio)
- Xcode (macOS only): Available on Mac App Store

## Setup Instructions

### 1. Verify Flutter Installation

First, check if Flutter is properly installed and configured:

```bash
flutter doctor
```

This command will show you if there are any missing dependencies or configuration issues. Follow the suggestions to resolve any problems.

### 2. Clone the Repository

Clone this project to your local machine:

```bash
git clone https://github.com/S-T-A-R-K-Projects/Capstone-Project.git
cd Capstone-Project
```

### 3. Navigate to Flutter Project

Navigate to the Flutter project directory:

```bash
cd senscribe
```

### 4. Clean and Install Dependencies

Clean any previous builds and install project dependencies:

```bash
flutter clean
flutter pub get
```

### 5. Check Connected Devices

Verify that you have a device or emulator available:

```bash
flutter devices
```

### 6. Connect a Device

You can run the app on:

#### Physical Device:

- **Android**: Enable Developer Options and USB Debugging
- **iOS**: Register device in Xcode and trust the developer certificate

#### Emulator:

- **Android**: Launch Android emulator from Android Studio
- **iOS**: Launch iOS Simulator from Xcode

### 7. Run the Application

Launch the app on your connected device:

```bash
flutter run
```

For release builds (optimized performance):

```bash
flutter run --release
```

## Features

- **Real-time Audio Classification**: Detects and identifies sounds in the environment.
- **Custom Sound Recognition**: Train your device to recognize specific custom sounds natively on Android.
- **Speech-to-Text (STT)**: Converts spoken language into text using Vosk Offline STT.
- **Text-to-Speech (TTS)**: Converts typed text into audible speech locally when supported.
- **Trigger Word Alerts**: Get alerted when specific words or phrases are spoken.
- **AI-Powered Summarization**: Summarizes conversations using on-device AI models.
- **Accessible UI**: Platform-adaptive UI and high contrast themes.

## Project Structure

```
senscribe/
├── lib/
│   ├── main.dart                       # App entry point
│   ├── models/                         # Data models
│   │   ├── custom_sound_profile.dart   # Profile for custom trained sounds
│   │   ├── history_item.dart           # Model for saved transcriptions/logs
│   │   ├── live_activity_snapshot.dart # Data for live activities
│   │   ├── llm_model.dart              # Summarization LLM metadata
│   │   ├── model_download_snapshot.dart# Download state for models
│   │   ├── sound_caption.dart          # Sound detection payload model
│   │   ├── sound_filter.dart           # Sound filtering configurations
│   │   ├── trigger_alert.dart          # Alert notification model
│   │   └── trigger_word.dart           # Trigger phrase model
│   ├── screens/                        # Application screens
│   │   ├── about_support.dart          # App info & licenses
│   │   ├── alerts_page.dart            # Trigger word alerts UI
│   │   ├── custom_sound_enrollment_page.dart # Custom sounds training UI
│   │   ├── experimental_page.dart      # Beta features and settings
│   │   ├── history_page.dart           # Event logs & saved texts
│   │   ├── home_page.dart              # Old home screen
│   │   ├── home_tab.dart               # Bottom navigation tab content
│   │   ├── model_settings_page.dart    # LLM & AI model configuration
│   │   ├── permissions_background_page.dart # Permissions onboarding
│   │   ├── privacy_data_page.dart      # Privacy policy and local data
│   │   ├── settings_page.dart          # General app configuration
│   │   ├── speech_to_text_page.dart    # Dedicated STT interface
│   │   ├── start_page.dart             # Splash & welcome screen
│   │   ├── text_to_speech_page.dart    # Dedicated TTS interface
│   │   └── unified_home_page.dart      # Main dashboard and feed
│   ├── services/                       # Background services & Logic
│   │   ├── android_offline_speech_service.dart # Vosk STT implementation
│   │   ├── app_permission_service.dart # Permission request logic
│   │   ├── app_settings_service.dart   # Shared preferences wrapper
│   │   ├── audio_classification_service.dart # YAMNet sound recognition
│   │   ├── custom_sound_service.dart   # Custom Sound Matcher logic
│   │   ├── history_service.dart        # Saved texts management
│   │   ├── leap_service.dart           # Leap SDK integration for AI
│   │   ├── live_update_service.dart    # Background notification updates
│   │   ├── model_download_service.dart # Model downloader logic
│   │   ├── sound_filter_service.dart   # Throttling and filtering sound
│   │   ├── stt_transcript_service.dart # Cross-platform STT service
│   │   ├── summarization_service.dart  # AI Summarization logic
│   │   ├── text_to_speech_service.dart # Cross-platform TTS service
│   │   └── trigger_word_service.dart   # Conversational phrase matching
│   ├── widgets/                        # Reusable UI components
│   │   ├── adaptive_input_sheet.dart   # Cross-platform bottom sheet
│   │   ├── sound_caption_card.dart     # Sound feed item widget
│   │   └── trigger_alert_dialog.dart   # Trigger alert popup
│   ├── navigation/                     # Routing logic
│   │   ├── adaptive_page_route.dart    # Platform-specific transitions
│   │   └── main_navigation.dart        # Bottom navigation logic
│   ├── theme/                          # Styling
│   │   └── app_theme.dart              # Light/Dark theme definitions
│   └── utils/                          # Helper functions & constants
│       ├── app_constants.dart          # App-wide constants
│       ├── sound_filter_catalog.dart   # Default sound map definitions
│       ├── themed_adaptive_alert_dialog.dart # Custom dialog styling
│       ├── time_utils.dart             # Date formatting functions
│       └── utils.dart                  # General helper methods
├── android/                            # Android-specific configuration
│   └── app/src/main/kotlin/com/example/senscribe/
│       ├── AndroidOfflineSpeechPlugin.kt       # Native Vosk STT runner
│       ├── AudioClassificationPlugin.kt        # Primary audio orchestrator
│       ├── CustomAudioFeatureExtractor.kt      # Feature creation for trained sounds
│       ├── CustomSoundMatching.kt              # Matcher for custom embeddings
│       ├── LiveUpdateForegroundService.kt      # Foreground Android service
│       ├── MainActivity.kt                     # Flutter engine host
│       ├── ManagedModelDownloadManager.kt      # Native file downloader
│       ├── ModelDownloadBridge.kt              # Downloads method channel
│       ├── ModelDownloadForegroundService.kt   # Persistent download service
│       ├── SharedAudioInputManager.kt          # Shared microphone input lock
│       └── YamnetLiteRtRunner.kt               # TFLite inference runner
├── ios/                                # iOS-specific configuration
│   └── Runner/
│       ├── AppDelegate.swift           # Flutter engine host
│       ├── AudioClassificationPlugin.swift # Primary audio orchestrator
│       ├── Info.plist                  # iOS app configuration
│       └── Runner.entitlements         # iOS security entitlements
└── pubspec.yaml                        # Project dependencies
```

## Development Commands

### Useful Flutter Commands:

```bash
# Check for code issues
flutter analyze

# Run tests (if available)
flutter test

# Build APK for Android
flutter build apk

# Build for iOS (macOS only)
flutter build ios

# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Clean build files
flutter clean
```

## Troubleshooting

### Common Issues:

1. **"flutter: command not found"**
   - Ensure Flutter is added to your PATH
   - Run `flutter doctor` to verify installation

2. **"No devices available"**
   - Connect a physical device or start an emulator
   - Check with `flutter devices`

3. **Build errors**
   - Run `flutter clean` then `flutter pub get`
   - Check `flutter doctor` for missing dependencies

4. **iOS build issues**
   - Ensure Xcode is installed and updated
   - Run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`

5. **Android build issues**
   - Ensure Android Studio and SDK are properly installed
   - Check Android SDK path in Flutter settings

## Development Team

**Team STARK:**

- Kaushik Naik
- Tamerlan Khalilbayov
- Spencer Russel
- Reewaz Rijal
