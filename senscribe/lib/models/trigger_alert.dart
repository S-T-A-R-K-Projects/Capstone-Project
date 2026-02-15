import 'dart:convert';
import 'package:uuid/uuid.dart';

class TriggerAlert {
  final String id;
  final String triggerWord;
  final String detectedText;
  final DateTime timestamp;
  final String source; // 'text_to_speech', 'audio_classification', etc.

  TriggerAlert({
    String? id,
    required this.triggerWord,
    required this.detectedText,
    DateTime? timestamp,
    required this.source,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggerWord': triggerWord,
    'detectedText': detectedText,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
  };

  factory TriggerAlert.fromJson(Map<String, dynamic> json) => TriggerAlert(
    id: json['id'],
    triggerWord: json['triggerWord'] ?? '',
    detectedText: json['detectedText'] ?? '',
    timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    source: json['source'] ?? 'unknown',
  );

  static String encodeList(List<TriggerAlert> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<TriggerAlert> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed.map((e) => TriggerAlert.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
