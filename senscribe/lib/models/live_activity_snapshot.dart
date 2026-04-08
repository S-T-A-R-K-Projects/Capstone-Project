class LiveActivitySnapshot {
  static const int unsetIntValue = -1;
  static const String unsetStringValue = '';

  const LiveActivitySnapshot({
    required this.status,
    required this.startedAtMs,
    this.lastDetectedIdentifier,
    this.lastDetectedLabel,
    this.lastDetectedConfidencePercent,
    this.lastDetectedAtMs,
  });

  final LiveActivityStatus status;
  final int startedAtMs;
  final String? lastDetectedIdentifier;
  final String? lastDetectedLabel;
  final int? lastDetectedConfidencePercent;
  final int? lastDetectedAtMs;

  LiveActivitySnapshot copyWith({
    LiveActivityStatus? status,
    int? startedAtMs,
    String? lastDetectedIdentifier,
    String? lastDetectedLabel,
    int? lastDetectedConfidencePercent,
    int? lastDetectedAtMs,
    bool clearLastDetectedIdentifier = false,
    bool clearLastDetectedLabel = false,
    bool clearLastDetectedConfidencePercent = false,
    bool clearLastDetectedAtMs = false,
  }) {
    return LiveActivitySnapshot(
      status: status ?? this.status,
      startedAtMs: startedAtMs ?? this.startedAtMs,
      lastDetectedIdentifier: clearLastDetectedIdentifier
          ? null
          : lastDetectedIdentifier ?? this.lastDetectedIdentifier,
      lastDetectedLabel: clearLastDetectedLabel
          ? null
          : lastDetectedLabel ?? this.lastDetectedLabel,
      lastDetectedConfidencePercent: clearLastDetectedConfidencePercent
          ? null
          : lastDetectedConfidencePercent ?? this.lastDetectedConfidencePercent,
      lastDetectedAtMs: clearLastDetectedAtMs
          ? null
          : lastDetectedAtMs ?? this.lastDetectedAtMs,
    );
  }

  Map<String, dynamic> toActivityData() {
    return <String, dynamic>{
      'status': status.value,
      'startedAtMs': startedAtMs,
      'lastDetectedIdentifier': lastDetectedIdentifier ?? unsetStringValue,
      'lastDetectedLabel': lastDetectedLabel ?? unsetStringValue,
      'lastDetectedConfidencePercent':
          lastDetectedConfidencePercent ?? unsetIntValue,
      'lastDetectedAtMs': lastDetectedAtMs ?? unsetIntValue,
    };
  }
}

enum LiveActivityStatus {
  listening('listening'),
  detected('detected');

  const LiveActivityStatus(this.value);

  final String value;
}
