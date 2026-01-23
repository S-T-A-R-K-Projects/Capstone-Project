import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_leap_sdk/flutter_leap_sdk.dart';

import 'leap_service.dart';
import '../models/llm_model.dart';

/// High-level service for text summarization using Liquid AI Leap.
/// Updated to use native managed models ONLY.
class SummarizationService {
  static const _modelNameKey = 'llm_model_name_leap';

  // Singleton pattern
  static final SummarizationService _instance =
      SummarizationService._internal();
  factory SummarizationService() => _instance;
  SummarizationService._internal();

  final LeapService _leapService = LeapService();

  /// Get currently selected model name
  Future<String> getSelectedModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_modelNameKey) ?? LLMModel.defaultModel.name;
  }

  /// Set selected model name
  Future<void> setSelectedModelName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelNameKey, name);
  }

  /// Get currently active model object
  Future<LLMModel> getActiveModel() async {
    final name = await getSelectedModelName();
    return LLMModel.getModelByName(name) ?? LLMModel.defaultModel;
  }

  /// Check if model is configured (Using SDK)
  Future<bool> isModelConfigured([LLMModel? model]) async {
    final m = model ?? await getActiveModel();
    // Use SDK to check if managed model exists
    return await FlutterLeapSdkService.checkModelExists(m.name);
  }

  // Maximum characters for input
  static const int _maxInputChars = 3000;

  /// Truncate transcript if too long
  String _truncateIfNeeded(String transcript) {
    if (transcript.length <= _maxInputChars) {
      return transcript;
    }
    final truncated = transcript.substring(0, _maxInputChars);
    final lastPeriod = truncated.lastIndexOf('.');
    if (lastPeriod > _maxInputChars * 0.8) {
      return '${truncated.substring(0, lastPeriod + 1)} [Text truncated]';
    }
    return '$truncated... [Text truncated]';
  }

  /// Download Model using Leap SDK Native Download
  Future<void> downloadModelFiles(
    LLMModel model, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    onStatus('Initializing Download...');

    try {
      // Use Native SDK Download
      onStatus('Downloading ${model.name}...');
      await FlutterLeapSdkService.downloadModel(
        modelName: model.name,
        onProgress: (progress) {
          // progress.percentage is 0-100
          final percent = progress.percentage / 100.0;
          onProgress(percent);
        },
      );

      onStatus('Model Downloaded.');
    } catch (e) {
      debugPrint('SummarizationService: Download failed: $e');
      throw SummarizationException('Failed to download model: $e');
    }
  }

  // Expose loadModel for UI reloading
  Future<void> loadModel(String modelName) async {
    // Just pass the model name to LeapService (which wraps SDK load)
    await _leapService.loadModel(modelName);
  }

  /// Unload the currently loaded model to free resources
  Future<void> unloadModel() async {
    debugPrint('SummarizationService: Unloading model...');
    await _leapService.dispose();
  }

  /// Summarize text using Leap service (streaming)
  Future<String> summarizeWithCallback(
    String transcript, {
    required void Function(String token) onToken,
  }) async {
    // Check if model is configured
    final name = await getSelectedModelName();

    debugPrint('SummarizationService: Loading managed model: $name');

    // Ensure model is downloaded
    final exists = await FlutterLeapSdkService.checkModelExists(name);
    if (!exists) {
      throw SummarizationException(
          'Model not found on device. Please download it in Settings.');
    }

    try {
      // 1. Load Model (SDK Native)
      await _leapService.loadModel(name);

      final processedTranscript = _truncateIfNeeded(transcript);
      String fullResponse = '';

      // 2. Generate
      final stream = _leapService.generateStream(processedTranscript);
      final completer = Completer<String>();

      stream.listen(
        (token) {
          fullResponse += token;
          onToken(token);
        },
        onError: (e) {
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete(fullResponse);
        },
      );

      final result = await completer.future;

      // 3. Unload Model (Cleanup)
      await unloadModel();

      return result;
    } catch (e) {
      debugPrint('SummarizationService: Error: $e');
      await unloadModel();
      throw SummarizationException('Summarization failed: $e');
    }
  }
}

class SummarizationException implements Exception {
  final String message;
  SummarizationException(this.message);
  @override
  String toString() => message;
}
