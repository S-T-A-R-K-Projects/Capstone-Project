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
- **Speech-to-Text (STT)**: Converts spoken language into text for easier communication.
- **Text-to-Speech (TTS)**: Converts typed text into audible speech.
- **Sound Direction Detection**: Visualizes the direction of detected sounds.
- **Name Recognition**: Alerts the user when their name is called.
- **AI-Powered Summarization**: Summarizes conversations using on-device AI models (via Flutter Leap SDK).
- **Customizable Alerts**: Trigger word alerts with vibration feedback.
- **Accessible UI**: High contrast themes and large text options.

## Project Structure

```
senscribe/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/                   # Data models
│   │   ├── sound_caption.dart
│   │   ├── trigger_word.dart
│   │   └── history_item.dart
│   ├── screens/                  # Application screens
│   │   ├── unified_home_page.dart      # Main dashboard
│   │   ├── speech_to_text_page.dart    # STT interface
│   │   ├── text_to_speech_page.dart    # TTS interface
│   │   ├── sound_direction_page.dart   # Directionality UI
│   │   ├── name_recognition_page.dart  # Name alerts
│   │   ├── settings_page.dart          # Configuration
│   │   └── history_page.dart           # Event logs
│   ├── services/                 # Background services & Logic
│   │   ├── audio_classification_service.dart
│   │   ├── summarization_service.dart  # AI Summarization
│   │   ├── leap_service.dart           # Leap SDK integration
│   │   └── text_to_speech_service.dart
│   ├── widgets/                  # Reusable UI components
│   │   ├── sound_caption_card.dart
│   │   └── trigger_alert_dialog.dart
│   ├── navigation/
│   │   └── main_navigation.dart  # Bottom navigation logic
│   └── theme/
│       └── app_theme.dart        # Light/Dark theme definitions
├── android/                      # Android-specific configuration
├── ios/                          # iOS-specific configuration
└── pubspec.yaml                  # Project dependencies
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
