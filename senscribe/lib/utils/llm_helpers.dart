import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Helper utilities for LLM model file management
class LLMHelpers {
  /// Required model files for Phi-3.5-Mini (INT4 quantized)
  static const List<String> requiredFiles = [
    'config.json',
    'genai_config.json',
    'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx',
    'phi-3.5-mini-instruct-cpu-int4-awq-block-128-acc-level-4.onnx.data',
    'special_tokens_map.json',
    'tokenizer.json',
    'tokenizer_config.json',
  ];

  /// Check which files are missing in a directory
  static Future<List<String>> getMissingFiles(String folderPath) async {
    final missing = <String>[];

    for (final fileName in requiredFiles) {
      final filePath = p.join(folderPath, fileName);
      final file = File(filePath);
      if (!await file.exists()) {
        missing.add(fileName);
      }
    }

    return missing;
  }

  /// Validate that all required files exist in the folder
  static Future<bool> validateModelFolder(String folderPath) async {
    final missing = await getMissingFiles(folderPath);
    return missing.isEmpty;
  }

  /// Get a human-readable string of missing files
  static Future<String> getMissingFilesDescription(String folderPath) async {
    final missing = await getMissingFiles(folderPath);
    if (missing.isEmpty) {
      return 'All files present';
    }
    return 'Missing ${missing.length} file(s):\n${missing.map((f) => '  - $f').join('\n')}';
  }

  /// Check if a folder path is valid and exists
  static Future<bool> isFolderValid(String? folderPath) async {
    if (folderPath == null || folderPath.isEmpty) {
      return false;
    }
    final dir = Directory(folderPath);
    return await dir.exists();
  }

  /// Get folder size in MB (approximate)
  static Future<double> getFolderSizeMB(String folderPath) async {
    int totalSize = 0;
    final dir = Directory(folderPath);

    if (!await dir.exists()) {
      return 0;
    }

    try {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Error calculating folder size: $e');
    }

    return totalSize / (1024 * 1024); // Convert to MB
  }
}
