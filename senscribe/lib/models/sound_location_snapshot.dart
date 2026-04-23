enum SoundLocationStatus {
  available('available'),
  permissionDenied('permissionDenied'),
  servicesDisabled('servicesDisabled'),
  unavailable('unavailable'),
  notRecorded('notRecorded');

  const SoundLocationStatus(this.storageValue);

  final String storageValue;

  static SoundLocationStatus fromStorageValue(String? value) {
    return SoundLocationStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => SoundLocationStatus.notRecorded,
    );
  }
}

class SoundLocationSnapshot {
  const SoundLocationSnapshot({
    required this.status,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
  });

  const SoundLocationSnapshot.available({
    required double latitude,
    required double longitude,
    double? accuracyMeters,
    required DateTime capturedAt,
  }) : this(
          status: SoundLocationStatus.available,
          latitude: latitude,
          longitude: longitude,
          accuracyMeters: accuracyMeters,
          capturedAt: capturedAt,
        );

  const SoundLocationSnapshot.permissionDenied()
      : this(status: SoundLocationStatus.permissionDenied);

  const SoundLocationSnapshot.servicesDisabled()
      : this(status: SoundLocationStatus.servicesDisabled);

  const SoundLocationSnapshot.unavailable()
      : this(status: SoundLocationStatus.unavailable);

  const SoundLocationSnapshot.notRecorded()
      : this(status: SoundLocationStatus.notRecorded);

  final SoundLocationStatus status;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;

  bool get hasCoordinates =>
      status == SoundLocationStatus.available &&
      latitude != null &&
      longitude != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': status.storageValue,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        if (capturedAt != null) 'capturedAt': capturedAt!.toIso8601String(),
      };

  factory SoundLocationSnapshot.fromJson(Map<String, dynamic> json) {
    final status = SoundLocationStatus.fromStorageValue(
      json['status'] as String?,
    );
    final latitude = _readDouble(json['latitude']);
    final longitude = _readDouble(json['longitude']);
    final accuracyMeters = _readDouble(json['accuracyMeters']);
    final capturedAt = _readDateTime(json['capturedAt']);

    if (status == SoundLocationStatus.available &&
        (latitude == null || longitude == null || capturedAt == null)) {
      return const SoundLocationSnapshot.unavailable();
    }

    return SoundLocationSnapshot(
      status: status,
      latitude: latitude,
      longitude: longitude,
      accuracyMeters: accuracyMeters,
      capturedAt: capturedAt,
    );
  }

  static SoundLocationSnapshot fromMetadata(
    Map<String, dynamic> metadata,
  ) {
    final rawLocation = metadata['location'];
    if (rawLocation is! Map) {
      return const SoundLocationSnapshot.notRecorded();
    }

    return SoundLocationSnapshot.fromJson(
      Map<String, dynamic>.from(rawLocation),
    );
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
