import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/model_download_snapshot.dart';
import '../services/summarization_service.dart';
import '../models/llm_model.dart';

/// Settings page for configuring the Leap AI model
class ModelSettingsPage extends StatefulWidget {
  const ModelSettingsPage({super.key});

  @override
  State<ModelSettingsPage> createState() => _ModelSettingsPageState();
}

class _ModelSettingsPageState extends State<ModelSettingsPage> {
  final SummarizationService _summarizationService = SummarizationService();

  // Using default model for simplified UI
  final String _modelId = LLMModel.defaultModel.name;

  bool _isConfigured = false;
  bool _isLoading = true;
  ModelDownloadSnapshot _downloadSnapshot = ModelDownloadSnapshot.idle(
    modelId: LLMModel.defaultModel.name,
  );
  StreamSubscription<ModelDownloadSnapshot>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _downloadSubscription =
        _summarizationService.downloadStateStream.listen(_handleDownloadUpdate);
    _checkStatus();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final model = LLMModel.getModelByName(_modelId) ?? LLMModel.defaultModel;
    final configured = await _summarizationService.isModelConfigured(model);
    final downloadSnapshot =
        await _summarizationService.refreshDownloadState(model);

    if (mounted) {
      setState(() {
        _isConfigured = configured;
        _downloadSnapshot = downloadSnapshot;
        _isLoading = false;
      });
    }
  }

  Future<void> _startDownload() async {
    if (_downloadSnapshot.isRunning) return;
    final shouldContinue = await _showDownloadWarning();
    if (!shouldContinue) return;

    try {
      final model = LLMModel.getModelByName(_modelId) ?? LLMModel.defaultModel;
      await _summarizationService.startModelDownload(model);
    } catch (e) {
      if (mounted) {
        _showError('Operation failed: $e');
      }
    }
  }

  Future<void> _deleteModel() async {
    if (!_isConfigured || _downloadSnapshot.isRunning) return;

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
      final model = LLMModel.getModelByName(_modelId) ?? LLMModel.defaultModel;
      await _summarizationService.deleteModelFiles(model);
      if (!mounted) return;

      _showSuccess('Model deleted');
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

  Future<bool> _showDownloadWarning() async {
    var shouldContinue = false;
    final message = Platform.isAndroid
        ? 'Stay on this screen until the download starts. Android can continue the download in the background.'
        : 'Stay on this screen until the download starts. iOS may pause the transfer if the app stays in the background too long.';

    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Keep this screen open',
      message: message,
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Start Download',
          style: AlertActionStyle.primary,
          onPressed: () {
            shouldContinue = true;
          },
        ),
      ],
    );
    return shouldContinue;
  }

  void _handleDownloadUpdate(ModelDownloadSnapshot snapshot) {
    if (snapshot.modelId != _modelId || !mounted) return;
    final wasRunning = _downloadSnapshot.isRunning;

    setState(() {
      _downloadSnapshot = snapshot;
    });

    if (wasRunning && !snapshot.isRunning) {
      if (snapshot.hasError) {
        _showError('Operation failed: ${snapshot.lastError}');
      } else if (snapshot.isComplete) {
        _showSuccess('Model loaded and ready!');
      }
      unawaited(_checkStatus());
    }
  }

  Future<void> _cancelDownload() async {
    try {
      await _summarizationService.cancelModelDownloadIfSupported();
      await _checkStatus();
    } catch (error) {
      if (!mounted) return;
      _showError('Unable to cancel download: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = PlatformInfo.isIOS26OrHigher()
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(title: 'AI Model Settings'),
      body: Material(
        color: Colors.transparent,
        child: _isLoading
            ? Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: const CircularProgressIndicator(),
                ),
              )
            : RefreshIndicator(
                onRefresh: _checkStatus,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (topInset > 0) SizedBox(height: topInset),
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
    final statusText = _downloadSnapshot.isRunning
        ? 'Download In Progress'
        : (_isConfigured ? 'Model Found' : 'Model Not Found');

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
                      _downloadSnapshot.isRunning
                          ? _downloadSnapshot.statusMessage
                          : (_isConfigured
                              ? 'Ready for use'
                              : 'Requires download'),
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
    if (_downloadSnapshot.isRunning) {
      return AdaptiveCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Downloading Model...',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (_downloadSnapshot.progress > 0 &&
                _downloadSnapshot.progress < 1.0)
              LinearProgressIndicator(value: _downloadSnapshot.progress)
            else
              const LinearProgressIndicator(), // Indeterminate active

            const SizedBox(height: 8),
            if (_downloadSnapshot.statusMessage.isNotEmpty)
              Text(
                _downloadSnapshot.statusMessage,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 8),
            Text(
              _downloadSnapshot.platformCanContinueInBackground
                  ? 'This download can continue while you leave the screen.'
                  : 'Keep this screen open when possible for the most stable transfer.',
              style: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: AdaptiveButton(
                onPressed: _cancelDownload,
                label: 'Cancel Download',
                style: AdaptiveButtonStyle.bordered,
                color: Colors.red,
                useNative: false,
              ),
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
            useNative: false,
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
                useNative: false,
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
          _buildInfoRow('Type', 'Liquid AI Managed Model', theme),
          _buildInfoRow(
            'Description',
            'LFM2.5-1.2B-Instruct Q8_0. Managed via liquid_ai.',
            theme,
          ),
          const SizedBox(height: 8),
          Text(
            'Powered by liquid_ai',
            style: GoogleFonts.inter(
                fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
