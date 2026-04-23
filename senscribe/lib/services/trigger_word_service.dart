import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/trigger_word.dart';
import '../models/trigger_alert.dart';
import '../utils/app_constants.dart';

class TriggerWordService {
  static const _kTriggerWordsKey = 'trigger_words_v1';
  static const _kTriggerAlertsKey = 'trigger_alerts_v1';
  static const MethodChannel _feedbackChannel = MethodChannel(
    'senscribe/alert_feedback',
  );

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

  Future<void> warmCache() async {
    await loadTriggerWords();
  }

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

  String refineRecognizedText(String text) {
    final trimmed = text.trim();
    final words = _triggerWordsCache;
    if (trimmed.isEmpty || words == null || words.isEmpty) {
      return trimmed;
    }

    final transcriptTokens = _tokenize(trimmed);
    if (transcriptTokens.isEmpty) {
      return trimmed;
    }

    final correctedTokens = List<String>.from(transcriptTokens);
    final reserved = List<bool>.filled(correctedTokens.length, false);
    final candidates = words
        .where((word) => word.enabled && word.exactMatch)
        .map(
          (word) => _PhraseCandidate(
            displayText: word.word.trim(),
            normalizedTokens: _tokenize(word.word),
          ),
        )
        .where((candidate) => candidate.normalizedTokens.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final tokenCompare =
            b.normalizedTokens.length.compareTo(a.normalizedTokens.length);
        if (tokenCompare != 0) {
          return tokenCompare;
        }
        return b.displayText.length.compareTo(a.displayText.length);
      });

    for (final candidate in candidates) {
      final phraseLength = candidate.normalizedTokens.length;
      if (phraseLength > correctedTokens.length) {
        continue;
      }

      for (var start = 0;
          start <= correctedTokens.length - phraseLength;
          start++) {
        if (_windowContainsReserved(reserved, start, phraseLength)) {
          continue;
        }

        final window = correctedTokens.sublist(start, start + phraseLength);
        if (!_isPhraseMatch(window, candidate.normalizedTokens)) {
          continue;
        }

        correctedTokens[start] = candidate.displayText;
        for (var index = start + 1; index < start + phraseLength; index++) {
          correctedTokens[index] = '';
        }
        for (var index = start; index < start + phraseLength; index++) {
          reserved[index] = true;
        }
      }
    }

    return correctedTokens.where((token) => token.isNotEmpty).join(' ').trim();
  }

  /// Check if text contains any trigger words and return matches
  Future<List<String>> checkForTriggers(String text) async {
    final words = await loadTriggerWords();
    final refinedText = refineRecognizedText(text);
    final matches = <String>[];

    for (final triggerWord in words) {
      if (!triggerWord.enabled) continue;

      final sourceText = triggerWord.exactMatch ? refinedText : text;
      final searchText =
          triggerWord.caseSensitive ? sourceText : sourceText.toLowerCase();
      final word = triggerWord.caseSensitive
          ? triggerWord.word
          : triggerWord.word.toLowerCase();

      if (triggerWord.exactMatch) {
        // Match whole words only
        final regex = RegExp(r'\b' + RegExp.escape(word) + r'\b',
            caseSensitive: triggerWord.caseSensitive);
        if (regex.hasMatch(sourceText)) {
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

  bool _windowContainsReserved(List<bool> reserved, int start, int length) {
    for (var index = start; index < start + length; index++) {
      if (reserved[index]) {
        return true;
      }
    }
    return false;
  }

  bool _isPhraseMatch(List<String> observedTokens, List<String> targetTokens) {
    if (observedTokens.length != targetTokens.length ||
        observedTokens.isEmpty) {
      return false;
    }

    if (_tokensEqual(observedTokens, targetTokens)) {
      return true;
    }

    if (observedTokens.length == 1) {
      return _isSingleTokenFuzzyMatch(observedTokens.first, targetTokens.first);
    }

    final observedPhrase = observedTokens.join(' ');
    final targetPhrase = targetTokens.join(' ');
    final phraseSimilarity = _similarity(observedPhrase, targetPhrase);
    if (phraseSimilarity < 0.82) {
      return false;
    }

    var strongTokenMatches = 0;
    for (var index = 0; index < observedTokens.length; index++) {
      final observed = observedTokens[index];
      final target = targetTokens[index];
      if (observed == target) {
        strongTokenMatches++;
        continue;
      }
      if (!_isSingleTokenFuzzyMatch(observed, target)) {
        return false;
      }
      strongTokenMatches++;
    }

    return strongTokenMatches == observedTokens.length;
  }

  bool _isSingleTokenFuzzyMatch(String observed, String target) {
    if (observed == target) {
      return true;
    }
    if (observed.length < 4 || target.length < 4) {
      return false;
    }
    if (observed[0] != target[0]) {
      return false;
    }
    if ((observed.length - target.length).abs() > 2) {
      return false;
    }
    return _similarity(observed, target) >= 0.84;
  }

  bool _tokensEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  List<String> _tokenize(String text) {
    final expression = RegExp(r"[a-z0-9']+");
    return expression
        .allMatches(text.toLowerCase())
        .map((match) => match.group(0) ?? '')
        .where((token) => token.isNotEmpty)
        .toList();
  }

  double _similarity(String left, String right) {
    final maxLength = left.length > right.length ? left.length : right.length;
    if (maxLength == 0) {
      return 1.0;
    }
    final distance = _levenshteinDistance(left, right);
    return 1.0 - (distance / maxLength);
  }

  int _levenshteinDistance(String left, String right) {
    if (left == right) {
      return 0;
    }
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }

    final previous = List<int>.generate(right.length + 1, (index) => index);
    final current = List<int>.filled(right.length + 1, 0);

    for (var leftIndex = 0; leftIndex < left.length; leftIndex++) {
      current[0] = leftIndex + 1;
      for (var rightIndex = 0; rightIndex < right.length; rightIndex++) {
        final substitutionCost = left[leftIndex] == right[rightIndex] ? 0 : 1;
        current[rightIndex + 1] = [
          current[rightIndex] + 1,
          previous[rightIndex + 1] + 1,
          previous[rightIndex] + substitutionCost,
        ].reduce((value, element) => value < element ? value : element);
      }

      for (var index = 0; index < current.length; index++) {
        previous[index] = current[index];
      }
    }

    return previous.last;
  }

  Future<void> playTriggerDetectedFeedback() async {
    try {
      await _feedbackChannel.invokeMethod<void>('playTriggerAlertFeedback');
    } on MissingPluginException {
      await _fallbackFeedback();
    } catch (_) {
      await _fallbackFeedback();
    }
  }

  Future<void> _fallbackFeedback() async {
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {
      // Ignore unsupported-platform or platform-channel failures.
    }
  }
}

class _PhraseCandidate {
  const _PhraseCandidate({
    required this.displayText,
    required this.normalizedTokens,
  });

  final String displayText;
  final List<String> normalizedTokens;
}
