
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/history_item.dart';
import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _service = HistoryService();
  List<HistoryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _remove(String id) async {
    await _service.remove(id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This will remove all history entries.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Clear')),
        ],
      ),
    );

    if (ok == true) {
      await _service.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('History', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
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
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
                        child: Text('No history yet', style: GoogleFonts.inter(color: Colors.grey[600])),
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
                              leading: const CircleAvatar(child: Icon(Icons.mic)),
                              title: Text(entry.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              subtitle: Text('${entry.subtitle} • ${_formatTimestamp(entry.timestamp)}', style: GoogleFonts.inter()),
                              onTap: () async {
                                // Minimal details sheet
                                await showModalBottomSheet<void>(
                                  context: context,
                                  builder: (c) => Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(entry.title, style: theme.textTheme.titleLarge),
                                        const SizedBox(height: 8),
                                        Text(entry.subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700])),
                                        const SizedBox(height: 8),
                                        Text('Recorded: ${entry.timestamp.toLocal().toString()}', style: theme.textTheme.bodySmall),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close')),
                                            TextButton(
                                              onPressed: () async {
                                                Navigator.of(c).pop();
                                                await _remove(entry.id);
                                              },
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
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
