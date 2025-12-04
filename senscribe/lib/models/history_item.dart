import 'dart:convert';

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
        metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      );

  static String encodeList(List<HistoryItem> items) => jsonEncode(items.map((e) => e.toJson()).toList());
  static List<HistoryItem> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed.map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
