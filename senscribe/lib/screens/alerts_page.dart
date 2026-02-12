import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/trigger_word_service.dart';
import '../models/trigger_word.dart';
import '../models/trigger_alert.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final TriggerWordService _triggerWordService = TriggerWordService();
  final TextEditingController _newWordController = TextEditingController();
  int _selectedTabIndex = 0; // 0 = Alerts, 1 = Trigger Words

  @override
  void dispose() {
    _newWordController.dispose();
    super.dispose();
  }

  void _showAddTriggerWordDialog() {
    _newWordController.clear();
    bool caseSensitive = false;
    bool exactMatch = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Add Trigger Word',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _newWordController,
                  decoration: InputDecoration(
                    labelText: 'Trigger Word',
                    hintText: 'Enter word to monitor',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: Text(
                    'Case Sensitive',
                    style: GoogleFonts.inter(),
                  ),
                  value: caseSensitive,
                  onChanged: (value) {
                    setState(() => caseSensitive = value ?? false);
                  },
                ),
                CheckboxListTile(
                  title: Text(
                    'Exact Word Match (whole word only)',
                    style: GoogleFonts.inter(),
                  ),
                  value: exactMatch,
                  onChanged: (value) {
                    setState(() => exactMatch = value ?? true);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_newWordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Please enter a trigger word')),
                  );
                  return;
                }

                final wordToAdd = _newWordController.text.trim();
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);

                await _triggerWordService.addTriggerWord(
                  TriggerWord(
                    word: wordToAdd,
                    caseSensitive: caseSensitive,
                    exactMatch: exactMatch,
                  ),
                );

                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Added trigger word: $wordToAdd'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: Text(
                'Add',
                style: GoogleFonts.inter(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Alerts',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header gradient
          Container(
            width: double.infinity,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Alert Management',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Monitor trigger words in your text',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tab selector
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 0
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Recent Alerts',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 0
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTabIndex = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _selectedTabIndex == 1
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Trigger Words',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          color: _selectedTabIndex == 1
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _selectedTabIndex == 0
                ? _buildAlertsTab()
                : _buildTriggerWordsTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsTab() {
    return StreamBuilder<List<TriggerAlert>>(
      stream: _triggerWordService.alertsStream,
      builder: (context, snapshot) {
        return FutureBuilder<List<TriggerAlert>>(
          future: _triggerWordService.loadAlerts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final alerts = snapshot.data ?? [];

            if (alerts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_rounded,
                      size: 80,
                      color: Colors.grey[400],
                    ).animate().scale(duration: 600.ms),
                    const SizedBox(height: 24),
                    Text(
                      'No trigger word alerts yet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add trigger words and use text-to-speech to generate alerts',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ).animate().fadeIn(duration: 800.ms),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      Icons.warning_rounded,
                      color: Colors.orange,
                    ),
                    title: Text(
                      'Trigger: "${alert.triggerWord}"',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          alert.detectedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTime(alert.timestamp),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _triggerWordService.removeAlert(alert.id);
                      },
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTriggerWordsTab() {
    return FutureBuilder<List<TriggerWord>>(
      future: _triggerWordService.loadTriggerWords(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final words = snapshot.data ?? [];

        return StreamBuilder<List<TriggerWord>>(
          stream: _triggerWordService.triggerWordsStream,
          builder: (context, streamSnapshot) {
            final displayWords =
                streamSnapshot.hasData ? streamSnapshot.data ?? words : words;

            if (displayWords.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.label_off_rounded,
                      size: 80,
                      color: Colors.grey[400],
                    ).animate().scale(duration: 600.ms),
                    const SizedBox(height: 24),
                    Text(
                      'No trigger words yet',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add words to monitor in your text',
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddTriggerWordDialog,
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add Trigger Word',
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 800.ms),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayWords.length + 1,
              itemBuilder: (context, index) {
                if (index == displayWords.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: ElevatedButton.icon(
                        onPressed: _showAddTriggerWordDialog,
                        icon: const Icon(Icons.add),
                        label: Text(
                          'Add Trigger Word',
                          style: GoogleFonts.inter(),
                        ),
                      ),
                    ),
                  );
                }

                final word = displayWords[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Icon(
                      word.enabled
                          ? Icons.label_rounded
                          : Icons.label_off_rounded,
                      color: word.enabled ? Colors.blue : Colors.grey,
                    ),
                    title: Text(
                      '"${word.word}"',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        if (word.caseSensitive)
                          Chip(
                            label: Text(
                              'Case Sensitive',
                              style: GoogleFonts.inter(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        const SizedBox(width: 8),
                        if (word.exactMatch)
                          Chip(
                            label: Text(
                              'Exact Match',
                              style: GoogleFonts.inter(fontSize: 10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          onTap: () async {
                            await _triggerWordService.updateTriggerWord(
                              word.word,
                              word.copyWith(enabled: !word.enabled),
                            );
                          },
                          child: Text(word.enabled ? 'Disable' : 'Enable'),
                        ),
                        PopupMenuItem(
                          onTap: () async {
                            await _triggerWordService
                                .removeTriggerWord(word.word);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1);
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
