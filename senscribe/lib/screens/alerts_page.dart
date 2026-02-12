import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
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
                  decoration: const InputDecoration(
                    hintText: 'Enter word to monitor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: caseSensitive,
                      onChanged: (value) {
                        setState(() => caseSensitive = value ?? false);
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Case Sensitive',
                      style: GoogleFonts.inter(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: exactMatch,
                      onChanged: (value) {
                        setState(() => exactMatch = value ?? true);
                      },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Exact Word Match (whole word only)',
                        style: GoogleFonts.inter(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (_newWordController.text.isEmpty) {
                  AdaptiveSnackBar.show(
                    context,
                    message: 'Please enter a trigger word',
                    type: AdaptiveSnackBarType.warning,
                  );
                  return;
                }

                final wordToAdd = _newWordController.text.trim();
                final navigator = Navigator.of(context);

                await _triggerWordService.addTriggerWord(
                  TriggerWord(
                    word: wordToAdd,
                    caseSensitive: caseSensitive,
                    exactMatch: exactMatch,
                  ),
                );

                if (mounted) {
                  navigator.pop();
                  AdaptiveSnackBar.show(
                    this.context,
                    message: 'Added trigger word: $wordToAdd',
                    type: AdaptiveSnackBarType.success,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: 'Alerts',
      ),
      body: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            // Top padding for iOS 26 translucent app bar
            if (PlatformInfo.isIOS26OrHigher())
              SizedBox(
                  height: MediaQuery.of(context).padding.top + kToolbarHeight),
            // Tab selector using AdaptiveSegmentedControl
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: AdaptiveSegmentedControl(
                  labels: const ['Recent Alerts', 'Trigger Words'],
                  selectedIndex: _selectedTabIndex,
                  onValueChanged: (index) {
                    setState(() => _selectedTabIndex = index);
                  },
                ),
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdaptiveCard(
                    padding: EdgeInsets.zero,
                    child: AdaptiveListTile(
                      leading: const Icon(
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
                      trailing: AdaptiveButton.icon(
                        icon: Icons.delete_outline,
                        onPressed: () async {
                          await _triggerWordService.removeAlert(alert.id);
                        },
                        style: AdaptiveButtonStyle.plain,
                      ),
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
                    AdaptiveButton(
                      onPressed: _showAddTriggerWordDialog,
                      label: 'Add Trigger Word',
                      style: AdaptiveButtonStyle.filled,
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
                      child: AdaptiveButton(
                        onPressed: _showAddTriggerWordDialog,
                        label: 'Add Trigger Word',
                        style: AdaptiveButtonStyle.filled,
                      ),
                    ),
                  );
                }

                final word = displayWords[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AdaptiveCard(
                    padding: EdgeInsets.zero,
                    child: AdaptiveListTile(
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
                      trailing: AdaptivePopupMenuButton.icon<String>(
                        icon: 'ellipsis.circle',
                        items: [
                          AdaptivePopupMenuItem(
                            label: word.enabled ? 'Disable' : 'Enable',
                            value: 'toggle',
                          ),
                          AdaptivePopupMenuItem(
                            label: 'Delete',
                            value: 'delete',
                          ),
                        ],
                        onSelected: (index, item) async {
                          if (item.value == 'toggle') {
                            await _triggerWordService.updateTriggerWord(
                              word.word,
                              word.copyWith(enabled: !word.enabled),
                            );
                          } else if (item.value == 'delete') {
                            await _triggerWordService
                                .removeTriggerWord(word.word);
                          }
                        },
                      ),
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
