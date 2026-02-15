import 'dart:async';
import 'dart:io';

import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/history_item.dart';
import '../services/history_service.dart';
import '../services/summarization_service.dart';
import 'model_settings_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _historyService = HistoryService();
  List<HistoryItem> _items = [];
  bool _loading = true;
  StreamSubscription<void>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    _changeSubscription = _historyService.onHistoryChanged.listen((_) {
      _load();
    });
  }

  @override
  void dispose() {
    _changeSubscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _historyService.loadHistory();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _previewContent(HistoryItem item) {
    final text = item.content.trim();
    if (text.isEmpty) return item.subtitle;
    const maxLength = 64;
    return text.length > maxLength
        ? '${text.substring(0, maxLength)}...'
        : text;
  }

  Future<void> _remove(String id) async {
    await _historyService.remove(id);
    await _load();
  }

  Future<void> _rename(HistoryItem item) async {
    final controller = TextEditingController(text: item.title);
    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename transcription'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Name',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (updatedTitle == null) return;
    final title = updatedTitle.trim();
    if (title.isEmpty) return;

    await _historyService.update(item.copyWith(title: title));
    await _load();
  }

  Future<void> _clearAll() async {
    var shouldClear = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Clear history?',
      message: 'This will remove all history entries.',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Clear',
          style: AlertActionStyle.destructive,
          onPressed: () {
            shouldClear = true;
          },
        ),
      ],
    );

    if (!shouldClear) return;
    await _historyService.clear();
    await _load();
  }

  Future<void> _openDetail(HistoryItem item) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => HistoryDetailPage(itemId: item.id),
      ),
    );

    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = Platform.isIOS
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'History',
        actions: [
          if (_items.isNotEmpty)
            AdaptiveAppBarAction(
              onPressed: _clearAll,
              icon: Icons.delete_sweep_outlined,
              iosSymbol: 'trash',
            ),
        ],
      ),
      body: Material(
        color: Colors.transparent,
        child: _loading
            ? Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: const CircularProgressIndicator(),
                ),
              )
            : _items.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: topInset),
                      child: Text(
                        'No history yet',
                        style: GoogleFonts.inter(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final entry = _items[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Dismissible(
                          key: ValueKey(entry.id),
                          direction: DismissDirection.endToStart,
                          onDismissed: (_) => _remove(entry.id),
                          background: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              color: theme.colorScheme.error,
                              alignment: Alignment.centerRight,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Icon(
                                Icons.delete,
                                color: theme.colorScheme.onError,
                              ),
                            ),
                          ),
                          child: AdaptiveCard(
                            padding: EdgeInsets.zero,
                            borderRadius: BorderRadius.circular(16),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: AdaptiveListTile(
                                leading: CircleAvatar(
                                  backgroundColor: entry.hasSummary
                                      ? theme.colorScheme.secondaryContainer
                                      : theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    entry.hasSummary
                                        ? Icons.summarize
                                        : Icons.mic,
                                    color: entry.hasSummary
                                        ? theme.colorScheme.onSecondaryContainer
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                title: Text(
                                  entry.title,
                                  style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  '${_previewContent(entry)} · ${_formatTimestamp(entry.timestamp)}',
                                  style: GoogleFonts.inter(),
                                ),
                                trailing: entry.hasSummary
                                    ? Icon(
                                        Icons.check_circle,
                                        color: theme.colorScheme.secondary,
                                        size: 18,
                                      )
                                    : null,
                                onTap: () => _openDetail(entry),
                                onLongPress: () => _rename(entry),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class HistoryDetailPage extends StatefulWidget {
  final String itemId;

  const HistoryDetailPage({super.key, required this.itemId});

  @override
  State<HistoryDetailPage> createState() => _HistoryDetailPageState();
}

class _HistoryDetailPageState extends State<HistoryDetailPage> {
  final HistoryService _historyService = HistoryService();
  final SummarizationService _summarizationService = SummarizationService();

  int _selectedViewIndex = 0;
  final TextEditingController _transcriptController = TextEditingController();

  HistoryItem? _item;
  bool _loading = true;
  bool _isEditing = false;
  bool _isSummarizing = false;
  String _streamedSummary = '';

  @override
  void initState() {
    super.initState();
    _loadItem();
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  Future<void> _loadItem() async {
    setState(() => _loading = true);
    final item = await _historyService.getById(widget.itemId);
    if (!mounted) return;

    setState(() {
      _item = item;
      _loading = false;
      _isEditing = false;
      _transcriptController.text = item?.content ?? '';
    });
  }

  String _formatTimestamp(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _renameTitle() async {
    final item = _item;
    if (item == null) return;

    final controller = TextEditingController(text: item.title);
    final updatedTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename transcription'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Name',
            border: OutlineInputBorder(),
          ),
          maxLength: 40,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (updatedTitle == null) return;
    final title = updatedTitle.trim();
    if (title.isEmpty) return;

    await _historyService.update(item.copyWith(title: title));
    await _loadItem();
    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: 'Title updated',
      type: AdaptiveSnackBarType.success,
    );
  }

  Future<void> _deleteItem() async {
    final item = _item;
    if (item == null) return;

    var shouldDelete = false;
    await AdaptiveAlertDialog.show(
      context: context,
      title: 'Delete transcription?',
      message: 'This action cannot be undone.',
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
    await _historyService.remove(item.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _saveTranscript() async {
    final item = _item;
    if (item == null) return;

    final updatedText = _transcriptController.text.trim();
    if (updatedText.isEmpty) return;

    await _historyService.update(item.copyWith(content: updatedText));
    await _loadItem();
    if (!mounted) return;

    setState(() {
      _isEditing = false;
    });

    AdaptiveSnackBar.show(
      context,
      message: 'Transcription updated',
      type: AdaptiveSnackBarType.success,
    );
  }

  void _cancelEdit() {
    final item = _item;
    if (item == null) return;
    setState(() {
      _isEditing = false;
      _transcriptController.text = item.content;
    });
  }

  Future<void> _startSummarization() async {
    final item = _item;
    if (item == null) return;

    final configured = await _summarizationService.isModelConfigured();
    if (!configured) {
      _showConfigureDialog();
      return;
    }

    setState(() {
      _isSummarizing = true;
      _streamedSummary = '';
      _selectedViewIndex = 1;
    });

    try {
      final summary = await _summarizationService.summarizeWithCallback(
        item.content,
        onToken: (token) {
          if (!mounted) return;
          setState(() {
            _streamedSummary += token;
          });
        },
      );

      await _historyService.updateSummary(item.id, summary);
      await _loadItem();
    } on SummarizationException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Summarization failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  void _showConfigureDialog() {
    AdaptiveAlertDialog.show(
      context: context,
      title: 'AI Model Not Configured',
      message:
          'To use text summarization, configure the AI model first in Model Settings.',
      actions: [
        AlertAction(
          title: 'Cancel',
          style: AlertActionStyle.cancel,
          onPressed: () {},
        ),
        AlertAction(
          title: 'Configure Now',
          style: AlertActionStyle.primary,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModelSettingsPage()),
            );
          },
        ),
      ],
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    AdaptiveSnackBar.show(
      context,
      message: message,
      type: AdaptiveSnackBarType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = Platform.isIOS
        ? MediaQuery.of(context).padding.top + kToolbarHeight
        : 0.0;

    final item = _item;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: item?.title ?? 'Transcript',
        actions: [
          if (item != null)
            AdaptiveAppBarAction(
              onPressed: _renameTitle,
              icon: Icons.drive_file_rename_outline,
              iosSymbol: 'pencil',
            ),
          if (item != null)
            AdaptiveAppBarAction(
              onPressed: _deleteItem,
              icon: Icons.delete_outline,
              iosSymbol: 'trash',
            ),
        ],
      ),
      body: Material(
        color: Colors.transparent,
        child: _loading
            ? Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topInset),
                  child: const CircularProgressIndicator(),
                ),
              )
            : item == null
                ? Center(
                    child: Text(
                      'Transcription not found',
                      style: GoogleFonts.inter(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      if (Platform.isIOS) SizedBox(height: topInset),
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.72),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Recorded ${_formatTimestamp(item.timestamp)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SizedBox(
                          height: 44,
                          child: AdaptiveSegmentedControl(
                            labels: const ['Transcript', 'Summary'],
                            color: theme.colorScheme.surfaceContainerHighest,
                            selectedIndex: _selectedViewIndex,
                            onValueChanged: (index) {
                              setState(() {
                                _selectedViewIndex = index;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: IndexedStack(
                          index: _selectedViewIndex,
                          children: [
                            _buildTranscriptTab(theme, item),
                            _buildSummaryTab(theme, item),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTranscriptTab(ThemeData theme, HistoryItem item) {
    final containerColor = PlatformInfo.isIOS26OrHigher()
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
    final textColor = theme.colorScheme.onSurface;

    if (!_isEditing && _transcriptController.text != item.content) {
      _transcriptController.value = TextEditingValue(
        text: item.content,
        selection: TextSelection.collapsed(offset: item.content.length),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (!_isEditing)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 110,
                child: AdaptiveButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _transcriptController.text = item.content;
                    });
                  },
                  label: 'Edit Text',
                  style: AdaptiveButtonStyle.plain,
                ),
              ),
            ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 90,
                    child: AdaptiveButton(
                      onPressed: _cancelEdit,
                      label: 'Cancel',
                      style: AdaptiveButtonStyle.plain,
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: AdaptiveButton(
                      onPressed: _saveTranscript,
                      label: 'Save',
                      style: AdaptiveButtonStyle.filled,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: _isEditing
                  ? TextField(
                      controller: _transcriptController,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Transcript text...',
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.6,
                        color: textColor,
                      ),
                    )
                  : SingleChildScrollView(
                      child: SelectableText(
                        item.content.trim().isEmpty
                            ? 'No transcript text available.'
                            : item.content,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          height: 1.6,
                          color: textColor,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isEditing) ...[
            _buildSummarizeButton(theme, item),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryTab(ThemeData theme, HistoryItem item) {
    final hasSummary = item.summary != null && item.summary!.isNotEmpty;

    String displayText;
    bool placeholder = false;

    if (_isSummarizing) {
      displayText = _streamedSummary.isEmpty
          ? 'Loading model and generating summary...'
          : _streamedSummary;
    } else if (hasSummary) {
      displayText = item.summary!;
    } else {
      placeholder = true;
      displayText =
          'No summary available yet.\n\nTap "Summarize" to generate a summary of this transcript using on-device AI.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSummarizing) ...[
                      Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Generating...',
                            style: GoogleFonts.inter(
                              fontStyle: FontStyle.italic,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    SelectableText(
                      displayText,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        height: 1.6,
                        color: placeholder
                            ? theme.colorScheme.onSurface
                                .withValues(alpha: 0.64)
                            : theme.colorScheme.onSurface,
                        fontStyle: placeholder ? FontStyle.italic : null,
                      ),
                    ),
                    if (item.summaryTimestamp != null && !_isSummarizing) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Summarized ${_formatTimestamp(item.summaryTimestamp!)}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummarizeButton(theme, item),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummarizeButton(ThemeData theme, HistoryItem item) {
    final hasSummary = item.summary != null && item.summary!.isNotEmpty;

    if (_isSummarizing) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: AdaptiveButton.child(
          onPressed: null,
          style: AdaptiveButtonStyle.filled,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Summarizing...',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: AdaptiveButton.child(
        onPressed: _startSummarization,
        style: AdaptiveButtonStyle.filled,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(hasSummary ? Icons.refresh : Icons.auto_awesome),
            const SizedBox(width: 8),
            Text(
              hasSummary ? 'Re-summarize' : 'Summarize',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
