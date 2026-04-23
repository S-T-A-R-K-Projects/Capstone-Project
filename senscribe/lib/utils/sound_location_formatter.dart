import '../models/sound_location_snapshot.dart';
import 'time_utils.dart';

class SoundLocationFormatter {
  SoundLocationFormatter._();

  static String detailsText(SoundLocationSnapshot? location) {
    final snapshot = location ?? const SoundLocationSnapshot.notRecorded();

    switch (snapshot.status) {
      case SoundLocationStatus.available:
        if (!snapshot.hasCoordinates) {
          return 'Location unavailable';
        }

        final buffer = StringBuffer()
          ..writeln(
            'Location: ${_coordinate(snapshot.latitude!)}, '
            '${_coordinate(snapshot.longitude!)}',
          );

        final accuracy = snapshot.accuracyMeters;
        buffer.writeln(
          accuracy == null
              ? 'Accuracy: Unknown'
              : 'Accuracy: +/- ${accuracy.round()} m',
        );

        final capturedAt = snapshot.capturedAt;
        buffer.write(
          capturedAt == null
              ? 'Location captured: Unknown'
              : 'Location captured: ${TimeUtils.formatExactDateTime(capturedAt)}',
        );
        return buffer.toString();
      case SoundLocationStatus.permissionDenied:
        return 'Location permission not given';
      case SoundLocationStatus.servicesDisabled:
        return 'Location services disabled';
      case SoundLocationStatus.unavailable:
        return 'Location unavailable';
      case SoundLocationStatus.notRecorded:
        return 'Location not recorded';
    }
  }

  static String _coordinate(double value) => value.toStringAsFixed(6);
}
