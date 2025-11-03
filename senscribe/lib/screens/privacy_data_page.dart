import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyDataPage extends StatelessWidget {
  const PrivacyDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Privacy & Data', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Privacy & data',
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
                    Text('Control how data is processed and stored.'),
                    SizedBox(height: 8),
                    Text('- On-device processing (prefer local models)'),
                    Text('- Export history (download or share)'),
                    Text('- Delete history (permanently remove saved captions)'),
                    Text('- Manage consents'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting history (placeholder)'))),
                    child: const Text('Export history'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete history?'),
                      content: const Text('This will permanently delete all saved captions.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                        TextButton(onPressed: () { Navigator.of(context).pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History deleted (placeholder)'))); }, child: const Text('Delete')),
                      ],
                    ),
                  ),
                  child: const Text('Delete history'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
