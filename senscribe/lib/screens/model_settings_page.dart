import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_leap_sdk/flutter_leap_sdk.dart';
import 'dart:io';

import '../services/summarization_service.dart';
import '../models/llm_model.dart';
import '../services/leap_service.dart';

/// Settings page for configuring the Leap AI model
class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final SummarizationService _summarizationService = SummarizationService();

  // Using default model for simplified UI
  final String _modelId = LeapService.defaultModelId;

  bool _isConfigured = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final configured = await _summarizationService.isModelConfigured();

    if (mounted) {
      setState(() {
        _isConfigured = configured;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _statusMessage = 'Initializing Leap...';
    });

    try {
      // Retrieve the full model definition to ensure downloadUrl and localPath are present
      final model = LLMModel.getModelByName(_modelId) ??
          LLMModel.defaultModel; // Fallback only if not found

      await _summarizationService.downloadModelFiles(
        model,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _downloadProgress = progress);
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() => _statusMessage = status);
          }
        },
      );

      if (mounted) {
        _showSuccess('Model loaded and ready!');
        await _checkStatus();
      }
    } catch (e) {
      if (mounted) {
        _showError('Operation failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
        _statusMessage = '';
      }
    }
  }

  Future<void> _deleteModel() async {
    if (!_isConfigured || _isDownloading) return;

    var shouldDelete = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Delete model files?',
      message:
          'This will remove the downloaded AI model from this device. You can download it again later.',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Delete',
          style: AlertActionStyle.destructive,
          onPressed: () {
            shouldDelete = true;
          },
        ),
      ],
    );

    if (!shouldDelete) return;

    try {
      await _summarizationService.unloadModel();
      final deleted = await FlutterLeapSdkService.deleteModel(_modelId);
      if (!mounted) return;

      if (deleted) {
        _showSuccess('Model deleted');
      } else {
        _showError('Model file was not found on device');
      }
      await _checkStatus();
    } catch (e) {
      if (mounted) {
        _showError('Delete failed: $e');
      }
    }
  }

  void _showError(String message) {
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.error,
    );
  }

  void _showSuccess(String message) {
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'AI Model Settings'),
      body: Material(
        color: Colors.transparent,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _checkStatus,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top padding for iOS 26 translucent app bar
                      if (Platform.isIOS)
                        SizedBox(
                            height: MediaQuery.of(context).padding.top +
                                kToolbarHeight),
                      _buildStatusCard(theme),
                      const SizedBox(height: 24),
                      _buildActionSection(theme),
                      const SizedBox(height: 24),
                      _buildModelInfoCard(theme),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard(ThemeData theme) {
    final statusColor = _isConfigured ? Colors.green : Colors.orange;
    final statusIcon =
        _isConfigured ? Icons.check_circle : Icons.cloud_off_rounded;
    final statusText = _isConfigured ? 'Model Found' : 'Model Not Found';

    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isConfigured ? 'Ready for use' : 'Requires download',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildActionSection(ThemeData theme) {
    if (_isDownloading) {
      return AdaptiveCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Initializing Model...',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_downloadProgress > 0 && _downloadProgress < 1.0)
              LinearProgressIndicator(value: _downloadProgress)
            else
              const LinearProgressIndicator(), // Indeterminate active

            const SizedBox(height: 8),
            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      );
    }

    // Action Buttons
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: AdaptiveButton(
            onPressed: _startDownload,
            label: _isConfigured ? 'Reload Model' : 'Download Model (~1.25 GB)',
            style: AdaptiveButtonStyle.filled,
          ),
        ),
        if (_isConfigured)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                onPressed: _deleteModel,
                label: 'Delete Model from Device',
                style: AdaptiveButtonStyle.plain,
                color: Colors.red,
              ),
            ),
          ),
        if (!_isConfigured)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Downloads model package managed by Liquid AI.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildModelInfoCard(ThemeData theme) {
    return AdaptiveCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Model Information',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('ID', _modelId, theme),
          _buildInfoRow('Type', 'Leap Managed Model', theme),
          _buildInfoRow(
            'Description',
            'LFM2.5-1.2B-Instruct Q8_0. Managed via Liquid SDK.',
            theme,
          ),
          const SizedBox(height: 8),
          Text(
            'Powered by flutter_leap_sdk',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
