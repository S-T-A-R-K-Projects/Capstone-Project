import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../models/history_item.dart';

class HistoryService {
  static const _kKey = 'history_items_v1';

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

  Future<void> add(HistoryItem item) async {
    final items = await loadHistory();
    items.insert(0, item); // newest first
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
