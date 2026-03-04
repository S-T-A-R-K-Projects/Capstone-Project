import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/services.dart';

import '../models/trigger_word.dart';
import '../models/trigger_alert.dart';
import '../utils/app_constants.dart';

// service helpers
import 'notification_service.dart';
import 'live_activity_service.dart';

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

  Future<List<TriggerWord>> loadTriggerWords() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTriggerWordsKey);
    if (json == null || json.isEmpty) return [];
    try {
      return TriggerWord.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTriggerWords(List<TriggerWord> words) async {
    final prefs = await SharedPreferences.getInstance();
    final json = TriggerWord.encodeList(words);
    await prefs.setString(_kTriggerWordsKey, json);
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
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kTriggerAlertsKey);
    if (json == null || json.isEmpty) return [];
    try {
      return TriggerAlert.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAlerts(List<TriggerAlert> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final json = TriggerAlert.encodeList(alerts);
    await prefs.setString(_kTriggerAlertsKey, json);
    _alertsController.add(alerts);
  }

  Future<void> addAlert(TriggerAlert alert) async {
    final alerts = await loadAlerts();
    alerts.insert(0, alert);
    if (alerts.length > AppConstants.alertHistoryMaxItems) {
      alerts.removeRange(AppConstants.alertHistoryMaxItems, alerts.length);
    }
    await saveAlerts(alerts);

    // give the user immediate haptic feedback so they feel the alert even if
    // notifications are suppressed/turned off at the system level.
    HapticFeedback.vibrate();

    // show a local notification as well.
    try {
      NotificationService.instance.showAlertNotification(
        'Trigger word detected',
        alert.triggerWord,
      );
    } catch (e) {
      debugPrint('could not show notification: $e');
    }

    // update live activity so the dynamic island/lockscreen shows the latest
    // word.  service will no-op if live activities are not supported.
    try {
      await LiveActivityService.instance.createOrUpdate(alert.triggerWord);
    } catch (e) {
      debugPrint('could not update live activity: $e');
    }
  }

  Future<void> clearAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kTriggerAlertsKey);
    _alertsController.add([]);

    // when the history is wiped we no longer have an active trigger word –
    // terminating any live activity keeps the UI in sync.
    try {
      await LiveActivityService.instance.endAll();
    } catch (_) {}
  }

  Future<void> removeAlert(String alertId) async {
    final alerts = await loadAlerts();
    alerts.removeWhere((a) => a.id == alertId);
    await saveAlerts(alerts);
  }

  void dispose() {
    _triggerWordsController.close();
    _alertsController.close();
  }
}
