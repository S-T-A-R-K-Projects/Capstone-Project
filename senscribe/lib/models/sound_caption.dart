enum SoundCaptionSource { builtIn, custom }

class SoundCaption {
  final String sound;
  final DateTime timestamp;
  final bool isCritical;
  final String direction;
  final double confidence;
  final SoundCaptionSource source;
  final String? customSoundId;

  SoundCaption({
    required this.sound,
    required this.timestamp,
    required this.isCritical,
    required this.direction,
    required this.confidence,
    this.source = SoundCaptionSource.builtIn,
    this.customSoundId,
  });
}
