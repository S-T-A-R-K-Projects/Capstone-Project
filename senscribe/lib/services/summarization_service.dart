import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_download_snapshot.dart';
import 'leap_service.dart';
import '../models/llm_model.dart';
import 'model_download_service.dart';

/// High-level service for text summarization using Liquid AI Leap.
/// Uses liquid_ai managed models.
class SummarizationService {
  static const _modelNameKey = 'llm_model_name_leap';

  // Singleton pattern
  static final SummarizationService _instance =
      SummarizationService._internal();
  factory SummarizationService() => _instance;
  SummarizationService._internal();

  final LeapService _leapService = LeapService();
  final ModelDownloadService _modelDownloadService = ModelDownloadService();

  bool get isSummarizationInProgress => _leapService.isSummarizationInProgress;
  Stream<ModelDownloadSnapshot> get downloadStateStream =>
      _modelDownloadService.stream;
  ModelDownloadSnapshot get currentDownload => _modelDownloadService.current;

  void cancelSummarization() {
    _leapService.cancelSummarization();
  }

  Future<String> getSelectedModelName() async {
    final prefs = await SharedPreferences.getInstance();
    final selected = prefs.getString(_modelNameKey);
    if (selected == null || selected.trim().isEmpty) {
      await prefs.setString(_modelNameKey, LLMModel.defaultModel.name);
      return LLMModel.defaultModel.name;
    }

    final normalized = selected.trim();
    final existsInCurrentCatalog = LLMModel.getModelByName(normalized) != null;
    if (!existsInCurrentCatalog) {
      await prefs.setString(_modelNameKey, LLMModel.defaultModel.name);
      return LLMModel.defaultModel.name;
    }

    if (normalized != selected) {
      await prefs.setString(_modelNameKey, normalized);
    }

    return normalized;
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
    return await _leapService.isModelCached(m.name);
  }

  Future<ModelDownloadSnapshot> refreshDownloadState([LLMModel? model]) async {
    final activeModel = model ?? await getActiveModel();
    return _modelDownloadService.refreshSnapshot(activeModel);
  }

  Future<void> startModelDownload(LLMModel model) async {
    await _modelDownloadService.startDownload(model);
  }

  Future<void> clearDownloadState([LLMModel? model]) async {
    final activeModel = model ?? await getActiveModel();
    await _modelDownloadService.clearSnapshot(modelId: activeModel.name);
  }

  Future<void> cancelModelDownloadIfSupported() async {
    await _modelDownloadService.cancelIfSupported();
  }

  /// Download Model using Leap SDK Native Download
  Future<void> downloadModelFiles(
    LLMModel model, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<ModelDownloadSnapshot> subscription;
    subscription = downloadStateStream.listen((snapshot) {
      if (snapshot.modelId != model.name) return;
      onProgress(snapshot.progress);
      if (snapshot.statusMessage.isNotEmpty) {
        onStatus(snapshot.statusMessage);
      }

      if (!snapshot.isRunning) {
        if (snapshot.hasError) {
          if (!completer.isCompleted) {
            completer.completeError(
              SummarizationException(
                snapshot.lastError ?? 'Failed to download model.',
              ),
            );
          }
        } else if (snapshot.isComplete && !completer.isCompleted) {
          completer.complete();
        }
      }
    });

    try {
      await startModelDownload(model);
      await completer.future;
    } catch (e) {
      debugPrint('SummarizationService: Download failed: $e');
      if (e is SummarizationException) {
        rethrow;
      }
      throw SummarizationException('Failed to download model: $e');
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> deleteModelFiles(LLMModel model) async {
    try {
      await _leapService.deleteModel(model.name);
      await clearDownloadState(model);
    } catch (e) {
      throw SummarizationException('Failed to delete model: $e');
    }
  }

  // Expose loadModel for UI reloading
  Future<void> loadModel(String modelName) async {
    await _leapService.loadModel(modelName);
  }

  /// Unload the currently loaded model to free resources
  Future<void> unloadModel() async {
    debugPrint('SummarizationService: Unloading model...');
    await _leapService.forceUnload();
  }

  /// Synchronous summarization: returns final ~200-word summary.
  Future<String> summarize(String transcript) async {
    final modelName = await getSelectedModelName();
    final exists = await _leapService.isModelCached(modelName);

    if (!exists) {
      throw SummarizationException(
        'Model not found on device. Please download it in Settings.',
      );
    }

    try {
      return await _leapService.summarizeLargeText(
        transcript,
        modelId: modelName,
      );
    } on LeapServiceException catch (e) {
      throw SummarizationException(e.message);
    } catch (e) {
      throw SummarizationException('Summarization failed: $e');
    }
  }

  /// Streaming summarization:
  /// emits progress updates first, then streams final summary tokens.
  Stream<String> summarizeStream(String transcript) async* {
    final modelName = await getSelectedModelName();
    final exists = await _leapService.isModelCached(modelName);

    if (!exists) {
      throw SummarizationException(
        'Model not found on device. Please download it in Settings.',
      );
    }

    try {
      yield* _leapService.summarizeLargeTextStream(
        transcript,
        modelId: modelName,
      );
    } on LeapServiceException catch (e) {
      throw SummarizationException(e.message);
    } catch (e) {
      throw SummarizationException('Summarization failed: $e');
    }
  }

  /// Summarize text using Leap service (streaming)
  Future<String> summarizeWithCallback(
    String transcript, {
    required void Function(String token) onToken,
  }) async {
    final buffer = StringBuffer();

    try {
      await for (final token in summarizeStream(transcript)) {
        if (_isProgressToken(token)) {
          onToken('${token.trim()}\n');
          continue;
        }

        buffer.write(token);
        onToken(token);
      }
      return buffer.toString().trim();
    } catch (e) {
      debugPrint('SummarizationService: Error: $e');
      if (e is SummarizationException) {
        rethrow;
      }
      throw SummarizationException('Summarization failed: $e');
    }
  }

  bool _isProgressToken(String token) {
    final trimmed = token.trimLeft();
    return trimmed.startsWith('Processing section ') ||
        trimmed.startsWith('Combining section summaries');
  }
}

class SummarizationException implements Exception {
  final String message;
  SummarizationException(this.message);
  @override
  String toString() => message;
}
//
