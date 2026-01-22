import 'dart:async';
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
  final HistoryService _service = HistoryService();
  List<HistoryItem> _items = [];
  bool _loading = true;
  StreamSubscription<void>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen for history changes from other parts of the app
    _changeSubscription = _service.onHistoryChanged.listen((_) {
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
    final items = await _service.loadHistory();
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
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
    await _service.remove(id);
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
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Name'),
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
    final title = updatedTitle.isEmpty ? item.title : updatedTitle;
    await _service.update(item.copyWith(title: title));
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove all history entries.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _service.clear();
      await _load();
    }
  }

  void _showDetailModal(HistoryItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => _HistoryDetailModal(
        item: item,
        onRename: () async {
          Navigator.of(c).pop();
          await _rename(item);
        },
        onDelete: () async {
          Navigator.of(c).pop();
          await _remove(item.id);
        },
        onSummaryUpdated: () {
          // Reload the list to reflect summary changes
          _load();
        },
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
          'History',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear history',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _items.isEmpty ? null : _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 84,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [primary, primary.withAlpha(0)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Recent activity',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                ? Center(
                    child: Text(
                      'No history yet',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final entry = _items[index];
                      return Dismissible(
                        key: ValueKey(entry.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _remove(entry.id),
                        background: Container(
                          color: Colors.redAccent,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: entry.hasSummary
                                ? Colors.green[100]
                                : theme.colorScheme.primaryContainer,
                            child: Icon(
                              entry.hasSummary ? Icons.summarize : Icons.mic,
                              color: entry.hasSummary
                                  ? Colors.green[700]
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            entry.title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${_previewContent(entry)} - ${_formatTimestamp(entry.timestamp)}',
                            style: GoogleFonts.inter(),
                          ),
                          trailing: entry.hasSummary
                              ? Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 18,
                                )
                              : null,
                          onTap: () => _showDetailModal(entry),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Modal for viewing history item details with tabbed transcript/summary view
class _HistoryDetailModal extends StatefulWidget {
  final HistoryItem item;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onSummaryUpdated;

  const _HistoryDetailModal({
    required this.item,
    required this.onRename,
    required this.onDelete,
    required this.onSummaryUpdated,
  });

  @override
  State<_HistoryDetailModal> createState() => _HistoryDetailModalState();
}

class _HistoryDetailModalState extends State<_HistoryDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HistoryItem _currentItem;

  final HistoryService _historyService = HistoryService();
  final SummarizationService _summarizationService = SummarizationService();

  bool _isSummarizing = false;
  String _streamedSummary = '';
  StreamSubscription<String>? _tokenSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _currentItem = widget.item;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _tokenSubscription?.cancel();
    super.dispose();
  }

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _startSummarization() async {
    // Check if model is configured
    final configured = await _summarizationService.isModelConfigured();

    if (!configured) {
      _showConfigureDialog();
      return;
    }

    setState(() {
      _isSummarizing = true;
      _streamedSummary = '';
    });

    // Switch to summary tab
    _tabController.animateTo(1);

    try {
      // Start summarization with callback for streaming
      final summary = await _summarizationService.summarizeWithCallback(
        _currentItem.content,
        onToken: (token) {
          if (mounted) {
            setState(() {
              _streamedSummary += token;
            });
          }
        },
      );

      // Save summary to history
      await _historyService.updateSummary(_currentItem.id, summary);

      // Update local item
      if (mounted) {
        setState(() {
          _currentItem = _currentItem.copyWith(
            summary: summary,
            summaryTimestamp: DateTime.now(),
          );
        });
        widget.onSummaryUpdated();
      }
    } on SummarizationException catch (e) {
      if (mounted) {
        _showError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _showError('Summarization failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  void _showConfigureDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Model Not Configured'),
        content: const Text(
          'To use text summarization, you need to configure the AI model first.\n\n'
          'This requires downloading the Phi-3.5-Mini model (~1.8 GB) and selecting its folder location in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close modal
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ModelSettingsPage(),
                ),
              );
            },
            child: const Text('Configure Now'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentItem.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Recorded ${_formatTimestamp(_currentItem.timestamp)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: widget.onRename,
                        tooltip: 'Rename',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: widget.onDelete,
                        tooltip: 'Delete',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: theme.colorScheme.onSurface,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Transcript'),
                  Tab(text: 'Summary'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTranscriptTab(theme, scrollController),
                  _buildSummaryTab(theme, scrollController),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranscriptTab(
    ThemeData theme,
    ScrollController scrollController,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: SelectableText(
                  _currentItem.content,
                  style: GoogleFonts.inter(fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSummarizeButton(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(ThemeData theme, ScrollController scrollController) {
    // Determine what to show
    String displayText;
    bool showPlaceholder = false;

    if (_isSummarizing) {
      displayText = _streamedSummary.isEmpty
          ? 'Loading model and generating summary...'
          : _streamedSummary;
    } else if (_currentItem.summary != null &&
        _currentItem.summary!.isNotEmpty) {
      displayText = _currentItem.summary!;
    } else {
      displayText =
          'No summary available yet.\n\nTap "Summarize" to generate a summary of this transcript using on-device AI.';
      showPlaceholder = true;
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
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
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
                        color: showPlaceholder ? Colors.grey[500] : null,
                        fontStyle: showPlaceholder ? FontStyle.italic : null,
                      ),
                    ),
                    if (_currentItem.summaryTimestamp != null &&
                        !_isSummarizing) ...[
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
                              'Summarized ${_formatTimestamp(_currentItem.summaryTimestamp!)}',
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
          _buildSummarizeButton(theme),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummarizeButton(ThemeData theme) {
    final hasSummary =
        _currentItem.summary != null && _currentItem.summary!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isSummarizing ? null : _startSummarization,
        icon: _isSummarizing
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.onPrimary,
                ),
              )
            : Icon(hasSummary ? Icons.refresh : Icons.auto_awesome),
        label: Text(
          _isSummarizing
              ? 'Summarizing...'
              : (hasSummary ? 'Re-summarize' : 'Summarize'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          disabledBackgroundColor: theme.colorScheme.primary.withValues(
            alpha: 0.7,
          ),
          disabledForegroundColor: theme.colorScheme.onPrimary.withValues(
            alpha: 0.7,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
