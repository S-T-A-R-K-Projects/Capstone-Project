import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sound_filter.dart';

class AppSettingsService {
  static const _themeModeKey = 'app_theme_mode_v1';
  static const _liveUpdatesEnabledKey = 'live_updates_enabled_v1';
  static const _selectedSoundFiltersKey = 'sound_filter_selection_v1';
  static const _soundFilterDisabledLabelsKeyPrefix =
      'sound_filter_disabled_labels_v1';
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

  Future<Set<SoundFilterId>> loadSelectedSoundFilters() async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues = prefs.getStringList(_selectedSoundFiltersKey);
    if (rawValues == null) {
      return Set<SoundFilterId>.from(SoundFilterId.defaultSelection);
    }
    if (rawValues.isEmpty) {
      return <SoundFilterId>{};
    }

    final filters = rawValues
        .map(SoundFilterId.fromStorageKey)
        .whereType<SoundFilterId>()
        .toSet();

    if (filters.isEmpty) {
      return <SoundFilterId>{};
    }

    return filters;
  }

  Future<void> saveSelectedSoundFilters(Set<SoundFilterId> filters) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValues = filters.map((filter) => filter.storageKey).toList()
      ..sort();
    await prefs.setStringList(_selectedSoundFiltersKey, rawValues);
  }

  Future<Map<SoundFilterId, Set<String>>> loadDisabledSoundLabelsByFilter({
    required bool isAndroid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final rawValue = prefs.getString(
      _disabledLabelsKeyForPlatform(isAndroid: isAndroid),
    );
    if (rawValue == null || rawValue.isEmpty) {
      return <SoundFilterId, Set<String>>{};
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic>) {
        return <SoundFilterId, Set<String>>{};
      }

      final output = <SoundFilterId, Set<String>>{};
      for (final entry in decoded.entries) {
        final filter = SoundFilterId.fromStorageKey(entry.key);
        if (filter == null || entry.value is! List) {
          continue;
        }
        output[filter] = Set<String>.from(
          (entry.value as List)
              .whereType<String>()
              .where((label) => label.trim().isNotEmpty),
        );
      }
      return output;
    } catch (_) {
      return <SoundFilterId, Set<String>>{};
    }
  }

  Future<void> saveDisabledSoundLabelsByFilter(
    Map<SoundFilterId, Set<String>> disabledLabels, {
    required bool isAndroid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final serializable = <String, List<String>>{};
    for (final entry in disabledLabels.entries) {
      final labels = entry.value.toList()..sort();
      if (labels.isEmpty) {
        continue;
      }
      serializable[entry.key.storageKey] = labels;
    }

    await prefs.setString(
      _disabledLabelsKeyForPlatform(isAndroid: isAndroid),
      jsonEncode(serializable),
    );
  }

  String _disabledLabelsKeyForPlatform({required bool isAndroid}) {
    final platformKey = isAndroid ? 'android' : 'ios';
    return '${_soundFilterDisabledLabelsKeyPrefix}_$platformKey';
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
