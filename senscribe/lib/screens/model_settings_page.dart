import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/summarization_service.dart';
import '../services/llm_service.dart';
import '../utils/llm_helpers.dart';
import '../models/llm_model.dart';

/// Settings page for configuring the on-device AI model for text summarization
class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final SummarizationService _summarizationService = SummarizationService();

  String? _modelPath;
  bool _isConfigured = false;
  List<String> _missingFiles = [];
  bool _isLoading = true;
  bool _isSelecting = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _loadModelStatus();
  }

  Future<void> _loadModelStatus() async {
    setState(() => _isLoading = true);

    final path = await _summarizationService.getModelPath();
    final configured = await _summarizationService.isModelConfigured();

    List<String> missing = [];
    bool isValid = false;

    if (path != null && path.isNotEmpty) {
      // On iOS, check if we have a valid bookmark (don't re-validate files)
      if (Platform.isIOS) {
        final llmService = LLMService();
        final hasBookmark = await llmService.hasValidBookmark();
        isValid = hasBookmark;
        // If no valid bookmark, show all files as missing to prompt re-selection
        if (!hasBookmark) {
          missing = List<String>.from(LLMHelpers.requiredFiles);
        }
      } else {
        // On Android, use Dart file validation
        missing = await LLMHelpers.getMissingFiles(path);
        isValid = missing.isEmpty;
      }
    }

    setState(() {
      _modelPath = path;
      _isConfigured = configured && isValid;
      _missingFiles = missing;
      _isLoading = false;
    });
  }

  /// Request storage permission on Android for direct file access
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;

    // For Android 11+ (API 30+), we need MANAGE_EXTERNAL_STORAGE permission
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
    }
    return status.isGranted;
  }

  Future<void> _selectModelFolder() async {
    if (_isSelecting) return;

    setState(() {
      _isSelecting = true;
      _statusMessage = '';
    });

    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final hasPermission = await _requestStoragePermission();
        if (!hasPermission) {
          if (mounted) {
            _showError(
              'Storage permission is required to access model files. '
              'Please grant "All files access" permission in Settings.',
            );
          }
          setState(() => _isSelecting = false);
          return;
        }
      }

      // Use directory picker
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select Model Folder',
      );

      if (selectedDirectory == null) {
        setState(() => _isSelecting = false);
        return;
      }

      setState(() => _statusMessage = 'Validating model files...');

      // On iOS, use native validation with security-scoped bookmark
      if (Platform.isIOS) {
        final llmService = LLMService();
        final result = await llmService.validateAndBookmarkFolder(
          selectedDirectory,
          LLMHelpers.requiredFiles,
        );

        if (result['success'] == true) {
          // Save path
          await _summarizationService.setModelPath(
            result['path'] ?? selectedDirectory,
          );
          await _loadModelStatus();
          if (mounted) {
            _showSuccess('Model configured successfully!');
          }
        } else if (result['missingFiles'] != null) {
          final missing = List<String>.from(result['missingFiles']);
          if (mounted) {
            _showError(
              'Missing ${missing.length} required file(s):\n${missing.take(3).join('\n')}${missing.length > 3 ? '\n...' : ''}',
            );
          }
        } else {
          if (mounted) {
            _showError(result['error'] ?? 'Failed to validate folder');
          }
        }
        setState(() => _isSelecting = false);
        return;
      }

      // On Android, use Dart file validation
      final valid = await LLMHelpers.validateModelFolder(selectedDirectory);

      if (!valid) {
        final missing = await LLMHelpers.getMissingFiles(selectedDirectory);
        if (mounted) {
          _showError(
            'Missing ${missing.length} required file(s):\n${missing.take(3).join('\n')}${missing.length > 3 ? '\n...' : ''}',
          );
        }
        setState(() => _isSelecting = false);
        return;
      }

      // Save path directly (no copying needed)
      await _summarizationService.setModelPath(selectedDirectory);

      // Reload status
      await _loadModelStatus();

      if (mounted) {
        _showSuccess('Model configured successfully!');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error selecting folder: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _clearConfiguration() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Configuration?'),
        content: const Text(
          'This will remove the saved model path. You can reconfigure it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _summarizationService.clearModelPath();
      // Also clear iOS bookmark if on iOS
      if (Platform.isIOS) {
        final llmService = LLMService();
        await llmService.clearBookmark();
      }
      await _loadModelStatus();
      if (mounted) {
        _showSuccess('Configuration cleared');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Model Configuration',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Gradient header
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primary, primary.withValues(alpha: 0.0)],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status card
                        _buildStatusCard(theme),
                        const SizedBox(height: 16),

                        // Configure button
                        _buildConfigureButton(theme),
                        const SizedBox(height: 24),

                        // Model information
                        _buildModelInfoCard(theme),
                        const SizedBox(height: 16),

                        // Required files (expandable)
                        _buildRequiredFilesCard(theme),
                        const SizedBox(height: 16),

                        // Clear configuration (if configured)
                        if (_modelPath != null && _modelPath!.isNotEmpty)
                          _buildClearButton(theme),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final statusColor = _isConfigured ? Colors.green : Colors.orange;
    final statusIcon = _isConfigured
        ? Icons.check_circle
        : Icons.warning_amber_rounded;
    final statusText = _isConfigured
        ? 'Model configured and ready'
        : _modelPath != null
        ? 'Model path set but files missing'
        : 'Model not configured';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.memory_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Model Status',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    statusText,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (_modelPath != null && _modelPath!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_outlined,
                      size: 16,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _modelPath!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_missingFiles.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Missing files:',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    ..._missingFiles
                        .take(5)
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              '- $f',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.red[600],
                              ),
                            ),
                          ),
                        ),
                    if (_missingFiles.length > 5)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '... and ${_missingFiles.length - 5} more',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.red[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildConfigureButton(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _isSelecting ? null : _selectModelFolder,
            icon: _isSelecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open),
            label: Text(
              _isSelecting
                  ? 'Selecting...'
                  : (_modelPath != null
                        ? 'Change Model Folder'
                        : 'Select Model Folder'),
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        if (_statusMessage.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _statusMessage,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: theme.colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildModelInfoCard(ThemeData theme) {
    final model = LLMModel.currentModel;
    const downloadUrl =
        'https://huggingface.co/microsoft/Phi-3.5-mini-instruct-onnx/tree/main/cpu_and_mobile/cpu-int4-awq-block-128-acc-level-4';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Model Information',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Model', model.name, theme),
            _buildInfoRow('Purpose', model.description, theme),
            _buildInfoRow('Size', '~${model.estimatedSizeMB} MB', theme),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Download the Phi-3.5-Mini model files and place them in a folder on your device. Then select that folder above.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(downloadUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_rounded,
                          color: Colors.blue[700],
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Download model files from HuggingFace',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[700],
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.open_in_new,
                          color: Colors.blue[700],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredFilesCard(ThemeData theme) {
    final model = LLMModel.currentModel;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.description_outlined,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          'Required Files',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${model.requiredFiles.length} files required',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        children: model.requiredFiles
            .map(
              (f) => ListTile(
                dense: true,
                leading: Icon(
                  _missingFiles.contains(f)
                      ? Icons.close_rounded
                      : (_modelPath != null
                            ? Icons.check_rounded
                            : Icons.description_outlined),
                  size: 18,
                  color: _missingFiles.contains(f)
                      ? Colors.red
                      : (_modelPath != null
                            ? Colors.green
                            : theme.iconTheme.color),
                ),
                title: Text(
                  f,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _missingFiles.contains(f) ? Colors.red : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1);
  }

  Widget _buildClearButton(ThemeData theme) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _clearConfiguration,
        icon: const Icon(Icons.clear_rounded),
        label: Text(
          'Clear Configuration',
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red[700],
          side: BorderSide(color: Colors.red[300]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1);
  }
}
