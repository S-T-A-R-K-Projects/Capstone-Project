import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/trigger_word.dart';
import '../models/trigger_alert.dart';
import '../utils/app_constants.dart';

class TriggerWordService {
  static const _kTriggerWordsKey = 'trigger_words_v1';
  static const _kTriggerAlertsKey = 'trigger_alerts_v1';

  // Singleton pattern
  static final TriggerWordService _instance = TriggerWordService._internal();
  factory TriggerWordService() => _instance;
  TriggerWordService._internal();

  // Stream controllers
  final _triggerWordsController =
      StreamController<List<TriggerWord>>.broadcast();
  final _alertsController = StreamController<List<TriggerAlert>>.broadcast();

  Stream<List<TriggerWord>> get triggerWordsStream =>
      _triggerWordsController.stream;
  Stream<List<TriggerAlert>> get alertsStream => _alertsController.stream;

  // In-memory caches — invalidated on every write operation.
  List<TriggerWord>? _triggerWordsCache;
  List<TriggerAlert>? _alertsCache;
  final Set<String> _pendingSoundAlertKeys = <String>{};

  Future<List<TriggerWord>> loadTriggerWords() async {
    if (_triggerWordsCache != null) return _triggerWordsCache!;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTriggerWordsKey);
    if (json == null || json.isEmpty) return [];
    try {
      final words = TriggerWord.decodeList(json);
      _triggerWordsCache = words;
      return words;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTriggerWords(List<TriggerWord> words) async {
    final prefs = await SharedPreferences.getInstance();
    final json = TriggerWord.encodeList(words);
    await prefs.setString(_kTriggerWordsKey, json);
    _triggerWordsCache = words;
    _triggerWordsController.add(words);
  }

  Future<void> addTriggerWord(TriggerWord word) async {
    final words = await loadTriggerWords();
    // Avoid duplicates
    words.removeWhere((w) => w.word.toLowerCase() == word.word.toLowerCase());
    words.add(word);
    await saveTriggerWords(words);
  }

  Future<void> removeTriggerWord(String word) async {
    final words = await loadTriggerWords();
    words.removeWhere((w) => w.word.toLowerCase() == word.toLowerCase());
    await saveTriggerWords(words);
  }

  Future<void> updateTriggerWord(String oldWord, TriggerWord newWord) async {
    final words = await loadTriggerWords();
    final index =
        words.indexWhere((w) => w.word.toLowerCase() == oldWord.toLowerCase());
    if (index == -1) return;
    words[index] = newWord;
    await saveTriggerWords(words);
  }

  /// Check if text contains any trigger words and return matches
  Future<List<String>> checkForTriggers(String text) async {
    final words = await loadTriggerWords();
    final matches = <String>[];

    for (final triggerWord in words) {
      if (!triggerWord.enabled) continue;

      final searchText = triggerWord.caseSensitive ? text : text.toLowerCase();
      final word = triggerWord.caseSensitive
          ? triggerWord.word
          : triggerWord.word.toLowerCase();

      if (triggerWord.exactMatch) {
        // Match whole words only
        final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b',
            caseSensitive: triggerWord.caseSensitive);
        if (regex.hasMatch(text)) {
          matches.add(triggerWord.word);
        }
      } else {
        // Substring match
        if (searchText.contains(word)) {
          matches.add(triggerWord.word);
        }
      }
    }

    return matches;
  }

  // Alert management
  Future<List<TriggerAlert>> loadAlerts() async {
    if (_alertsCache != null) return _alertsCache!;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTriggerAlertsKey);
    if (json == null || json.isEmpty) return [];
    try {
      final alerts = _normalizeAlerts(TriggerAlert.decodeList(json));
      _alertsCache = alerts;
      return alerts;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlerts(List<TriggerAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedAlerts = _normalizeAlerts(alerts);
    final json = TriggerAlert.encodeList(normalizedAlerts);
    await prefs.setString(_kTriggerAlertsKey, json);
    _alertsCache = normalizedAlerts;
    _alertsController.add(normalizedAlerts);
  }

  Future<bool> addAlert(TriggerAlert alert) async {
    if (alert.isSoundAlert) {
      final soundKey = alert.normalizedSoundKey;
      if (!_pendingSoundAlertKeys.add(soundKey)) {
        return false;
      }

      try {
        final alerts = List<TriggerAlert>.from(await loadAlerts());
        final alreadySaved = alerts.any(
          (existingAlert) =>
              existingAlert.isSoundAlert &&
              existingAlert.normalizedSoundKey == soundKey,
        );
        if (alreadySaved) return false;

        alerts.insert(0, alert);
        if (alerts.length > AppConstants.alertHistoryMaxItems) {
          alerts.removeRange(AppConstants.alertHistoryMaxItems, alerts.length);
        }
        await saveAlerts(alerts);
        // TODO: Add vibration/haptic feedback for alert trigger.
        return true;
      } finally {
        _pendingSoundAlertKeys.remove(soundKey);
      }
    }

    final alerts = List<TriggerAlert>.from(await loadAlerts());
    alerts.insert(0, alert);
    if (alerts.length > AppConstants.alertHistoryMaxItems) {
      alerts.removeRange(AppConstants.alertHistoryMaxItems, alerts.length);
    }
    await saveAlerts(alerts);
    // TODO: Add vibration/haptic feedback for alert trigger.
    return true;
  }

  Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTriggerAlertsKey);
    _alertsCache = null;
    _alertsController.add([]);
  }

  Future<void> removeAlert(String alertId) async {
    final alerts = await loadAlerts();
    alerts.removeWhere((a) => a.id == alertId);
    await saveAlerts(alerts);
  }

  List<TriggerAlert> _normalizeAlerts(List<TriggerAlert> alerts) {
    final seenSoundAlerts = <String>{};
    final normalized = <TriggerAlert>[];

    for (final alert in alerts) {
      if (!alert.isSoundAlert) {
        normalized.add(alert);
        continue;
      }

      if (seenSoundAlerts.add(alert.normalizedSoundKey)) {
        normalized.add(alert);
      }
    }

    if (normalized.length > AppConstants.alertHistoryMaxItems) {
      normalized.removeRange(
        AppConstants.alertHistoryMaxItems,
        normalized.length,
      );
    }

    return normalized;
  }

  void dispose() {
    _triggerWordsController.close();
    _alertsController.close();
  }
}
