import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../models/history_item.dart';

class HistoryService {
  static const _kKey = 'history_items_v1';
  static const _kCounterKey = 'history_text_counter_v1';

  // Singleton pattern
  static final HistoryService _instance = HistoryService._internal();
  factory HistoryService() => _instance;
  HistoryService._internal();

  // Stream controller to notify listeners of changes
  final _changeController = StreamController<void>.broadcast();

  /// Stream that emits when history data changes
  Stream<void> get onHistoryChanged => _changeController.stream;

  /// Notify listeners that history has changed
  void _notifyChange() {
    _changeController.add(null);
  }

  Future<List<HistoryItem>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_kKey);
    if (json == null || json.isEmpty) return [];
    try {
      return HistoryItem.decodeList(json);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveHistory(List<HistoryItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final json = HistoryItem.encodeList(items);
    await prefs.setString(_kKey, json);
  }

  Future<int> nextTextIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final next = (prefs.getInt(_kCounterKey) ?? 0) + 1;
    await prefs.setInt(_kCounterKey, next);
    return next;
  }

  Future<void> add(HistoryItem item) async {
    final items = await loadHistory();
    items.insert(0, item); // newest first
    await saveHistory(items);
    _notifyChange();
  }

  Future<void> update(HistoryItem item) async {
    final items = await loadHistory();
    final index = items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    items[index] = item;
    await saveHistory(items);
    _notifyChange();
  }

  Future<void> remove(String id) async {
    final items = await loadHistory();
    items.removeWhere((e) => e.id == id);
    await saveHistory(items);
    _notifyChange();
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
    _notifyChange();
  }

  /// Update the summary for a history item
  ///
  /// [id] - The ID of the history item to update
  /// [summary] - The generated summary text
  Future<void> updateSummary(String id, String summary) async {
    final items = await loadHistory();
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return;

    items[index] = items[index].copyWith(
      summary: summary,
      summaryTimestamp: DateTime.now(),
    );
    await saveHistory(items);
    _notifyChange();
  }

  /// Get a specific history item by ID
  Future<HistoryItem?> getById(String id) async {
    final items = await loadHistory();
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return null;
    return items[index];
  }

  /// Clear the summary for a history item
  Future<void> clearSummary(String id) async {
    final items = await loadHistory();
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return;

    // Create new item without summary
    final item = items[index];
    items[index] = HistoryItem(
      id: item.id,
      title: item.title,
      subtitle: item.subtitle,
      content: item.content,
      timestamp: item.timestamp,
      metadata: item.metadata,
      summary: null,
      summaryTimestamp: null,
    );
    await saveHistory(items);
    _notifyChange();
  }
}
