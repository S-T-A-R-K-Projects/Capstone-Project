import 'dart:convert';

enum CustomSoundProfileStatus {
  draft,
  recording,
  training,
  ready,
  failed,
}

extension CustomSoundProfileStatusX on CustomSoundProfileStatus {
  String get value => switch (this) {
        CustomSoundProfileStatus.draft => 'draft',
        CustomSoundProfileStatus.recording => 'recording',
        CustomSoundProfileStatus.training => 'training',
        CustomSoundProfileStatus.ready => 'ready',
        CustomSoundProfileStatus.failed => 'failed',
      };

  static CustomSoundProfileStatus fromValue(String? value) {
    return CustomSoundProfileStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => CustomSoundProfileStatus.draft,
    );
  }
}

class CustomSoundProfile {
  final String id;
  final String name;
  final bool enabled;
  final CustomSoundProfileStatus status;
  final List<String> targetSamplePaths;
  final List<String> backgroundSamplePaths;
  final DateTime updatedAt;
  final String? lastError;

  const CustomSoundProfile({
    required this.id,
    required this.name,
    this.enabled = true,
    this.status = CustomSoundProfileStatus.draft,
    this.targetSamplePaths = const [],
    this.backgroundSamplePaths = const [],
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  int get targetSampleCount => targetSamplePaths.length;
  int get backgroundSampleCount => backgroundSamplePaths.length;
  bool get hasBackgroundSample => backgroundSamplePaths.isNotEmpty;
  bool get hasEnoughSamples => targetSampleCount >= 3;

  CustomSoundProfile copyWith({
    String? id,
    String? name,
    bool? enabled,
    CustomSoundProfileStatus? status,
    List<String>? targetSamplePaths,
    List<String>? backgroundSamplePaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return CustomSoundProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      targetSamplePaths: targetSamplePaths ?? this.targetSamplePaths,
      backgroundSamplePaths:
          backgroundSamplePaths ?? this.backgroundSamplePaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'status': status.value,
        'targetSamplePaths': targetSamplePaths,
        'backgroundSamplePaths': backgroundSamplePaths,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'lastError': lastError,
      };

  factory CustomSoundProfile.fromJson(Map<String, dynamic> json) {
    return CustomSoundProfile(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      enabled: json['enabled'] as bool? ?? true,
      status: CustomSoundProfileStatusX.fromValue(json['status'] as String?),
      targetSamplePaths: (json['targetSamplePaths'] as List<dynamic>? ?? [])
          .map((path) => path.toString())
          .toList(growable: false),
      backgroundSamplePaths:
          (json['backgroundSamplePaths'] as List<dynamic>? ?? [])
              .map((path) => path.toString())
              .toList(growable: false),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      lastError: json['lastError'] as String?,
    );
  }

  static String encodeList(List<CustomSoundProfile> items) =>
      jsonEncode(items.map((item) => item.toJson()).toList());

  static List<CustomSoundProfile> decodeList(String jsonStr) {
    final parsed = jsonDecode(jsonStr) as List<dynamic>?;
    if (parsed == null) return [];
    return parsed
        .map((entry) =>
            CustomSoundProfile.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }
}
