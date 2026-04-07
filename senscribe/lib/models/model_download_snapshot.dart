class ModelDownloadSnapshot {
  const ModelDownloadSnapshot({
    required this.modelId,
    required this.isRunning,
    required this.progress,
    required this.statusMessage,
    required this.platformCanContinueInBackground,
    this.lastError,
    this.updatedAtMs,
  });

  factory ModelDownloadSnapshot.idle({String modelId = ''}) {
    return ModelDownloadSnapshot(
      modelId: modelId,
      isRunning: false,
      progress: 0,
      statusMessage: '',
      platformCanContinueInBackground: false,
    );
  }

  factory ModelDownloadSnapshot.fromMap(Map<Object?, Object?> map) {
    final progressValue =
        (((map['progress'] as num?) ?? 0).toDouble()).clamp(0.0, 1.0)
            .toDouble();
    return ModelDownloadSnapshot(
      modelId: (map['modelId'] as String?) ?? '',
      isRunning: (map['isRunning'] as bool?) ?? false,
      progress: progressValue,
      statusMessage: (map['statusMessage'] as String?) ?? '',
      platformCanContinueInBackground:
          (map['platformCanContinueInBackground'] as bool?) ?? false,
      lastError: map['lastError'] as String?,
      updatedAtMs: (map['updatedAtMs'] as num?)?.toInt(),
    );
  }

  final String modelId;
  final bool isRunning;
  final double progress;
  final String statusMessage;
  final bool platformCanContinueInBackground;
  final String? lastError;
  final int? updatedAtMs;

  bool get hasError => lastError != null && lastError!.trim().isNotEmpty;
  bool get isComplete => !isRunning && !hasError && progress >= 1.0;

  ModelDownloadSnapshot copyWith({
    String? modelId,
    bool? isRunning,
    double? progress,
    String? statusMessage,
    bool? platformCanContinueInBackground,
    String? lastError,
    bool clearLastError = false,
    int? updatedAtMs,
  }) {
    final nextProgress =
        (progress ?? this.progress).clamp(0.0, 1.0).toDouble();
    return ModelDownloadSnapshot(
      modelId: modelId ?? this.modelId,
      isRunning: isRunning ?? this.isRunning,
      progress: nextProgress,
      statusMessage: statusMessage ?? this.statusMessage,
      platformCanContinueInBackground:
          platformCanContinueInBackground ??
              this.platformCanContinueInBackground,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'modelId': modelId,
      'isRunning': isRunning,
      'progress': progress,
      'statusMessage': statusMessage,
      'platformCanContinueInBackground': platformCanContinueInBackground,
      'lastError': lastError,
      'updatedAtMs': updatedAtMs,
    };
  }
}
