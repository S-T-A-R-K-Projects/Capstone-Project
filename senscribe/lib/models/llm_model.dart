/// Model definition for on-device LLM
class LLMModel {
  final String name;
  final String description;
  final List<String> requiredFiles;
  final int estimatedSizeMB;
  final String? localPath;
  final String? downloadUrl;

  const LLMModel({
    required this.name,
    required this.description,
    required this.requiredFiles,
    required this.estimatedSizeMB,
    this.localPath,
    this.downloadUrl,
  });

  /// Liquid Managed Model (Qwen3 1.7B)
  static const qwenManaged = LLMModel(
    name: 'Qwen3-1.7B',
    description: 'Qwen 3 1.7B (Liquid Managed)',
    estimatedSizeMB: 1200,
    requiredFiles: [],
    // No local path or URL needed; SDK manages it.
  );

  /// Default model
  static const defaultModel = qwenManaged;

  /// Currently supported models
  static const List<LLMModel> availableModels = [qwenManaged];

  /// Get model by name
  static LLMModel? getModelByName(String name) {
    try {
      return availableModels.firstWhere((m) => m.name == name);
    } catch (_) {
      return null;
    }
  }
}
