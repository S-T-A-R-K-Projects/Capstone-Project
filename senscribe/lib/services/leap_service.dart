import 'package:flutter/foundation.dart';
import 'package:flutter_leap_sdk/flutter_leap_sdk.dart';

/// Service to handle interactions with the Liquid AI Leap SDK.
/// Uses `flutter_leap_sdk` wrapper.
class LeapService {
  // Model IDs supported by Flutter Leap SDK
  // Typically: 'Qwen3-1.7B', 'LFM2-350M', etc.
  static const String defaultModelId = 'Qwen3-1.7B';

  // Singleton instance
  static final LeapService _instance = LeapService._internal();

  factory LeapService() => _instance;

  LeapService._internal();

  Conversation? _activeConversation;

  /// Checks if the model is locally cached.
  Future<bool> isModelCached(String modelId) async {
    try {
      // The SDK checks for existence and downloads if needed.
      return await FlutterLeapSdkService.checkModelExists(modelId);
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
    debugPrint('LeapService: Starting load for $modelId');

    try {
      // Load model into memory using path or ID
      await FlutterLeapSdkService.loadModel(modelPath: modelId);
      debugPrint('LeapService: Model loaded successfully.');

      // Initialize a conversation for future requests
      _activeConversation = await FlutterLeapSdkService.createConversation(
        systemPrompt:
            'You are a helpful assistant that summarizes text concisely.',
        generationOptions: GenerationOptions(
          temperature: 0.7,
          maxTokens: 512,
        ),
      );
    } catch (e) {
      debugPrint('LeapService: Failed to load model: $e');
      throw Exception('Failed to load model: $e');
    }
  }

  /// Helper to check if a model is currently loaded in memory
  bool get isModelLoaded => _activeConversation != null;

  /// Generates a response stream for the given prompt.
  /// Ensures the model is loaded before generating.
  Stream<String> generateStream(String prompt) {
    if (_activeConversation == null) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }

    debugPrint(
        'LeapService: Generating stream for prompt length ${prompt.length}');

    // Use the active conversation for generation
    return _activeConversation!.generateResponseStream(prompt);
  }

  /// Disposes of the model resources.
  Future<void> dispose() async {
    // The SDK doesn't always expose explicit unload in all wrappers,
    // but check if available or just let it stay loaded for performance.
    // For now, we clear our conversation reference.
    _activeConversation = null;
    // Potentially call SDK unload if exposed in future versions
  }
}
