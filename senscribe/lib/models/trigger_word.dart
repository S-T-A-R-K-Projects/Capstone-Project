import 'dart:convert';

class TriggerWord {
  final String word;
  final bool caseSensitive;
  final bool exactMatch; // if true, match whole word only
  final bool enabled;

  const TriggerWord({
    required this.word,
    this.caseSensitive = false,
    this.exactMatch = true,
    this.enabled = true,
  });

  TriggerWord copyWith({
    String? word,
    bool? caseSensitive,
    bool? exactMatch,
    bool? enabled,
  }) {
    return TriggerWord(
      word: word ?? this.word,
      caseSensitive: caseSensitive ?? this.caseSensitive,
      exactMatch: exactMatch ?? this.exactMatch,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'caseSensitive': caseSensitive,
    'exactMatch': exactMatch,
    'enabled': enabled,
  };

  factory TriggerWord.fromJson(Map<String, dynamic> json) => TriggerWord(
    word: json['word'] ?? '',
    caseSensitive: json['caseSensitive'] ?? false,
    exactMatch: json['exactMatch'] ?? true,
    enabled: json['enabled'] ?? true,
  );

  static String encodeList(List<TriggerWord> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<TriggerWord> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed.map((e) => TriggerWord.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TriggerWord &&
          runtimeType == other.runtimeType &&
          word == other.word &&
          caseSensitive == other.caseSensitive &&
          exactMatch == other.exactMatch;

  @override
  int get hashCode =>
      word.hashCode ^ caseSensitive.hashCode ^ exactMatch.hashCode;
}
