import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../models/history_item.dart';

class HistoryService {
  static const _kKey = 'history_items_v1';
  static const _kCounterKey = 'history_text_counter_v1';

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
  }

  Future<void> update(HistoryItem item) async {
    final items = await loadHistory();
    final index = items.indexWhere((e) => e.id == item.id);
    if (index == -1) return;
    items[index] = item;
    await saveHistory(items);
  }

  Future<void> remove(String id) async {
    final items = await loadHistory();
    items.removeWhere((e) => e.id == id);
    await saveHistory(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}
