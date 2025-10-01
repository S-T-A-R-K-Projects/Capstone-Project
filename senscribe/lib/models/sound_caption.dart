class SoundCaption {
  final String sound;
  final DateTime timestamp;
  final bool isCritical;
  final String direction;
  final double confidence;

  SoundCaption({
    required this.sound,
    required this.timestamp,
    required this.isCritical,
    required this.direction,
    required this.confidence,
  });
}