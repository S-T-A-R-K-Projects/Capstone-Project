import 'dart:convert';
import 'package:uuid/uuid.dart';

class TriggerAlert {
  static const sourceSpeechToText = 'speech_to_text';
  static const sourceSoundRecognition = 'sound_recognition';
  static const sourceCustomSound = 'custom_sound';

  final String id;
  final String triggerWord;
  final String detectedText;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic> metadata;

  TriggerAlert({
    String? id,
    required this.triggerWord,
    required this.detectedText,
    DateTime? timestamp,
    required this.source,
    this.metadata = const {},
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  bool get isSoundAlert =>
      source == sourceSoundRecognition || source == sourceCustomSound;

  String get soundDetectorLabel {
    final label = metadata['detectorLabel'];
    if (label is String && label.trim().isNotEmpty) return label;
    if (source == sourceCustomSound) return 'Custom sound';
    return 'Built-in sound';
  }

  int? get soundConfidencePercent {
    final confidence = metadata['confidencePercent'];
    if (confidence is num) {
      return confidence.round().clamp(0, 100);
    }

    final match = RegExp(
      r'(\d{1,3})% confidence',
      caseSensitive: false,
    ).firstMatch(detectedText);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  String get soundPriorityLabel {
    final priority = metadata['priorityLabel'];
    if (priority is String && priority.trim().isNotEmpty) return priority;

    final isCritical = metadata['isCritical'];
    if (isCritical is bool) {
      return isCritical ? 'Critical' : 'Standard';
    }

    return detectedText.toLowerCase().contains('critical priority')
        ? 'Critical'
        : 'Standard';
  }

  String get normalizedSoundKey =>
      '${source.trim().toLowerCase()}:'
      '${triggerWord.trim().toLowerCase()}:'
      '${timestamp.toIso8601String()}';

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggerWord': triggerWord,
    'detectedText': detectedText,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
    'metadata': metadata,
  };

  factory TriggerAlert.fromJson(Map<String, dynamic> json) => TriggerAlert(
    id: json['id'],
    triggerWord: json['triggerWord'] ?? '',
    detectedText: json['detectedText'] ?? '',
    timestamp: DateTime.parse(
      json['timestamp'] ?? DateTime.now().toIso8601String(),
    ),
    source: json['source'] ?? 'unknown',
    metadata: Map<String, dynamic>.from(json['metadata'] ?? const {}),
  );

  static String encodeList(List<TriggerAlert> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<TriggerAlert> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed
        .map((e) => TriggerAlert.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
