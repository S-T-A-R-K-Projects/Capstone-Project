/// Model definition for on-device LLM
class LLMModel {
  final String name;
  final String description;
  final List<String> requiredFiles;
  final int estimatedSizeMB;

  const LLMModel({
    required this.name,
    required this.description,
    required this.requiredFiles,
    required this.estimatedSizeMB,
  });

  /// Default model: Phi-3.5-Mini (INT4 quantized for CPU)
  /// Optimized for text summarization on mobile devices
  static const phi35Mini = LLMModel(
    name: 'Phi-3.5-Mini',
    description: 'Optimized for text summarization on mobile devices',
    requiredFiles: [
      'config.json',
      'genai_config.json',
      'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx',
      'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx.data',
      'special_tokens_map.json',
      'tokenizer.json',
      'tokenizer_config.json',
    ],
    estimatedSizeMB: 2800,
  );

  /// Currently supported model (can be expanded in the future)
  static const currentModel = phi35Mini;
}
