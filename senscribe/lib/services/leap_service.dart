import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_leap_sdk/flutter_leap_sdk.dart';

/// Service to handle interactions with the Liquid AI Leap SDK.
/// Uses `flutter_leap_sdk` wrapper.
class LeapService {
  static const String defaultModelId =
      'LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle';
  static const String defaultModelDisplayName = 'LFM2.5-1.2B-Instruct Q8_0';

  static const int _chunkTokenSize = 1200;
  static const int _chunkOverlapTokens = 150;
  static const double _wordPerToken = 0.75;
  static const Duration _autoUnloadDelay = Duration(seconds: 3);

  static const double _summaryTemperature = 0.3;
  static const int _chunkSummaryMaxTokens = 150;
  static const int _finalSummaryMaxTokens = 300;
  static const Duration _chunkGenerationTimeout = Duration(seconds: 45);
  static const Duration _finalGenerationTimeout = Duration(seconds: 75);

  // Singleton instance
  static final LeapService _instance = LeapService._internal();

  factory LeapService() => _instance;

  LeapService._internal();

  Timer? _unloadTimer;
  bool _isModelLoaded = false;
  String? _loadedModelId;
  bool _isSummarizationInProgress = false;

  /// Checks if the model is locally cached.
  Future<bool> isModelCached(String modelId) async {
    try {
      return await FlutterLeapSdkService.checkModelExists(
        _resolveModelId(modelId),
      );
    } catch (e) {
      debugPrint('LeapService: Error checking model cache: $e');
      return false;
    }
  }

  /// Downloads and queues the model for loading.
  /// Loads the managed model by ID.
  Future<void> loadModel(
    String modelId, {
    Function(double)? onProgress,
  }) async {
    await _ensureModelLoaded(modelId);
  }

  Future<String> summarizeLargeText(
    String transcript, {
    String modelId = defaultModelId,
  }) async {
    if (_isSummarizationInProgress) {
      throw LeapServiceException(
        'Another summarization is already in progress. Please wait and try again.',
      );
    }

    _isSummarizationInProgress = true;
    _cancelAutoUnload();

    if (transcript.trim().isEmpty) {
      _isSummarizationInProgress = false;
      throw LeapServiceException('Transcript is empty. Nothing to summarize.');
    }

    try {
      final resolvedModelId = _resolveModelId(modelId);
      await _ensureModelLoaded(resolvedModelId);
      final chunks = _splitIntoChunks(transcript);

      debugPrint(
        'LeapService: Starting map-reduce summarization for ${chunks.length} chunks.',
      );

      final chunkSummaries = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final summary = await _summarizeChunk(
          chunkText: chunks[i],
          sectionIndex: i + 1,
          totalSections: chunks.length,
          modelId: resolvedModelId,
        );
        chunkSummaries.add(summary);
      }

      return await _buildFinalSummary(chunkSummaries, modelId: resolvedModelId);
    } catch (e) {
      debugPrint('LeapService: summarizeLargeText failed: $e');
      throw LeapServiceException('Summarization failed. Please try again. $e');
    } finally {
      _isSummarizationInProgress = false;
      _scheduleAutoUnload();
    }
  }

  Stream<String> summarizeLargeTextStream(
    String transcript, {
    String modelId = defaultModelId,
  }) async* {
    if (_isSummarizationInProgress) {
      throw LeapServiceException(
        'Another summarization is already in progress. Please wait and try again.',
      );
    }

    _isSummarizationInProgress = true;
    _cancelAutoUnload();

    if (transcript.trim().isEmpty) {
      _isSummarizationInProgress = false;
      throw LeapServiceException('Transcript is empty. Nothing to summarize.');
    }

    try {
      final resolvedModelId = _resolveModelId(modelId);
      await _ensureModelLoaded(resolvedModelId);
      final chunks = _splitIntoChunks(transcript);
      final chunkSummaries = <String>[];

      for (var i = 0; i < chunks.length; i++) {
        final section = i + 1;
        yield 'Processing section $section of ${chunks.length}...\n';

        final summary = await _summarizeChunk(
          chunkText: chunks[i],
          sectionIndex: section,
          totalSections: chunks.length,
          modelId: resolvedModelId,
        );
        chunkSummaries.add(summary);
      }

      yield 'Combining section summaries...\n';
      final combinedSummary = await _buildFinalSummary(
        chunkSummaries,
        modelId: resolvedModelId,
      );
      yield* _emitSummaryAsStream(combinedSummary);
    } catch (e) {
      debugPrint('LeapService: summarizeLargeTextStream failed: $e');
      throw LeapServiceException('Summarization failed. Please try again. $e');
    } finally {
      _isSummarizationInProgress = false;
      _scheduleAutoUnload();
    }
  }

  Future<void> _ensureModelLoaded(String requestedModelId) async {
    final modelId = _resolveModelId(requestedModelId);

    if (_isModelLoaded && _loadedModelId == modelId) {
      debugPrint('LeapService: Model already loaded: $modelId');
      return;
    }

    if (_isModelLoaded && _loadedModelId != modelId) {
      debugPrint(
        'LeapService: Switching model from $_loadedModelId to $modelId',
      );
      await forceUnload();
    }

    final exists = await isModelCached(modelId);
    if (!exists) {
      throw LeapServiceException(
        'Model is not downloaded on this device. Please download it in Model Settings.',
      );
    }

    debugPrint('LeapService: Loading model: $modelId');

    try {
      await FlutterLeapSdkService.loadModel(modelPath: modelId);
      _isModelLoaded = true;
      _loadedModelId = modelId;
      debugPrint('LeapService: Model loaded successfully: $modelId');
    } catch (e) {
      debugPrint('LeapService: Failed to load model: $e');
      _isModelLoaded = false;
      _loadedModelId = null;
      throw LeapServiceException('Failed to load model. $e');
    }
  }

  /// Helper to check if a model is currently loaded in memory
  bool get isModelLoaded => _isModelLoaded;

  /// Generates a response stream for the given prompt.
  /// Ensures the model is loaded before generating.
  Stream<String> generateStream(
    String prompt, {
    String modelId = defaultModelId,
  }) async* {
    await _ensureModelLoaded(modelId);

    final conversation = await FlutterLeapSdkService.createConversation(
      systemPrompt:
          'You summarize text faithfully. Keep key facts, names, dates, and intent intact.',
      generationOptions: GenerationOptions(
        temperature: _summaryTemperature,
        maxTokens: _finalSummaryMaxTokens,
      ),
    );

    try {
      yield* conversation.generateResponseStream(prompt);
    } finally {
      await _disposeConversation(conversation);
      _scheduleAutoUnload();
    }
  }

  Future<void> forceUnload() async {
    _cancelAutoUnload();

    if (!_isModelLoaded) {
      return;
    }

    try {
      await FlutterLeapSdkService.unloadModel();
      debugPrint('LeapService: Model unloaded.');
    } catch (e) {
      debugPrint('LeapService: unloadModel failed: $e');
      throw LeapServiceException('Failed to unload model. $e');
    } finally {
      _isModelLoaded = false;
      _loadedModelId = null;
    }
  }

  Future<String> _summarizeChunk({
    required String chunkText,
    required int sectionIndex,
    required int totalSections,
    required String modelId,
  }) async {
    final prompt = '''
Summarize section $sectionIndex of $totalSections in 50-100 words.

Requirements:
- Preserve key facts, entities, and important actions.
- If the text is noisy or contains errors, infer intent conservatively.
- Return plain text only.

Section text:
$chunkText
''';

    for (var attempt = 1; attempt <= 2; attempt++) {
      debugPrint(
        'LeapService: Summarizing chunk $sectionIndex/$totalSections attempt $attempt (${chunkText.length} chars).',
      );

      final conversation = await FlutterLeapSdkService.createConversation(
        systemPrompt:
            'You are a precise summarizer. Handle spelling, grammar, and formatting errors gracefully.',
        generationOptions: GenerationOptions(
          temperature: _summaryTemperature,
          maxTokens: _chunkSummaryMaxTokens,
        ),
      );

      try {
        final summary = (await conversation
                .generateResponse(prompt)
                .timeout(_chunkGenerationTimeout))
            .trim();
        if (summary.isEmpty) {
          throw LeapServiceException(
            'Received an empty chunk summary for section $sectionIndex.',
          );
        }
        return summary;
      } catch (e) {
        final shouldRetry = attempt < 2 && _isRecoverableGenerationStop(e);
        debugPrint(
          'LeapService: Chunk $sectionIndex/$totalSections failed on attempt $attempt: $e',
        );

        if (shouldRetry) {
          await _recoverModelAfterStop(modelId);
          continue;
        }

        throw LeapServiceException(
          'Failed while processing section $sectionIndex of $totalSections. $e',
        );
      } finally {
        await _disposeConversation(conversation);
      }
    }

    throw LeapServiceException(
      'Failed while processing section $sectionIndex of $totalSections.',
    );
  }

  Future<String> _buildFinalSummary(
    List<String> chunkSummaries, {
    required String modelId,
  }) async {
    final prompt = _createFinalPrompt(chunkSummaries);

    for (var attempt = 1; attempt <= 2; attempt++) {
      final conversation = await FlutterLeapSdkService.createConversation(
        systemPrompt:
            'You produce concise, factual summaries from multiple section summaries.',
        generationOptions: GenerationOptions(
          temperature: _summaryTemperature,
          maxTokens: _finalSummaryMaxTokens,
        ),
      );

      try {
        final response = (await conversation
                .generateResponse(prompt)
                .timeout(_finalGenerationTimeout))
            .trim();
        if (response.isEmpty) {
          throw LeapServiceException(
              'Final summary generation returned empty text.');
        }
        return response;
      } catch (e) {
        final shouldRetry = attempt < 2 && _isRecoverableGenerationStop(e);
        debugPrint('LeapService: Final summary failed on attempt $attempt: $e');

        if (shouldRetry) {
          await _recoverModelAfterStop(modelId);
          continue;
        }
        throw LeapServiceException('Failed to generate final summary. $e');
      } finally {
        await _disposeConversation(conversation);
      }
    }

    throw LeapServiceException('Failed to generate final summary.');
  }

  Stream<String> _emitSummaryAsStream(String summary) async* {
    final words =
        summary.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();

    for (var i = 0; i < words.length; i++) {
      if (i == words.length - 1) {
        yield words[i];
      } else {
        yield '${words[i]} ';
      }
    }
  }

  String _createFinalPrompt(List<String> chunkSummaries) {
    final joined = chunkSummaries
        .asMap()
        .entries
        .map((entry) => 'Section ${entry.key + 1}: ${entry.value}')
        .join('\n\n');

    return '''
Combine the section summaries below into a single final summary of about 200 words.

Requirements:
- Preserve factual accuracy.
- Remove repetition.
- Keep chronology and causality when present.
- Return plain text only.

Section summaries:
$joined
''';
  }

  List<String> _splitIntoChunks(String text) {
    final normalizedText = _normalizeTranscriptText(text);

    final words = normalizedText
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) {
      return const [];
    }

    final wordsPerChunk =
        math.max(1, (_chunkTokenSize * _wordPerToken).round());
    final overlapWords =
        math.max(0, (_chunkOverlapTokens * _wordPerToken).round());
    final step = math.max(1, wordsPerChunk - overlapWords);

    final chunks = <String>[];
    for (var start = 0; start < words.length; start += step) {
      final end = math.min(start + wordsPerChunk, words.length);
      chunks.add(words.sublist(start, end).join(' '));
      if (end >= words.length) {
        break;
      }
    }

    debugPrint(
      'LeapService: split ${words.length} words into ${chunks.length} chunks (chunkWords=$wordsPerChunk overlapWords=$overlapWords).',
    );
    return chunks;
  }

  String _normalizeTranscriptText(String text) {
    final condensed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (condensed.isEmpty) {
      return condensed;
    }

    final rawWords = condensed
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();

    if (rawWords.length < 3) {
      return condensed;
    }

    final repairedWords = <String>[];
    for (var index = 0; index < rawWords.length; index++) {
      final current = rawWords[index];

      final hasNext = index + 1 < rawWords.length;
      final hasPrev = repairedWords.isNotEmpty;

      if (hasNext &&
          hasPrev &&
          _isFragmentJoinCandidate(
              current, rawWords[index + 1], repairedWords.last)) {
        repairedWords.add('$current${rawWords[index + 1]}');
        index += 1;
        continue;
      }

      repairedWords.add(current);
    }

    return repairedWords.join(' ');
  }

  bool _isFragmentJoinCandidate(String middle, String next, String previous) {
    if (middle.length != 1) {
      return false;
    }

    final middleLower = middle.toLowerCase();
    if (middleLower == 'a' || middleLower == 'i') {
      return false;
    }

    if (!_isLowerWord(middle) || !_isLowerWord(next)) {
      return false;
    }

    if (next.length < 2 || next.length > 4) {
      return false;
    }

    if (previous.length < 3) {
      return false;
    }

    final previousLastChar = previous[previous.length - 1];
    final isPreviousLowerTail = RegExp(r'[a-z]').hasMatch(previousLastChar);
    if (!isPreviousLowerTail) {
      return false;
    }

    return true;
  }

  bool _isLowerWord(String value) {
    return RegExp(r'^[a-z]+$').hasMatch(value);
  }

  Future<void> _disposeConversation(Conversation conversation) async {
    try {
      await FlutterLeapSdkService.disposeConversation(conversation.id);
    } catch (e) {
      debugPrint(
        'LeapService: Conversation dispose failed for ${conversation.id}: $e',
      );
    }
  }

  bool _isRecoverableGenerationStop(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('stop request') ||
        text.contains('generation stopped') ||
        text.contains('stopped unexpectedly') ||
        text.contains('empty chunk summary') ||
        text.contains('returned empty') ||
        text.contains('stream ended') ||
        text.contains('timeoutexception');
  }

  Future<void> _recoverModelAfterStop(String modelId) async {
    debugPrint(
      'LeapService: Recovering model after generation interruption. Reloading model...',
    );
    try {
      await forceUnload();
    } catch (e) {
      debugPrint('LeapService: forceUnload during recovery failed: $e');
    }
    await _ensureModelLoaded(modelId);
  }

  void _scheduleAutoUnload() {
    _cancelAutoUnload();
    _unloadTimer = Timer(_autoUnloadDelay, () async {
      try {
        debugPrint('LeapService: Auto-unloading model after inactivity.');
        await forceUnload();
      } catch (e) {
        debugPrint('LeapService: Auto-unload failed: $e');
      }
    });
  }

  void _cancelAutoUnload() {
    if (_unloadTimer?.isActive ?? false) {
      _unloadTimer?.cancel();
      debugPrint('LeapService: Cancelled pending auto-unload timer.');
    }
    _unloadTimer = null;
  }

  String _resolveModelId(String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) {
      return defaultModelId;
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('lfm2.5') ||
        lower.contains('lfm2-1.2b') ||
        lower.contains('1.2b-instruct')) {
      return defaultModelId;
    }

    return normalized;
  }

  /// Disposes of the model resources.
  Future<void> dispose() async {
    await forceUnload();
  }
}

class LeapServiceException implements Exception {
  final String message;
  LeapServiceException(this.message);

  @override
  String toString() => message;
}
