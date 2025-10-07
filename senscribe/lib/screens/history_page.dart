import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';

class HistoryEntry {
  final String id;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  HistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.metadata = const {},
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
        'metadata': metadata,
      };

  String toCsvRow() {
    String safe(String? s) => (s ?? '').replaceAll('"', '""');
    return '"${safe(id)}","${safe(title)}","${safe(subtitle)}","${timestamp.toIso8601String()}","${jsonEncode(metadata).replaceAll('"', '""')}"';
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<HistoryEntry> _entries;

  @override
  void initState() {
    super.initState();
    // Example seeded history for prototype
    _entries = [
      HistoryEntry(
        id: '1',
        title: 'Bird Chirp',
        subtitle: 'Recorded at park',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        metadata: {'duration_ms': 2400, 'format': 'wav'},
      ),
      HistoryEntry(
        id: '2',
        title: 'Guitar Riff',
        subtitle: 'Sample from jam',
        timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        metadata: {'duration_ms': 5200, 'format': 'mp3'},
      ),
      HistoryEntry(
        id: '3',
        title: 'Voice Note',
        subtitle: 'Idea for chorus',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        metadata: {'duration_ms': 15000, 'format': 'm4a'},
      ),
    ];
  }

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _exportAsCsv() async {
    if (_entries.isEmpty) {
      _showSnack('No history to export');
      return;
    }
    final header = '"id","title","subtitle","timestamp","metadata"';
    final rows = _entries.map((e) => e.toCsvRow()).join('\n');
    final csv = '$header\n$rows';
    await Share.share(csv, subject: 'Sound history export.csv');
  }

  Future<void> _exportAsJson() async {
    if (_entries.isEmpty) {
      _showSnack('No history to export');
      return;
    }
    final list = _entries.map((e) => e.toMap()).toList();
    final jsonString = const JsonEncoder.withIndent('  ').convert(list);
    await Share.share(jsonString, subject: 'Sound history export.json');
  }

  void _deleteEntry(int index) {
    final removed = _entries.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) => _buildItem(removed, animation, index, removedItem: true),
      duration: const Duration(milliseconds: 300),
    );
    _showUndoSnack(
      message: 'Deleted "${removed.title}"',
      onUndo: () {
        _entries.insert(index, removed);
        _listKey.currentState?.insertItem(index, duration: const Duration(milliseconds: 300));
      },
    );
  }

  void _clearAll() async {
    if (_entries.isEmpty) {
      _showSnack('History is already empty');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all history'),
        content: const Text('This will permanently delete all history entries. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = List<HistoryEntry>.from(_entries);
      final count = _entries.length;
      for (var i = count - 1; i >= 0; i--) {
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => _buildItem(_entries[i], animation, i, removedItem: true),
          duration: const Duration(milliseconds: 200),
        );
      }
      _entries.clear();
      _showUndoSnack(
        message: 'Cleared all history',
        onUndo: () {
          _entries = removed;
          for (var i = 0; i < _entries.length; i++) {
            _listKey.currentState?.insertItem(i, duration: const Duration(milliseconds: 200));
          }
        },
      );
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showUndoSnack({required String message, required VoidCallback onUndo}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(label: 'Undo', onPressed: onUndo),
      ),
    );
  }

  Widget _buildItem(HistoryEntry entry, Animation<double> animation, int index, {bool removedItem = false}) {
    final tile = ListTile(
      leading: Semantics(
        label: 'History item ${entry.title}',
        child: CircleAvatar(child: Icon(Icons.audiotrack, size: 18)),
      ),
      title: Text(entry.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      subtitle: Text('${entry.subtitle} • ${_formatTimestamp(entry.timestamp)}', style: GoogleFonts.inter()),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          if (!removedItem) _deleteEntry(index);
        },
        tooltip: 'Delete',
      ),
      onTap: () {
        // Prototype: show details modal; replace with real playback/detail behavior
        showModalBottomSheet(
          context: context,
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entry.title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Recorded: ${entry.timestamp.toLocal()}'),
              const SizedBox(height: 8),
              Text('Metadata: ${jsonEncode(entry.metadata)}'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _showSnack('Play action would run here (prototype)');
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
            ]),
          ),
        );
      },
    );

    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: tile.animate().fadeIn().slideX(begin: 0.03).then().shimmer(duration: 700.ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final iconColor = Colors.grey[400];

    return Scaffold(
      appBar: AppBar(
        title: Text('History', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: primary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Export',
            onPressed: () async {
              final choice = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => SafeArea(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    ListTile(
                      leading: const Icon(Icons.table_chart),
                      title: const Text('Export CSV'),
                      onTap: () => Navigator.of(ctx).pop('csv'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: const Text('Export JSON'),
                      onTap: () => Navigator.of(ctx).pop('json'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.close),
                      title: const Text('Cancel'),
                      onTap: () => Navigator.of(ctx).pop(),
                    ),
                  ]),
                ),
              );
              if (choice == 'csv') {
                await _exportAsCsv();
              } else if (choice == 'json') {
                await _exportAsJson();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: 'Clear all',
            onPressed: _clearAll,
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
                  colors: [primary, primary.withOpacity(0.0)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    'Recent activity',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_rounded, size: 80, color: iconColor).animate().scale(duration: 600.ms).shimmer(),
                        const SizedBox(height: 24),
                        Text('History Page', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[700])),
                        const SizedBox(height: 8),
                        Text('Sound history will appear here', style: GoogleFonts.inter(color: Colors.grey[500])),
                      ],
                    ).animate().fadeIn(duration: 600.ms),
                  )
                : AnimatedList(
                    key: _listKey,
                    initialItemCount: _entries.length,
                    itemBuilder: (context, index, animation) {
                      final entry = _entries[index];
                      return _buildItem(entry, animation, index);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Prototype: add a new fake entry to demonstrate insertion
          final newEntry = HistoryEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: 'New Recording',
            subtitle: 'Quick demo',
            timestamp: DateTime.now(),
            metadata: {'duration_ms': 1800},
          );
          final insertIndex = 0;
          _entries.insert(insertIndex, newEntry);
          _listKey.currentState?.insertItem(insertIndex, duration: const Duration(milliseconds: 300));
          _showSnack('Added demo entry');
        },
        tooltip: 'Add demo entry',
        child: const Icon(Icons.add),
      ),
    );
  }
}
