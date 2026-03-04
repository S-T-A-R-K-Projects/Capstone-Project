import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  static const int soundHistoryMaxItems = 50;
  static const int alertHistoryMaxItems = 100;
  static const double audioConfidenceThreshold = 0.6;
  static const int historyPreviewMaxLength = 64;

  static const double defaultSectionHeight = 250.0;
  static const double sttSectionHeight = 280.0;
  static const double ttsSectionHeight = 150.0;
  static const double collapsedSectionHeight = 80.0;

  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration staggerAnimationDuration = Duration(milliseconds: 375);
  static const Duration fadeAnimationDuration = Duration(milliseconds: 600);

  static const double cardBorderRadius = 16.0;
  static const double sectionBorderRadius = 24.0;

  static const EdgeInsets cardPadding = EdgeInsets.all(16);
  static const EdgeInsets sectionPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets listPadding = EdgeInsets.fromLTRB(16, 8, 16, 120);

  static const double bottomNavHeight = 120.0;
}

class CriticalSounds {
  CriticalSounds._();

  static const List<String> labels = [
    'siren',
    'fire_alarm',
    'smoke_alarm',
    'scream',
    'baby_crying',
    'glass_breaking',
    'gunshot',
  ];

  static bool isCritical(String label) {
    return labels.contains(label.toLowerCase().replaceAll(' ', '_'));
  }
}

class Delays {
  Delays._();

  static const Duration speechRestart = Duration(milliseconds: 40);
  static const Duration speechRestartAfterError = Duration(milliseconds: 80);
  static const Duration speechRestartAfterFailed = Duration(milliseconds: 350);
  static const Duration scrollDelay = Duration(milliseconds: 100);
  static const Duration scrollAnimation = Duration(milliseconds: 300);
}
