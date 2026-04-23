import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../models/sound_location_snapshot.dart';

class SoundLocationMapLauncher {
  SoundLocationMapLauncher._();

  static Uri? uriFor(SoundLocationSnapshot location) {
    if (!location.hasCoordinates) return null;

    final latitude = location.latitude!;
    final longitude = location.longitude!;
    final coordinatePair = '$latitude,$longitude';

    if (Platform.isIOS) {
      return Uri.https('maps.apple.com', '/', <String, String>{
        'll': coordinatePair,
        'q': coordinatePair,
      });
    }

    return Uri.parse('geo:$coordinatePair?q=$coordinatePair');
  }

  static Future<bool> open(SoundLocationSnapshot location) async {
    final uri = uriFor(location);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
