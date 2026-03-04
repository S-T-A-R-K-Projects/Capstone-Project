import 'dart:async';


/// Lightweight stub of the real LeapService used in production.
///
/// This stub is designed to let the app compile and run on development
/// machines that don't have `liquid_ai` available. It implements the
/// small surface area used by the app and performs no real model work; all
/// operations are either no-ops or throw clear exceptions indicating the
/// feature is unavailable.
class LeapService {
  static final LeapService _instance = LeapService._internal();
  factory LeapService() => _instance;
  LeapService._internal();

  bool _isSummarizationInProgress = false;

  bool get isSummarizationInProgress => _isSummarizationInProgress;

  void cancelSummarization() {
    _isSummarizationInProgress = false;
  }

  Future<bool> isModelCached(String modelId) async {
    // Stub: report false so UI will prompt user to download; this avoids
    // depending on native model runtime during development.
    return Future.value(false);
  }

  Future<void> downloadModel(
    String modelId, {
    required Function(double) onProgress,
    required Function(String) onStatus,
  }) async {
    // Stub: indicate failure — caller should handle and show message.
    throw LeapServiceException('Liquid AI runtime is not available in this build.');
  }

  Future<void> loadModel(String modelId, {Function(double)? onProgress}) async {
    throw LeapServiceException('Liquid AI runtime is not available in this build.');
  }

  Future<void> forceUnload() async {
    // no-op for stub
  }

  Future<void> deleteModel(String modelId) async {
    // no-op for stub
  }

  Future<String> summarizeLargeText(String transcript, {String modelId = ''}) async {
    throw LeapServiceException('Summarization is unavailable in this build.');
  }

  Stream<String> summarizeLargeTextStream(String transcript, {String modelId = ''}) async* {
    throw LeapServiceException('Summarization is unavailable in this build.');
  }
}

class LeapServiceException implements Exception {
  final String message;
  LeapServiceException(this.message);
  @override
  String toString() => 'LeapServiceException: $message';
}
