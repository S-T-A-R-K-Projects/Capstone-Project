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

  /// Liquid Managed Model (LFM2.5 1.2B Instruct Q8_0)
  static const lfm25Instruct = LLMModel(
    name: 'LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle',
    description: 'LFM2.5-1.2B-Instruct Q8_0 (Liquid Managed)',
    estimatedSizeMB: 1250,
    requiredFiles: [],
    // No local path or URL needed; SDK manages it.
  );

  /// Default model
  static const defaultModel = lfm25Instruct;

  /// Currently supported models
  static const List<LLMModel> availableModels = [lfm25Instruct];

  /// Get model by name
  static LLMModel? getModelByName(String name) {
    try {
      return availableModels.firstWhere((m) => m.name == name);
    } catch (_) {
      return null;
    }
  }
}
