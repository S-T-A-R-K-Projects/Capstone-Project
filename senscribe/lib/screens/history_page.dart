
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
}

class HistoryPage extends StatelessWidget {
  HistoryPage({super.key});

  final List<HistoryEntry> _entries = [
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

  String _formatTimestamp(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
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
            child: ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (context, index) {
                final entry = _entries[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.audiotrack, size: 18)),
                  title: Text(entry.title, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  subtitle: Text('${entry.subtitle} • ${_formatTimestamp(entry.timestamp)}', style: GoogleFonts.inter()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
