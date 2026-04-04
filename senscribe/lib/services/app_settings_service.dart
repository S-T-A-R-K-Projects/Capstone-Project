import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  static const _themeModeKey = 'app_theme_mode_v1';
  static const _liveUpdatesEnabledKey = 'live_updates_enabled_v1';
  static const _initialPermissionsRequestedKey =
      'initial_permissions_requested_v1';

  static final AppSettingsService _instance = AppSettingsService._internal();
  factory AppSettingsService() => _instance;
  AppSettingsService._internal();

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(_themeModeKey);
    switch (rawValue) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }

  Future<bool> loadLiveUpdatesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_liveUpdatesEnabledKey) ?? true;
  }

  Future<void> saveLiveUpdatesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_liveUpdatesEnabledKey, enabled);
  }

  Future<bool> hasRequestedInitialPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_initialPermissionsRequestedKey) ?? false;
  }

  Future<void> markInitialPermissionsRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_initialPermissionsRequestedKey, true);
  }
}
