import 'dart:async';

class SttTranscriptSnapshot {
  final List<String> finalizedSegments;
  final String partialWords;

  const SttTranscriptSnapshot({
    required this.finalizedSegments,
    required this.partialWords,
  });

  String get finalizedText => finalizedSegments.join(' ').trim();

  String get fullText {
    final finalized = finalizedText;
    final partial = partialWords.trim();
    if (finalized.isEmpty) return partial;
    if (partial.isEmpty) return finalized;
    return '$finalized $partial';
  }

  bool get hasContent => fullText.isNotEmpty;

  static const SttTranscriptSnapshot empty = SttTranscriptSnapshot(
    finalizedSegments: [],
    partialWords: '',
  );
}

class SttTranscriptService {
  static final SttTranscriptService _instance =
      SttTranscriptService._internal();
  factory SttTranscriptService() => _instance;
  SttTranscriptService._internal();

  final _controller = StreamController<SttTranscriptSnapshot>.broadcast();

  SttTranscriptSnapshot _snapshot = SttTranscriptSnapshot.empty;

  Stream<SttTranscriptSnapshot> get stream => _controller.stream;
  SttTranscriptSnapshot get current => _snapshot;

  void setPartialWords(String words) {
    final nextWords = words.trim();
    if (_snapshot.partialWords == nextWords) return;
    _snapshot = SttTranscriptSnapshot(
      finalizedSegments: _snapshot.finalizedSegments,
      partialWords: nextWords,
    );
    _emit();
  }

  void commitFinalWords(String words) {
    final nextWords = words.trim();
    if (nextWords.isEmpty) return;
    _snapshot = SttTranscriptSnapshot(
      finalizedSegments: [..._snapshot.finalizedSegments, nextWords],
      partialWords: '',
    );
    _emit();
  }

  void clear() {
    _snapshot = SttTranscriptSnapshot.empty;
    _emit();
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(_snapshot);
    }
  }

  void dispose() {
    _controller.close();
  }
}
