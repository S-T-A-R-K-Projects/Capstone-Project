import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'llm_service.dart';

/// High-level service for text summarization
/// Handles model lifecycle (load -> summarize -> unload) automatically
class SummarizationService {
  static const _modelPathKey = 'llm_model_path';

  // Singleton pattern
  static final SummarizationService _instance =
      SummarizationService._internal();
  factory SummarizationService() => _instance;
  SummarizationService._internal();

  final LLMService _llmService = LLMService();

  /// Get stored model path
  Future<String?> getModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelPathKey);
  }

  /// Save model path
  Future<void> setModelPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPathKey, path);
  }

  /// Clear stored model path
  Future<void> clearModelPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_modelPathKey);
  }

  /// Check if model is configured
  Future<bool> isModelConfigured() async {
    final path = await getModelPath();
    return path != null && path.isNotEmpty;
  }

  /// Get the token stream for real-time updates
  Stream<String> get tokenStream => _llmService.tokenStream;

  // Maximum characters for input to stay within model's context window
  // Reduced to ~200 tokens (~800 chars) for mobile memory constraints
  static const int _maxInputChars = 800;

  /// Truncate transcript if too long to prevent context overflow
  String _truncateIfNeeded(String transcript) {
    if (transcript.length <= _maxInputChars) {
      return transcript;
    }
    // Truncate and add indicator
    final truncated = transcript.substring(0, _maxInputChars);
    // Try to cut at a sentence boundary
    final lastPeriod = truncated.lastIndexOf('.');
    if (lastPeriod > _maxInputChars * 0.8) {
      return '${truncated.substring(0, lastPeriod + 1)} [Text truncated for length]';
    }
    return '$truncated... [Text truncated for length]';
  }

  /// Build the summarization prompt with proper formatting for Phi-3.5-Mini
  String _buildSummarizationPrompt(String transcript) {
    final processedTranscript = _truncateIfNeeded(transcript);
    debugPrint(
      'SummarizationService: Original transcript length: ${transcript.length} chars',
    );
    debugPrint(
      'SummarizationService: Processed transcript length: ${processedTranscript.length} chars',
    );
    debugPrint(
      'SummarizationService: Was truncated: ${transcript.length != processedTranscript.length}',
    );
    return '''<|system|>
You are a helpful assistant that creates medium-length summaries in 4-6 sentences.
Capture all key points concisely and clearly. Focus on the most important information.
Write complete sentences and do not stop mid-sentence.
<|end|>
<|user|>
Summarize the following text in 4-6 complete sentences:

$processedTranscript
<|end|>
<|assistant|>
''';
  }

  /// Summarize text with automatic model load/unload
  ///
  /// This method:
  /// 1. Loads the model from the configured path
  /// 2. Runs inference with the summarization prompt
  /// 3. Unloads the model immediately after completion
  ///
  /// Returns the summary or throws an exception if something fails.
  ///
  /// Listen to [tokenStream] to receive real-time token updates.
  Future<String> summarize(String transcript) async {
    // Check if model is configured
    final modelPath = await getModelPath();
    if (modelPath == null || modelPath.isEmpty) {
      throw SummarizationException(
        'Model not configured. Please configure the AI model in settings.',
      );
    }

    try {
      // Load the model
      debugPrint('SummarizationService: Loading model from: $modelPath');
      final loaded = await _llmService.loadModel(modelPath);
      debugPrint('SummarizationService: Model loaded: $loaded');
      if (!loaded) {
        throw SummarizationException(
          'Failed to load the AI model. Please check if the model files are valid.',
        );
      }

      // Build the prompt
      final prompt = _buildSummarizationPrompt(transcript);
      debugPrint(
        'SummarizationService: Total prompt length: ${prompt.length} chars',
      );

      // Collect streamed tokens
      String summary = '';
      final completer = Completer<void>();
      int tokenCount = 0;

      late StreamSubscription<String> subscription;
      subscription = _llmService.tokenStream.listen(
        (token) {
          summary += token;
          tokenCount++;
          // Log every 10 tokens
          if (tokenCount <= 5 || tokenCount % 20 == 0) {
            debugPrint(
              'SummarizationService: Token #$tokenCount received, summary length: ${summary.length}',
            );
          }
        },
        onError: (error) {
          debugPrint('SummarizationService: Stream error: $error');
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      // Run inference with parameters optimized for summarization
      // Note: max_length in ONNX GenAI is TOTAL sequence length (input + output)
      // With ~500 input tokens, we need at least 800+ for meaningful output
      // Let native code handle max_length (default 1000)
      debugPrint('SummarizationService: Starting summarization...');
      final success = await _llmService.summarize(
        prompt,
        params: {}, // Let native code use default max_length
      );
      debugPrint(
        'SummarizationService: Summarization finished. Success: $success, Total tokens: $tokenCount',
      );
      debugPrint(
        'SummarizationService: Final summary length: ${summary.length} chars',
      );

      // Cancel subscription
      await subscription.cancel();

      // Always unload the model immediately after use
      await _llmService.unloadModel();

      if (!success) {
        throw SummarizationException('Summarization failed. Please try again.');
      }

      return summary.trim();
    } catch (e) {
      // Ensure model is unloaded even on error
      await _llmService.unloadModel();

      if (e is SummarizationException) {
        rethrow;
      }
      throw SummarizationException(
        'An error occurred during summarization: $e',
      );
    }
  }

  /// Summarize text with streaming callback
  ///
  /// [onToken] is called for each generated token (for real-time UI updates)
  /// Returns the complete summary when done.
  Future<String> summarizeWithCallback(
    String transcript, {
    required void Function(String token) onToken,
  }) async {
    // Check if model is configured
    final modelPath = await getModelPath();
    if (modelPath == null || modelPath.isEmpty) {
      throw SummarizationException(
        'Model not configured. Please configure the AI model in settings.',
      );
    }

    try {
      // Load the model
      debugPrint(
        'SummarizationService: [Callback] Loading model from: $modelPath',
      );
      final loaded = await _llmService.loadModel(modelPath);
      debugPrint('SummarizationService: [Callback] Model loaded: $loaded');
      if (!loaded) {
        throw SummarizationException(
          'Failed to load the AI model. Please check if the model files are valid.',
        );
      }

      // Build the prompt
      final prompt = _buildSummarizationPrompt(transcript);
      debugPrint(
        'SummarizationService: [Callback] Total prompt length: ${prompt.length} chars',
      );

      // Collect streamed tokens with callback
      String summary = '';
      int tokenCount = 0;

      late StreamSubscription<String> subscription;
      subscription = _llmService.tokenStream.listen((token) {
        summary += token;
        tokenCount++;
        onToken(token);
        // Log every 10 tokens
        if (tokenCount <= 5 || tokenCount % 20 == 0) {
          debugPrint(
            'SummarizationService: [Callback] Token #$tokenCount, summary length: ${summary.length}',
          );
        }
      });

      // Run inference - let native code handle max_length
      debugPrint('SummarizationService: [Callback] Starting summarization...');
      final success = await _llmService.summarize(
        prompt,
        params: {}, // Let native code use default max_length
      );
      debugPrint(
        'SummarizationService: [Callback] Finished. Success: $success, Total tokens: $tokenCount',
      );
      debugPrint(
        'SummarizationService: [Callback] Final summary: "${summary.substring(0, summary.length > 100 ? 100 : summary.length)}..."',
      );

      // Cancel subscription
      await subscription.cancel();

      // Always unload the model immediately after use
      await _llmService.unloadModel();

      if (!success) {
        throw SummarizationException('Summarization failed. Please try again.');
      }

      return summary.trim();
    } catch (e) {
      // Ensure model is unloaded even on error
      await _llmService.unloadModel();

      if (e is SummarizationException) {
        rethrow;
      }
      throw SummarizationException(
        'An error occurred during summarization: $e',
      );
    }
  }
}

/// Exception thrown when summarization fails
class SummarizationException implements Exception {
  final String message;
  SummarizationException(this.message);

  @override
  String toString() => message;
}
