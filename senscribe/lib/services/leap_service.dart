import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:liquid_ai/liquid_ai.dart';

/// Service to handle interactions with Liquid AI SDK.
/// Uses `liquid_ai` package for model lifecycle and inference.
class LeapService {
  static const String defaultModelId = 'LFM2.5-1.2B-Instruct';
  static const String defaultModelDisplayName = 'LFM2.5-1.2B-Instruct Q8_0';
  static const String defaultQuantization = 'Q8_0';

  static const int _chunkTokenSize = 1200;
  static const int _chunkOverlapTokens = 150;
  static const double _wordPerToken = 0.75;
  static const Duration _autoUnloadDelay = Duration(seconds: 3);

  static const double _summaryTemperature = 0.3;
  static const int _chunkSummaryMaxTokens = 150;
  static const int _finalSummaryMaxTokens = 300;
  static const int _singlePassSummaryMaxTokens = 96;
  static const int _tinyInputWordThreshold = 3;
  static const int _singlePassWordThreshold = 900;
  static const int _shortChunkPromptWordThreshold = 120;
  static const Duration _chunkGenerationTimeout = Duration(seconds: 45);
  static const Duration _finalGenerationTimeout = Duration(seconds: 30);
  static const Duration _conversationTransitionDelay = Duration(
    milliseconds: 120,
  );
  static const int _loadContextSize = 2048;
  static const int _loadBatchSize = 256;
  static const int _loadThreads = 2;
  static const int _loadGpuLayers = 0;

  static final LeapService _instance = LeapService._internal();

  factory LeapService() => _instance;

  LeapService._internal();

  final LiquidAi _liquidAi = LiquidAi();

  Timer? _unloadTimer;
  bool _isModelLoaded = false;
  String? _loadedModelSlug;
  String? _loadedQuantization;
  ModelRunner? _runner;
  bool _isSummarizationInProgress = false;

  Future<bool> isModelCached(String modelId) async {
    final resolved = _resolveModel(modelId);
    try {
      return await _liquidAi.isModelDownloaded(
        resolved.modelSlug,
        resolved.quantizationSlug,
      );
    } catch (e) {
      debugPrint('LeapService: Error checking model cache: $e');
      return false;
    }
  }

  Future<void> downloadModel(
    String modelId, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    final resolved = _resolveModel(modelId);

    try {
      await for (final event in _liquidAi.downloadModel(
        resolved.modelSlug,
        resolved.quantizationSlug,
      )) {
        switch (event) {
          case DownloadStartedEvent():
            onStatus('Starting download...');
          case DownloadProgressEvent(:final progress):
            onProgress(progress.progress.clamp(0.0, 1.0));
            final percentage = (progress.progress * 100).toStringAsFixed(1);
            onStatus('Downloading... $percentage%');
          case DownloadCompleteEvent():
            onProgress(1.0);
            onStatus('Download complete.');
          case DownloadErrorEvent(:final error):
            throw LeapServiceException('Model download failed: $error');
          case DownloadCancelledEvent():
            throw LeapServiceException('Model download cancelled.');
        }
      }
    } catch (e) {
      if (e is LeapServiceException) rethrow;
      throw LeapServiceException('Model download failed: $e');
    }
  }

  Future<void> loadModel(
    String modelId, {
    Function(double)? onProgress,
  }) async {
    await _ensureModelLoaded(modelId, onProgress: onProgress);
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
      final resolved = _resolveModel(modelId);
      await _ensureModelLoaded(resolved.modelSlug);

      final normalizedTranscript = _normalizeTranscriptText(transcript);
      final transcriptWords = _extractWords(normalizedTranscript);

      if (transcriptWords.length <= _tinyInputWordThreshold) {
        return normalizedTranscript;
      }

      if (transcriptWords.length <= _singlePassWordThreshold) {
        return await _summarizeSinglePass(
          normalizedTranscript,
          modelId: resolved.modelSlug,
        );
      }

      final chunks = _splitIntoChunks(normalizedTranscript);

      debugPrint(
        'LeapService: Starting map-reduce summarization for ${chunks.length} chunks.',
      );

      final chunkSummaries = <String>[];
      for (var i = 0; i < chunks.length; i++) {
        final summary = await _summarizeChunk(
          chunkText: chunks[i],
          sectionIndex: i + 1,
          totalSections: chunks.length,
          modelId: resolved.modelSlug,
        );
        chunkSummaries.add(summary);
      }

      if (chunkSummaries.length == 1) {
        return chunkSummaries.first;
      }

      await _prepareForFinalReduction(resolved.modelSlug);

      return await _buildFinalSummary(chunkSummaries,
          modelId: resolved.modelSlug);
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
      final resolved = _resolveModel(modelId);
      await _ensureModelLoaded(resolved.modelSlug);

      final normalizedTranscript = _normalizeTranscriptText(transcript);
      final transcriptWords = _extractWords(normalizedTranscript);

      if (transcriptWords.length <= _tinyInputWordThreshold) {
        yield normalizedTranscript;
        return;
      }

      if (transcriptWords.length <= _singlePassWordThreshold) {
        yield 'Summarizing...\n';
        final singlePass = await _summarizeSinglePass(
          normalizedTranscript,
          modelId: resolved.modelSlug,
        );
        yield* _emitSummaryAsStream(singlePass);
        return;
      }

      final chunks = _splitIntoChunks(normalizedTranscript);
      final chunkSummaries = <String>[];

      for (var i = 0; i < chunks.length; i++) {
        final section = i + 1;
        yield 'Processing section $section of ${chunks.length}...\n';

        final summary = await _summarizeChunk(
          chunkText: chunks[i],
          sectionIndex: section,
          totalSections: chunks.length,
          modelId: resolved.modelSlug,
        );
        chunkSummaries.add(summary);
      }

      if (chunkSummaries.length == 1) {
        yield* _emitSummaryAsStream(chunkSummaries.first);
        return;
      }

      yield 'Combining section summaries...\n';
      await _prepareForFinalReduction(resolved.modelSlug);
      final combinedSummary = await _buildFinalSummary(
        chunkSummaries,
        modelId: resolved.modelSlug,
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

  Future<void> _ensureModelLoaded(
    String requestedModelId, {
    Function(double)? onProgress,
  }) async {
    final resolved = _resolveModel(requestedModelId);

    if (_isModelLoaded &&
        _loadedModelSlug == resolved.modelSlug &&
        _loadedQuantization == resolved.quantizationSlug &&
        _runner != null &&
        !_runner!.isDisposed) {
      debugPrint(
        'LeapService: Model already loaded: ${resolved.modelSlug} ${resolved.quantizationSlug}',
      );
      return;
    }

    if (_isModelLoaded) {
      await forceUnload();
    }

    final exists = await isModelCached(resolved.modelSlug);
    if (!exists) {
      throw LeapServiceException(
        'Model is not downloaded on this device. Please download it in Model Settings.',
      );
    }

    debugPrint(
      'LeapService: Loading model: ${resolved.modelSlug} (${resolved.quantizationSlug})',
    );

    try {
      ModelRunner? loadedRunner;

      await for (final event in _liquidAi.loadModel(
        resolved.modelSlug,
        resolved.quantizationSlug,
        options: const LoadOptions(
          contextSize: _loadContextSize,
          batchSize: _loadBatchSize,
          threads: _loadThreads,
          gpuLayers: _loadGpuLayers,
        ),
      )) {
        switch (event) {
          case LoadProgressEvent(:final progress):
            onProgress?.call(progress.progress.clamp(0.0, 1.0));
          case LoadCompleteEvent(:final runner):
            loadedRunner = runner;
          case LoadErrorEvent(:final error):
            throw LeapServiceException('Failed to load model. $error');
          case LoadCancelledEvent():
            throw LeapServiceException('Model loading was cancelled.');
          case LoadStartedEvent():
            break;
        }
      }

      if (loadedRunner == null) {
        throw LeapServiceException(
          'Model loading did not return an active runner.',
        );
      }

      _runner = loadedRunner;
      _isModelLoaded = true;
      _loadedModelSlug = resolved.modelSlug;
      _loadedQuantization = resolved.quantizationSlug;
      debugPrint(
        'LeapService: Model loaded successfully: ${resolved.modelSlug} (${resolved.quantizationSlug})',
      );
    } catch (e) {
      debugPrint('LeapService: Failed to load model: $e');
      _isModelLoaded = false;
      _loadedModelSlug = null;
      _loadedQuantization = null;
      _runner = null;
      if (e is LeapServiceException) rethrow;
      throw LeapServiceException('Failed to load model. $e');
    }
  }

  bool get isModelLoaded => _isModelLoaded;

  Stream<String> generateStream(
    String prompt, {
    String modelId = defaultModelId,
  }) async* {
    await _ensureModelLoaded(modelId);

    final runner = _runner;
    if (runner == null || runner.isDisposed) {
      throw LeapServiceException('No active model runner available.');
    }

    final conversation = await runner.createConversation(
      systemPrompt:
          'You summarize text faithfully. Keep key facts, names, dates, and intent intact.',
    );

    try {
      await for (final event in conversation.generateResponse(
        ChatMessage.user(prompt),
        options: const GenerationOptions(
          temperature: _summaryTemperature,
          maxTokens: _finalSummaryMaxTokens,
        ),
      )) {
        switch (event) {
          case GenerationChunkEvent(:final chunk):
            yield chunk;
          case GenerationCompleteEvent(:final message):
            final text = message.text;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
          case GenerationErrorEvent(:final error):
            throw LeapServiceException('Generation failed: $error');
          default:
            break;
        }
      }
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
      await _runner?.dispose();
      debugPrint('LeapService: Model unloaded.');
    } catch (e) {
      debugPrint('LeapService: model dispose failed: $e');
      throw LeapServiceException('Failed to unload model. $e');
    } finally {
      _isModelLoaded = false;
      _loadedModelSlug = null;
      _loadedQuantization = null;
      _runner = null;
    }
  }

  Future<void> deleteModel(String modelId) async {
    final resolved = _resolveModel(modelId);
    if (_isModelLoaded &&
        _loadedModelSlug == resolved.modelSlug &&
        _loadedQuantization == resolved.quantizationSlug) {
      await forceUnload();
    }

    await _liquidAi.deleteModel(resolved.modelSlug, resolved.quantizationSlug);
  }

  Future<String> _summarizeChunk({
    required String chunkText,
    required int sectionIndex,
    required int totalSections,
    required String modelId,
  }) async {
    final chunkWordCount = _extractWords(chunkText).length;
    final isShortChunk = chunkWordCount <= _shortChunkPromptWordThreshold;

    final prompt = '''
Summarize section $sectionIndex of $totalSections ${isShortChunk ? 'in 1-2 concise sentences (max 30 words)' : 'in 50-100 words'}.

Requirements:
- Preserve key facts, entities, and important actions.
- Do not add details that are not present in the source.
- If the text is noisy or contains errors, infer intent conservatively.
- Return plain text only.

Section text:
$chunkText
''';

    for (var attempt = 1; attempt <= 2; attempt++) {
      debugPrint(
        'LeapService: Summarizing chunk $sectionIndex/$totalSections attempt $attempt (${chunkText.length} chars).',
      );

      final conversation = await _createConversation(
        systemPrompt:
            'You are a precise summarizer. Handle spelling, grammar, and formatting errors gracefully.',
      );

      var recoverAfterDispose = false;

      try {
        final summary = (await conversation
                .generateText(
                  prompt,
                  options: GenerationOptions(
                    temperature: _summaryTemperature,
                    maxTokens: isShortChunk
                        ? _singlePassSummaryMaxTokens
                        : _chunkSummaryMaxTokens,
                  ),
                )
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
          recoverAfterDispose = true;
        } else {
          throw LeapServiceException(
            'Failed while processing section $sectionIndex of $totalSections. $e',
          );
        }
      } finally {
        await _disposeConversation(conversation);
      }

      if (recoverAfterDispose) {
        await _recoverModelAfterStop(modelId);
        continue;
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
      final conversation = await _createConversation(
        systemPrompt:
            'You produce concise, factual summaries from multiple section summaries.',
      );

      var recoverAfterDispose = false;

      try {
        final response = (await conversation
                .generateText(
                  prompt,
                  options: const GenerationOptions(
                    temperature: _summaryTemperature,
                    maxTokens: _finalSummaryMaxTokens,
                  ),
                )
                .timeout(_finalGenerationTimeout))
            .trim();

        if (response.isEmpty) {
          throw LeapServiceException(
            'Final summary generation returned empty text.',
          );
        }
        return response;
      } catch (e) {
        final shouldRetry = attempt < 2 && _isRecoverableGenerationStop(e);
        debugPrint('LeapService: Final summary failed on attempt $attempt: $e');

        if (shouldRetry) {
          recoverAfterDispose = true;
        } else {
          throw LeapServiceException('Failed to generate final summary. $e');
        }
      } finally {
        await _disposeConversation(conversation);
      }

      if (recoverAfterDispose) {
        await _recoverModelAfterStop(modelId);
        continue;
      }
    }

    throw LeapServiceException('Failed to generate final summary.');
  }

  Future<String> _summarizeSinglePass(
    String transcript, {
    required String modelId,
  }) async {
    final prompt = '''
Summarize the text below faithfully.

Rules:
- If it is very short (for example a greeting like "hello"), keep the output very short.
- Do not invent facts, entities, or events.
- Preserve the original intent and tone.
- Return plain text only.

Text:
$transcript
''';

    for (var attempt = 1; attempt <= 2; attempt++) {
      final conversation = await _createConversation(
        systemPrompt:
            'You are a faithful summarizer. Keep output concise and grounded only in the provided text.',
      );

      var recoverAfterDispose = false;

      try {
        final response = (await conversation
                .generateText(
                  prompt,
                  options: const GenerationOptions(
                    temperature: 0.2,
                    maxTokens: _singlePassSummaryMaxTokens,
                  ),
                )
                .timeout(_finalGenerationTimeout))
            .trim();

        if (response.isEmpty) {
          throw LeapServiceException(
              'Single-pass summary returned empty text.');
        }
        return response;
      } catch (e) {
        final shouldRetry = attempt < 2 && _isRecoverableGenerationStop(e);
        if (shouldRetry) {
          recoverAfterDispose = true;
        } else {
          throw LeapServiceException('Failed to summarize short text. $e');
        }
      } finally {
        await _disposeConversation(conversation);
      }

      if (recoverAfterDispose) {
        await _recoverModelAfterStop(modelId);
      }
    }

    throw LeapServiceException('Failed to summarize short text.');
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
    final words = _extractWords(text);

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

  List<String> _extractWords(String text) {
    return text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
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
            current,
            rawWords[index + 1],
            repairedWords.last,
          )) {
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

  Future<Conversation> _createConversation({String? systemPrompt}) async {
    final runner = _runner;
    if (runner == null || runner.isDisposed) {
      throw LeapServiceException('Model is not loaded.');
    }

    return runner.createConversation(systemPrompt: systemPrompt);
  }

  Future<void> _disposeConversation(Conversation conversation) async {
    try {
      await conversation.dispose();
      await Future<void>.delayed(_conversationTransitionDelay);
    } catch (e) {
      debugPrint(
        'LeapService: Conversation dispose failed for ${conversation.conversationId}: $e',
      );
    }
  }

  bool _isRecoverableGenerationStop(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('stop request') ||
        text.contains('generation stopped') ||
        text.contains('stopped unexpectedly') ||
        text.contains('requestinterrupted') ||
        text.contains('operation was cancelled') ||
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

  Future<void> _prepareForFinalReduction(String modelId) async {
    debugPrint(
      'LeapService: Preparing final reduction stage with clean model state...',
    );
    try {
      await forceUnload();
    } catch (e) {
      debugPrint('LeapService: Pre-final forceUnload failed: $e');
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

  _ResolvedModel _resolveModel(String modelId) {
    final normalized = modelId.trim();
    if (normalized.isEmpty) {
      return const _ResolvedModel(defaultModelId, defaultQuantization);
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('8da4w_output_8da8w-seq_4096.bundle') ||
        lower.contains('lfm2.5-1.2b-instruct') ||
        lower.contains('1.2b-instruct') ||
        lower.contains('q8_0')) {
      return const _ResolvedModel(defaultModelId, defaultQuantization);
    }

    if (normalized.contains(':')) {
      final split = normalized.split(':');
      if (split.length == 2) {
        return _ResolvedModel(split[0], split[1]);
      }
    }

    return _ResolvedModel(normalized, defaultQuantization);
  }

  Future<void> dispose() async {
    await forceUnload();
  }
}

class _ResolvedModel {
  final String modelSlug;
  final String quantizationSlug;

  const _ResolvedModel(this.modelSlug, this.quantizationSlug);
}

class LeapServiceException implements Exception {
  final String message;
  LeapServiceException(this.message);

  @override
  String toString() => message;
}
