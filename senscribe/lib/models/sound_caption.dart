import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'sound_location_snapshot.dart';

enum SoundCaptionSource { builtIn, custom }

class SoundCaption {
  final String sound;
  final DateTime timestamp;
  final bool isCritical;
  final double confidence;
  final SoundCaptionSource source;
  final String? customSoundId;
  final SoundLocationSnapshot? location;

  SoundCaption({
    required this.sound,
    required this.timestamp,
    required this.isCritical,
    required this.confidence,
    this.source = SoundCaptionSource.builtIn,
    this.customSoundId,
    this.location,
  });

  SoundCaption copyWith({
    SoundLocationSnapshot? location,
  }) {
    return SoundCaption(
      sound: sound,
      timestamp: timestamp,
      isCritical: isCritical,
      confidence: confidence,
      source: source,
      customSoundId: customSoundId,
      location: location ?? this.location,
    );
  }

  static final RegExp _displaySoundPattern = RegExp(r'[_\-\s]+');

  late final String displaySound = _computeDisplaySound();

  String _computeDisplaySound() {
    final normalized = sound.trim().replaceAll(_displaySoundPattern, ' ');
    return normalized.isEmpty ? 'Unknown' : normalized;
  }
}

extension SoundCaptionIcon on SoundCaption {
  IconData get icon {
    if (isCritical) return Icons.warning_amber_rounded;

    final identifier = sound.toLowerCase().trim().replaceAll(' ', '_');

    switch (identifier) {
      case 'alarm_clock':
      case 'fire_alarm':
      case 'smoke_alarm':
      case 'door_bell':
      case 'bell':
      case 'church_bell':
      case 'chime':
      case 'bicycle_bell':
        return Icons.notifications_active_rounded;
      case 'ambulance_siren':
      case 'civil_defense_siren':
      case 'emergency_vehicle':
      case 'fire_engine_siren':
      case 'gunshot':
      case 'glass_breaking':
        return Icons.warning_rounded;
      case 'speech':
      case 'babble':
      case 'chatter':
      case 'crowd':
      case 'children_shouting':
      case 'choir_singing':
        return CupertinoIcons.quote_bubble_fill;
      case 'dog':
      case 'dog_bark':
      case 'dog_growl':
      case 'dog_howl':
      case 'cat':
      case 'cat_meow':
      case 'baby_crying':
        return Icons.pets_rounded;
      case 'car_horn':
      case 'car_passing_by':
      case 'engine':
      case 'engine_accelerating_revving':
      case 'engine_idling':
      case 'engine_starting':
        return Icons.directions_car_rounded;
      case 'aircraft':
      case 'airplane':
        return Icons.flight_rounded;
      case 'fire':
      case 'fire_crackle':
        return Icons.local_fire_department_rounded;
      default:
        return Icons.graphic_eq_rounded;
    }
  }
}
