import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExperimentalPage extends StatelessWidget {
  const ExperimentalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Experimental (P3)', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Experimental features',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('These features are experimental and may be unstable.'),
                    SizedBox(height: 8),
                    Text('- Summarization: Produce short summaries of recent audio.'),
                    Text('- Voice-to-Text: Beta speech recognition pipeline.'),
                    Text('- Text-to-Speech: Read captions aloud.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Experimental toggles placeholder')));
                    },
                    child: const Text('Manage experimental features'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Experimental Features'),
                      content: const Text('Experimental features may change. Use with caution.'),
                      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
                    ),
                  ),
                  child: const Text('View'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
