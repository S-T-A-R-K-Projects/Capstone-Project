import 'dart:convert';

class HistoryItem {
  final String id;
  final String title;
  final String subtitle;
  final String content;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  // Summary fields for on-device LLM summarization
  final String? summary;
  final DateTime? summaryTimestamp;

  HistoryItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.timestamp,
    this.metadata = const {},
    this.summary,
    this.summaryTimestamp,
  });

  HistoryItem copyWith({
    String? title,
    String? subtitle,
    String? content,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    String? summary,
    DateTime? summaryTimestamp,
  }) {
    return HistoryItem(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      summary: summary ?? this.summary,
      summaryTimestamp: summaryTimestamp ?? this.summaryTimestamp,
    );
  }

  /// Check if this item has been summarized
  bool get hasSummary => summary != null && summary!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'summary': summary,
    'summaryTimestamp': summaryTimestamp?.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    subtitle: json['subtitle'] ?? '',
    content: json['content'] ?? json['title'] ?? '',
    timestamp: DateTime.parse(
      json['timestamp'] ?? DateTime.now().toIso8601String(),
    ),
    metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    summary: json['summary'],
    summaryTimestamp: json['summaryTimestamp'] != null
        ? DateTime.parse(json['summaryTimestamp'])
        : null,
  );

  static String encodeList(List<HistoryItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<HistoryItem> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed
        .map((e) => HistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
