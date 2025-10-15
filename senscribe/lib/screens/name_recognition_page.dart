import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NameRecognitionPage extends StatelessWidget {
  const NameRecognitionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Name Recognition', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text(
              'Name recognition',
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
                    Text('Configure name recognition behavior and haptic feedback.'),
                    SizedBox(height: 8),
                    Text('- Enable/disable recognition'),
                    Text('- Enter name to prioritize'),
                    Text('- Choose haptic pattern'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open name recognition editor (placeholder)'))),
                    child: const Text('Edit name recognition'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Haptic patterns'),
                      content: const Text('Select the haptic pattern used when a recognized name appears.'),
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
