/// Model definition for on-device LLM
class LLMModel {
  final String name;
  final String displayName;
  final String description;
  final String modelSlug;
  final String quantizationSlug;
  final List<String> legacyNames;
  final List<String> requiredFiles;
  final int estimatedSizeMB;
  final String? localPath;
  final String? downloadUrl;

  const LLMModel({
    required this.name,
    required this.displayName,
    required this.description,
    required this.modelSlug,
    required this.quantizationSlug,
    this.legacyNames = const [],
    required this.requiredFiles,
    required this.estimatedSizeMB,
    this.localPath,
    this.downloadUrl,
  });

  /// Liquid Managed Model (LFM2.5 1.2B Instruct Q8_0)
  static const lfm25Instruct = LLMModel(
    name: 'LFM2.5-1.2B-Instruct',
    displayName: 'LFM2.5-1.2B-Instruct Q8_0',
    description: 'LFM2.5-1.2B-Instruct Q8_0 (liquid_ai managed)',
    modelSlug: 'LFM2.5-1.2B-Instruct',
    quantizationSlug: 'Q8_0',
    legacyNames: [
      'LFM2-1.2B-8da4w_output_8da8w-seq_4096.bundle',
      'LFM2.5-1.2B-Instruct Q8_0',
    ],
    estimatedSizeMB: 1250,
    requiredFiles: [],
  );

  /// Default model
  static const defaultModel = lfm25Instruct;

  /// Currently supported models
  static const List<LLMModel> availableModels = [lfm25Instruct];

  /// Get model by name
  static LLMModel? getModelByName(String name) {
    final normalized = name.trim().toLowerCase();
    try {
      return availableModels.firstWhere((model) {
        if (model.name.toLowerCase() == normalized) return true;
        if (model.modelSlug.toLowerCase() == normalized) return true;
        if (model.displayName.toLowerCase() == normalized) return true;

        return model.legacyNames
            .map((value) => value.toLowerCase())
            .contains(normalized);
      });
    } catch (_) {
      return null;
    }
  }
}
