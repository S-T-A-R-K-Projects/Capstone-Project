import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service for communicating with the native LLM (ONNX Runtime GenAI)
/// Handles model loading, inference, and token streaming
class LLMService {
  static const _methodChannel = MethodChannel('com.example.senscribe/llm');
  static const _eventChannel = EventChannel('com.example.senscribe/llm_tokens');

  // Singleton pattern
  static final LLMService _instance = LLMService._internal();
  factory LLMService() => _instance;
  LLMService._internal();

  // Cache the broadcast stream
  static Stream<String>? _tokenStreamInstance;

  /// Get the token stream for receiving generated tokens
  Stream<String> get tokenStream {
    _tokenStreamInstance ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString())
        .asBroadcastStream();
    return _tokenStreamInstance!;
  }

  /// Load model from the specified directory path
  /// Returns true if successful
  Future<bool> loadModel(String path) async {
    try {
      final result = await _methodChannel.invokeMethod('loadModel', path);
      return result == 'LOADED';
    } on PlatformException catch (e) {
      debugPrint('LLMService: Failed to load model: ${e.message}');
      return false;
    }
  }

  /// Unload the model and free resources
  Future<void> unloadModel() async {
    try {
      await _methodChannel.invokeMethod('unloadModel');
    } on PlatformException catch (e) {
      debugPrint('LLMService: Failed to unload model: ${e.message}');
    }
  }

  /// Check if model is currently loaded
  Future<bool> isModelLoaded() async {
    try {
      final result = await _methodChannel.invokeMethod('isModelLoaded');
      return result == true;
    } on PlatformException {
      return false;
    }
  }

  /// Run summarization inference with the given prompt
  /// Tokens will be streamed via [tokenStream]
  /// Returns true if successful
  Future<bool> summarize(String prompt, {Map<String, double>? params}) async {
    try {
      final result = await _methodChannel.invokeMethod('summarize', {
        'prompt': prompt,
        'params': params ?? {},
      });
      return result == 'DONE';
    } on PlatformException catch (e) {
      debugPrint('LLMService: Summarization failed: ${e.message}');
      return false;
    }
  }

  /// Validate folder and create security-scoped bookmark (iOS only)
  /// Returns a map with 'success', 'path', 'missingFiles', or 'error'
  Future<Map<String, dynamic>> validateAndBookmarkFolder(
    String path,
    List<String> requiredFiles,
  ) async {
    try {
      final result = await _methodChannel.invokeMethod(
        'validateAndBookmarkFolder',
        {'path': path, 'files': requiredFiles},
      );
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('LLMService: validateAndBookmarkFolder failed: ${e.message}');
      return {'success': false, 'error': e.message ?? 'Unknown error'};
    } on MissingPluginException {
      // Method not implemented on this platform (Android)
      // Return success and let the normal file validation handle it
      return {'success': true, 'path': path, 'notImplemented': true};
    }
  }

  /// Check if iOS has a valid security-scoped bookmark saved
  /// Returns true if bookmark exists and is not stale
  Future<bool> hasValidBookmark() async {
    try {
      final result = await _methodChannel.invokeMethod('hasValidBookmark');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint('LLMService: hasValidBookmark failed: ${e.message}');
      return false;
    } on MissingPluginException {
      // Not implemented on Android - return true to skip this check
      return true;
    }
  }

  /// Clear the saved security-scoped bookmark (iOS only)
  Future<void> clearBookmark() async {
    try {
      await _methodChannel.invokeMethod('clearBookmark');
    } on PlatformException catch (e) {
      debugPrint('LLMService: clearBookmark failed: ${e.message}');
    } on MissingPluginException {
      // Not implemented on Android - ignore
    }
  }
}
